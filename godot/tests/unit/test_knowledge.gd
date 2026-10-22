extends GutTest
## Phase 3 Phase 1: Knowledge System (conditions, effects, discovery gate, save v4) and the Ch1-3 story routes.

var act: ActionSystem
var s: GameState
var sm: Node


func before_each() -> void:
	var w: Dictionary = TestHelpers.world(5, false)
	act = w["act"]
	s = w["state"]
	s.flags["tutorial_started"] = true
	sm = load("res://autoload/save_manager.gd").new()


func after_each() -> void:
	sm.free()


func _fx(e: Dictionary) -> void:
	act.effects.apply(s, [e])


# ---------- condition + effect ----------

func test_learn_knowledge_is_idempotent_and_knows_reads_it() -> void:
	var cond := {"type": "knows", "knowledge": "herb_basics"}
	assert_false(act.conditions.is_met(cond, s))
	_fx({"type": "learn_knowledge", "knowledge": "herb_basics"})
	_fx({"type": "learn_knowledge", "knowledge": "herb_basics"})
	assert_true(act.conditions.is_met(cond, s))
	assert_eq(s.knowledge, ["herb_basics"])


func test_unknown_knowledge_is_a_validation_error() -> void:
	assert_false(act.conditions.validate({"type": "knows", "knowledge": "ghost"}, act.registry).is_empty())
	assert_false(EffectResolver.validate_effect({"type": "learn_knowledge", "knowledge": "ghost"}, act.registry, "t").is_empty())


func test_real_content_is_valid() -> void:
	assert_eq(act.registry.errors, [])


# ---------- discovery gate ----------

func test_undiscovered_actions_are_refused_everywhere() -> void:
	for id in ["breakthrough", "treat_meridian", "gather_herbs"]:
		assert_eq(act.check_can_start(s, id)["reason"], "not_discovered", id)
	s.knowledge = ["herb_basics"]
	assert_ne(act.check_can_start(s, "gather_herbs")["reason"], "not_discovered")


func test_automation_rejects_undiscovered_action() -> void:
	s.resources["wood"] = 30.0
	s.mastery["gather_wood"] = {"level": 3, "xp": 0.0}
	var r: Dictionary = act.automation.set_slots(s, [{"action": "gather_herbs", "repeat": 1}])
	assert_false(r["ok"])
	assert_eq(r["error"], "not_discovered")


func test_queue_and_offline_skip_an_action_forgotten_in_the_save() -> void:
	# A hand-edited save may still list an undiscovered action: it must be blocked at run time too.
	s.knowledge = ["herb_basics"]
	s.mastery["gather_wood"] = {"level": 3, "xp": 0.0}
	assert_true(act.automation.set_slots(s, [{"action": "gather_herbs", "repeat": 1}])["ok"])
	s.knowledge = []
	act.automation.start(s)
	assert_true(s.active_action.is_empty())
	OfflineSystem.apply(s, act, 600.0)
	assert_eq(s.action_counts.get("gather_herbs", 0), 0)


# ---------- save v3 -> v4 ----------

func test_v3_save_gets_knowledge_inferred_from_progress() -> void:
	var d: Dictionary = s.to_dict()
	d.erase("knowledge")
	d["schema_version"] = 3
	d["realm_id"] = "luyen_khi_2"
	var m: Dictionary = ContentMigration.apply(sm.migrate(d), act.registry)
	assert_eq(m["schema_version"], GameState.SCHEMA_VERSION)
	for k in ["village_life", "herb_basics", "body_lore", "martial_basics", "meridian_lore", "dao_entry", "qi_awareness"]:
		assert_true(m["knowledge"].has(k), k)
	assert_eq(sm.validate_state(m, act.registry), [])


func test_v3_commoner_keeps_only_everyday_knowledge() -> void:
	var d: Dictionary = s.to_dict()
	d.erase("knowledge")
	d["schema_version"] = 3
	d["realm_id"] = "vo"
	var m: Dictionary = ContentMigration.apply(sm.migrate(d), act.registry)
	assert_false(m["knowledge"].has("dao_entry"))
	assert_true(m["knowledge"].has("herb_basics"))


func test_v3_cuong_than_keeps_breakthrough() -> void:
	var d: Dictionary = s.to_dict()
	d.erase("knowledge")
	d["schema_version"] = 3
	d["realm_id"] = "cuong_than"
	var m: Dictionary = ContentMigration.apply(sm.migrate(d), act.registry)
	assert_true(m["knowledge"].has("dao_entry"))
	assert_false(m.has("infer_knowledge"))


func test_unknown_knowledge_id_in_a_save_is_rejected_then_parked() -> void:
	var d: Dictionary = s.to_dict()
	d["knowledge"] = ["ghost"]
	assert_false(sm.validate_state(d, act.registry).is_empty())
	var m: Dictionary = ContentMigration.apply(d, act.registry)
	assert_eq(m["knowledge"], [])
	assert_eq(m["orphans"]["knowledge"], ["ghost"])


# ---------- promote_realm ----------

func test_promote_realm_only_from_story_promotion_stage() -> void:
	_fx({"type": "promote_realm", "realm": "cuong_than"})
	assert_eq(s.realm_id, "cuong_than")
	_fx({"type": "promote_realm", "realm": "cam_khi"})  # cuong_than is not story-promoted
	assert_eq(s.realm_id, "cuong_than")


# ---------- story routes ----------

func _open_crossroads() -> void:
	s.story["done"]["ch2_mountain_rumor"] = "ask_elder"
	s.resources["body"] = 40.0
	s.resources["silver"] = 10.0
	act.story.scan(s)
	assert_eq(act.story.pending(s), "ch3_crossroads")


func _finish_route(first: String, route_node: String, last: String) -> void:
	_open_crossroads()
	assert_true(act.story.choose(s, first)["ok"])
	assert_eq(act.story.pending(s), route_node)
	assert_true(act.story.choose(s, last)["ok"])


func test_three_routes_reach_martial_basics_and_dan_the() -> void:
	var routes := [["study", "ch3_study", "careful"], ["help", "ch3_help", "learn_all"], ["explore", "ch3_explore", "follow"]]
	for r in routes:
		before_each()
		_finish_route(r[0], r[1], r[2])
		assert_true(s.knowledge.has("martial_basics"), r[0])
		assert_eq(s.realm_id, "cuong_than", r[0])


func test_every_route_has_a_free_fallback_that_still_promotes() -> void:
	var fallbacks := [["study", "ch3_study", "skim"], ["help", "ch3_help", "take_pay"], ["explore", "ch3_explore", "watch_hidden"]]
	for r in fallbacks:
		before_each()
		_finish_route(r[0], r[1], r[2])
		assert_eq(s.realm_id, "cuong_than", r[0])


func test_poor_player_can_still_take_a_route() -> void:
	_open_crossroads()
	s.resources["silver"] = 0.0
	assert_false(act.story.choose(s, "study")["ok"])  # refused, nothing changes
	assert_eq(act.story.pending(s), "ch3_crossroads")
	assert_true(act.story.choose(s, "help")["ok"])


func test_story_never_auto_chooses() -> void:
	_open_crossroads()
	act.advance(s, 600)
	assert_eq(act.story.pending(s), "ch3_crossroads")
	assert_ne(s.realm_id, "cuong_than")


func test_cultivation_knowledge_comes_after_the_rewind_not_in_life_one() -> void:
	s.realm_id = "cuong_than"
	s.story["done"]["ch3_crossroads"] = "explore"
	act.story.scan(s)
	assert_eq(act.story.pending(s), "ch1_before_mountain")
	assert_true(act.story.choose(s, "go_empty_handed")["ok"])
	assert_eq(act.story.pending(s), "ch1_wounded_taoist")
	assert_true(act.story.choose(s, "ask_first")["ok"])
	assert_eq(act.story.pending(s), "ch1_mountain_incident")
	assert_false(s.knowledge.has("dao_entry"))  # life one teaches nothing of the Way
	assert_true(act.story.choose(s, "watch_hunter")["ok"])
	assert_eq(act.story.pending(s), "ch1_return")
	for c in ["rescue", "ask_first", "hurry_off"]:
		assert_true(act.story.choose(s, c)["ok"])
	for k in ["dao_entry", "heard_of_cultivators"]:
		assert_true(s.knowledge.has(k), k)
	assert_false(s.knowledge.has("qi_awareness"))  # the method's knowledge waits for Cảm Khí
	assert_ne(act.check_can_start(s, "breakthrough")["reason"], "not_discovered")
