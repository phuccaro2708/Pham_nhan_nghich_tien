class_name AutomationQueue
extends RefCounted
## Automation queue (GDD IX). Up to `max_slots` (<= 3) actions run in order. It uses ActionSystem's own start path,
## so online, offline and replays go through identical code. It never picks a story choice and never queues a breakthrough.
## status: idle | running | stopped | finished | deadlock. `reason` explains the last stop/wait (for the UI).

signal status_changed(status: String, reason: String)

const ON_BLOCK: Array = ["skip", "wait", "stop"]
## Consecutive instant actions without any time passing; beyond this the queue stops instead of spinning.
const MAX_INSTANT_STREAK: int = 64

var actions: ActionSystem
var registry: ContentRegistry


func _init(p_actions: ActionSystem) -> void:
	actions = p_actions
	registry = p_actions.registry


func max_slots() -> int:
	return int(registry.config.get("automation", {}).get("max_slots", 3))


func is_unlocked(state: GameState) -> bool:
	return actions.conditions.is_met(registry.config.get("automation", {}).get("requirements", {}), state)


func status(state: GameState) -> String:
	return str(state.automation["status"])


# ---------- commands ----------

## Replaces the slot list. Returns {ok, error}. Resets progress; the queue ends up idle.
func set_slots(state: GameState, slots: Array) -> Dictionary:
	if not is_unlocked(state):
		return {"ok": false, "error": "automation_locked"}
	if slots.size() > max_slots():
		return {"ok": false, "error": "too_many_slots"}
	var clean: Array = []
	for s in slots:
		var err: String = _slot_error(s)
		if err != "":
			return {"ok": false, "error": err}
		clean.append({"action": str(s["action"]), "repeat": int(s.get("repeat", 1)), "on_block": str(s.get("on_block", "skip")),
			"until": (s.get("until", {}) as Dictionary).duplicate(true), "done": 0})
	state.active_action.erase("queue_slot")  # a cycle already running must not credit a slot of the new list
	state.automation["slots"] = clean
	state.automation["cursor"] = 0
	state.automation["instant_streak"] = 0
	_set_status(state, "idle", "")
	return {"ok": true, "error": ""}


func set_loop(state: GameState, on: bool) -> void:
	state.automation["loop"] = on


func start(state: GameState) -> Dictionary:
	if not is_unlocked(state):
		return {"ok": false, "error": "automation_locked"}
	if (state.automation["slots"] as Array).is_empty():
		return {"ok": false, "error": "empty_queue"}
	if not state.active_action.is_empty():
		actions.stop_action(state, "switched")  # a manual LOOP would restart itself forever and starve the queue
	for s in state.automation["slots"]:
		s["done"] = 0
	state.automation["cursor"] = 0
	state.automation["instant_streak"] = 0
	_set_status(state, "running", "")
	pump(state)
	return {"ok": true, "error": ""}


func stop(state: GameState, reason: String = "stopped_by_player") -> void:
	state.active_action.erase("queue_slot")  # the running cycle becomes a plain manual one: a LOOP keeps going, nothing is half-owned
	if status(state) == "running" or status(state) == "deadlock":
		_set_status(state, "stopped", reason)


func _slot_error(s: Variant) -> String:
	if typeof(s) != TYPE_DICTIONARY or not registry.has_action(str(s.get("action", ""))):
		return "unknown_action"
	var def: Dictionary = registry.actions[s["action"]]
	if def.get("breakthrough", false) or not def.get("automation_allowed", true):
		return "not_automatable"
	if not GameState.is_int(s.get("repeat", 1)) or int(s.get("repeat", 1)) < 0:
		return "bad_repeat"
	if not ON_BLOCK.has(str(s.get("on_block", "skip"))):
		return "bad_on_block"
	if typeof(s.get("until", {})) != TYPE_DICTIONARY or not actions.conditions.validate(s.get("until", {}), registry).is_empty():
		return "bad_until"
	return ""


# ---------- stepping (called by ActionSystem only) ----------

## Starts the next runnable slot. Instants resolve in place; stops at the first timed start or block.
func pump(state: GameState) -> void:
	if status(state) != "running" or not state.active_action.is_empty():
		return
	if actions.story.pending(state) != "":
		state.automation["reason"] = "story_pending"  # the queue waits for the player's choice, never decides
		return
	state.automation["reason"] = ""
	var slots: Array = state.automation["slots"]
	var guard: int = MAX_INSTANT_STREAK + slots.size() * 2 + 2
	while guard > 0:
		guard -= 1
		var i: int = _next_slot(state)
		if i < 0:
			return  # finished
		var slot: Dictionary = slots[i]
		var id: String = slot["action"]
		if actions.offline_mode and not registry.actions[id].get("offline_allowed", false):
			_set_status(state, "stopped", "offline_not_allowed")
			return
		var check: Dictionary = actions.check_can_start(state, id)
		if check["ok"]:
			if _start_slot(state, i):
				return
			continue
		match slot["on_block"]:
			"skip":
				state.automation["cursor"] = i + 1
			"stop":
				_set_status(state, "stopped", "blocked:%s" % check["reason"])
				return
			"wait":
				if _feed(state, i, check):
					return
				_set_status(state, "deadlock", "waiting:%s" % check["reason"])
				return
	if status(state) == "running":
		_set_status(state, "stopped", "all_blocked")


## Index of the slot to run, advancing the cursor past finished ones; -1 once the whole queue is done.
func _next_slot(state: GameState) -> int:
	var slots: Array = state.automation["slots"]
	for _pass in 2:  # second pass only after a loop reset
		var i: int = int(state.automation["cursor"])
		while i < slots.size():
			if not _slot_done(state, slots[i]):
				state.automation["cursor"] = i
				return i
			i += 1
		if not state.automation["loop"]:
			_set_status(state, "finished", "")
			return -1
		for s in slots:
			s["done"] = 0
		state.automation["cursor"] = 0
	_set_status(state, "stopped", "all_blocked")  # loop that cannot make progress must not spin
	return -1


func _slot_done(state: GameState, slot: Dictionary) -> bool:
	if int(slot["repeat"]) > 0 and int(slot["done"]) >= int(slot["repeat"]):
		return true
	return not (slot["until"] as Dictionary).is_empty() and actions.conditions.is_met(slot["until"], state)


## True when a timed action is now running. Instants are executed and counted here.
func _start_slot(state: GameState, i: int) -> bool:
	var id: String = state.automation["slots"][i]["action"]
	var r: Dictionary = actions.start_action(state, id, true)
	if not r["ok"]:
		return false
	if registry.actions[id]["type"] == "INSTANT":
		state.automation["slots"][i]["done"] = int(state.automation["slots"][i]["done"]) + 1
		var slot: Dictionary = state.automation["slots"][i]
		if int(slot["repeat"]) > 0 or not (slot["until"] as Dictionary).is_empty():
			return false  # bounded slot: it ends by itself, only unbounded instants need the spin guard
		state.automation["instant_streak"] = int(state.automation["instant_streak"]) + 1
		if int(state.automation["instant_streak"]) > MAX_INSTANT_STREAK:
			_set_status(state, "stopped", "instant_loop")
			return true
		return false
	state.automation["instant_streak"] = 0
	state.active_action["queue_slot"] = i
	return true


## "wait" slot lacks a resource: run another slot of the queue that produces it. False = nothing can feed it (deadlock).
func _feed(state: GameState, waiting: int, check: Dictionary) -> bool:
	if check["reason"] != "insufficient_resources":
		return false
	var slots: Array = state.automation["slots"]
	for j in slots.size():
		if j == waiting or _slot_done(state, slots[j]):
			continue
		var def: Dictionary = registry.actions[slots[j]["action"]]
		if def["type"] == "INSTANT":
			continue
		for e in def.get("effects", []):
			if e["type"] == "add_resource" and (check["detail"] as Dictionary).has(e["resource"]) \
					and actions.check_can_start(state, def["id"])["ok"]:
				if _start_slot(state, j):
					return true
				break  # this producer failed to start: try the next slot
	return false


## A queued cycle finished (called from ActionSystem._finish_cycle).
func on_completed(state: GameState, slot_index: int) -> void:
	var slots: Array = state.automation["slots"]
	if status(state) == "running" and slot_index >= 0 and slot_index < slots.size():
		slots[slot_index]["done"] = int(slots[slot_index]["done"]) + 1


## Static check for the UI: one entry per slot, {slot, ok, reason}. Never mutates.
func analyze(state: GameState) -> Array:
	var out: Array = []
	var slots: Array = state.automation["slots"]
	for i in slots.size():
		var c: Dictionary = actions.check_can_start(state, slots[i]["action"])
		var reason: String = str(c["reason"])
		if not c["ok"] and slots[i]["on_block"] == "wait" and not _can_feed_somewhere(state, i, c):
			reason = "deadlock_risk"
		out.append({"slot": i, "ok": c["ok"], "reason": reason})
	return out


func _can_feed_somewhere(state: GameState, waiting: int, check: Dictionary) -> bool:
	if check["reason"] != "insufficient_resources":
		return false
	for j in state.automation["slots"].size():
		if j == waiting:
			continue
		for e in registry.actions[state.automation["slots"][j]["action"]].get("effects", []):
			if e["type"] == "add_resource" and (check["detail"] as Dictionary).has(e["resource"]):
				return true
	return false


func _set_status(state: GameState, s: String, reason: String) -> void:
	if state.automation["status"] == s and state.automation["reason"] == reason:
		return
	state.automation["status"] = s
	state.automation["reason"] = reason
	status_changed.emit(s, reason)
