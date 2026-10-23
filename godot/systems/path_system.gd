class_name PathSystem
extends RefCounted
## Tiên Lộ (GDD §XIV.1): what the character has discovered, what to do next and why a route is blocked.
## Pure read of state: nothing is stored, so there is no save migration. Only entries whose `visible_when`
## holds, clues the character knows and blockers whose `visible_when` holds are returned (mystery stays intact).

var registry: ContentRegistry
var conditions: ConditionEvaluator


func _init(p_registry: ContentRegistry, p_conditions: ConditionEvaluator) -> void:
	registry = p_registry
	conditions = p_conditions


## [{id, name_key, goal_key, done, clues: [knowledge id], blockers: [reason_key]}] in data order.
func entries(state: GameState) -> Array:
	var out: Array = []
	for id in registry.path_order:
		var d: Dictionary = registry.path_entries[id]
		if not conditions.is_met(d.get("visible_when", {}), state):
			continue
		var done: bool = d.has("done_when") and conditions.is_met(d["done_when"], state)
		var blockers: Array = []
		if not done:
			for b in d.get("blockers", []):
				if conditions.is_met(b.get("visible_when", {}), state) and not conditions.is_met(b["needs"], state):
					blockers.append(b["reason_key"])
		var clues: Array = (d.get("clues", []) as Array).filter(func(k: String) -> bool: return state.knowledge.has(k))
		out.append({"id": id, "name_key": d["name_key"], "goal_key": d["goal_key"], "done": done, "clues": clues, "blockers": blockers})
	return out


## First visible milestone not yet done, or {} when there is none.
func current(state: GameState) -> Dictionary:
	for e in entries(state):
		if not e["done"]:
			return e
	return {}


## Immediate, non-spoiling consequences of a story choice: costs, resource gains and relation changes only.
## [{kind: "cost"|"resource"|"relation", id, amount}]. Knowledge, flags and the like stay hidden.
func choice_preview(choice: Dictionary) -> Array:
	var out: Array = []
	var costs: Dictionary = choice.get("costs", {})
	for rid in costs:
		out.append({"kind": "cost", "id": rid, "amount": float(costs[rid])})
	for e in choice.get("effects", []):
		match e.get("type", ""):
			"add_resource":
				if not e.has("chance"):
					out.append({"kind": "resource", "id": e["resource"], "amount": float(e["amount"])})
			"add_relation":
				out.append({"kind": "relation", "id": e["relation"], "amount": float(e["amount"])})
	return out


## Choices already made, in story order, with the result text and the authored hint about what comes later.
func ledger(state: GameState) -> Array:
	var out: Array = []
	var done: Dictionary = state.story["done"]
	for nid in registry.story_order:
		if not done.has(nid):
			continue
		for c in registry.story[nid]["choices"]:
			if c["id"] == done[nid]:
				out.append({"node": nid, "title_key": registry.story[nid]["title_key"], "choice": c["id"], "text_key": c["text_key"],
					"result_key": c.get("result_key", ""), "later_hint_key": c.get("later_hint_key", "")})
	return out
