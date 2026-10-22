class_name ContentMigration
extends RefCounted
## Keeps old saves valid when content ids change (docs/CONTENT_SCHEMA.md "Content migration").
## 1. Versioned renames from data/migrations/content.json are applied to saves older than the content.
## 2. Anything still unknown is moved to `orphans`, never deleted; if a later content version knows the id
##    again it moves back. An active action that no longer exists is cancelled and its paid costs refunded.

const KINDS: Array = [["resources", "resources"], ["upgrades", "upgrades"], ["action_counts", "actions"]]


## Returns a normalised copy of the save dictionary `data` (already schema-migrated).
static func apply(data: Dictionary, registry: ContentRegistry) -> Dictionary:
	var d: Dictionary = data.duplicate(true)
	var from_v: int = int(d["content_version"]) if GameState.is_int(d.get("content_version")) else 1
	for m in registry.migrations:
		if int(m["to_version"]) > from_v:
			_rename(d, m.get("renames", {}))
	d["content_version"] = maxi(from_v, registry.content_version)
	if typeof(d.get("orphans")) != TYPE_DICTIONARY:
		d["orphans"] = {}
	for pair in KINDS:
		_sort_known(d, pair[0], _known(registry, pair[0]))
	_orphan_active_action(d, registry)
	_orphan_realm(d, registry)
	_enforce_lifespan(d, registry)
	return d


static func _known(registry: ContentRegistry, kind: String) -> Dictionary:
	match kind:
		"resources": return registry.resources
		"upgrades": return registry.upgrades
	return registry.actions


static func _rename(d: Dictionary, renames: Dictionary) -> void:
	for key in renames.get("resources", {}):
		_move_key(d.get("resources", {}), key, renames["resources"][key])
		var a: Variant = d.get("active_action", {})
		if typeof(a) == TYPE_DICTIONARY and typeof(a.get("costs_paid")) == TYPE_DICTIONARY:
			_move_key(a["costs_paid"], key, renames["resources"][key])
	for key in renames.get("realms", {}):
		if d.get("realm_id") == key:
			d["realm_id"] = renames["realms"][key]
	for key in renames.get("upgrades", {}):
		_move_key(d.get("upgrades", {}), key, renames["upgrades"][key])
	for key in renames.get("actions", {}):
		_move_key(d.get("action_counts", {}), key, renames["actions"][key])
		var a2: Variant = d.get("active_action", {})
		if typeof(a2) == TYPE_DICTIONARY and a2.get("id") == key:
			a2["id"] = renames["actions"][key]


## Renames only when the target is free: an existing entry is never overwritten (the old key then
## ends up in orphans instead of being merged or lost).
static func _move_key(dict: Variant, old: String, new: String) -> void:
	if typeof(dict) == TYPE_DICTIONARY and dict.has(old) and not dict.has(new):
		dict[new] = dict[old]
		dict.erase(old)


static func _sort_known(d: Dictionary, field: String, known: Dictionary) -> void:
	if typeof(d.get(field)) != TYPE_DICTIONARY:
		return  # malformed: validate_state reports it, we do not touch it
	var orph: Dictionary = d["orphans"].get(field, {})
	for id in d[field].keys():
		if not known.has(id):
			orph[id] = d[field][id]
			d[field].erase(id)
	for id in orph.keys():
		if known.has(id) and not d[field].has(id):
			d[field][id] = orph[id]
			orph.erase(id)
	if orph.is_empty():
		d["orphans"].erase(field)
	else:
		d["orphans"][field] = orph


static func _orphan_active_action(d: Dictionary, registry: ContentRegistry) -> void:
	var a: Variant = d.get("active_action", {})
	if typeof(a) != TYPE_DICTIONARY or a.is_empty() or registry.has_action(a.get("id", "")):
		return
	var paid: Variant = a.get("costs_paid", {})
	if typeof(paid) == TYPE_DICTIONARY and typeof(d.get("resources")) == TYPE_DICTIONARY:
		for rid in paid:
			if registry.has_resource(rid) and GameState.is_number(paid[rid]):
				d["resources"][rid] = float(d["resources"].get(rid, 0.0)) + float(paid[rid])
	if typeof(d["orphans"].get("active_actions")) != TYPE_DICTIONARY:
		d["orphans"]["active_actions"] = {}
	d["orphans"]["active_actions"][str(a.get("id", "?"))] = a  # keyed by id: a second orphan never overwrites the first
	d["active_action"] = {}


## Saves from before the lifespan existed (v1) carry no verdict: a character already at the limit has died.
static func _enforce_lifespan(d: Dictionary, registry: ContentRegistry) -> void:
	var life: Variant = d.get("life")
	var rid: Variant = d.get("realm_id", "")
	if typeof(life) != TYPE_DICTIONARY or life.get("status") != "alive" or typeof(rid) != TYPE_STRING or registry.stage_of(rid).is_empty():
		return
	var age: Variant = d.get("age_years")
	var limit: float = float(registry.stage_of(rid)["lifespan_years"])
	if GameState.is_number(age) and float(age) >= limit:
		life["status"] = "deceased"
		life["ended"] = {"age_years": float(age), "realm_id": rid, "game_time_ticks": int(d.get("game_time_ticks", 0))}
		d["active_action"] = {}


## A realm id the content no longer has: keep it in orphans and restart at the first stage (age is
## then re-checked against that stage's lifespan). Renames are handled by migrations.
static func _orphan_realm(d: Dictionary, registry: ContentRegistry) -> void:
	var rid: Variant = d.get("realm_id", "")
	if registry.realm_order.is_empty() or typeof(rid) != TYPE_STRING or rid == "" or registry.has_realm(rid):
		return
	d["orphans"]["realm_id"] = rid
	d["realm_id"] = ""
