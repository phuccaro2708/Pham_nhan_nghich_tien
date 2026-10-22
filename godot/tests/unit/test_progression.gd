extends GutTest
## Phase 2A: number range, lifespan, realms/breakthrough, content migration.

var reg: ContentRegistry
var act: ActionSystem
var s: GameState


func before_each() -> void:
	var w: Dictionary = TestHelpers.world()
	reg = w["reg"]
	act = w["act"]
	s = w["state"]


# --- content ------------------------------------------------------------------------------------

func test_real_content_has_no_errors() -> void:
	assert_eq(reg.errors, [])
	assert_eq(reg.realm_order.size(), 13)


func test_bad_references_are_reported() -> void:
	var r := TestHelpers.mini_registry([
		{"id": "a", "type": "INSTANT", "name_key": "a", "effects": [], "age_cost_years": 0,
			"requirements": {"all_of": [{"type": "action_count_at_least", "action": "ghost", "count": 1}]}},
		{"id": "b", "type": "INSTANT", "name_key": "b", "effects": [], "age_cost_years": 0,
			"requirements": {"all_of": [{"type": "realm_at_least", "realm": "ghost"}]}},
	])
	assert_true(r.errors.size() >= 2, str(r.errors))


# --- numbers ------------------------------------------------------------------------------------

func test_large_amounts_survive_json_roundtrip() -> void:
	for v in [1.0e7 + 0.123456, 9.99999999e7 + 0.5, 1.0e8 + 3.0, 123456789012345.0, ResourceSystem.MAX_AMOUNT]:
		var x: float = GameState.snap(v)
		assert_eq(float(JSON.parse_string(JSON.stringify({"v": x}))["v"]), x, str(v))


func test_amount_is_clamped_to_max() -> void:
	var res := ResourceSystem.new(reg)
	res.add(s, "silver", 1.0e16)
	assert_eq(s.resources["silver"], ResourceSystem.MAX_AMOUNT)


func test_cultivation_cap_follows_realm() -> void:
	s.realm_id = "luyen_khi_1"
	assert_eq(ResourceSystem.new(reg).cap_of("cultivation", s), 200.0)
	s.realm_id = "luyen_khi_2"
	assert_eq(ResourceSystem.new(reg).cap_of("cultivation", s), 360.0)


# --- lifespan -----------------------------------------------------------------------------------

func test_warning_emitted_once_near_the_limit() -> void:
	var seen: Array = []
	act.lifespan.lifespan_warning.connect(func(r: float) -> void: seen.append(r))
	s.age_years = 80.0 - 5.0 - 0.001
	act.start_action(s, "gather_wood")
	act.advance(s, 50)  # +0.002 -> 4.999 left
	act.advance(s, 50)
	assert_eq(seen.size(), 1)
	assert_true(act.lifespan.is_warning(s))


func test_death_at_limit_stops_everything() -> void:
	var ended: Array = []
	act.lifespan.life_ended.connect(func(a: float) -> void: ended.append(a))
	s.age_years = 80.0 - 0.001
	act.start_action(s, "gather_wood")
	act.advance(s, 50)
	assert_eq(s.age_years, 80.0)  # clamped, never above the limit
	assert_eq(s.life["status"], "deceased")
	assert_eq(ended.size(), 1)
	assert_true(s.active_action.is_empty())
	var wood: float = s.resources["wood"]
	act.advance(s, 500)
	assert_eq(s.resources["wood"], wood)
	var r := act.start_action(s, "gather_wood")
	assert_false(r["ok"])
	assert_eq(r["reason"], "deceased")
	assert_eq(s.life["ended"]["age_years"], 80.0)


func test_no_age_when_start_is_refused() -> void:
	var age: float = s.age_years
	assert_false(act.start_action(s, "sell_wood")["ok"])
	assert_false(act.start_action(s, "absorb_qi")["ok"])  # realm requirement
	assert_eq(s.age_years, age)


func test_breakthrough_to_longer_life_rearms_warning() -> void:
	s.realm_id = "luyen_khi_9"
	s.age_years = 120.0 - 3.0
	s.life["warned"] = true
	s.resources["cultivation"] = 11020.0
	s.resources["silver"] = 500.0
	s.breakthrough_failures = 3  # pity: certain
	assert_true(act.start_action(s, "breakthrough")["ok"])
	assert_eq(s.realm_id, "truc_co_so")
	assert_eq(s.life["warned"], false)
	assert_false(act.lifespan.is_warning(s))


# --- realms -------------------------------------------------------------------------------------

func test_breakthrough_needs_the_stage_cost() -> void:
	var r := act.start_action(s, "breakthrough")
	assert_false(r["ok"])
	assert_eq(r["reason"], "insufficient_resources")
	s.resources["body"] = 30.0
	assert_true(act.start_action(s, "breakthrough")["ok"])
	assert_eq(s.realm_id, "cuong_than")
	assert_eq(s.resources["body"], 0.0)


func test_failed_ritual_damages_meridians_and_pity_guarantees() -> void:
	var failed: bool = false
	for seed_value in range(1, 60):  # P(success)=0.45 here, so a failing seed exists
		s.realm_id = "luyen_khi_9"
		s.flags["meridian_damaged"] = false
		s.breakthrough_failures = 0
		s.resources["cultivation"] = 11020.0
		s.resources["silver"] = 500.0
		s.rng_state = SimRng.seed_to_state(seed_value)
		act.start_action(s, "breakthrough")
		if s.realm_id == "luyen_khi_9":
			failed = true
			break
	assert_true(failed)
	assert_eq(s.flags["meridian_damaged"], true)
	assert_eq(s.breakthrough_failures, 1)
	assert_eq(s.resources["cultivation"], 0.0)  # the price is paid even on failure
	assert_false(act.start_action(s, "breakthrough")["ok"])  # blocked until treated
	s.breakthrough_failures = 3
	s.flags["meridian_damaged"] = false
	s.resources["cultivation"] = 11020.0
	s.resources["silver"] = 500.0
	assert_true(act.start_action(s, "breakthrough")["ok"])
	assert_eq(s.realm_id, "truc_co_so")
	assert_eq(s.breakthrough_failures, 0)


func test_last_stage_cannot_advance() -> void:
	s.realm_id = "truc_co_so"
	assert_eq(act.start_action(s, "breakthrough")["reason"], "max_realm")


func test_realm_gates_actions() -> void:
	assert_false(act.start_action(s, "refine_qi")["ok"])
	s.realm_id = "luyen_khi_1"
	assert_true(act.start_action(s, "absorb_qi")["ok"])


# --- content migration --------------------------------------------------------------------------

func _save(extra: Dictionary) -> Dictionary:
	var d: Dictionary = GameState.new_game(3).to_dict()
	d.merge(extra, true)
	return d


func test_rename_applies_and_unknown_goes_to_orphans() -> void:
	reg.content_version = 2
	reg.migrations = [{"to_version": 2, "renames": {"resources": {"old_wood": "wood"}}}]
	var d := _save({"resources": {"old_wood": 7.0, "mystery": 4.0}})
	var m := ContentMigration.apply(d, reg)
	assert_eq(m["resources"]["wood"], 7.0)
	assert_false(m["resources"].has("old_wood"))
	assert_eq(m["orphans"]["resources"], {"mystery": 4.0})
	assert_eq(m["content_version"], 2)
	assert_eq(d["resources"].has("mystery"), true)  # input untouched


func test_rename_never_overwrites_existing_target() -> void:
	reg.content_version = 2
	reg.migrations = [{"to_version": 2, "renames": {"resources": {"old_wood": "wood"}}}]
	var m := ContentMigration.apply(_save({"resources": {"old_wood": 7.0, "wood": 5.0}}), reg)
	assert_eq(m["resources"]["wood"], 5.0)
	assert_eq(m["orphans"]["resources"]["old_wood"], 7.0)


func test_orphans_return_when_id_returns() -> void:
	var m := ContentMigration.apply(_save({"orphans": {"resources": {"wood": 9.0}}}), reg)
	assert_eq(m["resources"]["wood"], 9.0)
	assert_false(m["orphans"].has("resources"))


func test_unknown_active_action_is_cancelled_with_refund() -> void:
	var a := {"id": "gone", "progress_ticks": 3, "duration_ticks": 9, "costs_paid": {"silver": 4.0, "mystery": 1.0}}
	var m := ContentMigration.apply(_save({"active_action": a, "resources": {"silver": 1.0}}), reg)
	assert_eq(m["active_action"], {})
	assert_eq(m["resources"]["silver"], 5.0)
	assert_eq(m["orphans"]["active_actions"]["gone"]["id"], "gone")


func test_v1_save_loads_as_v2() -> void:
	var sm: Node = load("res://autoload/save_manager.gd").new()
	var d := GameState.new_game(3).to_dict()
	for k in ["content_version", "realm_id", "breakthrough_failures", "life", "orphans"]:
		d.erase(k)
	d["schema_version"] = 1
	var m: Dictionary = ContentMigration.apply(sm.migrate(d), reg)
	assert_eq(m["schema_version"], 2)
	assert_eq(sm.validate_state(m, reg), [])
	sm.free()


func test_save_from_newer_content_is_rejected_and_file_kept() -> void:
	var sm: Node = load("res://autoload/save_manager.gd").new()
	sm.save_path = "user://test_saves/newer.json"
	DirAccess.make_dir_recursive_absolute("user://test_saves")
	var st := GameState.new_game(3)
	st.content_version = 1
	assert_eq(sm.save_game(st, reg), OK)
	var before := FileAccess.get_file_as_string(sm.save_path)
	reg.content_version = 0  # simulate an older build reading a newer save
	assert_true(sm.load_game(reg).has("error"))
	assert_eq(FileAccess.get_file_as_string(sm.save_path), before)
	DirAccess.remove_absolute(sm.save_path)
	sm.free()


# --- regressions from the Phase 2A audit (Codex review of Phase 1, verified by hand) ---------------

func test_failed_switch_at_max_amount_loses_nothing() -> void:
	s.flags["meridian_damaged"] = true
	s.resources["silver"] = 1000.0
	assert_true(act.start_action(s, "treat_meridian")["ok"])  # pays 50
	s.resources["silver"] = ResourceSystem.MAX_AMOUNT
	s.resources["wood"] = 200.0  # gather_wood's reward is fully capped -> cannot start
	assert_false(act.start_action(s, "gather_wood")["ok"])
	assert_eq(s.resources["silver"], ResourceSystem.MAX_AMOUNT)
	assert_eq(s.active_action["id"], "treat_meridian")


func test_listener_cannot_make_a_switch_free_or_lose_costs() -> void:
	s.flags["meridian_damaged"] = true
	s.resources["silver"] = 60.0
	act.start_action(s, "treat_meridian")  # silver 10 left, 50 paid
	act.action_stopped.connect(func(_id: String, _why: String) -> void: act.start_action(s, "gather_wood"))
	var r := act.start_action(s, "train_body")
	assert_false(r["ok"])
	assert_eq(r["reason"], "interrupted")
	assert_eq(s.active_action["id"], "gather_wood")


func test_initial_above_max_amount_is_a_content_error() -> void:
	var r := ContentRegistry.new()
	r.add_definitions("resource", [{"id": "x", "name_key": "x", "cap": null, "initial": 2.0e15}])
	r.validate()
	assert_false(r.errors.is_empty())


func test_two_orphan_actions_are_both_kept() -> void:
	var a1 := {"id": "gone1", "progress_ticks": 1, "duration_ticks": 9, "costs_paid": {}}
	var m := ContentMigration.apply(_save({"active_action": a1}), reg)
	var a2 := {"id": "gone2", "progress_ticks": 1, "duration_ticks": 9, "costs_paid": {}}
	m["active_action"] = a2
	m = ContentMigration.apply(m, reg)
	assert_eq(m["orphans"]["active_actions"].keys().size(), 2)


func test_v1_save_at_the_age_limit_is_deceased_not_revived() -> void:
	var m := ContentMigration.apply(_save({"age_years": 80.0}), reg)
	assert_eq(m["life"]["status"], "deceased")
	var sm: Node = load("res://autoload/save_manager.gd").new()
	assert_eq(sm.validate_state(m, reg), [])
	m["life"] = {"status": "alive", "warned": false, "ended": {}}
	assert_false(sm.validate_state(m, reg).is_empty())  # alive at the limit is impossible
	sm.free()


func test_deceased_with_running_action_does_not_complete_it() -> void:
	act.start_action(s, "gather_wood")
	s.life = {"status": "deceased", "warned": true, "ended": {"age_years": 16.0}}
	act.advance(s, 100)
	assert_eq(s.resources.get("wood", 0.0), 0.0)
	assert_true(s.active_action.is_empty())


# --- review follow-ups ----------------------------------------------------------------------------

func test_realm_rename_and_unknown_realm_are_migrated() -> void:
	reg.content_version = 2
	reg.migrations = [{"to_version": 2, "renames": {"realms": {"old_cam_khi": "cam_khi"}}}]
	var m := ContentMigration.apply(_save({"realm_id": "old_cam_khi"}), reg)
	assert_eq(m["realm_id"], "cam_khi")
	m = ContentMigration.apply(_save({"realm_id": "vanished"}), reg)
	assert_eq(m["realm_id"], "")
	assert_eq(m["orphans"]["realm_id"], "vanished")
	var sm: Node = load("res://autoload/save_manager.gd").new()
	assert_eq(sm.validate_state(m, reg), [])
	sm.free()


func test_garbage_version_fields_return_errors_not_crashes() -> void:
	var sm: Node = load("res://autoload/save_manager.gd").new()
	sm.save_path = "user://test_saves/garbage.json"
	DirAccess.make_dir_recursive_absolute("user://test_saves")
	assert_true(sm.migrate({"schema_version": [1]}).has("error"))
	for bad in [[1], {"a": 1}, "x"]:
		var d := GameState.new_game(3).to_dict()
		d["content_version"] = bad
		var payload := JSON.stringify(d)
		var f := FileAccess.open(sm.save_path, FileAccess.WRITE)
		f.store_string(JSON.stringify({"schema_version": 2, "checksum": payload.sha256_text(), "payload": payload}))
		f.close()
		assert_true(sm.load_game(reg).has("error"))
	DirAccess.remove_absolute(sm.save_path)
	sm.free()


func test_new_game_keeps_orphans() -> void:
	var gc: Node = load("res://autoload/game_controller.gd").new()
	gc.registry = reg
	gc.state = GameState.new_game(1)
	gc.state.orphans = {"resources": {"mystery": 3.0}}
	gc.new_game(2)
	assert_eq(gc.state.orphans, {"resources": {"mystery": 3.0}})
	gc.free()


func test_offline_across_death_stops_progress() -> void:
	s.age_years = 80.0 - 0.1  # 50 gather cycles of 0.002 would pass the limit
	act.start_action(s, "gather_wood")
	var rep := OfflineSystem.apply(s, act, 3600.0)
	assert_eq(s.life["status"], "deceased")
	assert_eq(s.age_years, 80.0)
	assert_true(s.resources["wood"] <= 200.0)
	assert_true(s.active_action.is_empty())
	assert_true(rep["seconds_simulated"] > 0.0)
	var wood: float = s.resources["wood"]
	OfflineSystem.apply(s, act, 3600.0)
	assert_eq(s.resources["wood"], wood)


func test_replace_failure_restores_resources_in_place() -> void:
	var held: Dictionary = s.resources
	s.flags["meridian_damaged"] = true
	s.resources["silver"] = 100.0
	act.start_action(s, "treat_meridian")
	s.resources["wood"] = 200.0
	assert_false(act.start_action(s, "gather_wood")["ok"])
	assert_true(is_same(held, s.resources))
	assert_eq(s.resources["silver"], 50.0)
