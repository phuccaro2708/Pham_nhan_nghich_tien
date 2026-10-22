class_name ContentMigration
extends RefCounted
## Keeps old saves valid when content ids change (docs/CONTENT_SCHEMA.md "Content migration").
## 1. Versioned renames from data/migrations/content.json are applied to saves older than the content.
## 2. Anything still unknown is moved to `orphans`, never deleted; if a later content version knows the id
##    again it moves back. An active action that no longer exists is cancelled and its paid costs refunded.

const KINDS: Array = [["resources", "resources"], ["upgrades", "upgrades"], ["action_counts", "actions"],
		["mastery", "actions"], ["relations", "relations"]]


## Returns a normalised copy of the save dictionary `data` (already schema-migrated).
static func apply(data: Dictionary, registry: ContentRegistry) -> Dictionary:
	var d: Dictionary = data.duplicate(true)
	var from_v: int = int(d["content_version"]) if GameState.is_int(d.get("content_version")) else 1
	for m in registry.migrations:
		if int(m["to_version"]) > from_v:
			_rename(d, m.get("renames", {}))
	d["content_version"] = maxi(from_v, registry.content_version)
	_infer_knowledge(d, registry)
	if typeof(d.get("orphans")) != TYPE_DICTIONARY:
		d["orphans"] = {}
	for pair in KINDS:
		_sort_known(d, pair[0], _known(registry, pair[0]))
	_orphan_phase2b(d, registry)
	_orphan_active_action(d, registry)
	_orphan_realm(d, registry)
	_enforce_lifespan(d, registry)
	return d


## v3 -> v4: grant the knowledge the old save already relied on, as declared by each knowledge's `legacy_when`.
static func _infer_knowledge(d: Dictionary, registry: ContentRegistry) -> void:
	if not d.erase("infer_knowledge"):
		return
	var ev := ConditionEvaluator.new()
	ev.content = registry
	var s: GameState = GameState.from_dict(d)
	for id in registry.knowledge:
		if registry.knowledge[id].has("legacy_when") and ev.is_met(registry.knowledge[id]["legacy_when"], s) and not s.knowledge.has(id):
			s.knowledge.append(id)
	s.knowledge.sort()
	d["knowledge"] = s.knowledge


static func _known(registry: ContentRegistry, kind: String) -> Dictionary:
	match kind:
		"resources": return registry.resources
		"upgrades": return registry.upgrades
		"relations": return registry.relations
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


## Phase 2B data that names content the game no longer has: parked in orphans, never deleted.
static func _orphan_phase2b(d: Dictionary, registry: ContentRegistry) -> void:
	var st: Variant = d.get("story")
	if typeof(st) == TYPE_DICTIONARY and typeof(st.get("done")) == TYPE_DICTIONARY:
		var lost: Dictionary = d["orphans"].get("story_done", {})
		for nid in st["done"].keys():
			if not registry.has_story_node(nid):
				lost[nid] = st["done"][nid]
				st["done"].erase(nid)
		for nid in lost.keys():
			if registry.has_story_node(nid) and not st["done"].has(nid):
				st["done"][nid] = lost[nid]
				lost.erase(nid)
		if not lost.is_empty():
			d["orphans"]["story_done"] = lost
		else:
			d["orphans"].erase("story_done")
		if typeof(st.get("pending")) == TYPE_STRING and st["pending"] != "" and (not registry.has_story_node(st["pending"]) or st["done"].has(st["pending"])):
			if not registry.has_story_node(st["pending"]):
				d["orphans"]["story_pending"] = st["pending"]
			st["pending"] = ""
		var parked: Variant = d["orphans"].get("story_pending", "")  # the node came back: reopen the event
		if typeof(parked) == TYPE_STRING and parked != "" and st.get("pending", "") == "" and registry.has_story_node(parked) and not st["done"].has(parked):
			st["pending"] = parked
			d["orphans"].erase("story_pending")
		elif typeof(parked) == TYPE_STRING and parked != "" and st["done"].has(parked):
			d["orphans"].erase("story_pending")  # resolved meanwhile: nothing left to restore
	var techs: Variant = d.get("techniques")
	if typeof(techs) == TYPE_ARRAY:
		var keep: Array = []
		var lost_t: Array = d["orphans"].get("techniques", [])
		for tid in techs:
			(keep if registry.has_technique(str(tid)) else lost_t).append(tid)
		for tid in lost_t.duplicate():
			if registry.has_technique(str(tid)):
				keep.append(tid)
				lost_t.erase(tid)
		keep.sort()
		d["techniques"] = keep
		if lost_t.is_empty():
			d["orphans"].erase("techniques")
		else:
			d["orphans"]["techniques"] = lost_t
	var know: Variant = d.get("knowledge")
	if typeof(know) == TYPE_ARRAY:  # same parking rule as techniques: unknown ids wait in orphans
		var kkeep: Array = []
		var lost_k: Array = d["orphans"].get("knowledge", [])
		for kid in know:
			(kkeep if registry.has_knowledge(str(kid)) else lost_k).append(kid)
		for kid in lost_k.duplicate():
			if registry.has_knowledge(str(kid)):
				kkeep.append(kid)
				lost_k.erase(kid)
		kkeep.sort()
		d["knowledge"] = kkeep
		if lost_k.is_empty():
			d["orphans"].erase("knowledge")
		else:
			d["orphans"]["knowledge"] = lost_k
	var au: Variant = d.get("automation")
	if typeof(au) == TYPE_DICTIONARY and typeof(au.get("slots")) == TYPE_ARRAY:
		for s in au["slots"]:
			if typeof(s) == TYPE_DICTIONARY and not registry.has_action(str(s.get("action", ""))):
				var key: String = "automation"
				while d["orphans"].has(key):
					key += "_"  # never overwrite a queue parked earlier
				d["orphans"][key] = au  # the queue refers to content that is gone: park it whole, start empty
				d["automation"] = GameState.new().automation.duplicate(true)
				var a: Variant = d.get("active_action")
				if typeof(a) == TYPE_DICTIONARY:
					a.erase("queue_slot")
				break
