class_name OfflineSystem
extends RefCounted
## Basic offline progression (GDD §9.3). Uses ActionSystem.advance - the same code as online play -
## so the result equals running the same ticks online.

const MIN_OFFLINE_SECONDS: float = 1.0


## Simulates `elapsed_seconds` (clamped to [0, 8h]) and returns a report Dictionary.
static func apply(state: GameState, actions: ActionSystem, elapsed_seconds: float) -> Dictionary:
	var elapsed: float = elapsed_seconds if is_finite(elapsed_seconds) else 0.0
	var capped: bool = elapsed > SimulationClock.MAX_OFFLINE_SECONDS
	elapsed = clampf(elapsed, 0.0, SimulationClock.MAX_OFFLINE_SECONDS)
	var report: Dictionary = {
		"seconds_real": elapsed_seconds, "seconds_simulated": 0.0, "capped": capped,
		"resources_delta": {}, "completions": {}, "age_delta": 0.0, "stop_reason": "",
	}
	if elapsed < MIN_OFFLINE_SECONDS:
		return report

	var before_res: Dictionary = state.resources.duplicate()
	var before_counts: Dictionary = state.action_counts.duplicate()
	var before_age: float = state.age_years
	var stop: Array = [""]
	var on_stop := func(id: String, reason: String) -> void: stop[0] = "%s:%s" % [id, reason]
	actions.action_stopped.connect(on_stop)

	actions.combat.abort(state)  # a dungeon run is never decided offline
	if not state.active_action.is_empty():
		var def: Dictionary = actions.registry.actions[state.active_action["id"]]
		if not def.get("offline_allowed", false):
			actions.stop_action(state, "offline_not_allowed")

	var ticks: int = int(elapsed * SimulationClock.TICKS_PER_SECOND + 1e-9)
	actions.offline_mode = true
	actions.advance(state, ticks)
	actions.offline_mode = false
	actions.action_stopped.disconnect(on_stop)

	report["seconds_simulated"] = SimulationClock.ticks_to_seconds(ticks)
	report["age_delta"] = GameState.snap(state.age_years - before_age)
	report["stop_reason"] = stop[0]
	for id in state.resources:
		var d: float = GameState.snap(float(state.resources[id]) - float(before_res.get(id, 0.0)))
		if d != 0.0:
			report["resources_delta"][id] = d
	for id in state.action_counts:
		var n: int = int(state.action_counts[id]) - int(before_counts.get(id, 0))
		if n > 0:
			report["completions"][id] = n
	return report
