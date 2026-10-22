extends GutTest

var act: ActionSystem
var s: GameState


func before_each() -> void:
	var w: Dictionary = TestHelpers.world()
	act = w["act"]
	s = w["state"]


func test_gather_completes_once_and_pays_age() -> void:
	assert_true(act.start_action(s, "gather_wood")["ok"])
	act.advance(s, 49)
	assert_eq(s.resources.get("wood", 0.0), 0.0)
	act.advance(s, 1)
	assert_eq(s.resources["wood"], 3.0)
	assert_eq(s.action_counts["gather_wood"], 1)
	assert_almost_eq(s.age_years, 16.002, 1e-9)


func test_loop_repeats_automatically() -> void:
	act.start_action(s, "gather_wood")
	act.advance(s, 500)  # 10 cycles
	assert_eq(s.resources["wood"], 30.0)
	assert_eq(s.action_counts["gather_wood"], 10)
	assert_almost_eq(s.age_years, 16.02, 1e-9)


func test_sell_wood_instant() -> void:
	s.resources["wood"] = 25.0
	assert_true(act.start_action(s, "sell_wood")["ok"])
	assert_eq(s.resources["wood"], 15.0)
	assert_eq(s.resources["silver"], 5.0)
	assert_eq(s.age_years, 16.0)  # age moves only by age_cost_years (0 here)


func test_cannot_sell_without_wood_and_reason_given() -> void:
	var r := act.start_action(s, "sell_wood")
	assert_false(r["ok"])
	assert_eq(r["reason"], "insufficient_resources")
	assert_eq(r["detail"], {"wood": 10.0})
	assert_eq(s.action_counts.size(), 0)


func test_axe_price_curve_and_yield_bonus() -> void:
	s.resources["silver"] = 1000.0
	assert_eq(act.get_costs(act.registry.actions["buy_iron_axe"], s), {"silver": 20.0})
	act.start_action(s, "buy_iron_axe")
	assert_eq(s.upgrades["iron_axe"], 1)
	assert_eq(s.resources["silver"], 980.0)
	assert_eq(act.get_costs(act.registry.actions["buy_iron_axe"], s), {"silver": 24.0})  # ceil(20*1.18)
	act.start_action(s, "gather_wood")
	act.advance(s, 50)
	assert_eq(s.resources["wood"], 4.5)  # 3 * (1 + 0.5)


func test_axe_stops_at_max_level() -> void:
	s.resources["silver"] = 1.0e6
	for i in 10:
		assert_true(act.start_action(s, "buy_iron_axe")["ok"])
	assert_eq(act.start_action(s, "buy_iron_axe")["reason"], "max_level")
	assert_eq(s.upgrades["iron_axe"], 10)


func test_requirement_blocks_start() -> void:
	s.flags["tutorial_started"] = false
	assert_eq(act.start_action(s, "gather_wood")["reason"], "requirements_not_met")
	assert_true(s.active_action.is_empty())


func test_restarting_action_resets_progress_without_reward() -> void:
	act.start_action(s, "gather_wood")
	act.advance(s, 30)
	act.start_action(s, "gather_wood")
	act.advance(s, 49)
	assert_eq(s.resources.get("wood", 0.0), 0.0)
	act.advance(s, 1)
	assert_eq(s.resources["wood"], 3.0)


func test_switching_actions_never_duplicates_rewards() -> void:
	s.resources["silver"] = 100.0
	act.start_action(s, "gather_wood")
	act.advance(s, 49)
	act.start_action(s, "buy_iron_axe")  # INSTANT does not disturb the loop
	act.advance(s, 1)
	assert_eq(s.action_counts["gather_wood"], 1)
	assert_eq(s.resources["wood"], 4.5)  # axe bought before completion applies once


func test_stop_refunds_paid_costs_and_gives_nothing() -> void:
	var reg := TestHelpers.mini_registry([{"id": "brew", "type": "TIMED", "duration": 2.0, "costs": {"wood": 10},
		"effects": [{"type": "add_resource", "resource": "silver", "amount": 9}]}])
	var a2 := ActionSystem.new(reg)
	var st := GameState.new_game()
	st.resources["wood"] = 10.0
	a2.start_action(st, "brew")
	assert_eq(st.resources["wood"], 0.0)
	a2.advance(st, 5)
	a2.stop_action(st)
	assert_eq(st.resources["wood"], 10.0)
	assert_eq(st.resources.get("silver", 0.0), 0.0)
	assert_true(st.active_action.is_empty())


func test_loop_pauses_without_resources_and_never_spins() -> void:
	var reg := TestHelpers.mini_registry([{"id": "mill", "type": "LOOP", "duration": 1.0, "costs": {"wood": 10},
		"effects": [{"type": "add_resource", "resource": "silver", "amount": 1}]}])
	var a2 := ActionSystem.new(reg)
	var st := GameState.new_game()
	st.resources["wood"] = 25.0
	var stops: Array = []
	a2.action_stopped.connect(func(id: String, why: String) -> void: stops.append([id, why]))
	a2.start_action(st, "mill")
	a2.advance(st, 10000)
	assert_eq(st.action_counts["mill"], 2)  # 25 wood -> two runs
	assert_eq(st.resources["wood"], 5.0)
	assert_eq(stops, [["mill", "insufficient_resources"]])
	assert_true(st.active_action.is_empty())
	assert_eq(st.game_time_ticks, 10000)


func test_cost_timing_complete_charges_on_completion_only() -> void:
	var reg := TestHelpers.mini_registry([{"id": "t", "type": "TIMED", "duration": 1.0, "cost_timing": "complete",
		"costs": {"wood": 5}, "effects": [{"type": "add_resource", "resource": "silver", "amount": 1}]}])
	var a2 := ActionSystem.new(reg)
	var st := GameState.new_game()
	st.resources["wood"] = 5.0
	a2.start_action(st, "t")
	assert_eq(st.resources["wood"], 5.0)
	st.resources["wood"] = 0.0  # spent elsewhere meanwhile
	a2.advance(st, 10)
	assert_eq(st.resources.get("silver", 0.0), 0.0)  # no reward without payment
	assert_true(st.active_action.is_empty())


func test_speed_bonus_respects_min_time() -> void:
	var reg := TestHelpers.mini_registry([{"id": "q", "type": "LOOP", "duration": 1.0, "effects": []}])
	reg.upgrades["fast"] = {"id": "fast", "bonuses": [{"stat": "speed.all", "per_level": 100.0}]}
	var a2 := ActionSystem.new(reg)
	var st := GameState.new_game()
	st.upgrades["fast"] = 1
	assert_eq(a2.duration_ticks(reg.actions["q"], st), 3)  # T_min 0.25s -> 3 ticks


func test_wood_cap_loses_only_overflow() -> void:
	s.resources["wood"] = 199.0
	act.start_action(s, "gather_wood")
	act.advance(s, 50)
	assert_eq(s.resources["wood"], 200.0)


func test_chance_effect_is_seeded() -> void:
	var defs: Array = [{"id": "g", "type": "LOOP", "duration": 1.0,
		"effects": [{"type": "add_resource", "resource": "silver", "amount": 1, "chance": 0.5}]}]
	var out: Array = []
	for i in 2:
		var a2 := ActionSystem.new(TestHelpers.mini_registry(defs))
		var st := GameState.new_game(99)
		a2.start_action(st, "g")
		a2.advance(st, 1000)
		out.append(st.resources.get("silver", 0.0))
	assert_eq(out[0], out[1])
	assert_true(out[0] > 20.0 and out[0] < 80.0)


func test_loop_stops_when_reward_capped_and_burns_no_age() -> void:
	s.resources["wood"] = 200.0
	assert_eq(act.start_action(s, "gather_wood")["reason"], "reward_capped")
	assert_eq(s.age_years, 16.0)


func test_completion_handler_starting_other_action_keeps_its_costs() -> void:
	var reg := TestHelpers.mini_registry([
		{"id": "a", "type": "LOOP", "duration": 1.0, "effects": []},
		{"id": "b", "type": "TIMED", "duration": 5.0, "costs": {"silver": 10}, "effects": []}])
	var a2 := ActionSystem.new(reg)
	var st := GameState.new_game()
	st.resources["silver"] = 10.0
	a2.action_completed.connect(func(id: String) -> void:
		if id == "a":
			a2.start_action(st, "b"))
	a2.start_action(st, "a")
	a2.advance(st, 10)
	assert_eq(st.active_action.get("id"), "b")
	assert_eq(float(st.active_action["costs_paid"]["silver"]), 10.0)
	assert_eq(st.resources["silver"], 0.0)


func test_refund_is_not_clipped_by_cap() -> void:
	var reg := TestHelpers.mini_registry([{"id": "x", "type": "TIMED", "duration": 5.0, "costs": {"wood": 40}, "effects": []}])
	var a2 := ActionSystem.new(reg)
	var st := GameState.new_game()
	st.resources["wood"] = 50.0
	a2.start_action(st, "x")
	st.resources["wood"] = 50.0  # refilled to cap while running
	a2.stop_action(st)
	assert_eq(st.resources["wood"], 90.0)


func test_registry_validation_catches_unsavable_content() -> void:
	var r := ContentRegistry.new()
	r.add_definitions("resource", [{"id": "w", "name_key": "w", "cap": 50, "initial": 80}])
	r.add_definitions("upgrade", [{"id": "u", "cost_resource": "w", "base_cost": 1, "cost_growth": 1.1, "max_level": 3,
		"bonuses": [{"stat": "yield.w", "per_level": -1}]}])
	r.add_definitions("action", [{"id": "a", "type": "INSTANT", "effects": [{"type": "add_upgrade_level", "upgrade": "u", "levels": -3}]}])
	r.validate()
	assert_true(str(r.errors).contains("initial exceeds cap"))
	assert_true(str(r.errors).contains("per_level"))
	assert_true(str(r.errors).contains("levels"))


func test_flag_is_mismatched_types_is_false_without_error() -> void:
	s.flags["n"] = 1
	assert_false(act.conditions.is_met({"type": "flag_is", "flag": "n", "value": true}, s))


func test_flag_is_numbers_compare_by_value_after_json_roundtrip() -> void:
	s.flags["n"] = 1.0  # what JSON gives back for an int
	assert_true(act.conditions.is_met({"type": "flag_is", "flag": "n", "value": 1}, s))


func test_restart_paid_action_is_judged_after_refund_and_reports_restarted() -> void:
	var reg := TestHelpers.mini_registry([{"id": "x", "type": "TIMED", "duration": 5.0, "costs": {"wood": 10}, "effects": []}])
	var a2 := ActionSystem.new(reg)
	var st := GameState.new_game()
	st.resources["wood"] = 10.0
	var why: Array = []
	a2.action_stopped.connect(func(_id: String, r: String) -> void: why.append(r))
	a2.start_action(st, "x")
	assert_true(a2.start_action(st, "x")["ok"])
	assert_eq(st.resources["wood"], 0.0)
	assert_eq(why, ["restarted"])
