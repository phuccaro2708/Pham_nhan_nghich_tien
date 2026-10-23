class_name ActionSystem
extends RefCounted
## The single processor for every action (INSTANT / TIMED / LOOP).
## One active slot; time only moves through advance(). Rewards are applied in
## exactly one place (_complete), so save/load, switching and offline cannot duplicate them.

signal action_completed(action_id: String)
signal action_stopped(action_id: String, reason: String)
signal research_resolved(route_id: String, success: bool)

const MIN_ACTION_SECONDS: float = 0.25  # GDD §5.2 T_min

var registry: ContentRegistry
var resources: ResourceSystem
var conditions: ConditionEvaluator
var effects: EffectResolver
var realms: RealmSystem
var lifespan: LifespanSystem
var mastery: MasterySystem
var story: StorySystem
var automation: AutomationQueue
var combat: CombatSystem
var path: PathSystem
## Set by OfflineSystem while it simulates: the queue then refuses actions that are not offline_allowed.
var offline_mode: bool = false


func _init(p_registry: ContentRegistry) -> void:
	registry = p_registry
	resources = ResourceSystem.new(registry)
	conditions = ConditionEvaluator.new()
	conditions.content = registry
	realms = RealmSystem.new(registry)
	lifespan = LifespanSystem.new(registry, realms)
	effects = EffectResolver.new(registry, resources, realms)
	mastery = MasterySystem.new(registry, effects)
	story = StorySystem.new(registry, conditions, effects, resources)
	automation = AutomationQueue.new(self)
	combat = CombatSystem.new(registry, conditions, effects, lifespan)
	path = PathSystem.new(registry, conditions)


# ---------- queries ----------

## Costs for the next run. Upgrade-purchase actions price from the upgrade curve (GDD §11.2).
func get_costs(def: Dictionary, state: GameState) -> Dictionary:
	if def.get("breakthrough", false):
		return realms.breakthrough_costs(state)  # the ritual's price belongs to the current realm stage
	if def.has("upgrade"):
		var up: Dictionary = registry.upgrades[def["upgrade"]]
		var n: int = int(state.upgrades.get(def["upgrade"], 0))
		return {up["cost_resource"]: ceil(float(up["base_cost"]) * pow(float(up["cost_growth"]), n))}
	return def.get("costs", {})


## {ok: bool, reason: String, detail: Variant}. Never mutates state.
func check_can_start(state: GameState, action_id: String) -> Dictionary:
	if not registry.has_action(action_id):
		return {"ok": false, "reason": "unknown_action", "detail": action_id}
	if not lifespan.is_alive(state):
		return {"ok": false, "reason": "deceased", "detail": null}
	if combat.is_active(state):
		return {"ok": false, "reason": "in_dungeon", "detail": null}
	var def: Dictionary = registry.actions[action_id]
	if def.has("upgrade"):
		var up: Dictionary = registry.upgrades[def["upgrade"]]
		if int(state.upgrades.get(def["upgrade"], 0)) >= int(up["max_level"]):
			return {"ok": false, "reason": "max_level", "detail": def["upgrade"]}
	if not conditions.is_met(def.get("visible_when", {}), state):  # undiscovered: not startable by UI, automation or offline
		return {"ok": false, "reason": "not_discovered", "detail": null}
	var fail: Dictionary = conditions.first_failure(def.get("requirements", {}), state)
	if not fail.is_empty():
		return {"ok": false, "reason": "requirements_not_met", "detail": fail}
	if def.get("breakthrough", false):
		if realms.next_stage(state).is_empty():
			return {"ok": false, "reason": "max_realm", "detail": null}
		var bfail: Dictionary = conditions.first_failure(realms.breakthrough_def(state).get("requirements", {}), state)
		if not bfail.is_empty():
			return {"ok": false, "reason": "requirements_not_met", "detail": bfail}
	if _reward_fully_capped(state, def):
		return {"ok": false, "reason": "reward_capped", "detail": null}
	var miss: Dictionary = resources.missing(state, get_costs(def, state))
	if not miss.is_empty():
		return {"ok": false, "reason": "insufficient_resources", "detail": miss}
	return {"ok": true, "reason": "", "detail": null}


## True when the action's only outcome is resource gain and every target is full: running it
## would burn age (age_cost_years) for nothing, which GDD 3.2 forbids (idle is not a penalty).
func _reward_fully_capped(state: GameState, def: Dictionary) -> bool:
	var fx: Array = def.get("effects", [])
	if fx.is_empty():
		return false
	for e in fx:
		if e["type"] != "add_resource" or resources.get_amount(state, e["resource"]) < resources.cap_of(e["resource"], state):
			return false
	return true


## T_final = max(T_min, T_base / (1 + S + M)) in ticks (GDD §5.2).
func duration_ticks(def: Dictionary, state: GameState) -> int:
	var s_plus_m: float = effects.stat_bonus(state, "speed.all") + effects.stat_bonus(state, "speed." + str(def["id"]))
	var t: float = maxf(MIN_ACTION_SECONDS, float(def.get("duration", 0.0)) / (1.0 + s_plus_m))
	return SimulationClock.seconds_to_ticks(t)


# ---------- commands ----------

## `from_queue` is true only for AutomationQueue's own starts; any other timed start is a manual override that halts the queue.
func start_action(state: GameState, action_id: String, from_queue: bool = false) -> Dictionary:
	var replaces: bool = not state.active_action.is_empty() and registry.actions.get(action_id, {}).get("type", "INSTANT") != "INSTANT"
	var prev: Dictionary = state.active_action.duplicate(true) if replaces else {}
	var before: Dictionary = state.resources.duplicate() if replaces else {}
	if replaces:
		resources.refund(state, prev.get("costs_paid", {}))  # judge affordability as if the running action were cancelled
	var check: Dictionary = check_can_start(state, action_id)
	if not check["ok"]:
		if replaces:  # exact undo: a spend() after a clamped refund would lose resources
			state.resources.clear()
			state.resources.merge(before)
		return check
	var def: Dictionary = registry.actions[action_id]
	if def["type"] == "INSTANT":
		_run_instant(state, def)
		return check
	if replaces:
		state.active_action = {}
		action_stopped.emit(prev["id"], "restarted" if prev["id"] == action_id else "switched")
		# A listener may have started something else or spent the resources: never overwrite or start for free.
		if not state.active_action.is_empty():
			return {"ok": false, "reason": "interrupted", "detail": null}
		check = check_can_start(state, action_id)
		if not check["ok"]:
			return check
	_begin_cycle(state, def)
	if not from_queue:
		automation.stop(state, "manual_override")
	return check


## Enters a dungeon: whatever is running stops (costs refunded) and fighting takes over the clock.
## Chooses the main technique. The first choice is free; changing it costs `technique.switch_age_years` of life.
func set_main_technique(state: GameState, technique_id: String) -> Dictionary:
	if not registry.has_technique(technique_id):
		return {"ok": false, "reason": "unknown_technique"}
	if not state.techniques.has(technique_id):
		return {"ok": false, "reason": "not_known"}
	if registry.techniques[technique_id].get("role", "base") != "main":
		return {"ok": false, "reason": "not_main_technique"}
	if state.main_technique == technique_id:
		return {"ok": false, "reason": "already_main"}
	if combat.is_active(state):
		return {"ok": false, "reason": "in_dungeon"}
	if not lifespan.is_alive(state):
		return {"ok": false, "reason": "deceased"}
	if state.main_technique != "":
		lifespan.commit_age(state, float(registry.config["technique"]["switch_age_years"]))
	state.main_technique = technique_id
	return {"ok": true, "reason": ""}


## Tries one data-defined route that mends a technique's flaw (V4). The price and the years are paid up front; a failure
## returns `on_fail_refund` of the price, may wound, and counts toward pity (after `pity_failures` the next try is certain).
## The counter moves before the technique is learned and a known variant ends the route, so the reward is paid once.
func research(state: GameState, route_id: String) -> Dictionary:
	if not registry.research.has(route_id):
		return {"ok": false, "reason": "unknown_route"}
	if not lifespan.is_alive(state):
		return {"ok": false, "reason": "deceased"}
	if combat.is_active(state):
		return {"ok": false, "reason": "in_dungeon"}
	var def: Dictionary = registry.research[route_id]
	if state.techniques.has(def["variant"]):
		return {"ok": false, "reason": "already_done"}
	if not conditions.is_met(def.get("visible_when", {}), state):
		return {"ok": false, "reason": "not_discovered"}
	var fail: Dictionary = conditions.first_failure(def.get("requirements", {}), state)
	if not fail.is_empty() or not state.techniques.has(def["technique"]):
		return {"ok": false, "reason": "requirements_not_met", "detail": fail}
	var costs: Dictionary = def["costs"]
	var miss: Dictionary = resources.missing(state, costs)
	if not miss.is_empty():
		return {"ok": false, "reason": "insufficient_resources", "detail": miss}
	resources.spend(state, costs)
	if not lifespan.commit_age(state, float(def.get("age_cost_years", 0.0))):
		resources.refund(state, costs)  # the years ran out before the work began: nothing was attempted
		return {"ok": false, "reason": "deceased"}
	var failures: int = int(state.research_failures.get(route_id, 0))
	var pity: int = int(def.get("pity_failures", 0))
	var success: bool = (pity > 0 and failures >= pity) or SimRng.next_float(state) < float(def["chance"])
	if success:
		state.research_failures.erase(route_id)
		effects.apply(state, [{"type": "learn_technique", "technique": def["variant"]}])
	else:
		state.research_failures[route_id] = failures + 1
		var back: Dictionary = {}
		for rid in costs:
			back[rid] = float(costs[rid]) * float(def.get("on_fail_refund", 0.0))
		resources.refund(state, back)
		combat.add_wounds(state, int(def.get("on_fail_wounds", 0)))
	research_resolved.emit(route_id, success)
	return {"ok": true, "reason": "", "success": success}


## prep = {pills: n}: pills are taken from the stock at the door and come back if unused.
func enter_dungeon(state: GameState, dungeon_id: String, prep: Dictionary = {}) -> Dictionary:
	var check: Dictionary = combat.check_enter(state, dungeon_id, prep)
	if not check["ok"]:
		return check
	stop_action(state, "entered_dungeon")
	automation.stop(state, "entered_dungeon")
	combat.begin(state, dungeon_id, prep)
	return check


## Answers to the pause after a tier. Only the player calls these; the clock and the automation queue never do.
func continue_run(state: GameState) -> Dictionary:
	return combat.continue_run(state)


func leave_run(state: GameState) -> Dictionary:
	var r: Dictionary = combat.leave_run(state)
	if r["ok"]:
		story.scan(state)
	return r


## Cancels the active action. Costs paid at start are refunded; nothing is rewarded.
func stop_action(state: GameState, reason: String = "stopped_by_player") -> void:
	if state.active_action.is_empty():
		return
	var id: String = state.active_action["id"]
	resources.refund(state, state.active_action.get("costs_paid", {}))
	state.active_action = {}
	if reason != "insufficient_resources" and reason != "switched" and reason != "restarted":
		automation.stop(state, reason)
	action_stopped.emit(id, reason)


## Moves simulation time forward by `ticks`. The only entry point that advances time.
func advance(state: GameState, ticks: int) -> void:
	if not lifespan.is_alive(state):
		stop_action(state, "deceased")  # a deceased character never completes anything, whatever the save said
		combat.abort(state)
		state.game_time_ticks += maxi(ticks, 0)
		return
	var remaining: int = ticks
	while remaining > 0:
		if combat.is_active(state):
			if offline_mode:  # nobody is there to fight; the run is dropped, not decided for the player
				combat.abort(state)
				continue
			if combat.is_paused(state):  # waiting for the player costs nothing and changes nothing
				state.game_time_ticks += remaining
				return
			if combat.step(state):
				story.scan(state)
			state.game_time_ticks += 1
			remaining -= 1
			continue
		if state.active_action.is_empty():
			automation.pump(state)
		if state.active_action.is_empty():
			state.game_time_ticks += remaining
			return
		var a: Dictionary = state.active_action
		var step: int = clampi(int(a["duration_ticks"]) - int(a["progress_ticks"]), 0, remaining)
		a["progress_ticks"] = int(a["progress_ticks"]) + step
		state.game_time_ticks += step
		remaining -= step
		if int(a["progress_ticks"]) >= int(a["duration_ticks"]):
			_finish_cycle(state)


# ---------- internals ----------

func _begin_cycle(state: GameState, def: Dictionary) -> void:
	var costs: Dictionary = get_costs(def, state)
	var paid: Dictionary = {}
	if def.get("cost_timing", "start") == "start":
		if resources.spend(state, costs):
			paid = costs.duplicate()
	state.active_action = {
		"id": def["id"],
		"progress_ticks": 0,
		"duration_ticks": duration_ticks(def, state),
		"costs_paid": paid,
	}


func _finish_cycle(state: GameState) -> void:
	var def: Dictionary = registry.actions[state.active_action["id"]]
	var queue_slot: int = int(state.active_action.get("queue_slot", -1))
	if def.get("cost_timing", "start") == "complete":
		if not resources.spend(state, get_costs(def, state)):
			state.active_action = {}
			action_stopped.emit(def["id"], "insufficient_resources")
			return
	state.active_action = {}  # cleared before rewards so a re-entrant call cannot see a finished action
	_complete(state, def)
	if queue_slot >= 0:
		automation.on_completed(state, queue_slot)
		return  # the queue decides what runs next (it restarts this slot's LOOP itself)
	if def["type"] != "LOOP":
		return
	if not state.active_action.is_empty():
		return  # a completion handler already started something; never overwrite (and lose) its paid costs
	var check: Dictionary = check_can_start(state, def["id"])
	if check["ok"]:
		_begin_cycle(state, def)
	else:
		# Loop pauses and never spins on a failing action. By design it does not auto-resume
		# (e.g. after reward_capped): that belongs to the Phase 2 automation queue.
		action_stopped.emit(def["id"], check["reason"])


func _run_instant(state: GameState, def: Dictionary) -> void:
	# INSTANT: pay and resolve in the same call; cost_timing is irrelevant. Cost is priced before effects.
	var paid: bool = resources.spend(state, get_costs(def, state))
	assert(paid)  # check_can_start just verified affordability
	_complete(state, def)


## The only place rewards, age and counters change. Costs were settled by the caller.
func _complete(state: GameState, def: Dictionary) -> void:
	effects.apply(state, def.get("effects", []))
	var alive: bool = lifespan.commit_age(state, float(def.get("age_cost_years", 0.0)))
	state.action_counts[def["id"]] = int(state.action_counts.get(def["id"], 0)) + 1
	mastery.on_completed(state, str(def["id"]))
	story.scan(state)
	action_completed.emit(def["id"])
	if not alive:
		stop_action(state, "deceased")  # tọa hóa: nothing may keep running
