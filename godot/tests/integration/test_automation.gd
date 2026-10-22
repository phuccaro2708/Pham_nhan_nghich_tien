extends GutTest
## Automation queue + save/offline equivalence (Phase 2B).

const DIR := "user://test_saves"

var act: ActionSystem
var s: GameState
var sm: Node


func before_each() -> void:
	var w: Dictionary = TestHelpers.world(11)
	act = w["act"]
	s = w["state"]
	s.flags["tutorial_started"] = true
	s.content_version = act.registry.content_version  # a saved state is migrated to the newest content version on load
	for id in act.registry.resources:
		s.resources[id] = float(act.registry.resources[id].get("initial", 0.0))
	s.mastery["gather_wood"] = {"level": 3, "xp": 0.0, "claimed": []}  # unlocks automation
	s.story["done"]["ch1_morning_smoke"] = "ignore"  # keep the chapter from pausing queues; the story test erases it
	sm = load("res://autoload/save_manager.gd").new()
	sm.save_path = DIR + "/q.json"
	_wipe()


func after_each() -> void:
	_wipe()
	sm.free()


func _wipe() -> void:
	for f in DirAccess.get_files_at(DIR):
		DirAccess.remove_absolute(DIR + "/" + f)


func _slot(id: String, repeat: int = 1, on_block: String = "skip") -> Dictionary:
	return {"action": id, "repeat": repeat, "on_block": on_block}


func test_locked_until_mastery_requirement() -> void:
	s.mastery.clear()
	assert_eq(act.automation.set_slots(s, [_slot("gather_wood")])["error"], "automation_locked")


func test_slot_validation() -> void:
	assert_eq(act.automation.set_slots(s, [_slot("nope")])["error"], "unknown_action")
	assert_eq(act.automation.set_slots(s, [_slot("breakthrough")])["error"], "not_automatable")
	assert_eq(act.automation.set_slots(s, [_slot("gather_wood", -1)])["error"], "bad_repeat")
	assert_eq(act.automation.set_slots(s, [_slot("gather_wood", 1, "dance")])["error"], "bad_on_block")
	var four: Array = [_slot("gather_wood"), _slot("gather_wood"), _slot("gather_wood"), _slot("gather_wood")]
	assert_eq(act.automation.set_slots(s, four)["error"], "too_many_slots")
	assert_eq(act.automation.start(s)["error"], "empty_queue")


func test_runs_slots_in_order_then_finishes() -> void:
	assert_true(act.automation.set_slots(s, [_slot("gather_wood", 2), _slot("train_body", 1)])["ok"])
	assert_true(act.automation.start(s)["ok"])
	act.advance(s, 10000)
	assert_eq(s.action_counts["gather_wood"], 2)
	assert_eq(s.action_counts["train_body"], 1)
	assert_eq(act.automation.status(s), "finished")
	assert_true(s.active_action.is_empty())


func test_skip_moves_on_and_instant_slot_runs() -> void:
	s.resources["wood"] = 10.0
	act.automation.set_slots(s, [_slot("treat_meridian", 1, "skip"), _slot("sell_wood", 1)])
	act.automation.start(s)
	assert_eq(s.resources["silver"], 5.0)
	assert_eq(s.resources["wood"], 0.0)
	assert_eq(act.automation.status(s), "finished")


func test_stop_on_block_reports_reason() -> void:
	act.automation.set_slots(s, [_slot("sell_wood", 1, "stop")])
	act.automation.start(s)
	assert_eq(act.automation.status(s), "stopped")
	assert_string_contains(str(s.automation["reason"]), "insufficient_resources")


func test_wait_feeds_from_producing_slot_and_deadlock_is_detected() -> void:
	act.automation.set_slots(s, [_slot("sell_wood", 1, "wait"), _slot("gather_wood", 99)])
	act.automation.start(s)
	act.advance(s, 3000)
	assert_gt(s.resources["silver"], 0.0, "wait slot must be fed by gather_wood")
	# nothing in the queue produces silver or herb => a wait on it cannot be fed
	s.resources["silver"] = 0.0
	act.stop_action(s)
	s.story["pending"] = ""  # the earlier gathering opened another chapter event; irrelevant here
	act.automation.set_slots(s, [_slot("treat_meridian", 1, "wait")])
	s.flags["meridian_damaged"] = true
	assert_eq(act.automation.analyze(s)[0]["reason"], "deadlock_risk")
	act.automation.start(s)
	assert_eq(act.automation.status(s), "deadlock", "pending=%s reason=%s" % [s.story["pending"], s.automation["reason"]])


func test_loop_with_no_progress_does_not_spin() -> void:
	act.automation.set_slots(s, [_slot("treat_meridian", 1, "skip")])
	act.automation.set_loop(s, true)
	act.automation.start(s)
	assert_eq(act.automation.status(s), "stopped")


func test_manual_start_overrides_and_stops_queue() -> void:
	act.automation.set_slots(s, [_slot("gather_wood", 5)])
	act.automation.start(s)
	act.start_action(s, "train_body")
	assert_eq(act.automation.status(s), "stopped")
	assert_eq(s.active_action["id"], "train_body")
	act.advance(s, 2000)
	assert_eq(act.automation.status(s), "stopped")  # not resumed behind the player's back


func test_pending_story_pauses_queue_and_never_picks_a_choice() -> void:
	s.story["done"].erase("ch1_morning_smoke")
	s.action_counts["gather_wood"] = 2
	act.automation.set_slots(s, [_slot("gather_wood", 5)])
	act.automation.start(s)
	act.advance(s, 500)  # the first completion opens the morning-smoke event
	assert_eq(act.story.pending(s), "ch1_morning_smoke")
	var done_before: int = int(s.automation["slots"][0]["done"])
	act.advance(s, 3000)
	assert_eq(act.story.pending(s), "ch1_morning_smoke")
	assert_eq(int(s.automation["slots"][0]["done"]), done_before)
	assert_true(s.story["done"].is_empty())
	act.story.choose(s, "ignore")
	act.automation.pump(s)
	act.advance(s, 3000)
	assert_gt(int(s.automation["slots"][0]["done"]), done_before)


func test_offline_refuses_actions_not_allowed_offline() -> void:
	s.flags["knows_qi_method"] = true
	s.realm_id = "cam_khi"
	s.resources["herb"] = 3.0
	act.automation.set_slots(s, [_slot("sense_qi", 1, "stop")])
	act.automation.start(s)  # online: allowed to start
	act.stop_action(s)
	act.automation.start(s)
	var online := GameState.from_dict(s.to_dict())
	OfflineSystem.apply(online, act, 600.0)
	assert_ne(online.automation["reason"], "")


func test_offline_equals_online_with_queue() -> void:
	act.automation.set_slots(s, [_slot("gather_wood", 3), _slot("train_body", 2)]) # offline-allowed actions only
	act.automation.set_loop(s, true)
	act.automation.start(s)
	var a := GameState.from_dict(s.to_dict())
	var b := GameState.from_dict(s.to_dict())
	act.advance(a, 36000)
	OfflineSystem.apply(b, act, 3600.0)
	b.save_metadata = a.save_metadata
	assert_eq(a.to_dict(), b.to_dict())


func test_queue_round_trips_through_save_and_resumes_identically() -> void:
	act.automation.set_slots(s, [_slot("gather_wood", 4), _slot("train_body", 2)])
	act.automation.start(s)
	act.advance(s, 77)
	assert_eq(sm.save_game(s, act.registry), OK)
	var loaded: Dictionary = sm.load_game(act.registry)
	assert_true(loaded.has("state"))
	var b: GameState = loaded["state"]
	assert_eq(b.automation, s.automation)
	act.advance(s, 5000)
	act.advance(b, 5000)
	assert_eq(b.to_dict(), s.to_dict())


func test_pending_story_round_trips_through_save() -> void:
	s.story["done"].erase("ch1_morning_smoke")
	s.action_counts["gather_wood"] = 3
	act.story.scan(s)
	assert_eq(sm.save_game(s, act.registry), OK)
	var b: GameState = sm.load_game(act.registry)["state"]
	assert_eq(act.story.pending(b), "ch1_morning_smoke")
	assert_true(act.story.choose(b, "ignore")["ok"])
	assert_eq(act.story.pending(b), "")


func test_v2_save_migrates_to_v3_without_losing_progress() -> void:
	var d: Dictionary = s.to_dict()
	for k in ["mastery", "relations", "techniques", "story", "automation"]:
		d.erase(k)
	d["schema_version"] = 2
	d["resources"]["wood"] = 12.0
	var m: Dictionary = sm.migrate(d)
	var b := GameState.from_dict(m)
	assert_eq(b.resources["wood"], 12.0)
	assert_eq(b.story["pending"], "")
	assert_eq(b.automation["status"], "idle")


# ---------- regressions from the independent Codex review ----------

func test_yield_uses_groups_multiplicatively_in_real_rewards() -> void:
	s.upgrades["iron_axe"] = 2  # +100% wood
	s.mastery["gather_wood"] = {"level": 5, "xp": 0.0, "claimed": [5]}  # +10% wood (own group)
	act.start_action(s, "gather_wood")
	act.advance(s, act.duration_ticks(act.registry.actions["gather_wood"], s))
	assert_almost_eq(s.resources["wood"], 3.0 * 2.0 * 1.1, 1e-9)


func test_replacing_slots_mid_cycle_does_not_credit_the_new_slot() -> void:
	act.automation.set_slots(s, [_slot("gather_wood", 5)])
	act.automation.start(s)
	act.automation.set_slots(s, [_slot("train_body", 1)])
	act.automation.start(s)  # stops the gathering cycle (switched) and starts train_body for real
	assert_eq(s.active_action["id"], "train_body")
	act.advance(s, 3)  # far less than one cycle
	assert_eq(int(s.automation["slots"][0]["done"]), 0)
	assert_false(s.active_action.is_empty())


func test_set_slots_while_running_drops_stale_queue_slot() -> void:
	act.automation.set_slots(s, [_slot("gather_wood", 5)])
	act.automation.start(s)
	act.automation.set_slots(s, [_slot("train_body", 1)])
	assert_false(s.active_action.has("queue_slot"))
	act.advance(s, 200)  # the old gathering cycle finishes; it must not mark train_body done
	assert_eq(int(s.automation["slots"][0]["done"]), 0)


func test_start_queue_takes_over_from_a_manual_loop() -> void:
	act.start_action(s, "gather_wood")
	act.automation.set_slots(s, [_slot("train_body", 2)])
	assert_true(act.automation.start(s)["ok"])
	act.advance(s, 3000)
	assert_eq(s.action_counts["train_body"], 2)
	assert_eq(act.automation.status(s), "finished")


func test_manual_instant_does_not_halt_the_queue() -> void:
	# design: only a manual *timed* start interrupts the running action, so only that stops the queue
	s.resources["wood"] = 10.0
	act.automation.set_slots(s, [_slot("gather_wood", 5)])
	act.automation.start(s)
	assert_true(act.start_action(s, "sell_wood")["ok"])
	assert_eq(act.automation.status(s), "running")
	assert_eq(s.active_action["id"], "gather_wood")


func test_parked_pending_story_event_returns_with_its_content() -> void:
	s.story["pending"] = "ch1_taoist_tale"
	var d: Dictionary = s.to_dict()
	var gone: ContentRegistry = TestHelpers.real_registry()
	gone.story.erase("ch1_taoist_tale")
	var parked: Dictionary = ContentMigration.apply(d.duplicate(true), gone)
	assert_eq(parked["story"]["pending"], "")
	assert_eq(parked["orphans"]["story_pending"], "ch1_taoist_tale")
	var back: Dictionary = ContentMigration.apply(parked, act.registry)
	assert_eq(back["story"]["pending"], "ch1_taoist_tale")
	assert_false(back["orphans"].has("story_pending"))
