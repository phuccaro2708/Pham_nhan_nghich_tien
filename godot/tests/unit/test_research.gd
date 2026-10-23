extends GutTest
## V4 Nghịch Mệnh Tàn Kinh (GDD §XIV.1): thấy khiếm khuyết -> thu chứng cứ -> thử một hướng sửa -> công pháp biến thể có cái giá. Save v9.

const BASE: String = "dan_khi_nhap_mon"
const FLAW: String = "flaw_dan_khi"
const ROUTES: Dictionary = {
	"fix_stable": "dan_khi_on_dinh",
	"fix_swift": "dan_khi_cap_toc",
	"fix_reverse": "dan_khi_nghich_kinh",
}

var act: ActionSystem
var s: GameState
var reg: ContentRegistry


func before_each() -> void:
	var w: Dictionary = TestHelpers.world(17, false)
	act = w["act"]
	s = w["state"]
	reg = act.registry
	s.flags["tutorial_started"] = true
	for id in reg.resources:
		s.resources[id] = float(reg.resources[id].get("initial", 0.0))
	act.effects.apply(s, [{"type": "learn_technique", "technique": BASE}])


func _ready_to_research(fragments: float = 40.0) -> void:
	act.effects.apply(s, [{"type": "learn_knowledge", "knowledge": "mem_black_rock"}, {"type": "learn_knowledge", "knowledge": FLAW}])
	s.resources["technique_fragment"] = fragments
	s.resources["silver"] = 200.0


func _force(route: String, chance: float) -> void:
	reg.research[route]["chance"] = chance


func test_flaw_needs_evidence() -> void:
	assert_eq(act.start_action(s, "study_flaw")["reason"], "not_discovered", "no clue about the cave yet")
	act.effects.apply(s, [{"type": "learn_knowledge", "knowledge": "mem_black_rock"}])
	assert_eq(act.start_action(s, "study_flaw")["reason"], "insufficient_resources", "no fragments to study")
	s.resources["technique_fragment"] = 5.0
	assert_true(act.start_action(s, "study_flaw")["ok"])
	assert_true(s.knowledge.has(FLAW))
	assert_lt(float(s.resources["technique_fragment"]), 5.0, "studying costs evidence")
	assert_eq(act.start_action(s, "study_flaw")["reason"], "not_discovered", "the flaw is seen once")


func test_research_is_closed_until_the_flaw_is_seen() -> void:
	s.resources["technique_fragment"] = 40.0
	s.resources["silver"] = 200.0
	assert_false(act.research(s, "fix_stable")["ok"])
	act.effects.apply(s, [{"type": "learn_knowledge", "knowledge": FLAW}])
	assert_true(act.research(s, "fix_stable")["ok"])
	assert_eq(act.research(s, "nope")["reason"], "unknown_route")


func test_research_needs_the_base_technique() -> void:
	_ready_to_research()
	s.techniques.clear()
	assert_false(act.research(s, "fix_stable")["ok"])


func test_costs_are_paid_and_missing_resources_refused_without_loss() -> void:
	_ready_to_research(0.0)
	var before: Dictionary = s.resources.duplicate()
	var r: Dictionary = act.research(s, "fix_stable")
	assert_eq(r["reason"], "insufficient_resources")
	assert_eq(s.resources, before, "a refusal costs nothing")
	s.resources["technique_fragment"] = 40.0
	var age0: float = s.age_years
	assert_true(act.research(s, "fix_stable")["ok"])
	assert_gt(s.age_years, age0, "research takes time of life")


func test_variant_has_cost_not_flat_bonus() -> void:
	for route in ROUTES:
		var v: Dictionary = reg.techniques[ROUTES[route]]
		assert_eq(v["variant_of"], BASE)
		assert_eq(v["role"], "main", "a variant competes for the main slot")
	var swift: Dictionary = reg.techniques["dan_khi_cap_toc"]
	var reverse: Dictionary = reg.techniques["dan_khi_nghich_kinh"]
	assert_gt(int(swift["traits"]["injury_per_run"]), 0)
	assert_gt(int(reverse["traits"]["injury_per_run"]), int(swift["traits"]["injury_per_run"]))
	assert_gt(_absorb("dan_khi_cap_toc"), _absorb("dan_khi_on_dinh"))
	assert_gt(float(reverse.get("insight_modifier", 0.0)), float(swift.get("insight_modifier", 0.0)))


func _absorb(tid: String) -> float:
	for b in reg.techniques[tid]["bonuses"]:
		if b["stat"] == "speed.absorb_qi":
			return float(b["value"])
	return 0.0


func test_three_routes_end_in_distinct_variants() -> void:
	_ready_to_research(200.0)
	var seen: Dictionary = {}
	for route in ROUTES:
		_force(route, 1.0)
		var r: Dictionary = act.research(s, route)
		assert_true(r["ok"] and r["success"], route)
		assert_true(s.techniques.has(ROUTES[route]))
		seen[ROUTES[route]] = true
	assert_eq(seen.size(), 3)
	s.main_technique = "dan_khi_cap_toc"
	assert_gt(act.effects.trait_total(s, "injury_per_run"), 0)
	s.main_technique = "dan_khi_on_dinh"
	assert_eq(act.effects.trait_total(s, "injury_per_run"), 0)


func test_failure_refunds_part_and_pity_guarantees() -> void:
	_ready_to_research()
	var route: String = "fix_reverse"
	var pity: int = int(reg.research[route]["pity_failures"])
	assert_gt(pity, 0)
	_force(route, 0.0)
	var cost: float = float(reg.research[route]["costs"]["technique_fragment"])
	for i in pity:
		var before: float = float(s.resources["technique_fragment"])
		var r: Dictionary = act.research(s, route)
		assert_true(r["ok"] and not r["success"], "failure %d" % i)
		var spent: float = before - float(s.resources["technique_fragment"])
		assert_gt(spent, 0.0, "a failed attempt still costs")
		assert_lt(spent, cost, "but part of the price comes back")
		assert_false(s.techniques.has(ROUTES[route]))
	assert_gt(s.wounds, 0, "the risky route hurts when it fails")
	assert_eq(int(s.research_failures[route]), pity)
	var last: Dictionary = act.research(s, route)
	assert_true(last["success"], "pity: guaranteed after enough failures")
	assert_true(s.techniques.has(ROUTES[route]))
	assert_false(s.research_failures.has(route), "the counter resets on success")


func test_outcome_is_deterministic_from_the_seed() -> void:
	var outs: Array = []
	for i in 2:
		var w: Dictionary = TestHelpers.world(5, true)
		var a: ActionSystem = w["act"]
		var st: GameState = w["state"]
		a.effects.apply(st, [{"type": "learn_technique", "technique": BASE}, {"type": "learn_knowledge", "knowledge": FLAW}])
		st.resources["technique_fragment"] = 60.0
		st.resources["silver"] = 200.0
		var seq: Array = []
		a.registry.research["fix_swift"]["chance"] = 0.5
		for k in 4:
			seq.append(a.research(st, "fix_swift").get("success"))
			st.techniques.erase("dan_khi_cap_toc")
		outs.append(seq)
	assert_eq(outs[0], outs[1])


func test_reward_is_paid_once_and_survives_save_load() -> void:
	_ready_to_research()
	_force("fix_stable", 1.0)
	assert_true(act.research(s, "fix_stable")["success"])
	var frag: float = float(s.resources["technique_fragment"])
	assert_eq(act.research(s, "fix_stable")["reason"], "already_done")
	assert_eq(float(s.resources["technique_fragment"]), frag, "a repeat spends nothing")
	var sm: Node = load("res://autoload/save_manager.gd").new()
	s.research_failures["fix_swift"] = 1
	var parsed: Variant = JSON.parse_string(JSON.stringify(s.to_dict()))
	assert_eq(sm.validate_state(parsed, reg), [])
	var b: GameState = GameState.from_dict(parsed)
	assert_eq(b.to_dict(), s.to_dict())
	assert_eq(b.research_failures, {"fix_swift": 1})
	for mut in [{"nope": 1}, {"fix_swift": -1}, {"fix_swift": 1.5}, {"fix_swift": "x"}]:
		var d: Dictionary = (parsed as Dictionary).duplicate(true)
		d["research_failures"] = mut
		assert_false(sm.validate_state(d, reg).is_empty(), str(mut))
	sm.free()


func test_research_not_available_while_in_a_dungeon_or_dead() -> void:
	_ready_to_research()
	s.flags["bamboo_forest_cleared"] = true
	s.combat = {"dungeon": "bamboo_forest", "tier": 0, "paused": false, "pills": 0, "index": 0, "player_hp": 10, "enemy_hp": 10, "player_cd": 1, "enemy_cd": 1}
	assert_eq(act.research(s, "fix_stable")["reason"], "in_dungeon")
	s.combat = {}
	s.life["status"] = "deceased"
	assert_eq(act.research(s, "fix_stable")["reason"], "deceased")


func test_v8_save_migrates_to_v9() -> void:
	var sm: Node = load("res://autoload/save_manager.gd").new()
	var old: Dictionary = s.to_dict()
	old.erase("research_failures")
	old["schema_version"] = 8
	var m: Dictionary = sm.migrate(old)
	assert_eq(m["schema_version"], 9)
	assert_eq(m["research_failures"], {})
	assert_eq(sm.validate_state(m, reg), [])
	sm.free()


func test_content_validation_rejects_bad_routes() -> void:
	var cases: Array = [
		["variant", "nope"], ["variant", BASE], ["technique", "nope"], ["costs", {"nope": 1}],
		["chance", 0.0], ["chance", 1.5], ["pity_failures", -1], ["on_fail_refund", 1.5], ["on_fail_wounds", -1],
	]
	for c in cases:
		var r := TestHelpers.real_registry()
		r.research["fix_swift"][c[0]] = c[1]
		r.errors.clear()
		r.validate()
		assert_false(r.errors.is_empty(), str(c))
	var ok := TestHelpers.real_registry()
	assert_eq(ok.errors, [])
	assert_eq(ok.research.size(), 3)


func test_every_research_text_is_localized_in_both_languages() -> void:
	var en: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/localization/en.json"))
	for id in reg.research:
		for k in ["name_key", "desc_key"]:
			assert_true(reg.texts.has(reg.research[id][k]) and en.has(reg.research[id][k]), id)
	for tid in ROUTES.values():
		assert_true(reg.texts.has(reg.techniques[tid]["name_key"]) and en.has(reg.techniques[tid]["desc_key"]), tid)
