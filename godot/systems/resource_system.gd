class_name ResourceSystem
extends RefCounted
## All resource mutation goes through here. Amounts are snapped to avoid float drift.

## Hard ceiling of float64 storage: whole numbers up to 1e15 are exact and round-trip through JSON
## (see GameState.SNAP_LIMIT). Going past it needs a different representation (docs/PHASE2A_REPORT.md).
const MAX_AMOUNT: float = 1.0e15

var registry: ContentRegistry


func _init(p_registry: ContentRegistry) -> void:
	registry = p_registry


func get_amount(state: GameState, id: String) -> float:
	return float(state.resources.get(id, 0.0))


## `cap_from: "cultivation_cap"` resources take their cap from the current realm stage.
func cap_of(id: String, state: GameState = null) -> float:
	var def: Dictionary = registry.resources.get(id, {})
	if def.get("cap_from", "") == "cultivation_cap":
		var st: Dictionary = registry.stage_of(state.realm_id) if state != null else {}
		return minf(float(st.get("cultivation_cap", 0.0)), MAX_AMOUNT) if not st.is_empty() else MAX_AMOUNT
	var c: Variant = def.get("cap", null)
	return MAX_AMOUNT if c == null else minf(float(c), MAX_AMOUNT)


## Adds up to the cap. Returns the amount actually stored (overflow is lost by the cap rule).
func add(state: GameState, id: String, amount: float) -> float:
	assert(amount >= 0.0 and is_finite(amount))
	var cur: float = get_amount(state, id)
	var nxt: float = GameState.snap(minf(cur + amount, maxf(cap_of(id, state), cur)))  # a lower cap never destroys stock
	state.resources[id] = nxt
	return nxt - cur


func can_afford(state: GameState, costs: Dictionary) -> bool:
	return missing(state, costs).is_empty()


## {resource_id: shortfall} for everything not affordable.
func missing(state: GameState, costs: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for id in costs:
		var short: float = float(costs[id]) - get_amount(state, id)
		if short > 1e-9:
			out[id] = GameState.snap(short)
	return out


## Atomic: pays everything or nothing.
func spend(state: GameState, costs: Dictionary) -> bool:
	if not can_afford(state, costs):
		return false
	for id in costs:
		state.resources[id] = GameState.snap(get_amount(state, id) - float(costs[id]))
	return true


## Gives back previously paid costs (cancelled action). Ignores `cap`: the cap limits gains,
## and a refund must never lose what the player paid. Still bounded by MAX_AMOUNT.
func refund(state: GameState, costs: Dictionary) -> void:
	for id in costs:
		state.resources[id] = GameState.snap(minf(get_amount(state, id) + float(costs[id]), MAX_AMOUNT))
