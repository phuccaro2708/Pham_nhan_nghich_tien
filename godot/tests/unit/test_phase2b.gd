extends GutTest
## Phase 2B unit tests: mastery, story graph, content validation.

var w: Dictionary
var act: ActionSystem
var s: GameState


func before_each() -> void:
	w = TestHelpers.world(3)
	act = w["act"]
	s = w["state"]
	s.flags["tutorial_started"] = true
	for id in act.registry.resources:
		s.resources[id] = float(act.registry.resources[id].get("initial", 0.0))


func _complete(id: String, times: int = 1) -> void:
	for _i in times:
		s.resources["wood"] = 0.0  # keep under the storage cap so long loops never block
		assert_true(act.start_action(s, id)["ok"], "start %s" % id)
		act.advance(s, act.duration_ticks(act.registry.actions[id], s))
		act.stop_action(s)


# ---------- mastery ----------

func test_xp_curve_matches_gdd() -> void:
	var def: Dictionary = act.registry.mastery_for_action("gather_wood")
	assert_almost_eq(MasterySystem.xp_required(def, 1), 20.0, 1e-9)
	assert_almost_eq(MasterySystem.xp_required(def, 2), 27.0, 1e-9)
	assert_almost_eq(MasterySystem.xp_required(def, 5), 20.0 * pow(1.35, 4), 1e-6)


func test_completion_gives_xp_and_levels_up_once() -> void:
	_complete("gather_wood", 20)
	assert_eq(act.mastery.level_of(s, "gather_wood"), 2)
	assert_almost_eq(float(s.mastery["gather_wood"]["xp"]), 0.0, 1e-9)
	_complete("gather_wood", 1)
	assert_almost_eq(float(s.mastery["gather_wood"]["xp"]), 1.0, 1e-9)


func test_cancelled_or_unfinished_action_gives_no_xp() -> void:
	act.start_action(s, "gather_wood")
	act.advance(s, 10)
	act.stop_action(s)
	assert_false(s.mastery.has("gather_wood"))


func test_milestone_effect_is_paid_exactly_once() -> void:
	s.mastery["gather_wood"] = {"level": 9, "xp": 0.0, "claimed": [5]}
	var need: int = int(ceil(MasterySystem.xp_required(act.registry.mastery_for_action("gather_wood"), 9)))
	_complete("gather_wood", need)
	assert_eq(act.mastery.level_of(s, "gather_wood"), 10)
	assert_eq(s.resources["silver"], 20.0)  # level 10 milestone: +20 silver
	assert_eq(s.mastery["gather_wood"]["claimed"], [5, 10])
	# crossing the same level again (e.g. a replayed completion) cannot pay it again
	act.mastery._claim(s, act.registry.mastery_for_action("gather_wood"), s.mastery["gather_wood"], 10)
	assert_eq(s.resources["silver"], 20.0)


func test_bonus_is_derived_from_level_not_stored() -> void:
	var base: float = act.effects.yield_multiplier(s, "wood")
	s.mastery["gather_wood"] = {"level": 5, "xp": 0.0, "claimed": [5]}
	assert_almost_eq(act.effects.yield_multiplier(s, "wood"), base * 1.10, 1e-9)
	s.mastery["gather_wood"]["level"] = 4  # losing the level removes the bonus: nothing was baked into state
	assert_almost_eq(act.effects.yield_multiplier(s, "wood"), base, 1e-9)


func test_groups_add_inside_and_multiply_between() -> void:
	s.upgrades["iron_axe"] = 2  # +100%
	s.mastery["gather_wood"] = {"level": 5, "xp": 0.0, "claimed": [5]}  # +10%
	assert_almost_eq(act.effects.yield_multiplier(s, "wood"), 2.0 * 1.1, 1e-9)


func test_max_level_stops_xp() -> void:
	s.mastery["carry_water"] = {"level": 10, "xp": 0.0, "claimed": [5, 10]}
	act.registry.mastery["mastery_carry_water"]["max_level"] = 10
	assert_eq(act.mastery.on_completed(s, "carry_water"), 0)
	assert_eq(s.mastery["carry_water"]["xp"], 0.0)


func test_save_mid_action_does_not_double_xp() -> void:
	act.start_action(s, "gather_wood")
	act.advance(s, 20)
	var copy := GameState.from_dict(s.to_dict())
	act.advance(copy, 1000)
	act.advance(s, 1000)
	assert_eq(copy.to_dict(), s.to_dict())


# ---------- story ----------

func _trigger_first_node() -> void:
	s.action_counts["gather_wood"] = 3
	act.story.scan(s)


func test_trigger_opens_pending_event() -> void:
	assert_eq(act.story.pending(s), "")
	_trigger_first_node()
	assert_eq(act.story.pending(s), "ch1_morning_smoke")


func test_completing_an_action_can_open_event() -> void:
	s.action_counts["gather_wood"] = 2
	_complete("gather_wood")
	assert_eq(act.story.pending(s), "ch1_morning_smoke")


func test_choice_requirements_and_costs_are_enforced() -> void:
	_trigger_first_node()
	var r: Dictionary = act.story.choose(s, "give_wood")
	assert_false(r["ok"])
	assert_eq(r["reason"], "insufficient_resources")
	assert_eq(act.story.pending(s), "ch1_morning_smoke")  # a refused choice changes nothing
	assert_false(act.story.choose(s, "nope")["ok"])


func test_choice_applies_effects_once_and_closes_event() -> void:
	_trigger_first_node()
	s.resources["wood"] = 7.0
	assert_true(act.story.choose(s, "give_wood")["ok"])
	assert_eq(s.resources["wood"], 2.0)
	assert_eq(s.relations["ba_ly"], 2)
	assert_eq(s.story["done"]["ch1_morning_smoke"], "give_wood")
	assert_false(act.story.choose(s, "give_wood")["ok"])  # nothing pending any more
	assert_eq(s.relations["ba_ly"], 2)
	assert_ne(act.story.pending(s), "ch1_morning_smoke")  # a done node never reopens


func test_chain_only_nodes_open_through_next_only() -> void:
	s.action_counts["gather_wood"] = 99
	s.action_counts["train_body"] = 99
	s.story["done"]["ch3_crossroads"] = "explore"
	s.knowledge = []  # the fixture knows everything; the mốc is only for a character who has not entered the Way
	s.realm_id = "cuong_than"
	var seen: Array = []
	for _i in 12:
		if act.story.pending(s) == "":
			act.story.scan(s)
		var p: String = act.story.pending(s)
		if p == "":
			break
		seen.append(p)
		assert_false(act.registry.story[p].get("chain_only", false) and seen.size() == 1, "a chain_only node opened through scan")
		if p == "ch1_wounded_taoist":
			s.resources["herb"] = 5.0
			assert_true(act.story.choose(s, "heal")["ok"])
			assert_eq(act.story.pending(s), "ch1_mountain_incident")
			return
		act.story.choose(s, act.registry.story[p]["choices"][-1]["id"])
	fail_test("wounded taoist never opened: %s" % [seen])


func test_pending_event_survives_save_load() -> void:
	_trigger_first_node()
	var copy := GameState.from_dict(s.to_dict())
	assert_eq(act.story.pending(copy), "ch1_morning_smoke")
	assert_eq(copy.to_dict(), s.to_dict())


# ---------- cultivation chain ----------

func test_sense_qi_gates_luyen_khi() -> void:
	s.realm_id = "cam_khi"
	s.resources["body"] = 200.0
	s.resources["silver"] = 50.0
	assert_false(act.check_can_start(s, "breakthrough")["ok"])
	assert_false(act.check_can_start(s, "sense_qi")["ok"])  # needs the method from the story
	s.flags["knows_qi_method"] = true
	s.resources["herb"] = 3.0
	_complete("sense_qi")
	assert_true(s.flags["qi_sensed"])
	assert_true(act.check_can_start(s, "breakthrough")["ok"])


func test_intro_technique_is_learned_once_and_speeds_cultivation() -> void:
	s.realm_id = "luyen_khi_1"
	s.flags["knows_qi_method"] = true
	s.resources["herb"] = 4.0
	var before: int = act.duration_ticks(act.registry.actions["absorb_qi"], s)
	assert_true(act.start_action(s, "learn_dan_khi")["ok"])
	assert_true(s.techniques.has("dan_khi_nhap_mon"))
	assert_false(act.check_can_start(s, "learn_dan_khi")["ok"])  # cannot be bought twice
	assert_lt(act.duration_ticks(act.registry.actions["absorb_qi"], s), before)
	assert_eq(s.resources["herb"], 2.0)


func test_technique_insight_raises_breakthrough_chance() -> void:
	s.realm_id = "luyen_khi_9"
	var base: float = act.realms.success_chance(s)
	s.techniques.append("dan_khi_nhap_mon")
	assert_almost_eq(act.realms.success_chance(s), base + 0.05, 1e-9)


func test_failed_ritual_refunds_part_of_cultivation_only() -> void:
	s.realm_id = "luyen_khi_9"
	var failed: bool = false
	for seed_value in range(1, 80):
		s.realm_id = "luyen_khi_9"
		s.flags["meridian_damaged"] = false
		s.breakthrough_failures = 0
		s.resources["cultivation"] = 11020.0
		s.resources["silver"] = 500.0
		s.rng_state = SimRng.seed_to_state(seed_value)
		act.start_action(s, "breakthrough")
		if s.realm_id == "luyen_khi_9":
			failed = true
			break
	assert_true(failed)
	assert_almost_eq(s.resources["cultivation"], 11020.0 * float(act.realms.breakthrough_def(s)["on_fail_refund"]["cultivation"]), 0.01)
	assert_eq(s.resources["silver"], 0.0)


# ---------- content validation ----------

func _fresh() -> ContentRegistry:
	var r := ContentRegistry.new()
	assert_true(r.load_all(), str(r.errors))
	return r


func _errors_after(r: ContentRegistry) -> String:
	r.errors.clear()
	r.validate()
	return str(r.errors)


func test_real_content_is_valid_and_english_is_complete() -> void:
	var r := _fresh()
	for key in r.texts:
		assert_true(r.translations["en"].has(key), "en.json lacks %s" % key)


func test_story_node_without_free_choice_is_rejected() -> void:
	var r := _fresh()
	r.story["ch1_morning_smoke"]["choices"] = [{"id": "x", "text_key": "story.ch1_morning_smoke.ignore", "costs": {"wood": 1}}]
	assert_string_contains(_errors_after(r), "softlock guard")


func test_story_cycle_is_rejected() -> void:
	var r := _fresh()
	r.story["ch1_cave_rumor"]["choices"][0]["next"] = "ch1_wounded_taoist"
	r.story["ch1_wounded_taoist"]["choices"][1]["next"] = "ch1_cave_rumor"
	assert_string_contains(_errors_after(r), "cycle")


func test_story_unknown_next_is_rejected() -> void:
	var r := _fresh()
	r.story["ch1_cave_rumor"]["choices"][0]["next"] = "no_such_node"
	assert_string_contains(_errors_after(r), "unknown next node")


func test_milestone_cannot_advance_realm() -> void:
	var r := _fresh()
	r.mastery["mastery_gather_wood"]["milestones"][0]["effects"] = [{"type": "advance_realm"}]
	assert_string_contains(_errors_after(r), "only allowed on breakthrough")


func test_story_choice_cannot_advance_realm() -> void:
	var r := _fresh()
	r.story["ch1_morning_smoke"]["choices"][2]["effects"] = [{"type": "advance_realm"}]
	assert_string_contains(_errors_after(r), "only allowed on breakthrough")


func test_missing_english_story_text_is_an_error() -> void:
	var r := _fresh()
	r.texts.erase("story.ch1_morning_smoke.text")
	assert_string_contains(_errors_after(r), "ch1_morning_smoke")


func test_breakthrough_cannot_be_automatable() -> void:
	var r := _fresh()
	r.actions["breakthrough"]["automation_allowed"] = true
	assert_string_contains(_errors_after(r), "never be automated")


func test_old_realm_id_migrates_to_vo() -> void:
	var d: Dictionary = s.to_dict()
	d["realm_id"] = "pham_the"
	d["content_version"] = 1
	var m: Dictionary = ContentMigration.apply(d, act.registry)
	assert_eq(m["realm_id"], "vo")


func test_qi_resources_hidden_until_cam_khi() -> void:
	var cond: Dictionary = act.registry.resources["cultivation"]["visible_when"]
	assert_false(act.conditions.is_met(cond, s))
	s.realm_id = "cam_khi"
	assert_true(act.conditions.is_met(cond, s))


func test_early_cultivation_actions_and_tab_are_gated_until_cam_khi() -> void:
	var reg: ContentRegistry = TestHelpers.real_registry()
	var w: Dictionary = TestHelpers.world(3, false)
	var s: GameState = w["state"]
	var cond: ConditionEvaluator = w["act"].conditions
	for id in ["absorb_qi", "refine_qi", "sense_qi", "learn_dan_khi"]:
		assert_false(cond.is_met(reg.actions[id]["visible_when"], s), id)
	assert_false(reg.actions["train_body"].has("visible_when"))
	var tab: Dictionary = reg.config["ui"]["tab_visible_when"]
	assert_false(cond.is_met(tab["cultivation"], s))
	s.realm_id = "cam_khi"
	assert_true(cond.is_met(tab["cultivation"], s))
	assert_true(cond.is_met(reg.actions["absorb_qi"]["visible_when"], s))


func test_bad_ui_visibility_config_is_rejected() -> void:
	var r: ContentRegistry = TestHelpers.real_registry()
	r.errors.clear()
	r.config["ui"] = {"tab_visible_when": {"cultivaton": {"type": "realm_at_least", "realm": "cam_khi"}}}
	r.validate()
	assert_true(str(r.errors).contains("unknown page"))
	r.errors.clear()
	r.config["ui"] = []
	r.validate()
	assert_true(str(r.errors).contains("tab_visible_when must be an object"))
	r.errors.clear()
	r.config["ui"] = {}
	r.actions["absorb_qi"]["visible_when"] = {"type": "realm_at_least", "realm": "nope"}
	r.validate()
	assert_true(str(r.errors).contains("absorb_qi"))
