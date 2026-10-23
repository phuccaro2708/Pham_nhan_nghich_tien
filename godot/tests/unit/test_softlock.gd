extends GutTest
## V7 chống softlock chiến dịch dài: tài nguyên bắt buộc luôn tái tạo được, mọi thất bại có hành động phục hồi, hết thọ nguyên giữ story + tri thức.

var act: ActionSystem
var s: GameState
var reg: ContentRegistry


func before_each() -> void:
	var w: Dictionary = TestHelpers.world(3, true)
	act = w["act"]
	s = w["state"]
	reg = act.registry
	s.flags["tutorial_started"] = true


func _errors_after(mutate: Callable) -> Array:
	var r := TestHelpers.real_registry()
	mutate.call(r)
	r.errors.clear()
	r.validate()
	return r.errors


func test_required_resources_always_have_renewable_source() -> void:
	var req: Array = []
	for id in reg.resources:
		if reg.resources[id].get("required_for_main", false):
			req.append(id)
	for id in ["wood", "silver", "body", "spirit_qi", "cultivation", "herb"]:
		assert_true(req.has(id), id)
	assert_eq(TestHelpers.real_registry().errors, [])


func test_validator_catches_a_resource_with_no_free_source() -> void:
	var errs: Array = _errors_after(func(r: ContentRegistry) -> void: r.actions["gather_herbs"]["effects"] = [])
	assert_string_contains(str(errs), "herb")
	errs = _errors_after(func(r: ContentRegistry) -> void: r.actions["gather_herbs"]["costs"] = {"herb": 1})  # needs what it makes
	assert_string_contains(str(errs), "herb")
	errs = _errors_after(func(r: ContentRegistry) -> void: r.resources["technique_fragment"]["required_for_main"] = true)
	assert_string_contains(str(errs), "technique_fragment")


func test_every_failure_leaves_a_recovery_action() -> void:
	assert_eq(_errors_after(func(r: ContentRegistry) -> void: r.actions["treat_meridian"]["effects"] = []).is_empty(), false)
	assert_eq(_errors_after(func(r: ContentRegistry) -> void: r.actions["rest_heal"]["effects"] = []).is_empty(), false)


func test_no_dead_end_after_a_failed_breakthrough_or_a_defeat() -> void:
	s.realm_id = "luyen_khi_9"
	s.breakthrough_failures = 0
	s.flags["meridian_damaged"] = true
	s.wounds = int(reg.config["combat"]["max_wounds"])
	s.resources["silver"] = 0.0
	s.flags["knows_qi_method"] = true
	# silver is earned again by a free action, then the damage is treated and the wounds heal
	var r: Dictionary = act.start_action(s, "gather_wood")
	assert_true(r["ok"], str(r))
	act.stop_action(s)
	s.resources["silver"] = 50.0
	r = act.start_action(s, "treat_meridian")
	assert_true(r["ok"], str(r))
	act.advance(s, act.duration_ticks(reg.actions["treat_meridian"], s))
	act.stop_action(s)
	assert_false(s.flags["meridian_damaged"])
	r = act.start_action(s, "rest_heal")
	assert_true(r["ok"], str(r))


func test_life_end_keeps_story_and_knowledge() -> void:
	s.story["done"]["ch1_wounded_taoist"] = "heal"
	s.knowledge.append("mem_taoist_wound")
	s.life["status"] = "deceased"
	var back := GameState.from_dict(JSON.parse_string(JSON.stringify(s.to_dict())))
	assert_eq(back.life["status"], "deceased")
	assert_eq(back.story["done"], s.story["done"])
	assert_eq(back.knowledge, s.knowledge)
	assert_false(act.start_action(s, "gather_wood")["ok"], "the dead take no actions")
