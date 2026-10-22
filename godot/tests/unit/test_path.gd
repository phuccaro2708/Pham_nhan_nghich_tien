extends GutTest
## V1 Tiên Lộ: PathSystem shows only what the character has discovered, explains blocked routes, and
## previews story choices. It reads state and never changes it.

var act: ActionSystem
var s: GameState


func before_each() -> void:
	var w: Dictionary = TestHelpers.world(5, false)
	act = w["act"]
	s = w["state"]


func _ids(list: Array) -> Array:
	return list.map(func(e: Dictionary) -> String: return e["id"])


func test_path_hides_undiscovered_entries() -> void:
	assert_eq(act.path.entries(s), [], "a fresh commoner has no path yet")
	assert_true(act.path.current(s).is_empty())


func test_path_shows_blocker_reason_and_next_step() -> void:
	s.knowledge = ["heard_of_cultivators", "mem_cave_site"]
	var list: Array = act.path.entries(s)
	assert_eq(_ids(list), ["qi_method"])
	assert_eq(list[0]["clues"], ["heard_of_cultivators", "mem_cave_site"], "only known clues, in data order")
	assert_eq(list[0]["blockers"], ["path.qi_method.blocked"])
	assert_eq(act.path.current(s)["id"], "qi_method")


func test_unknown_clues_stay_hidden() -> void:
	s.knowledge = ["heard_of_cultivators"]
	assert_eq(act.path.entries(s)[0]["clues"], ["heard_of_cultivators"])


func test_path_moves_on_when_method_is_known() -> void:
	s.knowledge = ["heard_of_cultivators"]
	s.flags["knows_qi_method"] = true
	var list: Array = act.path.entries(s)
	assert_eq(_ids(list), ["qi_method", "sense_qi"])
	assert_true(list[0]["done"])
	assert_eq(list[0]["blockers"], [], "a finished milestone lists no blockers")
	assert_eq(act.path.current(s)["id"], "sense_qi")
	assert_eq(list[1]["blockers"], ["path.sense_qi.blocked_realm"], "needs a realm the commoner lacks")


func test_path_is_pure_and_deterministic() -> void:
	s.knowledge = ["heard_of_cultivators", "martial_basics"]
	var before: Dictionary = s.to_dict()
	var a: Array = act.path.entries(s)
	assert_eq(a, act.path.entries(s))
	assert_eq(s.to_dict(), before, "describing the path never mutates state")


func test_every_path_key_is_localized_in_both_languages() -> void:
	var r: ContentRegistry = act.registry
	assert_true(r.errors.is_empty(), str(r.errors))
	assert_false(r.path_order.is_empty())
	for id in r.path_order:
		var d: Dictionary = r.path_entries[id]
		var keys: Array = [d["name_key"], d["goal_key"]]
		for b in d.get("blockers", []):
			keys.append(b["reason_key"])
		for k in keys:
			assert_true(r.texts.has(k), "vi lacks %s" % k)
			assert_true(r.translations["en"].has(k), "en lacks %s" % k)


func test_path_refs_are_validated() -> void:
	var r := TestHelpers.real_registry()
	r.path_entries["qi_method"]["clues"] = ["no_such_knowledge"]
	r.errors.clear()
	r.validate()
	assert_string_contains(str(r.errors), "no_such_knowledge")
	r = TestHelpers.real_registry()
	r.path_entries["sense_qi"]["blockers"][0]["needs"] = {"type": "nope"}
	r.errors.clear()
	r.validate()
	assert_false(r.errors.is_empty())


func _choice(node: String, id: String) -> Dictionary:
	for c in act.registry.story[node]["choices"]:
		if c["id"] == id:
			return c
	return {}


func test_choice_preview_lists_costs_gains_and_relations() -> void:
	var heal: Array = act.path.choice_preview(_choice("ch1_wounded_taoist", "heal"))
	assert_true(heal.any(func(l: Dictionary) -> bool: return l["kind"] == "cost" and l["id"] == "herb" and l["amount"] == 3.0))
	var loot: Array = act.path.choice_preview(_choice("ch1_wounded_taoist", "loot"))
	assert_true(loot.any(func(l: Dictionary) -> bool: return l["kind"] == "resource" and l["id"] == "silver" and l["amount"] == 30.0))
	assert_true(loot.any(func(l: Dictionary) -> bool: return l["kind"] == "relation" and l["id"] == "dao_si" and l["amount"] == -2.0))


func test_choice_preview_does_not_spoil_knowledge_or_flags() -> void:
	for l in act.path.choice_preview(_choice("ch1_wounded_taoist", "heal")):
		assert_true(["cost", "resource", "relation"].has(l["kind"]))


func test_story_followup_recognizes_choice() -> void:
	var node := "ch1_mountain_incident"
	var base: String = act.story.node_text_key(s, node)
	assert_eq(base, act.registry.story[node]["text_key"])
	s.story["done"]["ch1_wounded_taoist"] = "heal"
	var healed: String = act.story.node_text_key(s, node)
	s.story["done"]["ch1_wounded_taoist"] = "loot"
	var robbed: String = act.story.node_text_key(s, node)
	assert_ne(healed, base)
	assert_ne(robbed, base)
	assert_ne(healed, robbed)


func test_ledger_lists_chosen_branch_with_hint() -> void:
	s.story["done"]["ch1_wounded_taoist"] = "loot"
	var l: Array = act.path.ledger(s)
	assert_eq(l.size(), 1)
	assert_eq(l[0]["node"], "ch1_wounded_taoist")
	assert_eq(l[0]["choice"], "loot")
	assert_eq(l[0]["later_hint_key"], "story.ch1_wounded_taoist.loot.later")
