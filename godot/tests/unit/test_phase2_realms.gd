extends GutTest
## V8 nền GĐ2: thang cảnh giới tới Hóa Thần có trong data, nhưng chưa mở cho người chơi (cờ `phase2_open`).

const LADDER: Array = [
	"truc_co_so", "truc_co_trung", "truc_co_hau", "truc_co_vien_man",
	"kim_dan_so", "kim_dan_trung", "kim_dan_hau", "kim_dan_vien_man",
	"nguyen_anh_so", "nguyen_anh_trung", "nguyen_anh_hau", "nguyen_anh_vien_man",
	"hoa_than_so", "hoa_than_trung", "hoa_than_hau", "hoa_than_vien_man",
]
const LIFESPAN: Dictionary = {"truc_co": 200, "kim_dan": 500, "nguyen_anh": 1000, "hoa_than": 2000}

var reg: ContentRegistry


func before_each() -> void:
	reg = TestHelpers.real_registry()


func test_ladder_ends_at_hoa_than_vien_man_in_order() -> void:
	var i: int = reg.realm_order.find("truc_co_so")
	assert_eq(reg.realm_order.slice(i), LADDER)
	assert_eq(reg.errors, [])


func test_lifespan_follows_gdd_table() -> void:
	for id in LADDER:
		var major: String = "truc_co"
		for k in LIFESPAN:
			if id.begins_with(k):
				major = k
		assert_eq(int(reg.realms[id]["lifespan_years"]), LIFESPAN[major], id)


func test_every_new_stage_is_localized_in_both_languages() -> void:
	var en: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/localization/en.json"))
	for id in LADDER:
		var k: String = reg.realms[id]["name_key"]
		assert_true(reg.texts.has(k) and en.has(k), id)


func test_phase2_stays_closed_until_flag_is_set() -> void:
	var w: Dictionary = TestHelpers.world(5, true)
	var act: ActionSystem = w["act"]
	var s: GameState = w["state"]
	s.realm_id = "truc_co_so"
	s.resources["cultivation"] = 1.0e9
	s.resources["silver"] = 1.0e9
	assert_eq(act.start_action(s, "breakthrough")["reason"], "requirements_not_met", "GĐ2 chưa mở cho người chơi")
	s.flags["phase2_open"] = true
	assert_true(act.start_action(s, "breakthrough")["ok"])


func test_costs_and_caps_rise_along_the_ladder() -> void:
	var prev_cap: float = 0.0
	for id in LADDER:
		var d: Dictionary = reg.realms[id]
		assert_gt(float(d["cultivation_cap"]), prev_cap, id)
		prev_cap = float(d["cultivation_cap"])
		if id != "hoa_than_vien_man":
			assert_gt(float(d["breakthrough"]["costs"]["cultivation"]), 0.0, id)
			assert_lte(float(d["breakthrough"]["chance"]["max"]), 0.8, "GDD 6.5: trần 80%")
