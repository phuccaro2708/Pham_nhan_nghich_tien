class_name StorySystem
extends RefCounted
## Story graph runner (GDD VII). One pending event at a time; a choice is the only way to resolve it, so the
## queue/offline never decide for the player. Triggers are monotonic (progress only ever adds), and every node has
## a free fallback choice (validated in ContentRegistry), so no path softlocks.

signal event_pending(node_id: String)
signal choice_resolved(node_id: String, choice_id: String)

var registry: ContentRegistry
var conditions: ConditionEvaluator
var effects: EffectResolver
var resources: ResourceSystem


func _init(p_registry: ContentRegistry, p_conditions: ConditionEvaluator, p_effects: EffectResolver, p_resources: ResourceSystem) -> void:
	registry = p_registry
	conditions = p_conditions
	effects = p_effects
	resources = p_resources


func pending(state: GameState) -> String:
	return str(state.story["pending"])


## Opens the first not-yet-seen node whose trigger holds. Does nothing while an event is waiting.
func scan(state: GameState) -> void:
	if pending(state) != "":
		return
	for id in registry.story_order:
		if (state.story["done"] as Dictionary).has(id) or registry.story[id].get("chain_only", false):
			continue  # chain_only nodes open only through a choice's `next`
		if conditions.is_met(registry.story[id].get("trigger", {}), state):
			_open(state, id)
			return


func _open(state: GameState, id: String) -> void:
	state.story["pending"] = id
	event_pending.emit(id)


## {ok, reason, detail} for one choice of the pending node. Never mutates.
func check_choice(state: GameState, choice_id: String) -> Dictionary:
	var node_id: String = pending(state)
	if node_id == "":
		return {"ok": false, "reason": "no_pending_event", "detail": null}
	var c: Dictionary = _choice(node_id, choice_id)
	if c.is_empty():
		return {"ok": false, "reason": "unknown_choice", "detail": choice_id}
	var fail: Dictionary = conditions.first_failure(c.get("requirements", {}), state)
	if not fail.is_empty():
		return {"ok": false, "reason": "requirements_not_met", "detail": fail}
	var miss: Dictionary = resources.missing(state, c.get("costs", {}))
	if not miss.is_empty():
		return {"ok": false, "reason": "insufficient_resources", "detail": miss}
	return {"ok": true, "reason": "", "detail": null}


## Command: resolve the pending event. Marks the node done first, so effects can never fire twice.
func choose(state: GameState, choice_id: String) -> Dictionary:
	var check: Dictionary = check_choice(state, choice_id)
	if not check["ok"]:
		return check
	var node_id: String = pending(state)
	var c: Dictionary = _choice(node_id, choice_id)
	resources.spend(state, c.get("costs", {}))
	(state.story["done"] as Dictionary)[node_id] = choice_id
	state.story["pending"] = ""
	effects.apply(state, c.get("effects", []))
	choice_resolved.emit(node_id, choice_id)
	var nxt: Variant = c.get("next")
	if nxt != null and not (state.story["done"] as Dictionary).has(nxt):
		_open(state, str(nxt))
	else:
		scan(state)
	return check


func _choice(node_id: String, choice_id: String) -> Dictionary:
	for c in registry.story.get(node_id, {}).get("choices", []):
		if c["id"] == choice_id:
			return c
	return {}
