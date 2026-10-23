class_name TestHelpers
extends RefCounted
## Shared fixtures. Real data lives in res://data; mini_registry builds in-memory content.


static func real_registry() -> ContentRegistry:
	var r := ContentRegistry.new()
	r.load_all()
	return r


static func mini_registry(extra_actions: Array = []) -> ContentRegistry:
	var r := ContentRegistry.new()
	r.add_definitions("resource", [
		{"id": "wood", "name_key": "w", "cap": 50},
		{"id": "silver", "name_key": "s", "cap": null},
	])
	r.add_definitions("action", extra_actions)
	r.validate()
	return r


## `knowing_all` skips discovery gating so older tests can use any action; pass false for a fresh commoner.
static func world(seed_value: int = 7, knowing_all: bool = true) -> Dictionary:
	var reg := real_registry()
	var st := GameState.new_game(seed_value)
	if knowing_all:
		st.knowledge = reg.knowledge.keys()
		st.knowledge.sort()
	return {"reg": reg, "act": ActionSystem.new(reg), "state": st}


## Greedy bot (BalanceSimulator policy) until `realm_id` or death; returns the number of steps used.
static func climb_to(act: ActionSystem, st: GameState, realm_id: String = "truc_co_so", max_steps: int = 60000) -> int:
	var steps: int = 0
	while steps < max_steps and st.realm_id != realm_id and act.lifespan.is_alive(st):
		steps += 1
		BalanceSimulator.resolve_story(act, st)
		var id: String = BalanceSimulator.policy(act, st)
		if not act.start_action(st, id)["ok"]:
			continue
		if act.registry.actions[id]["type"] != "INSTANT":
			act.advance(st, act.duration_ticks(act.registry.actions[id], st))
			act.stop_action(st)
	return steps
