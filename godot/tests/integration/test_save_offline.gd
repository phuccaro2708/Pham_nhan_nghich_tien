extends GutTest

const DIR := "user://test_saves"

var reg: ContentRegistry
var sm: Node


func before_each() -> void:
	reg = TestHelpers.real_registry()
	sm = load("res://autoload/save_manager.gd").new()
	sm.save_path = DIR + "/s.json"
	_wipe()


func after_each() -> void:
	_wipe()
	sm.free()


func _wipe() -> void:
	for f in DirAccess.get_files_at(DIR):
		DirAccess.remove_absolute(DIR + "/" + f)


func _busy_state() -> GameState:
	var act := ActionSystem.new(reg)
	var s := GameState.new_game(5)
	s.resources["wood"] = 37.0
	s.upgrades["iron_axe"] = 2
	act.start_action(s, "gather_wood")
	act.advance(s, 123)
	return s


func _overwrite(path: String, text: String) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(text)
	f.close()


# ---------- save / load ----------

func test_save_load_round_trip_is_exact() -> void:
	var s := _busy_state()
	s.content_version = reg.content_version  # load migrates to the newest content version
	assert_eq(sm.save_game(s, reg, 1000), OK)
	var r: Dictionary = sm.load_game(reg)
	assert_eq(r["source"], "main")
	var a: Dictionary = r["state"].to_dict()
	var b: Dictionary = s.to_dict()
	for k in b:
		assert_eq(a[k], b[k], "key " + k)


func test_save_load_does_not_duplicate_reward() -> void:
	var s := _busy_state()
	var act := ActionSystem.new(reg)
	var control := GameState.from_dict(s.to_dict())
	sm.save_game(s, reg, 1)
	var loaded: GameState = sm.load_game(reg)["state"]
	act.advance(loaded, 500)
	act.advance(control, 500)
	assert_eq(loaded.resources, control.resources)
	assert_eq(loaded.action_counts, control.action_counts)


func test_corrupt_main_falls_back_to_backup() -> void:
	var s := _busy_state()
	sm.save_game(s, reg, 1)
	var first_wood: float = s.resources["wood"]
	s.resources["wood"] = 1.0
	sm.save_game(s, reg, 2)  # first save becomes .bak
	_overwrite(sm.save_path, "{ truncated")
	var r: Dictionary = sm.load_game(reg)
	assert_eq(r["source"], "backup")
	assert_eq(r["state"].resources["wood"], first_wood)


func test_tampered_payload_detected() -> void:
	sm.save_game(_busy_state(), reg, 1)
	_overwrite(sm.save_path, FileAccess.get_file_as_string(sm.save_path).replace("gather_wood", "gather_wxod"))
	assert_true(sm.load_game(reg).has("error"))


func test_no_save_reports_error() -> void:
	assert_true(sm.load_game(reg).has("error"))
	assert_false(sm.has_save())


func test_validate_rejects_bad_data() -> void:
	var good: Dictionary = GameState.new_game().to_dict()
	assert_eq(sm.validate_state(good, reg), [])
	var cases: Array = []
	var d: Dictionary
	d = good.duplicate(true); d["resources"]["wood"] = NAN; cases.append(d)
	d = good.duplicate(true); d["resources"]["wood"] = -1.0; cases.append(d)
	d = good.duplicate(true); d["resources"]["wood"] = 2.0e15; cases.append(d)
	d = good.duplicate(true); d["resources"]["ghost"] = 1.0; cases.append(d)
	d = good.duplicate(true); d["upgrades"]["iron_axe"] = 99; cases.append(d)
	d = good.duplicate(true); d["age_years"] = INF; cases.append(d)
	d = good.duplicate(true); d["active_action"] = {"id": "nope", "progress_ticks": 0, "duration_ticks": 5}; cases.append(d)
	d = good.duplicate(true); d["active_action"] = {"id": "gather_wood", "progress_ticks": 9, "duration_ticks": 5}; cases.append(d)
	d = good.duplicate(true); d["game_time_ticks"] = -3; cases.append(d)
	for c in cases:
		assert_false(sm.validate_state(c, reg).is_empty(), str(c))


func test_migration_v0_to_v1() -> void:
	var old: Dictionary = GameState.new_game().to_dict()
	old.erase("age_years")
	old["age"] = 21.5
	old["schema_version"] = 0
	var m: Dictionary = sm.migrate(old)
	assert_eq(m["schema_version"], GameState.SCHEMA_VERSION)
	assert_eq(m["age_years"], 21.5)
	assert_eq(sm.validate_state(m, reg), [])
	assert_true(sm.migrate({"schema_version": 99}).has("error"))


func test_save_refuses_invalid_state_and_keeps_previous_save() -> void:
	var s := _busy_state()
	sm.save_game(s, reg, 1)
	var bad := GameState.new_game()
	bad.resources["wood"] = -5.0
	assert_eq(sm.save_game(bad, reg, 2), ERR_INVALID_DATA)
	assert_push_error_count(1)
	assert_eq(sm.load_game(reg)["state"].resources, s.resources)


# ---------- offline ----------

func test_offline_equals_online() -> void:
	var act := ActionSystem.new(reg)
	var a := _busy_state()
	var b := GameState.from_dict(a.to_dict())
	var report: Dictionary = OfflineSystem.apply(a, act, 3600.0)
	for i in 36000:
		act.advance(b, 1)
	assert_eq(a.to_dict(), b.to_dict())
	assert_eq(report["seconds_simulated"], 3600.0)
	assert_gt(report["completions"]["gather_wood"], 20)  # stops once wood is full


func test_advance_in_chunks_equals_one_jump() -> void:
	var act := ActionSystem.new(reg)
	var a := _busy_state()
	var b := GameState.from_dict(a.to_dict())
	act.advance(a, 12345)
	for n in [1, 7, 100, 4000, 8237]:
		act.advance(b, n)
	assert_eq(a.to_dict(), b.to_dict())


func test_offline_cap_8h() -> void:
	var act := ActionSystem.new(reg)
	var s := GameState.new_game(1)
	act.start_action(s, "gather_wood")
	var report: Dictionary = OfflineSystem.apply(s, act, 3.0 * 24 * 3600)
	assert_true(report["capped"])
	assert_eq(report["seconds_simulated"], 28800.0)
	assert_eq(s.game_time_ticks, 288000)
	assert_eq(s.resources["wood"], 200.0)  # hit the cap
	assert_eq(report["stop_reason"], "gather_wood:reward_capped")
	assert_eq(s.action_counts["gather_wood"], 67)  # ceil(200/3): stops once full, no age burned
	assert_almost_eq(report["age_delta"], 67 * 0.002, 1e-9)


func test_offline_ignores_negative_nan_and_tiny_elapsed() -> void:
	var act := ActionSystem.new(reg)
	for e in [-500.0, NAN, 0.5]:
		var s := _busy_state()
		var before: Dictionary = s.to_dict()
		OfflineSystem.apply(s, act, e)
		assert_eq(s.to_dict(), before)


func test_offline_disallowed_action_is_stopped_with_refund() -> void:
	var r2 := TestHelpers.mini_registry([{"id": "brew", "type": "TIMED", "duration": 2.0, "costs": {"wood": 10},
		"effects": [{"type": "add_resource", "resource": "silver", "amount": 9}], "offline_allowed": false}])
	var act := ActionSystem.new(r2)
	var s := GameState.new_game()
	s.resources["wood"] = 10.0
	act.start_action(s, "brew")
	var report: Dictionary = OfflineSystem.apply(s, act, 600.0)
	assert_eq(s.resources["wood"], 10.0)
	assert_eq(s.resources.get("silver", 0.0), 0.0)
	assert_eq(report["stop_reason"], "brew:offline_not_allowed")


func test_offline_report_flags_stalled_loop() -> void:
	var r2 := TestHelpers.mini_registry([{"id": "mill", "type": "LOOP", "duration": 1.0, "costs": {"wood": 10},
		"effects": [{"type": "add_resource", "resource": "silver", "amount": 1}], "offline_allowed": true}])
	var act := ActionSystem.new(r2)
	var s := GameState.new_game()
	s.resources["wood"] = 30.0
	act.start_action(s, "mill")
	var report: Dictionary = OfflineSystem.apply(s, act, 3600.0)
	assert_eq(report["completions"], {"mill": 3})
	assert_eq(report["stop_reason"], "mill:insufficient_resources")


func test_corrupt_main_does_not_destroy_good_backup() -> void:
	var s := _busy_state()
	sm.save_game(s, reg, 1)
	s.resources["wood"] = 2.0
	sm.save_game(s, reg, 2)  # main = wood 2, bak = first save
	_overwrite(sm.save_path, "{trunc")
	s.resources["wood"] = 3.0
	sm.save_game(s, reg, 3)  # must keep the good bak, not rotate the corrupt main into it
	assert_false(FileAccess.get_file_as_string(sm.save_path + ".bak").begins_with("{trunc"))
	assert_eq(sm.load_game(reg)["state"].resources["wood"], 3.0)
