extends GutTest
## V9 Kết Đan: phẩm Kim Đan (`dan_grade`) tính từ độ thuần công pháp, mastery, thương tích, Đạo Tâm; ảnh hưởng chỉ số và đột phá sau.

var act: ActionSystem
var s: GameState
var reg: ContentRegistry


func before_each() -> void:
	var w: Dictionary = TestHelpers.world(9, true)
	act = w["act"]
	s = w["state"]
	reg = act.registry
	s.realm_id = "truc_co_vien_man"
	s.resources["cultivation"] = 1.0e9
	s.resources["silver"] = 1.0e9


func _form(main: String = "", mastery: int = 0, wounds: int = 0, echo: String = "") -> void:
	if main != "":
		act.effects.apply(s, [{"type": "learn_technique", "technique": main}])
		s.main_technique = main
	if mastery > 0:
		s.mastery["absorb_qi"] = {"level": mastery, "xp": 0.0, "claimed": []}
	s.wounds = wounds
	if echo != "":
		s.story["done"]["ch6_rock_echo"] = echo
	s.breakthrough_failures = 3  # pity: the grade is what is under test, not the roll
	assert_eq(act.realms.attempt(s)["to"], "kim_dan_so")


func test_grade_is_empty_before_the_core_forms() -> void:
	assert_eq(s.dan_grade, "")


func test_bare_character_forms_the_lowest_grade() -> void:
	_form()
	assert_eq(s.dan_grade, "ha_pham")


func test_purer_technique_and_mastery_raise_the_grade() -> void:
	_form("dan_khi_on_dinh", 20, 0, "echo_guided")
	assert_eq(s.dan_grade, "cuc_pham")


func test_wounds_lower_the_grade() -> void:
	var w: GameState = s
	_form("dan_khi_on_dinh", 20, 0, "echo_guided")
	var clean: int = reg.dan_grade_index(w.dan_grade)
	s = GameState.new_game(3)
	s.realm_id = "truc_co_vien_man"
	_form("dan_khi_on_dinh", 20, 5, "echo_guided")
	assert_lt(reg.dan_grade_index(s.dan_grade), clean)


func test_builds_end_in_different_grades() -> void:
	var seen: Dictionary = {}
	for cfg in [["", 0], ["thanh_moc_duong_khi", 10], ["dan_khi_on_dinh", 20]]:
		s = GameState.new_game(4)
		s.realm_id = "truc_co_vien_man"
		_form(cfg[0], cfg[1])
		seen[s.dan_grade] = true
	assert_eq(seen.size(), 3, str(seen.keys()))


func test_grade_adds_stat_bonus_and_helps_later_breakthroughs() -> void:
	var base_hp: float = act.effects.stat_bonus(s, "combat.hp")
	_form("dan_khi_on_dinh", 20, 0, "echo_guided")
	assert_gt(act.effects.stat_bonus(s, "combat.hp"), base_hp)
	var high: float = act.realms.success_chance(s)
	s.dan_grade = "ha_pham"
	assert_lt(act.realms.success_chance(s), high)
	assert_lte(high, 0.8)


func test_grade_conditions_and_validation() -> void:
	var c := ConditionEvaluator.new()
	c.content = reg
	s.dan_grade = "thuong_pham"
	assert_true(c.is_met({"type": "dan_grade_at_least", "grade": "trung_pham"}, s))
	assert_false(c.is_met({"type": "dan_grade_at_least", "grade": "cuc_pham"}, s))
	assert_true(c.validate({"type": "dan_grade_at_least", "grade": "nope"}, reg).size() > 0)
	assert_true(c.validate({"type": "main_technique_is", "technique": "nope"}, reg).size() > 0)
	assert_eq(c.validate({"type": "main_technique_is", "technique": "dan_khi_on_dinh"}, reg), [])


func test_save_round_trip_migration_and_rewind() -> void:
	_form("dan_khi_on_dinh", 20)
	var copy := GameState.from_dict(JSON.parse_string(JSON.stringify(s.to_dict())))
	assert_eq(copy.dan_grade, s.dan_grade)
	assert_eq(SaveManager.validate_state(s.to_dict(), reg), [])
	var old: Dictionary = s.to_dict()
	old.erase("dan_grade")
	old["schema_version"] = 9
	var m: Dictionary = SaveManager.migrate(old)
	assert_eq(m["dan_grade"], "")
	assert_eq(m["schema_version"], GameState.SCHEMA_VERSION)
	var bad: Dictionary = s.to_dict()
	bad["dan_grade"] = "nope"
	assert_true(SaveManager.validate_state(bad, reg).size() > 0)
	assert_true(GameState.WORLD_KEYS.has("dan_grade"), "the core is part of the world a rewind restores")


func test_failed_core_attempt_damages_meridians_and_can_be_treated() -> void:
	var b: Dictionary = reg.realms["truc_co_vien_man"]["breakthrough"]
	assert_eq(b["on_fail_flag"], "meridian_damaged")
	s.flags["meridian_damaged"] = true
	assert_eq(act.start_action(s, "breakthrough")["reason"], "requirements_not_met")
