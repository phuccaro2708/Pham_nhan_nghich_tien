extends GutTest
## Headless strategy run of the technical vertical slice (GDD §15.2 / §11.1 targets).


func _play(seed_value: int, seconds: int) -> Dictionary:
	var reg := TestHelpers.real_registry()
	var act := ActionSystem.new(reg)
	var s := GameState.new_game(seed_value)
	var first_upgrade_s: int = -1
	act.start_action(s, "gather_wood")
	for sec in range(1, seconds + 1):
		act.advance(s, SimulationClock.TICKS_PER_SECOND)
		if float(s.resources.get("wood", 0.0)) >= 10.0:
			act.start_action(s, "sell_wood")
		if act.start_action(s, "buy_iron_axe")["ok"] and first_upgrade_s < 0:
			first_upgrade_s = sec
		if s.active_action.is_empty():
			act.start_action(s, "gather_wood")
	return {"state": s, "first_upgrade_s": first_upgrade_s}


func test_first_upgrade_within_pacing_target() -> void:
	var r := _play(1, 300)
	assert_between(r["first_upgrade_s"], 60, 120, "GDD §11.1: first upgrade in 60-120 s")


func test_simulation_is_deterministic() -> void:
	assert_eq(_play(3, 900)["state"].to_dict(), _play(3, 900)["state"].to_dict())


func test_invariants_hold_over_long_run() -> void:
	var s: GameState = _play(2, 3600)["state"]
	var reg := TestHelpers.real_registry()
	# Age is paid only by completed actions: 16 + completions * age_cost_years.
	var expected_age: float = 16.0
	for id in s.action_counts:
		expected_age += s.action_counts[id] * float(reg.actions[id].get("age_cost_years", 0.0))
	assert_almost_eq(s.age_years, expected_age, 1e-6)
	for id in s.resources:
		assert_true(s.resources[id] >= 0.0 and is_finite(s.resources[id]))
	assert_gt(s.upgrades["iron_axe"], 3)
	assert_eq(SaveManagerValidate.errors_for(s, reg), [])
