extends GutTest
## Cổng V6: mỗi hướng chủ tu đều tới Trúc Cơ còn sống, kể cả khi không có mảnh công pháp (tài nguyên hiếm).

const MAINS: Array = ["thanh_moc_duong_khi", "huyet_luyen_than_kinh", "ngu_hanh_dan_khi"]


func _play(main: String, no_fragments: bool, seed_value: int = 11) -> GameState:
	var w: Dictionary = TestHelpers.world(seed_value)
	var act: ActionSystem = w["act"]
	var s: GameState = w["state"]
	var steps: int = 0
	while steps < 60000 and s.realm_id != "truc_co_so" and act.lifespan.is_alive(s):
		steps += 1
		if main != "" and not s.techniques.has(main) and s.techniques.has("dan_khi_nhap_mon"):
			act.effects.apply(s, [{"type": "learn_technique", "technique": main}])
			s.main_technique = main
		if no_fragments:
			s.resources["technique_fragment"] = 0.0
		BalanceSimulator.resolve_story(act, s)
		var id: String = BalanceSimulator.policy(act, s)
		if not act.start_action(s, id)["ok"]:
			continue
		if act.registry.actions[id]["type"] != "INSTANT":
			act.advance(s, act.duration_ticks(act.registry.actions[id], s))
			act.stop_action(s)
	return s


func test_every_main_technique_reaches_truc_co_alive() -> void:
	for main in MAINS:
		for seed_value in [11, 12, 13]:
			var s: GameState = _play(main, false, seed_value)
			assert_eq(s.realm_id, "truc_co_so", "%s seed %d" % [main, seed_value])
			assert_eq(s.life["status"], "alive", main)


func test_missing_rare_resource_does_not_block_the_goal() -> void:
	for main in MAINS:
		assert_eq(_play(main, true).realm_id, "truc_co_so", main)


func test_exploring_bot_prepares_cave_researches_and_reaches_goal() -> void:
	var sim := BalanceSimulator.new(TestHelpers.real_registry())
	for main in MAINS:
		var plain: Dictionary = sim.run("optimizer", 1, main, false)
		var explored: Dictionary = sim.run("optimizer", 1, main, true)
		assert_true(plain["reached"] and explored["reached"], main)
		assert_eq(plain["actual_main"], main)
		assert_eq(explored["actual_main"], main)
		assert_eq(plain["dungeon_attempts"], 0, main)
		assert_true(explored["cave_cleared"], main)
		assert_gt(explored["dungeon_attempts"], 0, main)
		assert_gt(explored["research_attempts"], 0, main)
		assert_true(explored["variant"], main)
		assert_true(str(explored["echo"]).begins_with("echo_"), main)
		assert_eq(explored["wounds_at_breakthrough"], 0, main)
