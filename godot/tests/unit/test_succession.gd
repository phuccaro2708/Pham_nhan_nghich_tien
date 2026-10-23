extends GutTest
## V10 truyền thừa: hết thọ nguyên không còn cụt; hậu duệ nối dòng giữ story/tri thức/Đạo Quả, làm mới thân xác.

const DIR := "user://test_succession"

var act: ActionSystem
var s: GameState
var reg: ContentRegistry
var sm: Node


func before_each() -> void:
	var w: Dictionary = TestHelpers.world(9, true)
	act = w["act"]
	s = w["state"]
	reg = act.registry
	sm = load("res://autoload/save_manager.gd").new()
	sm.save_path = DIR + "/s.json"
	_wipe()


func after_each() -> void:
	_wipe()
	sm.free()


func _wipe() -> void:
	DirAccess.make_dir_recursive_absolute(DIR)
	for f in DirAccess.get_files_at(DIR):
		DirAccess.remove_absolute(DIR + "/" + f)


## An ancestor in Luyện Khí 5 with a past, dead of old age.
func _dead_ancestor() -> void:
	s.realm_id = "luyen_khi_5"
	s.age_years = 120.0
	s.story["done"]["ch1_wounded_taoist"] = "heal"
	s.resources["silver"] = 500.0
	s.upgrades["iron_axe"] = 3
	s.mastery["gather_wood"] = {"level": 8, "xp": 0.0, "claimed": []}
	s.flags["meridian_damaged"] = true
	s.flags["qi_sensed"] = true
	s.wounds = 2
	s.techniques = ["dan_khi_nhap_mon", "thanh_moc_duong_khi", "huyet_luyen_than_kinh"]
	s.main_technique = "thanh_moc_duong_khi"
	s.life = {"status": "deceased", "warned": true, "ended": {"age_years": 120.0, "realm_id": "luyen_khi_5", "game_time_ticks": 5}}


func _roundtrip(st: GameState) -> GameState:
	return GameState.from_dict(JSON.parse_string(JSON.stringify(st.to_dict())))


func test_living_character_cannot_succeed() -> void:
	var before := s.to_dict()
	var r: Dictionary = act.legacy.succeed(s)
	assert_false(r["ok"])
	assert_eq(r["reason"], "still_alive")
	assert_eq(s.to_dict(), before)


func test_succession_keeps_the_line_and_renews_the_body() -> void:
	_dead_ancestor()
	var know: Array = s.knowledge.duplicate()
	var dungeon_clears: Dictionary = {"bamboo_forest": 2}
	s.dungeon_clears = dungeon_clears.duplicate()
	var r: Dictionary = act.legacy.succeed(s)
	assert_true(r["ok"], str(r))
	assert_eq(s.life, {"status": "alive", "warned": false, "ended": {}})
	assert_eq(s.legacy["generation"], 2)
	assert_eq(s.legacy["lineage"].size(), 1)
	assert_eq(s.legacy["lineage"][0]["realm_id"], "luyen_khi_5")
	# kept
	assert_eq(s.story["done"]["ch1_wounded_taoist"], "heal")
	assert_eq(s.knowledge, know)
	assert_eq(s.dungeon_clears, dungeon_clears)
	assert_true(s.flags.get("qi_sensed", false))
	assert_true(s.techniques.has("dan_khi_nhap_mon"))
	assert_true(s.techniques.has("thanh_moc_duong_khi"), "the ancestor's main technique stays as a memory")
	assert_false(s.techniques.has("huyet_luyen_than_kinh"), "other main techniques are lost")
	# renewed
	assert_eq(s.main_technique, "")
	assert_eq(s.realm_id, "cuong_than")
	assert_eq(s.age_years, GameState.START_AGE_YEARS)
	assert_eq(s.wounds, 0)
	assert_false(s.flags.has("meridian_damaged"))
	assert_true(s.upgrades.is_empty() and s.mastery.is_empty() and s.relations.is_empty() and s.action_counts.is_empty())
	assert_eq(s.resources["silver"], float(reg.resources["silver"].get("initial", 0.0)))
	assert_true(s.checkpoint.is_empty())
	assert_eq(sm.validate_state(s.to_dict(), reg), [])


func test_dao_qua_is_paid_once() -> void:
	_dead_ancestor()
	var first: Dictionary = act.legacy.succeed(s)
	assert_gt(first["dao_qua"], 0)
	var second: Dictionary = act.legacy.succeed(s)
	assert_false(second["ok"])
	assert_eq(s.legacy["dao_qua"], first["dao_qua"])
	assert_eq(s.legacy["generation"], 2)


func test_dao_qua_formula_and_no_farming() -> void:
	_dead_ancestor()
	var c: Dictionary = act.legacy.cfg()
	var steps: int = reg.realm_index("luyen_khi_5") - reg.realm_index(c["start_realm"])
	var p: float = steps * float(c["w_realm"]) + 7 * float(c["w_mastery"])
	assert_eq(act.legacy.dao_qua_for(s), int(floor(float(c["scale"]) * sqrt(p / float(c["p0"])))))
	act.legacy.succeed(s)
	# the heir dies at once having done nothing: the ancestor's work is not paid again
	s.age_years = 80.0
	s.life = {"status": "deceased", "warned": true, "ended": {"age_years": 80.0, "realm_id": "cuong_than", "game_time_ticks": 9}}
	var before: int = s.legacy["dao_qua"]
	var r: Dictionary = act.legacy.succeed(s)
	assert_eq(r["dao_qua"], 0)
	assert_eq(s.legacy["dao_qua"], before)
	assert_eq(s.legacy["generation"], 3)


func test_legacy_bonus_is_derived_and_capped() -> void:
	var b: Dictionary = act.legacy.cfg()["bonuses"][0]
	var stat: String = b["stat"]
	assert_eq(act.effects.group_bonus(s, stat, "legacy"), 0.0)
	s.legacy["dao_qua"] = 1
	assert_almost_eq(act.effects.group_bonus(s, stat, "legacy"), float(b["per_dao_qua"]), 1e-9)
	s.legacy["dao_qua"] = 100000
	assert_eq(act.effects.group_bonus(s, stat, "legacy"), float(b["cap"]))
	assert_gte(act.effects.stat_bonus(s, stat), float(b["cap"]))


func test_rewind_does_not_undo_the_line() -> void:
	s.legacy = {"generation": 2, "dao_qua": 3, "lineage": [{"generation": 1, "realm_id": "cuong_than", "age_years": 80.0, "dao_qua": 3}]}
	act.effects.apply(s, [{"type": "set_checkpoint"}])
	s.legacy["dao_qua"] = 9
	act.effects.apply(s, [{"type": "rewind"}])
	assert_eq(s.legacy["dao_qua"], 9)
	assert_eq(s.legacy["generation"], 2)
	assert_false(GameState.WORLD_KEYS.has("legacy"))


func test_succession_through_save_load_equals_direct() -> void:
	_dead_ancestor()
	var direct := _roundtrip(s)
	act.legacy.succeed(direct)
	assert_eq(sm.save_game(s, reg, 1000), OK)
	var loaded: GameState = sm.load_game(reg)["state"]
	assert_eq(loaded.life["status"], "deceased")
	assert_true(act.legacy.succeed(loaded)["ok"])
	loaded.save_metadata = direct.save_metadata.duplicate()
	direct.content_version = loaded.content_version  # the fixture state predates ContentMigration.apply
	assert_eq(loaded.to_dict(), direct.to_dict())
	assert_eq(sm.save_game(loaded, reg, 2000), OK)
	assert_eq(sm.load_game(reg)["state"].legacy, loaded.legacy)


func test_v10_deceased_save_migrates_and_can_succeed() -> void:
	_dead_ancestor()
	var d: Dictionary = s.to_dict()
	d.erase("legacy")
	d["schema_version"] = 10
	var m: Dictionary = sm.migrate(d)
	assert_eq(m["schema_version"], GameState.SCHEMA_VERSION)
	assert_eq(m["legacy"], {"generation": 1, "dao_qua": 0, "lineage": []})
	assert_eq(sm.validate_state(m, reg), [])
	var old := GameState.from_dict(m)
	assert_eq(old.life["status"], "deceased")
	assert_true(act.legacy.succeed(old)["ok"])


func test_offline_stops_at_death_and_never_succeeds_itself() -> void:
	var w1: Dictionary = TestHelpers.world(5)
	var w2: Dictionary = TestHelpers.world(5)
	for w in [w1, w2]:
		w["state"].age_years = 80.0 - 0.01
		w["act"].start_action(w["state"], "gather_wood")
	var report: Dictionary = OfflineSystem.apply(w1["state"], w1["act"], 3600.0)
	w2["act"].advance(w2["state"], 36000)
	assert_eq(w1["state"].life["status"], "deceased")
	assert_eq(w1["state"].legacy["generation"], 1, "offline never chooses for the player")
	assert_eq(w1["state"].to_dict(), w2["state"].to_dict())
	assert_true(w1["act"].legacy.succeed(w1["state"])["ok"])
	assert_true(report["stop_reason"].begins_with("gather_wood:"), str(report["stop_reason"]))


func test_offline_capped_at_eight_hours_after_succession() -> void:
	_dead_ancestor()
	act.legacy.succeed(s)
	var r: Dictionary = OfflineSystem.apply(s, act, 20.0 * 3600.0)
	assert_true(r["capped"])
	assert_eq(r["seconds_simulated"], 8.0 * 3600.0)


func test_invalid_legacy_is_rejected() -> void:
	_dead_ancestor()
	act.legacy.succeed(s)
	var good: Dictionary = s.to_dict()
	assert_eq(sm.validate_state(good, reg), [])
	var muts: Array = [
		func(l: Dictionary) -> void: l["dao_qua"] = NAN,
		func(l: Dictionary) -> void: l["dao_qua"] = -1,
		func(l: Dictionary) -> void: l["dao_qua"] = int(l["dao_qua"]) + 5,
		func(l: Dictionary) -> void: l["generation"] = 0,
		func(l: Dictionary) -> void: l["generation"] = 7,
		func(l: Dictionary) -> void: l["lineage"][0]["realm_id"] = "khong_co",
		func(l: Dictionary) -> void: l["lineage"][0]["age_years"] = -3.0,
		func(l: Dictionary) -> void: l["lineage"][0]["generation"] = 2,
		func(l: Dictionary) -> void: l["lineage"][0]["dao_qua"] = 0.5,
	]
	for i in muts.size():
		var c: Dictionary = good.duplicate(true)
		muts[i].call(c["legacy"])
		assert_false(sm.validate_state(c, reg).is_empty(), "mutation %d" % i)
	var c2: Dictionary = good.duplicate(true)
	c2["legacy"] = []
	assert_false(sm.validate_state(c2, reg).is_empty())


func test_config_validation_catches_bad_start_realm() -> void:
	for bad in ["vo", "khong_co"]:
		var r := TestHelpers.real_registry()
		r.config["legacy"]["start_realm"] = bad
		r.errors.clear()
		r.validate()
		assert_false(r.errors.is_empty(), bad)
	assert_true(TestHelpers.real_registry().errors.is_empty())


func test_milestone_reward_is_paid_once_per_line() -> void:
	_dead_ancestor()
	s.mastery["gather_wood"] = {"level": 10, "xp": 0.0, "claimed": [5, 10]}
	assert_true(act.legacy.succeed(s)["ok"])
	var silver: float = s.resources["silver"]
	assert_eq(s.mastery["gather_wood"]["level"], 1, "levels are the body's")
	var def: Dictionary = reg.mastery_for_action("gather_wood")
	s.mastery["gather_wood"]["level"] = 9
	s.mastery["gather_wood"]["xp"] = act.mastery.xp_required(def, 9)
	act.mastery.on_completed(s, "gather_wood")
	assert_eq(s.mastery["gather_wood"]["level"], 10)
	assert_eq(s.resources["silver"], silver, "the level-10 reward was already paid to the line")
	assert_eq(_roundtrip(s).mastery["gather_wood"]["claimed"], [5, 10])


func test_heir_does_not_skip_a_stage_the_ancestor_never_left() -> void:
	_dead_ancestor()
	s.realm_id = "vo"
	assert_true(act.legacy.succeed(s)["ok"])
	assert_eq(s.realm_id, "vo")
	assert_eq(act.legacy.dao_qua_for(s), 0)


func test_can_succeed_needs_config_and_death() -> void:
	assert_false(act.legacy.can_succeed(s))
	_dead_ancestor()
	assert_true(act.legacy.can_succeed(s))
	reg.config.erase("legacy")
	assert_false(act.legacy.can_succeed(s))


func test_config_validation_catches_bad_flags_and_stats() -> void:
	for mut in [func(l: Dictionary) -> void: l["reset_flags"] = [123],
			func(l: Dictionary) -> void: l["bonuses"][0]["stat"] = "speed.khong_co"]:
		var r := TestHelpers.real_registry()
		mut.call(r.config["legacy"])
		r.errors.clear()
		r.validate()
		assert_false(r.errors.is_empty())


func test_heir_walks_back_to_truc_co_without_story() -> void:
	# the ancestor's story is done and never replays: the heir must still climb on its own (no softlock)
	var w: Dictionary = TestHelpers.world(11)
	var a: ActionSystem = w["act"]
	var st: GameState = w["state"]
	_climb(a, st)
	assert_eq(st.realm_id, "truc_co_so")
	gut.p("Tổ tiên tới Trúc Cơ: P=%.2f, tuổi %.1f, DQ=%d" % [a.legacy.points(st), st.age_years, a.legacy.dao_qua_for(st)])
	st.age_years = a.lifespan.limit(st)
	st.life = {"status": "deceased", "warned": true, "ended": {"age_years": st.age_years, "realm_id": st.realm_id, "game_time_ticks": st.game_time_ticks}}
	assert_true(a.legacy.succeed(st)["ok"])
	assert_gt(st.legacy["dao_qua"], 0)
	_climb(a, st)
	gut.p("Hậu duệ tới Trúc Cơ lần nữa: tuổi %.1f, %.2f giờ game-time tổng" % [st.age_years, st.game_time_ticks / 36000.0])
	assert_eq(st.realm_id, "truc_co_so", "heir stuck at %s age %.1f" % [st.realm_id, st.age_years])
	assert_eq(st.life["status"], "alive")


func _climb(a: ActionSystem, st: GameState) -> void:
	TestHelpers.climb_to(a, st)
