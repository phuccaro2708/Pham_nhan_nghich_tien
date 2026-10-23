class_name LegacySystem
extends RefCounted
## Truyền thừa hậu duệ (GDD §3.2.1). The only way past tọa hóa: succeed() is valid while the character is deceased and
## makes them alive again, so one life pays its Đạo Quả exactly once (also across save/load).

signal succeeded(generation: int, dao_qua_gained: int)

var registry: ContentRegistry
var realms: RealmSystem
var lifespan: LifespanSystem


func _init(p_registry: ContentRegistry, p_realms: RealmSystem, p_lifespan: LifespanSystem) -> void:
	registry = p_registry
	realms = p_realms
	lifespan = p_lifespan


func cfg() -> Dictionary:
	return registry.config.get("legacy", {})


## Achievement points of the life that is ending: realm steps beyond the start realm + mastery levels. All of it is wiped
## by succeed(), so an heir cannot be paid for the ancestor's work twice.
func points(state: GameState) -> float:
	var c: Dictionary = cfg()
	var steps: int = maxi(registry.realm_index(state.realm_id) - registry.realm_index(str(c["start_realm"])), 0)
	var levels: int = 0
	for aid in state.mastery:
		levels += int(state.mastery[aid]["level"]) - 1
	return float(steps) * float(c["w_realm"]) + float(levels) * float(c["w_mastery"])


## GDD §X with A = 0: floor(scale * sqrt(P / P0)).
func dao_qua_for(state: GameState) -> int:
	var c: Dictionary = cfg()
	return int(floor(float(c["scale"]) * sqrt(points(state) / float(c["p0"]))))


func can_succeed(state: GameState) -> bool:
	return not cfg().is_empty() and not lifespan.is_alive(state)


## Command. Returns {ok, reason|generation, dao_qua}.
func succeed(state: GameState) -> Dictionary:
	if cfg().is_empty():
		return {"ok": false, "reason": "no_legacy_config"}
	if lifespan.is_alive(state):
		return {"ok": false, "reason": "still_alive"}
	var c: Dictionary = cfg()
	var gained: int = dao_qua_for(state)
	var gen: int = int(state.legacy["generation"])
	state.legacy["lineage"].append({"generation": gen, "realm_id": realms.stage(state).get("id", ""),
		"age_years": state.age_years, "dao_qua": gained})
	state.legacy["dao_qua"] = int(state.legacy["dao_qua"]) + gained
	state.legacy["generation"] = gen + 1
	_new_body(state, c)
	succeeded.emit(gen + 1, gained)
	return {"ok": true, "generation": gen + 1, "dao_qua": gained}


## Kept: story, knowledge, flags (minus body flags), dungeon_clears, base techniques + the ancestor's main one, loop, clock, rng, orphans, legacy.
func _new_body(state: GameState, c: Dictionary) -> void:
	var keep_roles: Array = c.get("keep_technique_roles", ["base"])
	var kept: Array = []
	for tid in state.techniques:
		var role: String = str(registry.techniques[tid].get("role", "base"))
		if keep_roles.has(role) or tid == state.main_technique:
			kept.append(tid)
	var reset_flags: Array = (c.get("reset_flags", []) as Array).duplicate()
	for rid in registry.realm_order:
		var f: String = str(registry.realms[rid].get("breakthrough", {}).get("on_fail_flag", ""))
		if f != "" and not reset_flags.has(f):
			reset_flags.append(f)
	for f in reset_flags:
		state.flags.erase(f)
	state.techniques = kept
	state.main_technique = ""
	state.resources.clear()
	for id in registry.resources:
		state.resources[id] = float(registry.resources[id].get("initial", 0.0))
	state.upgrades = {}
	state.action_counts = {}
	state.active_action = {}
	state.mastery = {}
	state.relations = {}
	state.research_failures = {}
	state.last_run = {}
	state.combat = {}
	state.checkpoint = {}
	state.automation = GameState.new().automation.duplicate(true)
	state.realm_id = str(c["start_realm"])
	state.age_years = GameState.START_AGE_YEARS
	state.breakthrough_failures = 0
	state.wounds = 0
	state.dan_grade = ""
	state.life = {"status": "alive", "warned": false, "ended": {}}
