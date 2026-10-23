extends GutTest
## A scripted player must be able to reach Trúc Cơ alive, deterministically, and offline must match online.


## Plays greedily from a fresh character; returns the finished state. Each step runs one action to completion.
func _play(seed_value: int, max_steps: int = 60000) -> Dictionary:
	var w: Dictionary = TestHelpers.world(seed_value)
	var act: ActionSystem = w["act"]
	var s: GameState = w["state"]
	return {"state": s, "steps": TestHelpers.climb_to(act, s, "truc_co_so", max_steps)}


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
