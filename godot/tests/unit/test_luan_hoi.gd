extends GutTest
## Luân hồi lần đầu (GDD 7.4): checkpoint/rewind, bốn nhánh quay lại, nguồn pháp môn, save v5.

# Free-only scripts: after the incident (which rewinds), the choices a player with no spare resources can always make.
const BRANCHES: Dictionary = {
	"guided": {"incident": "stay_by_taoist", "path": ["rescue", "ask_first", "hurry_off"]},
	"relic": {"incident": "watch_hunter", "path": ["trace_hunter", "follow_quietly", "copy_by_hand"]},
	"evidence": {"incident": "run_to_village", "path": ["warn_village", "warn_elder", "search_alone"]},
	"rogue": {"incident": "watch_hunter", "path": ["keep_secret", "slip_away"]},
	"rogue_cave": {"incident": "watch_hunter", "path": ["keep_secret", "rob_pouch", "skip"]},
}

var act: ActionSystem
var s: GameState
var reg: ContentRegistry


func before_each() -> void:
	var w: Dictionary = TestHelpers.world(11, false)
	act = w["act"]
	s = w["state"]
	reg = act.registry
	s.flags["tutorial_started"] = true
	for id in reg.resources:
		s.resources[id] = float(reg.resources[id].get("initial", 0.0))


func _pick(ids: Array) -> void:
	for id in ids:
		assert_true(act.story.choose(s, id)["ok"], "choose %s at %s" % [id, act.story.pending(s)])


## Reaches the mốc with a character who has done the village chain, then lives life 1 up to the incident.
func _to_incident(taoist_choice: String = "ask_first") -> void:
	s.realm_id = "cuong_than"
	s.story["done"]["ch3_crossroads"] = "explore"
	act.story.scan(s)
	assert_eq(act.story.pending(s), "ch1_before_mountain")
	_pick(["go_empty_handed"])
	assert_eq(act.story.pending(s), "ch1_wounded_taoist")
	_pick([taoist_choice])
	assert_eq(act.story.pending(s), "ch1_mountain_incident")


func _play_branch(key: String) -> void:
	var b: Dictionary = BRANCHES[key]
	_to_incident()
	_pick([b["incident"]])
	assert_eq(act.story.pending(s), "ch1_return")
	_pick(b["path"])


func _run(id: String) -> void:
	assert_true(act.start_action(s, id)["ok"], "start %s" % id)
	act.advance(s, act.duration_ticks(reg.actions[id], s))
	act.stop_action(s)


func _free_choice() -> String:
	for c in reg.story[act.story.pending(s)]["choices"]:
		if (c.get("requirements", {}) as Dictionary).is_empty() and (c.get("costs", {}) as Dictionary).is_empty():
			return c["id"]
	return ""


# ---------- rewind contract ----------

func test_chapter_one_does_not_grant_the_method() -> void:
	for key in BRANCHES:
		s = GameState.new_game(5)
		s.flags["tutorial_started"] = true
		_play_branch(key)
		assert_false(s.flags.get("knows_qi_method", false), "%s granted the method in chapter I" % key)
		assert_true(s.knowledge.has("dao_entry"), key)
		assert_true(s.flags.has("qi_source"), key)


func test_rewind_resets_world_but_keeps_memory() -> void:
	s.realm_id = "cuong_than"
	s.story["done"]["ch3_crossroads"] = "explore"
	s.resources["silver"] = 12.0
	s.resources["wood"] = 7.0
	s.flags["tutorial_started"] = true
	s.relations["ba_ly"] = 3
	act.story.scan(s)
	_pick(["go_empty_handed"])
	var at_mark: Dictionary = s.to_dict()
	s.resources["silver"] = 99.0  # the doomed life earns and trusts, none of it survives
	s.relations["dao_si"] = 4
	s.relations["ba_ly"] = 9
	s.flags["junk_flag"] = true
	s.age_years += 0.5
	_pick(["ask_first", "watch_hunter"])
	assert_eq(s.resources["silver"], at_mark["resources"]["silver"])
	assert_eq(s.resources["wood"], 7.0)
	assert_eq(int(s.relations.get("ba_ly", 0)), 3)
	assert_eq(int(s.relations.get("dao_si", 0)), 0)  # trust is rebuilt from nothing
	assert_false(s.flags.has("junk_flag"))
	assert_eq(s.age_years, at_mark["age_years"])
	assert_eq(s.realm_id, "cuong_than")  # the mốc is after Đoán Thể, which is story-only
	assert_true(s.knowledge.has("mem_cave_site"))
	assert_true(s.knowledge.has("mem_taoist_wound"))
	assert_true((s.story["done"] as Dictionary).has("ch1_mountain_incident"))
	assert_eq(s.loop, 1)
	assert_true(s.checkpoint.is_empty())
	assert_eq(act.story.pending(s), "ch1_return")


func test_incident_never_reopens_and_second_rewind_is_noop() -> void:
	_to_incident()
	_pick(["watch_hunter"])
	var before: Dictionary = s.to_dict()
	act.effects.apply(s, [{"type": "rewind"}])
	assert_eq(s.to_dict(), before, "rewind with no checkpoint must change nothing")
	s.story["pending"] = ""
	act.story.scan(s)
	assert_ne(act.story.pending(s), "ch1_mountain_incident")
	assert_ne(act.story.pending(s), "ch1_wounded_taoist")
	assert_ne(act.story.pending(s), "ch1_before_mountain")


func test_rewind_drops_running_action_without_refund() -> void:
	s.resources["wood"] = 0.0
	# a running timed action has already paid its cost; the mốc must be the world before it started
	s.active_action = {"id": "gather_wood", "progress_ticks": 1, "duration_ticks": 50, "costs_paid": {"wood": 10.0}}
	act.effects.apply(s, [{"type": "set_checkpoint"}])
	assert_eq(float(s.checkpoint["resources"]["wood"]), 10.0)
	s.resources["wood"] = 3.0
	act.effects.apply(s, [{"type": "rewind"}])
	assert_true(s.active_action.is_empty())
	assert_eq(float(s.resources["wood"]), 10.0)  # restored once, never refunded on top
	assert_eq(s.automation["status"], "idle")


func test_checkpoint_only_in_story_choices() -> void:
	for kind in ["set_checkpoint", "rewind"]:
		var errs: Array = EffectResolver.validate_effect({"type": kind}, reg, "x", false, false)
		assert_false(errs.is_empty(), kind)
		assert_true(EffectResolver.validate_effect({"type": kind}, reg, "x", false, true).is_empty(), kind)


func test_rewind_must_be_last_effect_in_a_choice() -> void:
	var r := ContentRegistry.new()
	r.errors.clear()
	r._validate_rewind_last([{"type": "rewind"}, {"type": "set_flag", "flag": "a", "value": true}], "p")
	assert_eq(r.errors.size(), 1)


# ---------- branches ----------

func test_memory_gates_the_return_choices() -> void:
	_to_incident("loot")  # robbed: no trust, so staying by the taoist is not offered
	var inc: Dictionary = act.story.check_choice(s, "stay_by_taoist")
	assert_false(inc["ok"])
	_pick(["run_to_village"])
	assert_false(act.story.check_choice(s, "trace_hunter")["ok"], "the hunter's cave was never witnessed")
	assert_true(act.story.check_choice(s, "warn_village")["ok"])
	assert_true(act.story.check_choice(s, "rescue")["ok"])
	assert_true(act.story.check_choice(s, "keep_secret")["ok"])


func test_every_branch_reaches_sense_qi_with_free_choices_and_real_actions() -> void:
	for key in BRANCHES:
		s = GameState.new_game(21)
		s.flags["tutorial_started"] = true
		_play_branch(key)
		var src: String = str(s.flags["qi_source"])
		assert_eq(s.realm_id, "cuong_than", key)
		assert_eq(act.story.pending(s), "", "%s left an event pending: %s" % [key, act.story.pending(s)])
		s.resources["body"] = 100.0
		_run("breakthrough")
		assert_eq(s.realm_id, "cam_khi", key)
		assert_eq(act.story.pending(s), "ch4_method_" + src, key)
		# before the method node is resolved, nothing lets the player sense qi
		assert_false(act.check_can_start(s, "sense_qi")["ok"], "%s: sense_qi before the method" % key)
		assert_true(_free_choice() != "", key)
		_pick([_free_choice()])
		assert_true(s.flags.get("knows_qi_method", false), key)
		s.resources["herb"] = 3.0
		_run("sense_qi")
		assert_true(s.flags.get("qi_sensed", false), key)
		s.resources["body"] = 200.0
		s.resources["silver"] = 50.0
		_run("breakthrough")
		assert_eq(s.realm_id, "luyen_khi_1", key)


func test_no_qi_method_before_the_method_nodes() -> void:
	var allowed: Array = ["ch4_method_guided", "ch4_method_relic", "ch4_method_evidence", "ch4_method_rogue", "ch1_qi_clue"]
	for id in reg.story:
		for c in reg.story[id]["choices"]:
			for e in c.get("effects", []):
				if e["type"] == "set_flag" and e["flag"] == "knows_qi_method":
					assert_true(allowed.has(id), "%s grants the method" % id)
	# every method node waits for Cảm Khí and its own source
	for src in ["guided", "relic", "evidence", "rogue"]:
		var trig: String = JSON.stringify(reg.story["ch4_method_" + src]["trigger"])
		assert_true(trig.contains("cam_khi") and trig.contains(src), src)


func test_branches_end_in_different_worlds() -> void:
	var ends: Dictionary = {}
	for key in BRANCHES:
		s = GameState.new_game(33)
		s.flags["tutorial_started"] = true
		_play_branch(key)
		var f: Dictionary = {}
		for k in ["qi_source", "npc_taoist_alive", "npc_taoist_dead", "npc_hunter_alive", "village_believes", "village_suspicious", "taoist_robbed", "relic_copied", "cave_explored"]:
			if s.flags.has(k):
				f[k] = s.flags[k]
		ends[key] = {"relations": s.relations.duplicate(), "knowledge": s.knowledge.duplicate(), "flags": f, "resources": s.resources.duplicate()}
	var keys: Array = ends.keys()
	for i in keys.size():
		for j in range(i + 1, keys.size()):
			var a: Dictionary = ends[keys[i]]
			var b: Dictionary = ends[keys[j]]
			assert_ne(JSON.stringify([a["relations"], a["flags"]]), JSON.stringify([b["relations"], b["flags"]]), "%s == %s" % [keys[i], keys[j]])
	assert_ne(ends["guided"]["flags"]["qi_source"], ends["relic"]["flags"]["qi_source"])
	# the four distinct sources of the method
	var sources: Dictionary = {}
	for key in ["guided", "relic", "evidence", "rogue"]:
		sources[ends[key]["flags"]["qi_source"]] = true
	assert_eq(sources.size(), 4)


func test_robbery_branch_has_its_own_cave_source() -> void:
	_play_branch("rogue_cave")
	assert_true(s.flags.get("taoist_robbed", false))
	assert_eq(s.flags["qi_source"], "rogue")
	assert_true((s.story["done"] as Dictionary).has("ch1_cave_rumor"))
	assert_ne(act.story.pending(s), "ch1_qi_clue")  # F2: skipping the cave must not open the clue chain
	assert_false(s.flags.get("knows_qi_method", false))


func test_cave_rumor_skip_and_explore_differ() -> void:
	var node: Dictionary = reg.story["ch1_cave_rumor"]
	var ex: Dictionary = {}
	var sk: Dictionary = {}
	for c in node["choices"]:
		if c["id"] == "explore": ex = c
		if c["id"] == "skip": sk = c
	assert_ne(JSON.stringify(ex.get("effects")), JSON.stringify(sk.get("effects")))
	assert_false(ex.has("next") or sk.has("next"), "next would open a node without checking its trigger")


func test_taoist_choices_have_different_price_and_consequence() -> void:
	var node: Dictionary = reg.story["ch1_wounded_taoist"]
	var sigs: Dictionary = {}
	for c in node["choices"]:
		sigs[c["id"]] = JSON.stringify([c.get("costs", {}), c.get("effects", [])])
	assert_eq(sigs.size(), 3)
	assert_ne(sigs["heal"], sigs["ask_first"])
	assert_ne(sigs["heal"], sigs["loot"])
	assert_ne(sigs["ask_first"], sigs["loot"])


func test_legacy_clue_is_unreachable_in_a_new_game() -> void:
	for key in BRANCHES:
		s = GameState.new_game(3)
		s.flags["tutorial_started"] = true
		_play_branch(key)
		s.realm_id = "cam_khi"
		act.story.scan(s)
		assert_ne(act.story.pending(s), "ch1_qi_clue", key)


# ---------- save ----------

func test_save_round_trip_after_rewind_and_with_checkpoint() -> void:
	_to_incident()
	assert_false(s.checkpoint.is_empty())
	assert_eq(SaveManagerValidate.errors_for(s, reg), [])  # a live checkpoint validates
	assert_eq(GameState.from_dict(s.to_dict()).to_dict(), s.to_dict())
	_pick(["watch_hunter"])
	assert_eq(SaveManagerValidate.errors_for(s, reg), [])
	var copy := GameState.from_dict(s.to_dict())
	assert_eq(copy.to_dict(), s.to_dict())
	assert_eq(copy.loop, 1)


func test_every_choice_of_a_branch_fixes_its_npc_fate() -> void:
	var need := {"ch4_r_rescue": "npc_taoist_alive", "ch4_r_hunter": "npc_hunter_alive", "ch4_r_warn": "npc_taoist_dead"}
	for node in need:
		for c in reg.story[node]["choices"]:
			var flags: Array = []
			for e in c.get("effects", []):
				if e["type"] == "set_flag":
					flags.append(e["flag"])
			assert_true(flags.has(need[node]), "%s/%s" % [node, c["id"]])


func test_rewind_after_json_round_trip_keeps_int_types() -> void:
	_to_incident()
	var loaded := GameState.from_dict(JSON.parse_string(JSON.stringify(s.to_dict())))
	assert_eq(loaded.checkpoint, s.checkpoint)
	for k in loaded.checkpoint["action_counts"]:
		assert_eq(typeof(loaded.checkpoint["action_counts"][k]), TYPE_INT, k)
	for k in loaded.checkpoint["relations"]:
		assert_eq(typeof(loaded.checkpoint["relations"][k]), TYPE_INT, k)


func test_rewind_rewards_are_paid_once_across_save_load() -> void:
	_to_incident()
	_pick(["watch_hunter"])
	var copy := GameState.from_dict(s.to_dict())
	assert_eq(copy.resources, s.resources)
	act.story.scan(copy)
	assert_eq(act.story.pending(copy), "ch1_return")  # the pending return event survives and reopens nothing twice
	assert_eq((copy.story["done"] as Dictionary).size(), (s.story["done"] as Dictionary).size())


func test_v4_save_migrates_without_checkpoint() -> void:
	var sm: Node = load("res://autoload/save_manager.gd").new()
	var d: Dictionary = s.to_dict()
	d.erase("loop")
	d.erase("checkpoint")
	d["schema_version"] = 4
	var m: Dictionary = sm.migrate(d)
	assert_eq(m["schema_version"], GameState.SCHEMA_VERSION)
	assert_eq(sm.validate_state(m, reg), [])
	var back := GameState.from_dict(m)
	assert_eq(back.loop, 0)
	assert_true(back.checkpoint.is_empty())
	sm.free()


func test_bad_checkpoint_is_rejected() -> void:
	var sm: Node = load("res://autoload/save_manager.gd").new()
	_to_incident()
	var good: Dictionary = s.to_dict()
	assert_eq(sm.validate_state(good, reg), [])
	var bad: Dictionary = good.duplicate(true)
	bad["checkpoint"]["resources"]["wood"] = NAN
	assert_false(sm.validate_state(bad, reg).is_empty())
	bad = good.duplicate(true)
	bad["checkpoint"]["relations"]["nobody"] = 1
	assert_false(sm.validate_state(bad, reg).is_empty())
	bad = good.duplicate(true)
	bad["checkpoint"].erase("flags")
	assert_false(sm.validate_state(bad, reg).is_empty())
	bad = good.duplicate(true)
	bad["loop"] = -1
	assert_false(sm.validate_state(bad, reg).is_empty())
	sm.free()


func test_content_validates_with_localization_in_both_languages() -> void:
	assert_eq(reg.errors, [])
	for k in ["ch1_return", "ch4_r_rescue", "ch4_method_rogue", "ch5_path_relic"]:
		assert_true(reg.story.has(k), k)
