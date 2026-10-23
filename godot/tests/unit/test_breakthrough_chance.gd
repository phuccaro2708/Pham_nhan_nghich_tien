extends GutTest
## V6 đột phá Trúc Cơ: P có số hạng thật (nền tảng, thương tích, Đạo Tâm, công pháp), do người chơi ra lệnh, pity vẫn đảm bảo.

var act: ActionSystem
var s: GameState
var reg: ContentRegistry


func before_each() -> void:
	var w: Dictionary = TestHelpers.world(9, false)
	act = w["act"]
	s = w["state"]
	reg = act.registry
	s.realm_id = "luyen_khi_9"


func _p() -> float:
	return act.realms.success_chance(s)


func test_terms_are_filled_and_bounded() -> void:
	var ch: Dictionary = reg.realms["luyen_khi_9"]["breakthrough"]["chance"]
	assert_gt((ch["terms"] as Array).size(), 0)
	assert_lte(float(ch["max"]), 0.8, "GDD 6.5: the ceiling is 80%")
	assert_gte(_p(), float(ch["min"]))
	assert_lte(_p(), float(ch["max"]))


func test_chance_reflects_build_and_wounds() -> void:
	var base: float = _p()
	s.mastery["absorb_qi"] = {"level": 10, "xp": 0.0}
	var trained: float = _p()
	assert_gt(trained, base, "mastery raises the odds")
	s.wounds = 3
	assert_lt(_p(), trained, "wounds lower them")
	s.wounds = 0
	s.story["done"]["ch6_rock_echo"] = "echo_guided"
	assert_gt(_p(), trained, "the Đạo Tâm term follows the story")
	s.story["done"]["ch6_rock_echo"] = "walk_on"
	assert_eq(_p(), trained, "walking on adds nothing")
	var steady: float = _p()
	act.effects.apply(s, [{"type": "learn_technique", "technique": "dan_khi_nhap_mon"}, {"type": "learn_technique", "technique": "dan_khi_on_dinh"}])
	s.main_technique = "dan_khi_on_dinh"
	assert_gt(_p(), steady, "a steadier technique helps")


func test_chance_is_clamped_to_the_floor_and_ceiling() -> void:
	var ch: Dictionary = reg.realms["luyen_khi_9"]["breakthrough"]["chance"]
	s.wounds = 5
	assert_gte(_p(), float(ch["min"]))
	s.mastery["absorb_qi"] = {"level": 20, "xp": 0.0}
	s.story["done"]["ch6_rock_echo"] = "echo_relic"
	reg.realms["luyen_khi_9"]["breakthrough"]["chance"]["base"] = 5.0
	assert_eq(_p(), float(ch["max"]))


func test_automation_never_queues_the_breakthrough() -> void:
	assert_true(reg.actions["breakthrough"].get("breakthrough", false))
	var src: String = FileAccess.get_file_as_string("res://systems/automation_queue.gd")
	assert_string_contains(src, 'def.get("breakthrough", false)')
	assert_false(reg.actions["breakthrough"].get("offline_allowed", false))


func test_pity_still_guarantees_after_three_failures() -> void:
	s.breakthrough_failures = 3
	s.wounds = 5
	assert_true(act.realms.pity_reached(s))
	assert_true(act.realms.attempt(s)["success"])
	assert_eq(s.realm_id, "truc_co_so")


func test_bad_terms_are_rejected() -> void:
	for term in [{"when": {"type": "nope"}, "weight": 0.1}, {"when": {}, "weight": "x"}, {"when": {}, "weight": 0.1, "resource": "silver"}, {"weight": 0.1}]:
		var r := TestHelpers.real_registry()
		r.realms["luyen_khi_9"]["breakthrough"]["chance"]["terms"].append(term)
		r.errors.clear()
		r.validate()
		assert_false(r.errors.is_empty(), str(term))
	assert_eq(TestHelpers.real_registry().errors, [])
