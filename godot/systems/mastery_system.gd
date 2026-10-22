class_name MasterySystem
extends RefCounted
## Action Mastery (GDD 5.5). XP is paid in exactly one place: on_completed(), called from ActionSystem._complete,
## which already runs once per finished cycle - so save/load, switching and offline cannot pay XP twice.
## Milestone effects are paid once per level, recorded in state.mastery[action].claimed. Milestone *bonuses* are
## derived from the level (EffectResolver.group_bonus) and never stored.

signal level_up(action_id: String, level: int)
signal milestone_claimed(action_id: String, level: int)

## Hard stop for pathological definitions (xp_required tiny): XP can never loop forever.
const MAX_LEVELS_PER_AWARD: int = 99

var registry: ContentRegistry
var effects: EffectResolver


func _init(p_registry: ContentRegistry, p_effects: EffectResolver) -> void:
	registry = p_registry
	effects = p_effects


## XP needed to go from `level` to `level + 1`: base x growth^(level-1).
static func xp_required(def: Dictionary, level: int) -> float:
	return float(def.get("xp_base", 20.0)) * pow(float(def.get("xp_growth", 1.35)), float(level - 1))


func level_of(state: GameState, action_id: String) -> int:
	return int((state.mastery.get(action_id, {}) as Dictionary).get("level", 0))


## {level, xp, required, max_level} for the UI; {} when the action has no mastery.
func progress(state: GameState, action_id: String) -> Dictionary:
	var def: Dictionary = registry.mastery_for_action(action_id)
	if def.is_empty():
		return {}
	var m: Dictionary = state.mastery.get(action_id, {"level": 1, "xp": 0.0, "claimed": []})
	var lvl: int = int(m["level"])
	return {"level": lvl, "xp": float(m["xp"]), "max_level": int(def["max_level"]),
		"required": xp_required(def, lvl) if lvl < int(def["max_level"]) else 0.0}


## Pays XP for one completed cycle of `action_id` and every milestone crossed. Returns levels gained.
func on_completed(state: GameState, action_id: String) -> int:
	var def: Dictionary = registry.mastery_for_action(action_id)
	if def.is_empty():
		return 0
	if not state.mastery.has(action_id):
		state.mastery[action_id] = {"level": 1, "xp": 0.0, "claimed": []}
	var m: Dictionary = state.mastery[action_id]
	var max_level: int = int(def["max_level"])
	if int(m["level"]) >= max_level:
		return 0
	m["xp"] = GameState.snap(float(m["xp"]) + float(def.get("xp_per_completion", 1.0)))
	var gained: int = 0
	while int(m["level"]) < max_level and gained < MAX_LEVELS_PER_AWARD and float(m["xp"]) >= xp_required(def, int(m["level"])) - 1e-9:
		m["xp"] = GameState.snap(maxf(float(m["xp"]) - xp_required(def, int(m["level"])), 0.0))
		m["level"] = int(m["level"]) + 1
		gained += 1
		level_up.emit(action_id, int(m["level"]))
		_claim(state, def, m, int(m["level"]))
	if int(m["level"]) >= max_level:
		m["xp"] = 0.0
	return gained


func _claim(state: GameState, def: Dictionary, m: Dictionary, level: int) -> void:
	for ms in def.get("milestones", []):
		if int(ms["level"]) == level and not (m["claimed"] as Array).has(level):
			(m["claimed"] as Array).append(level)  # recorded before the effects run: a re-entrant call cannot pay twice
			effects.apply(state, ms.get("effects", []))
			milestone_claimed.emit(str(def["action"]), level)
