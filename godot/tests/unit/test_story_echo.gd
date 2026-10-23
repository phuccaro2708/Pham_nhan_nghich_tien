extends GutTest
## V5 hệ quả về sau: node sau Hắc Thạch Động nhận ra nguồn pháp môn đã chọn; các nhánh gặp nhau ở cùng một node nhưng để lại cờ khác nhau.

const NODE: String = "ch6_rock_echo"
const SOURCES: Array = ["guided", "evidence", "relic", "rogue"]

var act: ActionSystem
var s: GameState
var reg: ContentRegistry


func before_each() -> void:
	var w: Dictionary = TestHelpers.world(23, false)
	act = w["act"]
	s = w["state"]
	reg = act.registry
	s.flags["tutorial_started"] = true
	for id in reg.resources:
		s.resources[id] = float(reg.resources[id].get("initial", 0.0))


func _cleared(src: String) -> void:
	s.flags["qi_source"] = src
	s.flags["black_rock_cleared"] = true
	act.story.scan(s)


func test_node_waits_for_the_cave_to_be_cleared() -> void:
	s.flags["qi_source"] = "guided"
	act.story.scan(s)
	assert_ne(act.story.pending(s), NODE)
	_cleared("guided")
	assert_eq(act.story.pending(s), NODE)


func test_followup_text_matches_choice() -> void:
	var seen: Dictionary = {}
	for src in SOURCES:
		s.flags["qi_source"] = src
		var k: String = act.story.node_text_key(s, NODE)
		assert_ne(k, reg.story[NODE]["text_key"], src)
		seen[k] = true
	assert_eq(seen.size(), SOURCES.size(), "each source reads its own memory of the cave")


func test_each_branch_has_its_own_echo_and_everyone_a_free_way_on() -> void:
	for src in SOURCES:
		s = GameState.new_game(5)
		s.flags["tutorial_started"] = true
		_cleared(src)
		var ok: Array = []
		for c in reg.story[NODE]["choices"]:
			if act.story.check_choice(s, c["id"])["ok"]:
				ok.append(c["id"])
		assert_true(ok.has("echo_" + src), src)
		assert_true(ok.has("walk_on"), "the free choice never locks")
		assert_eq(ok.size(), 2, "%s sees only its own echo: %s" % [src, ok])


func test_branches_converge_with_different_flags() -> void:
	var ends: Dictionary = {}
	for src in SOURCES:
		s = GameState.new_game(5)
		s.flags["tutorial_started"] = true
		_cleared(src)
		assert_true(act.story.choose(s, "echo_" + src)["ok"], src)
		assert_eq(act.story.pending(s), "", src)
		assert_true((s.story["done"] as Dictionary).has(NODE), src)
		assert_eq(s.flags["rock_echo"], src)
		ends[src] = JSON.stringify([s.relations, s.resources, s.flags["rock_echo"]])
	assert_eq(ends.values().size(), 4)
	for i in SOURCES.size():
		for j in range(i + 1, SOURCES.size()):
			assert_ne(ends[SOURCES[i]], ends[SOURCES[j]], "%s == %s" % [SOURCES[i], SOURCES[j]])


func test_walk_on_still_converges_without_the_echo() -> void:
	_cleared("relic")
	assert_true(act.story.choose(s, "walk_on")["ok"])
	assert_eq(s.flags["rock_echo"], "none")


func test_paid_once_across_save_load() -> void:
	_cleared("rogue")
	act.story.choose(s, "echo_rogue")
	var silver: float = float(s.resources["silver"])
	var copy := GameState.from_dict(JSON.parse_string(JSON.stringify(s.to_dict())))
	act.story.scan(copy)
	act.story.scan(s)
	assert_eq(act.story.pending(copy), "")
	assert_eq(act.story.pending(s), "")
	assert_eq(float(copy.resources["silver"]), silver)


func test_every_choice_has_a_hint_and_ledger_shows_it() -> void:
	for c in reg.story[NODE]["choices"]:
		assert_true(c.has("later_hint_key") and c.has("result_key"), c["id"])
	_cleared("evidence")
	act.story.choose(s, "echo_evidence")
	var l: Array = act.path.ledger(s).filter(func(e: Dictionary) -> bool: return e["node"] == NODE)
	assert_eq(l.size(), 1)
	assert_eq(l[0]["choice"], "echo_evidence")


func test_echo_text_is_localized_in_both_languages() -> void:
	var en: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/localization/en.json"))
	var keys: Array = [reg.story[NODE]["title_key"], reg.story[NODE]["text_key"]]
	for v in reg.story[NODE]["text_variants"]:
		keys.append(v["text_key"])
	for c in reg.story[NODE]["choices"]:
		for k in ["text_key", "result_key", "later_hint_key"]:
			keys.append(c[k])
	for k in keys:
		assert_true(reg.texts.has(k) and en.has(k), k)
