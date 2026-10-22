extends GutTest


func test_clock_converts_time_to_whole_ticks() -> void:
	var c := SimulationClock.new()
	assert_eq(c.feed(0.25), 2)  # 0.05s carried
	assert_eq(c.feed(0.05), 1)  # carry + new = 0.1
	c.paused = true
	assert_eq(c.feed(5.0), 0)
	c.paused = false
	c.speed = 2.0
	assert_eq(c.feed(0.5), 10)


func test_clock_caps_ticks_per_feed() -> void:
	var c := SimulationClock.new()
	assert_eq(c.feed(100.0), c.max_ticks_per_feed)


func test_seconds_to_ticks_minimum_one() -> void:
	assert_eq(SimulationClock.seconds_to_ticks(0.0), 1)
	assert_eq(SimulationClock.seconds_to_ticks(0.25), 3)
	assert_eq(SimulationClock.seconds_to_ticks(5.0), 50)


func test_rng_deterministic_and_state_resumes() -> void:
	var a := GameState.new_game(42)
	var b := GameState.new_game(42)
	var xs: Array = []
	for i in 5:
		xs.append(SimRng.next_float(a))
	for i in 5:
		assert_eq(SimRng.next_float(b), xs[i])
	var c := GameState.from_dict(a.to_dict())
	assert_eq(SimRng.next_float(c), SimRng.next_float(a))


func test_rng_different_seeds_differ() -> void:
	assert_ne(SimRng.next_float(GameState.new_game(1)), SimRng.next_float(GameState.new_game(2)))


func test_condition_forms() -> void:
	var reg := TestHelpers.real_registry()
	var ev := ConditionEvaluator.new()
	var s := GameState.new_game()
	s.resources["wood"] = 5.0
	assert_true(ev.is_met({}, s))
	assert_true(ev.is_met({"type": "resource_at_least", "resource": "wood", "amount": 5}, s))
	assert_false(ev.is_met({"type": "resource_at_least", "resource": "wood", "amount": 6}, s))
	assert_true(ev.is_met({"not": {"type": "flag_is", "flag": "x", "value": true}}, s))
	var f := {"any_of": [{"type": "flag_is", "flag": "x", "value": true}, {"type": "flag_is", "flag": "tutorial_started", "value": true}]}
	assert_true(ev.is_met(f, s))
	assert_false(ev.is_met({"any_of": []}, s))
	assert_true(ev.is_met({"all_of": []}, s))
	var fail := ev.first_failure({"all_of": [
		{"type": "flag_is", "flag": "tutorial_started", "value": true},
		{"type": "upgrade_level_at_least", "upgrade": "iron_axe", "level": 1}]}, s)
	assert_eq(fail["type"], "upgrade_level_at_least")
	assert_eq(ev.validate({"type": "bogus"}, reg).size(), 1)
	assert_eq(ev.validate({"type": "resource_at_least", "resource": "nope", "amount": 1}, reg).size(), 1)
	assert_eq(ev.validate({"all_of": [], "any_of": []}, reg).size(), 1)
	assert_eq(ev.validate({"type": "flag_is", "flag": "x", "value": true}, reg).size(), 0)


func test_unknown_condition_type_never_met() -> void:
	assert_false(ConditionEvaluator.new().is_met({"type": "bogus"}, GameState.new_game()))


func test_registry_loads_real_data() -> void:
	var r := ContentRegistry.new()
	assert_true(r.load_all(), str(r.errors))
	assert_true(r.has_action("gather_wood") and r.has_resource("silver") and r.has_upgrade("iron_axe"))


func test_registry_rejects_bad_definitions() -> void:
	var r := TestHelpers.mini_registry([
		{"id": "a", "type": "LOOP", "duration": 0, "effects": []},
		{"id": "b", "type": "INSTANT", "effects": [{"type": "add_resource", "resource": "nope", "amount": 1}]},
		{"id": "c", "type": "INSTANT", "effects": [{"type": "run_script", "code": "x"}]},
		{"id": "d", "type": "INSTANT", "costs": {"wood": -1}, "effects": []},
		{"id": "e", "type": "INSTANT", "age_cost_years": -1, "effects": []},
	])
	assert_true(r.errors.size() >= 5, str(r.errors))
	r.add_definitions("action", [{"id": "a", "type": "INSTANT"}])
	assert_true(str(r.errors).contains("duplicate"))


func test_resource_cap_and_atomic_spend() -> void:
	var rs := ResourceSystem.new(TestHelpers.mini_registry())
	var s := GameState.new_game()
	assert_eq(rs.add(s, "wood", 80.0), 50.0)  # capped at 50
	assert_eq(s.resources["wood"], 50.0)
	assert_false(rs.spend(s, {"wood": 10, "silver": 1}))  # silver missing -> nothing spent
	assert_eq(s.resources["wood"], 50.0)
	assert_true(rs.spend(s, {"wood": 10}))
	assert_eq(s.resources["wood"], 40.0)
	assert_eq(rs.missing(s, {"silver": 3}), {"silver": 3.0})


func test_state_dict_round_trip_through_json() -> void:
	var w := TestHelpers.world()
	w["act"].start_action(w["state"], "gather_wood")
	w["act"].advance(w["state"], 23)
	var s2 := GameState.from_dict(JSON.parse_string(JSON.stringify(w["state"].to_dict())))
	assert_eq(s2.to_dict(), w["state"].to_dict())
