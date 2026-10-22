class_name ConditionEvaluator
extends RefCounted
## Evaluates requirement trees (GDD §5.4).
## Forms: {} (always true) | {"all_of":[..]} | {"any_of":[..]} | {"not":{..}} | {"type":"<leaf>", ...}

const LEAF_TYPES: Array = [
	"resource_at_least", "flag_is", "stat_at_least", "upgrade_level_at_least", "action_count_at_least", "realm_at_least",
]


## Needed by realm_at_least; ActionSystem sets it. Without it that leaf is false.
var content: ContentRegistry


func is_met(cond: Dictionary, state: GameState) -> bool:
	return first_failure(cond, state).is_empty()


## Returns the first failing leaf (for UI "why locked"), or {} when satisfied.
func first_failure(cond: Dictionary, state: GameState) -> Dictionary:
	if cond.is_empty():
		return {}
	if cond.has("all_of"):
		for c in cond["all_of"]:
			var f: Dictionary = first_failure(c, state)
			if not f.is_empty():
				return f
		return {}
	if cond.has("any_of"):
		var last: Dictionary = {}
		for c in cond["any_of"]:
			var f2: Dictionary = first_failure(c, state)
			if f2.is_empty():
				return {}
			last = f2
		return last if not (cond["any_of"] as Array).is_empty() else {"type": "any_of_empty"}
	if cond.has("not"):
		return {"type": "not", "inner": cond["not"]} if is_met(cond["not"], state) else {}
	return {} if _leaf(cond, state) else cond


func _leaf(c: Dictionary, s: GameState) -> bool:
	match c.get("type", ""):
		"resource_at_least":
			return float(s.resources.get(c["resource"], 0.0)) >= float(c["amount"])
		"flag_is":
			var cur: Variant = s.flags.get(c["flag"], false)
			return _same(cur, c["value"])
		"stat_at_least":
			return _stat(c["stat"], s) >= float(c["value"])
		"upgrade_level_at_least":
			return int(s.upgrades.get(c["upgrade"], 0)) >= int(c["level"])
		"action_count_at_least":
			return int(s.action_counts.get(c["action"], 0)) >= int(c["count"])
		"realm_at_least":
			return content != null and content.has_realm(c["realm"]) \
					and content.realm_index(s.realm_id) >= content.realm_index(str(c["realm"]))
	return false  # unknown type never unlocks anything


## JSON turns every number into float, so numbers compare by value; other types must match exactly.
func _same(a: Variant, b: Variant) -> bool:
	var na: bool = typeof(a) == TYPE_INT or typeof(a) == TYPE_FLOAT
	var nb: bool = typeof(b) == TYPE_INT or typeof(b) == TYPE_FLOAT
	if na and nb:
		return float(a) == float(b)
	return typeof(a) == typeof(b) and a == b


func _stat(stat: String, s: GameState) -> float:
	match stat:
		"age_years":
			return s.age_years
	return 0.0


## Returns error strings; empty means the tree is well formed.
func validate(cond: Variant, registry: ContentRegistry, path: String = "requirements") -> Array:
	var errs: Array = []
	if typeof(cond) != TYPE_DICTIONARY:
		return ["%s: must be an object" % path]
	var d: Dictionary = cond
	if d.is_empty():
		return errs
	if d.has("all_of") or d.has("any_of"):
		var key: String = "all_of" if d.has("all_of") else "any_of"
		if d.size() != 1 or typeof(d[key]) != TYPE_ARRAY:
			return ["%s: %s must be the only key and an array" % [path, key]]
		for i in (d[key] as Array).size():
			errs.append_array(validate(d[key][i], registry, "%s.%s[%d]" % [path, key, i]))
		return errs
	if d.has("not"):
		if d.size() != 1:
			return ["%s: 'not' must be the only key" % path]
		return validate(d["not"], registry, path + ".not")
	var t: String = str(d.get("type", ""))
	if not LEAF_TYPES.has(t):
		return ["%s: unknown condition type '%s'" % [path, t]]
	var req: Array = []
	match t:
		"resource_at_least": req = ["resource", "amount"]
		"flag_is": req = ["flag", "value"]
		"stat_at_least": req = ["stat", "value"]
		"upgrade_level_at_least": req = ["upgrade", "level"]
		"action_count_at_least": req = ["action", "count"]
		"realm_at_least": req = ["realm"]
	for k in req:
		if not d.has(k):
			errs.append("%s: '%s' missing field '%s'" % [path, t, k])
	if not errs.is_empty():
		return errs
	if t == "resource_at_least" and not registry.has_resource(d["resource"]):
		errs.append("%s: unknown resource '%s'" % [path, d["resource"]])
	if t == "upgrade_level_at_least" and not registry.has_upgrade(d["upgrade"]):
		errs.append("%s: unknown upgrade '%s'" % [path, d["upgrade"]])
	if t == "action_count_at_least" and not registry.has_action(d["action"]):
		errs.append("%s: unknown action '%s'" % [path, d["action"]])
	if t == "realm_at_least" and not registry.has_realm(d["realm"]):
		errs.append("%s: unknown realm '%s'" % [path, d["realm"]])
	if t == "stat_at_least" and not ["age_years"].has(d["stat"]):
		errs.append("%s: unknown stat '%s'" % [path, d["stat"]])
	return errs
