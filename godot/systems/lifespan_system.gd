class_name LifespanSystem
extends RefCounted
## Lifespan (thọ nguyên, GDD §3.2). Age moves only through commit_age(), called when an action
## completes. Reaching the realm's limit ends the life (tọa hóa): no action can start afterwards.
## Reincarnation is not implemented; the state just records the end.

signal lifespan_warning(remaining_years: float)
signal life_ended(age_years: float)

const DEFAULT_WARNING_YEARS: float = 5.0

var registry: ContentRegistry
var realms: RealmSystem


func _init(p_registry: ContentRegistry, p_realms: RealmSystem) -> void:
	registry = p_registry
	realms = p_realms


func is_alive(state: GameState) -> bool:
	return state.life.get("status", "alive") == "alive"


## INF when the content defines no realms (e.g. minimal test registries).
func limit(state: GameState) -> float:
	var st: Dictionary = realms.stage(state)
	return float(st["lifespan_years"]) if not st.is_empty() else INF


func remaining(state: GameState) -> float:
	return limit(state) - state.age_years


func warning_years() -> float:
	return float(registry.config.get("lifespan_warning_years", DEFAULT_WARNING_YEARS))


func is_warning(state: GameState) -> bool:
	return is_alive(state) and remaining(state) <= warning_years()


## Adds `years` (the completed action's age_cost_years). Age never exceeds the limit.
## Returns false when this commit ended the life.
func commit_age(state: GameState, years: float) -> bool:
	if years <= 0.0 or not is_alive(state):
		return is_alive(state)
	var lim: float = limit(state)
	state.age_years = GameState.snap(minf(state.age_years + years, lim))
	if state.age_years >= lim:
		state.life["status"] = "deceased"
		state.life["ended"] = {"age_years": state.age_years, "realm_id": realms.stage(state).get("id", ""),
			"game_time_ticks": state.game_time_ticks}
		life_ended.emit(state.age_years)
		return false
	if not state.life.get("warned", false) and is_warning(state):
		state.life["warned"] = true
		lifespan_warning.emit(remaining(state))
	return true
