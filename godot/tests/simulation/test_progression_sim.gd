extends GutTest
## A scripted player must be able to reach Trúc Cơ alive, deterministically, and offline must match online.


## Plays greedily from a fresh character; returns the finished state. Each step runs one action to completion.
func _play(seed_value: int, max_steps: int = 60000) -> Dictionary:
	var w: Dictionary = TestHelpers.world(seed_value)
	var act: ActionSystem = w["act"]
	var s: GameState = w["state"]
	var steps: int = 0
	while steps < max_steps and s.realm_id != "truc_co_so" and act.lifespan.is_alive(s):
		steps += 1
		var id: String = _choose(act, s)
		var r: Dictionary = act.start_action(s, id)
		if not r["ok"]:
			continue
		if act.registry.actions[id]["type"] != "INSTANT":
			act.advance(s, act.duration_ticks(act.registry.actions[id], s))
			act.stop_action(s)
	return {"state": s, "steps": steps}


func _choose(act: ActionSystem, s: GameState) -> String:
	if act.check_can_start(s, "breakthrough")["ok"]:
		return "breakthrough"
	if s.flags.get("meridian_damaged", false):
		return "treat_meridian" if s.resources.get("silver", 0.0) >= 50.0 else "sell_wood" if s.resources.get("wood", 0.0) >= 10.0 else "gather_wood"
	var cost: Dictionary = act.realms.breakthrough_costs(s)
	for rid in cost:
		if s.resources.get(rid, 0.0) < cost[rid]:
			match rid:
				"body": return "train_body"
				"silver": return "sell_wood" if s.resources.get("wood", 0.0) >= 10.0 else "gather_wood"
				"cultivation": return "refine_qi" if s.resources.get("spirit_qi", 0.0) >= 8.0 else "absorb_qi"
	return "gather_wood"


func test_bot_reaches_truc_co_alive() -> void:
	var r := _play(11)
	var s: GameState = r["state"]
	assert_eq(s.realm_id, "truc_co_so", "steps=%d age=%.2f ticks=%d" % [r["steps"], s.age_years, s.game_time_ticks])
	assert_eq(s.life["status"], "alive")
	gut.p("Truc Co reached: %.2f h, age %.2f, failures reset" % [s.game_time_ticks / 36000.0, s.age_years])


func test_run_is_deterministic() -> void:
	var a: GameState = _play(11)["state"]
	var b: GameState = _play(11)["state"]
	assert_eq(a.to_dict(), b.to_dict())


func test_offline_equals_online_for_cultivation_loop() -> void:
	var w1: Dictionary = TestHelpers.world(5)
	var w2: Dictionary = TestHelpers.world(5)
	for w in [w1, w2]:
		w["state"].realm_id = "luyen_khi_1"
		w["act"].start_action(w["state"], "absorb_qi")
	OfflineSystem.apply(w1["state"], w1["act"], 3600.0)
	w2["act"].advance(w2["state"], 36000)
	assert_eq(w1["state"].to_dict(), w2["state"].to_dict())
