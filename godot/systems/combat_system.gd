class_name CombatSystem
extends RefCounted
## Auto-combat inside a dungeon (bí cảnh, GDD §VIII). One run = enemies in order, one fight at a time.
## Time only moves through step(), one fixed tick, and every roll uses the saved SimRng, so a run is
## reproducible from the save. All outcomes (loot, clear reward, age) are applied in kill_enemy / _end
## only, after the progress counters moved, so save/load cannot pay them twice.
## Skill multipliers do not exist yet (GDD formula with SkillMultiplier = 1).

signal enemy_defeated(dungeon_id: String, enemy_id: String)
## result: "cleared" | "defeated" | "retreated" | "aborted"
signal run_ended(dungeon_id: String, result: String)

var registry: ContentRegistry
var conditions: ConditionEvaluator
var effects: EffectResolver
var lifespan: LifespanSystem


func _init(p_registry: ContentRegistry, p_conditions: ConditionEvaluator, p_effects: EffectResolver, p_lifespan: LifespanSystem) -> void:
	registry = p_registry
	conditions = p_conditions
	effects = p_effects
	lifespan = p_lifespan


func is_active(state: GameState) -> bool:
	return not state.combat.is_empty()


func _cfg() -> Dictionary:
	return registry.config.get("combat", {})


## Base stats from config + bonuses (upgrades / techniques / mastery via `combat.*`) scaled by the realm stage.
func player_stats(state: GameState) -> Dictionary:
	var base: Dictionary = _cfg()["player"]
	var grow: float = 1.0 + float(_cfg()["stage_bonus"]) * maxi(registry.realm_index(state.realm_id), 0)
	var out: Dictionary = {"hit": float(base["hit"]), "crit": float(base["crit"])}
	for k in ["hp", "atk", "def"]:
		out[k] = (float(base[k]) + effects.stat_bonus(state, "combat." + k)) * grow
	out["hp"] = maxi(int(round(out["hp"] * (1.0 - float(_cfg()["wound_hp_penalty"]) * state.wounds))), 1)
	out["spd"] = float(base["spd"]) + effects.stat_bonus(state, "combat.spd")
	return out


func interval_ticks(spd: float) -> int:
	return maxi(1, int(round(float(_cfg()["interval_base"]) / spd)))


## {ok, reason, detail}. Never mutates state.
func check_enter(state: GameState, dungeon_id: String) -> Dictionary:
	if not registry.has_dungeon(dungeon_id):
		return {"ok": false, "reason": "unknown_dungeon", "detail": dungeon_id}
	if not lifespan.is_alive(state):
		return {"ok": false, "reason": "deceased", "detail": null}
	if is_active(state):
		return {"ok": false, "reason": "in_dungeon", "detail": null}
	if str(state.story["pending"]) != "":
		return {"ok": false, "reason": "story_pending", "detail": null}
	var def: Dictionary = registry.dungeons[dungeon_id]
	if not conditions.is_met(def.get("visible_when", {}), state):
		return {"ok": false, "reason": "not_discovered", "detail": null}
	var fail: Dictionary = conditions.first_failure(def.get("requirements", {}), state)
	if not fail.is_empty():
		return {"ok": false, "reason": "requirements_not_met", "detail": fail}
	return {"ok": true, "reason": "", "detail": null}


func begin(state: GameState, dungeon_id: String) -> void:
	var first: Dictionary = registry.enemies[registry.dungeons[dungeon_id]["enemies"][0]]
	var ps: Dictionary = player_stats(state)
	state.combat = {"dungeon": dungeon_id, "index": 0, "player_hp": ps["hp"], "enemy_hp": int(first["hp"]),
		"player_cd": interval_ticks(ps["spd"]), "enemy_cd": interval_ticks(float(first["spd"]))}


## One fixed tick. Returns true when a kill or the end of the run happened (the caller rescans story triggers).
func step(state: GameState) -> bool:
	var c: Dictionary = state.combat
	var def: Dictionary = registry.dungeons[c["dungeon"]]
	var enemy: Dictionary = registry.enemies[def["enemies"][int(c["index"])]]
	var ps: Dictionary = player_stats(state)
	c["player_cd"] = int(c["player_cd"]) - 1
	if int(c["player_cd"]) <= 0:
		c["player_cd"] = interval_ticks(ps["spd"])
		c["enemy_hp"] = maxi(int(c["enemy_hp"]) - _damage(state, ps, enemy), 0)
		if int(c["enemy_hp"]) <= 0:
			_kill_enemy(state, def, enemy, ps)
			return true
	c["enemy_cd"] = int(c["enemy_cd"]) - 1
	if int(c["enemy_cd"]) <= 0:
		c["enemy_cd"] = interval_ticks(float(enemy["spd"]))
		c["player_hp"] = maxi(int(c["player_hp"]) - _damage(state, enemy, ps), 0)
		if int(c["player_hp"]) <= 0:
			_end(state, "defeated")
			return true
	return false


## DMG = max(1, round(ATK - DEF x 0.5)); a miss deals 0. Both attackers are Dictionaries with atk/def/hit/crit.
func _damage(state: GameState, attacker: Dictionary, defender: Dictionary) -> int:
	if SimRng.next_float(state) >= float(attacker["hit"]):
		return 0
	var dmg: float = maxf(1.0, round(float(attacker["atk"]) - float(defender["def"]) * 0.5))
	if SimRng.next_float(state) < float(attacker["crit"]):
		dmg = round(dmg * float(_cfg()["crit_multiplier"]))
	return int(dmg)


func _kill_enemy(state: GameState, def: Dictionary, enemy: Dictionary, ps: Dictionary) -> void:
	var c: Dictionary = state.combat
	var done_idx: int = int(c["index"])
	c["index"] = done_idx + 1  # progress first: the loot below is paid exactly once
	effects.apply(state, enemy.get("effects", []))
	enemy_defeated.emit(c["dungeon"], enemy["id"])
	if int(c["index"]) >= (def["enemies"] as Array).size():
		_end(state, "cleared")
		return
	var nxt: Dictionary = registry.enemies[def["enemies"][int(c["index"])]]
	c["enemy_hp"] = int(nxt["hp"])
	c["enemy_cd"] = interval_ticks(float(nxt["spd"]))
	var heal: int = int(ceil(float(ps["hp"]) * float(_cfg()["heal_after_kill"])))
	c["player_hp"] = mini(int(c["player_hp"]) + heal, int(ps["hp"]))


## Leaves the dungeon at once. The time spent is paid in age, nothing else is rewarded.
func retreat(state: GameState) -> void:
	if is_active(state):
		_end(state, "retreated")


## Drops the run without cost or reward (offline, death, rewind).
func abort(state: GameState) -> void:
	if is_active(state):
		_end(state, "aborted")


## Wounds are capped, so they hurt but never lock the character out.
func add_wounds(state: GameState, n: int) -> void:
	state.wounds = clampi(state.wounds + n, 0, int(_cfg()["max_wounds"]))


func _end(state: GameState, result: String) -> void:
	var id: String = state.combat["dungeon"]
	var def: Dictionary = registry.dungeons[id]
	state.combat = {}  # cleared before rewards so a re-entrant call cannot see a finished run
	if result == "cleared":
		state.dungeon_clears[id] = int(state.dungeon_clears.get(id, 0)) + 1
		effects.apply(state, def.get("clear_effects", []))
	if result != "aborted":
		add_wounds(state, (1 if result == "defeated" else 0) + effects.trait_total(state, "injury_per_run"))
		lifespan.commit_age(state, float(def.get("age_cost_years", 0.0)))
	run_ended.emit(id, result)
