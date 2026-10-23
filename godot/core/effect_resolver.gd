class_name EffectResolver
extends RefCounted
## Applies a fixed, registered set of effects (GDD §13.3). Never runs script from data.
## Effect types: add_resource | set_flag | add_upgrade_level | advance_realm | add_relation | learn_technique
## Story choices and mastery milestones may not advance_realm (the ritual is always a deliberate player action); only story choices may promote_realm, set_checkpoint or rewind.
## rewind (luân hồi, GDD X) restores the world saved by set_checkpoint, keeps knowledge/story, and consumes the checkpoint: a second rewind is a no-op.

const EFFECT_TYPES: Array = ["add_resource", "set_flag", "add_upgrade_level", "advance_realm", "add_relation", "learn_technique", "learn_knowledge", "promote_realm", "set_checkpoint", "rewind", "heal_wounds"]

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
				# GDD §5.3: bonuses of one group add up, groups multiply.
				resource_system.add(state, e["resource"], float(e["amount"]) * yield_multiplier(state, str(e["resource"])))
			"set_flag":
				state.flags[e["flag"]] = e["value"]
			"advance_realm":
				_advance_realm(state)
			"add_relation":
				var rel: Dictionary = registry.relations[e["relation"]]
				state.relations[e["relation"]] = clampi(int(state.relations.get(e["relation"], 0)) + int(e["amount"]),
						int(rel.get("min", -10)), int(rel.get("max", 10)))
			"learn_technique":
				if not state.techniques.has(e["technique"]):
					state.techniques.append(e["technique"])
					state.techniques.sort()
			"learn_knowledge":
				if not state.knowledge.has(e["knowledge"]):
					state.knowledge.append(e["knowledge"])
					state.knowledge.sort()
			"heal_wounds":  # the active technique can add to the amount (Thanh Mộc)
				state.wounds = maxi(state.wounds - int(e["amount"]) - trait_total(state, "heal_bonus"), 0)
			"promote_realm":
				realm_system.promote(state, str(e["realm"]))
			"set_checkpoint":
				state.checkpoint = state.world_snapshot()
			"rewind":
				if not state.checkpoint.is_empty():
					state.restore_world(state.checkpoint)
					state.checkpoint = {}
					state.loop += 1
			"add_upgrade_level":
				var up: Dictionary = registry.upgrades[e["upgrade"]]
				var lvl: int = int(state.upgrades.get(e["upgrade"], 0)) + int(e.get("levels", 1))
				state.upgrades[e["upgrade"]] = mini(lvl, int(up["max_level"]))


## A failed ritual returns the data-defined share of its price (breakthrough.on_fail_refund, GDD 5.6:
## a breakthrough must not burn materials without limit). The ratio per resource lives in realms.json.
func _advance_realm(state: GameState) -> void:
	var costs: Dictionary = realm_system.breakthrough_costs(state)
	var refund: Dictionary = realm_system.breakthrough_def(state).get("on_fail_refund", {})
	var r: Dictionary = realm_system.attempt(state)
	if r.get("success", true):
		return
	var back: Dictionary = {}
	for rid in refund:
		back[rid] = float(costs.get(rid, 0.0)) * float(refund[rid])
	resource_system.refund(state, back)


## GDD §5.3: bonuses of one group add up, groups multiply: R = base x (1+U) x (1+P) x (1+M).
func yield_multiplier(state: GameState, resource: String) -> float:
	var stat: String = "yield." + resource
	return (1.0 + group_bonus(state, stat, "upgrades")) * (1.0 + group_bonus(state, stat, "techniques")) \
			* (1.0 + group_bonus(state, stat, "mastery")) * (1.0 + group_bonus(state, stat, "core"))


## Additive total over all groups (used for speed: T = T_base / (1 + S + M), GDD 5.2).
func stat_bonus(state: GameState, stat: String) -> float:
	return group_bonus(state, stat, "upgrades") + group_bonus(state, stat, "techniques") + group_bonus(state, stat, "mastery") \
			+ group_bonus(state, stat, "core")


## Sum of one group's bonuses for `stat`. Derived from state every time, never stored, so it cannot be granted twice.
func group_bonus(state: GameState, stat: String, group: String) -> float:
	var total: float = 0.0
	match group:
		"upgrades":
			for uid in state.upgrades:
				for b in registry.upgrades.get(uid, {}).get("bonuses", []):
					if b["stat"] == stat:
						total += float(state.upgrades[uid]) * float(b["per_level"])
		"techniques":
			for tid in registry.active_techniques(state):
				for b in registry.techniques.get(tid, {}).get("bonuses", []):
					if b["stat"] == stat:
						total += float(b["value"])
		"core":  # V9: the formed Kim Đan's grade
			var i: int = registry.dan_grade_index(state.dan_grade)
			if i >= 0:
				for b in registry.core_def()["grades"][i].get("bonuses", []):
					if b["stat"] == stat:
						total += float(b["value"])
		"mastery":
			for aid in state.mastery:
				var level: int = int(state.mastery[aid]["level"])
				for m in registry.mastery_for_action(aid).get("milestones", []):
					if int(m["level"]) > level:
						break
					for b in m.get("bonuses", []):
						if b["stat"] == stat:
							total += float(b["value"])
	return total


## Sum of one integer trait over the active techniques.
func trait_total(state: GameState, key: String) -> int:
	var total: int = 0
	for tid in registry.active_techniques(state):
		total += int(registry.techniques[tid].get("traits", {}).get(key, 0))
	return total


static func validate_effect(e: Variant, registry: ContentRegistry, path: String, allow_realm: bool = true, allow_promote: bool = false) -> Array:
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
			if registry.realms.is_empty() or not allow_realm:
				errs.append("%s: advance_realm needs realms and is only allowed on breakthrough actions" % path)
		"add_relation":
			if not registry.has_relation(e.get("relation", "")):
				errs.append("%s: add_relation unknown relation" % path)
			if not (GameState.is_int(e.get("amount")) and int(e["amount"]) != 0):
				errs.append("%s: add_relation amount must be a non-zero integer" % path)
		"heal_wounds":
			if not (GameState.is_int(e.get("amount")) and int(e["amount"]) >= 1):
				errs.append("%s: heal_wounds amount must be an integer >= 1" % path)
		"learn_technique":
			if not registry.has_technique(e.get("technique", "")):
				errs.append("%s: learn_technique unknown technique" % path)
		"learn_knowledge":
			if not registry.has_knowledge(e.get("knowledge", "")):
				errs.append("%s: learn_knowledge unknown knowledge" % path)
		"promote_realm":
			if not allow_promote:
				errs.append("%s: promote_realm is only allowed in story choices" % path)
			var ri: int = registry.realm_index(str(e.get("realm", ""))) if registry.has_realm(e.get("realm", "")) else -1
			if ri < 1 or not registry.realms[registry.realm_order[ri - 1]].get("story_promotion", false):
				errs.append("%s: promote_realm needs a realm whose previous stage has story_promotion" % path)
		"set_checkpoint", "rewind":
			if not allow_promote:
				errs.append("%s: %s is only allowed in story choices" % [path, e["type"]])
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
