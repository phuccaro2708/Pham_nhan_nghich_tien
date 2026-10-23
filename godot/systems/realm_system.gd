class_name RealmSystem
extends RefCounted
## Realm ladder queries and the one mutation: attempt() (reached only through the advance_realm effect).
## Everything comes from the data in res://data/realms; no realm is named in code.

signal breakthrough_resolved(success: bool, from_id: String, to_id: String)

var registry: ContentRegistry
var _conditions := ConditionEvaluator.new()


func _init(p_registry: ContentRegistry) -> void:
	registry = p_registry
	_conditions.content = p_registry


func stage(state: GameState) -> Dictionary:
	return registry.stage_of(state.realm_id)


## {} when the character is at the last stage (or no realms exist).
func next_stage(state: GameState) -> Dictionary:
	var i: int = registry.realm_index(state.realm_id)
	if i < 0 or i + 1 >= registry.realm_order.size():
		return {}
	return registry.realms[registry.realm_order[i + 1]]


func breakthrough_def(state: GameState) -> Dictionary:
	return stage(state).get("breakthrough", {})


func breakthrough_costs(state: GameState) -> Dictionary:
	return breakthrough_def(state).get("costs", {})


## GDD §6.5: P = clamp(base + sum(terms) + insight, min, max). 1.0 without a chance block.
## A term is {resource, weight, max} (weight * clamp(resource/max, 0, 1)) or {when: condition, weight} (weight when it holds;
## this is how wounds, mastery and story choices (Đạo Tâm) enter, V6).
func success_chance(state: GameState) -> float:
	var ch: Dictionary = breakthrough_def(state).get("chance", {})
	if ch.is_empty():
		return 1.0
	var p: float = float(ch["base"])
	for t in ch.get("terms", []):
		if t.has("when"):
			p += float(t["weight"]) if _conditions.is_met(t["when"], state) else 0.0
		else:
			p += float(t["weight"]) * clampf(float(state.resources.get(t["resource"], 0.0)) / float(t["max"]), 0.0, 1.0)
	p += registry.insight_total(state)  # techniques that help comprehension raise the odds (GDD 6.4 insight_modifier)
	return clampf(p, float(ch["min"]), float(ch["max"]))


## V9: Σ weights of the `core.terms` that hold now (technique purity, mastery, wounds, Đạo Tâm).
func core_score(state: GameState) -> float:
	var score: float = 0.0
	for t in registry.core_def().get("terms", []):
		if _conditions.is_met(t["when"], state):
			score += float(t["weight"])
	return score


## Highest grade whose min_score the current score reaches ("" when the game has no core).
func core_grade(state: GameState) -> String:
	var score: float = core_score(state)
	var out: String = ""
	for g in registry.core_def().get("grades", []):
		if score >= float(g["min_score"]):
			out = g["id"]
	return out


## After `pity_failures` failures the ritual is guaranteed (GDD §6.5).
func pity_reached(state: GameState) -> bool:
	var pity: int = int(breakthrough_def(state).get("chance", {}).get("pity_failures", 0))
	return pity > 0 and state.breakthrough_failures >= pity


## Story-driven step to the next stage; only stages flagged `story_promotion` allow it (no risk, no ritual).
func promote(state: GameState, realm_id: String) -> void:
	var nxt: Dictionary = next_stage(state)
	var cur: Dictionary = stage(state)
	if nxt.is_empty() or nxt["id"] != realm_id or not cur.get("story_promotion", false):
		return
	state.realm_id = realm_id
	state.breakthrough_failures = 0
	state.life["warned"] = false
	breakthrough_resolved.emit(true, str(cur["id"]), realm_id)


## Rolls (seeded, only when the outcome is not certain) and applies the result. Costs were paid by the caller.
## Success: next stage, failures reset, lifespan warning re-armed (the limit may have grown).
## Failure: nobody dies; failure counter and the data-defined flag record the damaged state.
func attempt(state: GameState) -> Dictionary:
	var nxt: Dictionary = next_stage(state)
	if nxt.is_empty():
		return {"success": false, "reason": "max_realm"}
	var from_id: String = str(stage(state)["id"])
	var bt: Dictionary = breakthrough_def(state)
	var p: float = success_chance(state)
	var ok: bool = p >= 1.0 or pity_reached(state) or SimRng.next_float(state) < p
	if ok:
		if nxt.has("core"):
			state.dan_grade = core_grade(state)
		state.realm_id = nxt["id"]
		state.breakthrough_failures = 0
		state.life["warned"] = false
		if bt.has("on_fail_flag"):
			state.flags[bt["on_fail_flag"]] = false
	else:
		state.breakthrough_failures += 1
		if bt.has("on_fail_flag"):
			state.flags[bt["on_fail_flag"]] = true
	breakthrough_resolved.emit(ok, from_id, nxt["id"] if ok else from_id)
	return {"success": ok, "from": from_id, "to": nxt["id"] if ok else from_id}
