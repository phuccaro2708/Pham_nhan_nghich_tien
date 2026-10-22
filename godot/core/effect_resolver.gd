class_name EffectResolver
extends RefCounted
## Applies a fixed, registered set of effects (GDD §13.3). Never runs script from data.
## Effect types: add_resource | set_flag | add_upgrade_level | advance_realm

const EFFECT_TYPES: Array = ["add_resource", "set_flag", "add_upgrade_level", "advance_realm"]

var registry: ContentRegistry
var resource_system: ResourceSystem
var realm_system: RealmSystem


func _init(p_registry: ContentRegistry, p_resources: ResourceSystem, p_realms: RealmSystem) -> void:
	registry = p_registry
	resource_system = p_resources
	realm_system = p_realms


func apply(state: GameState, effects: Array) -> void:
	for e in effects:
		match e["type"]:
			"add_resource":
				if e.has("chance") and SimRng.next_float(state) >= float(e["chance"]):
					continue
				# GDD §5.3: bonuses of one group add up, groups multiply. Phase 1 has the upgrade group only.
				var u: float = stat_bonus(state, "yield." + str(e["resource"]))
				resource_system.add(state, e["resource"], float(e["amount"]) * (1.0 + u))
			"set_flag":
				state.flags[e["flag"]] = e["value"]
			"advance_realm":
				realm_system.attempt(state)
			"add_upgrade_level":
				var up: Dictionary = registry.upgrades[e["upgrade"]]
				var lvl: int = int(state.upgrades.get(e["upgrade"], 0)) + int(e.get("levels", 1))
				state.upgrades[e["upgrade"]] = mini(lvl, int(up["max_level"]))


## Sum of (level * per_level) over all upgrades granting `stat`.
func stat_bonus(state: GameState, stat: String) -> float:
	var total: float = 0.0
	for uid in state.upgrades:
		var def: Dictionary = registry.upgrades.get(uid, {})
		for b in def.get("bonuses", []):
			if b["stat"] == stat:
				total += float(state.upgrades[uid]) * float(b["per_level"])
	return total


static func validate_effect(e: Variant, registry: ContentRegistry, path: String) -> Array:
	if typeof(e) != TYPE_DICTIONARY or not EFFECT_TYPES.has(e.get("type", "")):
		return ["%s: unknown or malformed effect %s" % [path, e]]
	var errs: Array = []
	match e["type"]:
		"add_resource":
			if not registry.has_resource(e.get("resource", "")):
				errs.append("%s: add_resource unknown resource" % path)
			var amt: Variant = e.get("amount")
			if not (GameState.is_number(amt) and float(amt) >= 0.0):
				errs.append("%s: add_resource amount must be >= 0" % path)
			if e.has("chance") and not (GameState.is_number(e["chance"]) and float(e["chance"]) >= 0.0 and float(e["chance"]) <= 1.0):
				errs.append("%s: chance must be in [0,1]" % path)
		"advance_realm":
			if registry.realms.is_empty():
				errs.append("%s: advance_realm needs realms" % path)
		"set_flag":
			if typeof(e.get("flag")) != TYPE_STRING or not e.has("value"):
				errs.append("%s: set_flag needs 'flag' and 'value'" % path)
		"add_upgrade_level":
			if not registry.has_upgrade(e.get("upgrade", "")):
				errs.append("%s: add_upgrade_level unknown upgrade" % path)
			var lv: Variant = e.get("levels", 1)
			if not (GameState.is_number(lv) and float(lv) == floor(float(lv)) and float(lv) >= 1.0):
				errs.append("%s: levels must be an integer >= 1" % path)
	return errs
