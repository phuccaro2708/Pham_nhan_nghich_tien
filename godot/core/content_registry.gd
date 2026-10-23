class_name ContentRegistry
extends RefCounted
## Loads and validates data definitions (GDD §13.3). Definitions are immutable after load.
## Each data file is a JSON array of definitions.

const COST_TIMINGS: Array = ["start", "complete"]
## Trade-off knobs of a technique (V2): wounds gained per dungeon run, extra wounds healed per rest.
const TECHNIQUE_TRAITS: Array = ["injury_per_run", "heal_bonus"]
const ACTION_TYPES: Array = ["INSTANT", "TIMED", "LOOP"]  # Phase 1 subset of GDD §5.1

var resources: Dictionary = {}
var actions: Dictionary = {}
var upgrades: Dictionary = {}
## Phase 2B content. `mastery` is keyed by definition id (one per action, see mastery_for_action);
## `story` nodes keep file order in `story_order` (deterministic trigger scan); `relations` and `techniques` by id.
var mastery: Dictionary = {}
var _mastery_index: Dictionary = {}  # action id -> mastery def, see mastery_for_action
var story: Dictionary = {}
var story_order: Array = []
var techniques: Dictionary = {}
var knowledge: Dictionary = {}
var relations: Dictionary = {}
## Combat content (GDD §VIII): enemies and dungeons (bí cảnh) by id.
var enemies: Dictionary = {}
var dungeons: Dictionary = {}
## Nghịch Mệnh Tàn Kinh (V4): routes that mend a technique's flaw into a variant, by id.
var research: Dictionary = {}
## Tiên Lộ (GDD §XIV.1, V1): path milestones by id, `path_order` is display order.
var path_entries: Dictionary = {}
var path_order: Array = []
## `texts` is the primary language (vi) and the validation base; `texts_en` etc. live in `translations`.
var texts: Dictionary = {}
var translations: Dictionary = {}  # lang -> {key: text}
var language: String = "vi"
## Realm stages in progression order (GDD §3.1): `realms` by id, `realm_order` is the ladder.
var realms: Dictionary = {}
var realm_order: Array = []
var config: Dictionary = {}
## Versioned id renames for old saves (see ContentMigration). `content_version` is the newest entry.
var content_version: int = 1
var migrations: Array = []
var errors: Array = []

var _conditions := ConditionEvaluator.new()


func has_resource(id: Variant) -> bool: return resources.has(id)
func has_action(id: Variant) -> bool: return actions.has(id)
func has_upgrade(id: Variant) -> bool: return upgrades.has(id)
func has_realm(id: Variant) -> bool: return realms.has(id)
func has_story_node(id: Variant) -> bool: return story.has(id)
func has_technique(id: Variant) -> bool: return techniques.has(id)


## The one stage that forms the Kim Đan (its `core` block, V9): {grades:[{id,name_key,min_score,bonuses}], terms:[{when,weight}]}.
func core_def() -> Dictionary:
	for rid in realm_order:
		if realms[rid].has("core"):
			return realms[rid]["core"]
	return {}


## Rank of a grade id in the ladder (0 = lowest), -1 when unknown.
func dan_grade_index(id: Variant) -> int:
	var g: Array = core_def().get("grades", [])
	for i in g.size():
		if g[i]["id"] == id:
			return i
	return -1


## Techniques whose bonuses count: every learned `base` technique plus the chosen main one.
func active_techniques(state: GameState) -> Array:
	var out: Array = []
	for tid in state.techniques:
		if techniques.get(tid, {}).get("role", "base") == "base" or tid == state.main_technique:
			out.append(tid)
	return out


## Sum of `insight_modifier` over active techniques (GDD 6.4: raises the breakthrough chance).
func insight_total(state: GameState) -> float:
	var total: float = 0.0
	for tid in active_techniques(state):
		total += float(techniques[tid].get("insight_modifier", 0.0))
	return total
func has_relation(id: Variant) -> bool: return relations.has(id)
func has_knowledge(id: Variant) -> bool: return knowledge.has(id)
func has_dungeon(id: Variant) -> bool: return dungeons.has(id)


## Mastery definition of an action, {} when it has none.
func mastery_for_action(action_id: String) -> Dictionary:
	if _mastery_index.size() != mastery.size():  # rebuilt only when definitions were (re)loaded
		_mastery_index.clear()
		for mid in mastery:
			_mastery_index[mastery[mid]["action"]] = mastery[mid]
	return _mastery_index.get(action_id, {})


## Stage definition for a realm id; "" means the first stage. {} when no realms are defined.
func stage_of(realm_id: String) -> Dictionary:
	if realm_order.is_empty():
		return {}
	return realms.get(realm_order[0] if realm_id == "" else realm_id, {})


func realm_index(realm_id: String) -> int:
	if realm_order.is_empty():
		return -1
	return realm_order.find(realm_order[0] if realm_id == "" else realm_id)


func text(key: String) -> String:
	var t: Dictionary = translations.get(language, texts)
	return str(t.get(key, texts.get(key, key)))


## Loads everything under `base` (e.g. "res://data"). Returns true when valid.
func load_all(base: String = "res://data") -> bool:
	errors.clear()
	_load_dir(base + "/resources", resources, "resource")
	_load_dir(base + "/upgrades", upgrades, "upgrade")
	_load_dir(base + "/actions", actions, "action")
	_load_dir(base + "/realms", realms, "realm")
	_load_dir(base + "/relations", relations, "relation")
	_load_dir(base + "/techniques", techniques, "technique")
	_load_dir(base + "/knowledge", knowledge, "knowledge")
	_load_dir(base + "/mastery", mastery, "mastery")
	_load_dir(base + "/story", story, "story")
	_load_dir(base + "/enemies", enemies, "enemy")
	_load_dir(base + "/dungeons", dungeons, "dungeon")
	_load_dir(base + "/path", path_entries, "path")
	_load_dir(base + "/research", research, "research")
	_load_texts(base + "/localization/vi.json")
	translations = {"vi": texts}
	_load_translation(base + "/localization/en.json", "en")
	_load_optional_object(base + "/config/progression.json", func(o: Dictionary) -> void: config = o)
	_load_optional_object(base + "/migrations/content.json", func(o: Dictionary) -> void:
		migrations = o.get("migrations", [])
		content_version = int(o.get("content_version", 1)))
	validate()
	return errors.is_empty()


func add_definitions(kind: String, defs: Array) -> void:
	for d in defs:
		_register(kind, d, "inline")


func _load_dir(dir: String, into: Dictionary, kind: String) -> void:
	var files: PackedStringArray = DirAccess.get_files_at(dir)
	files.sort()
	for f in files:
		if not f.ends_with(".json"):
			continue
		var parsed: Variant = _read_json(dir + "/" + f)
		if typeof(parsed) != TYPE_ARRAY:
			errors.append("%s/%s: must be a JSON array of %s definitions" % [dir, f, kind])
			continue
		for d in parsed:
			_register(kind, d, f)


func _load_optional_object(path: String, apply: Callable) -> void:
	if not FileAccess.file_exists(path):
		return
	var parsed: Variant = _read_json(path)
	if typeof(parsed) == TYPE_DICTIONARY:
		apply.call(parsed)
	else:
		errors.append("%s: must be a JSON object" % path)


func _register(kind: String, d: Variant, source: String) -> void:
	if typeof(d) != TYPE_DICTIONARY or typeof((d as Dictionary).get("id", null)) != TYPE_STRING or str(d["id"]) == "":
		errors.append("%s: %s definition without string 'id'" % [source, kind])
		return
	var target: Dictionary
	match kind:
		"resource": target = resources
		"upgrade": target = upgrades
		"realm": target = realms
		"relation": target = relations
		"technique": target = techniques
		"knowledge": target = knowledge
		"mastery": target = mastery
		"story": target = story
		"enemy": target = enemies
		"dungeon": target = dungeons
		"path": target = path_entries
		"research": target = research
		_: target = actions
	if target.has(d["id"]):
		errors.append("%s: duplicate %s id '%s'" % [source, kind, d["id"]])
		return
	target[d["id"]] = d
	if kind == "realm":
		realm_order.append(d["id"])
	elif kind == "story":
		story_order.append(d["id"])
	elif kind == "path":
		path_order.append(d["id"])


func _load_texts(path: String) -> void:
	var parsed: Variant = _read_json(path)
	if typeof(parsed) == TYPE_DICTIONARY:
		texts = parsed
	else:
		errors.append("%s: localization must be a JSON object" % path)


func _load_translation(path: String, lang: String) -> void:
	var parsed: Variant = _read_json(path)
	if typeof(parsed) != TYPE_DICTIONARY:
		errors.append("%s: localization must be a JSON object" % path)
		return
	for k in texts:
		if not parsed.has(k):
			errors.append("%s: missing key %s" % [path, k])
	translations[lang] = parsed


func _read_json(path: String) -> Variant:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		errors.append("%s: cannot open" % path)
		return null
	var json := JSON.new()
	if json.parse(f.get_as_text()) != OK:
		errors.append("%s: JSON error line %d: %s" % [path, json.get_error_line(), json.get_error_message()])
		return null
	return json.data


## Cross-reference and field validation. Appends to `errors`.
func validate() -> void:
	for id in resources:
		_validate_resource(resources[id])
	for id in upgrades:
		_validate_upgrade(upgrades[id])
	for id in actions:
		_validate_action(actions[id])
	_validate_realms()
	_validate_relations()
	_validate_techniques()
	_validate_knowledge()
	_validate_mastery()
	_validate_story()
	_validate_path()
	_validate_research()
	_validate_softlock()
	_validate_combat()
	_validate_migrations()
	_validate_automation_config()
	_validate_ui_config()
	if not config.is_empty() and not (GameState.is_number(config.get("lifespan_warning_years")) and float(config["lifespan_warning_years"]) > 0.0):
		errors.append("config: lifespan_warning_years must be > 0")


func _validate_resource(d: Dictionary) -> void:
	var p: String = "resource '%s'" % d["id"]
	if not texts.is_empty() and not texts.has(d.get("name_key", "")):
		errors.append("%s: name_key missing in localization" % p)
	if d.has("group") and not texts.is_empty() and not texts.has("group." + str(d["group"])):
		errors.append("%s: group needs localization key group.%s" % [p, d["group"]])
	if d.has("cap") and d["cap"] != null and not (GameState.is_number(d["cap"]) and float(d["cap"]) > 0.0):
		errors.append("%s: cap must be null or > 0" % p)
	if d.has("cap_from") and (d["cap_from"] != "cultivation_cap" or d.get("cap") != null or realms.is_empty()):
		errors.append("%s: cap_from must be 'cultivation_cap', exclusive with cap, and needs realms" % p)
	if d.has("visible_when"):  # UI only: hides the row until the condition holds; the amount is still tracked
		errors.append_array(_conditions.validate(d["visible_when"], self, p + " visible_when"))
	if d.has("initial") and not (GameState.is_number(d["initial"]) and float(d["initial"]) >= 0.0):
		errors.append("%s: initial must be >= 0" % p)
	elif d.has("initial") and float(d["initial"]) > ResourceSystem.MAX_AMOUNT:
		errors.append("%s: initial exceeds ResourceSystem.MAX_AMOUNT" % p)
	elif d.has("initial") and d.get("cap") != null and GameState.is_number(d.get("cap")) and float(d["initial"]) > float(d["cap"]):
		errors.append("%s: initial exceeds cap" % p)


func _validate_upgrade(d: Dictionary) -> void:
	var p: String = "upgrade '%s'" % d["id"]
	if not resources.has(d.get("cost_resource", "")):
		errors.append("%s: unknown cost_resource" % p)
	if not (GameState.is_number(d.get("base_cost")) and float(d["base_cost"]) > 0.0):
		errors.append("%s: base_cost must be > 0" % p)
	if not (GameState.is_number(d.get("cost_growth")) and float(d["cost_growth"]) >= 1.0):
		errors.append("%s: cost_growth must be >= 1" % p)
	if not (GameState.is_number(d.get("max_level")) and int(d["max_level"]) >= 1):
		errors.append("%s: max_level must be >= 1" % p)
	if GameState.is_number(d.get("base_cost")) and GameState.is_number(d.get("cost_growth")) and GameState.is_number(d.get("max_level")) \
			and float(d["base_cost"]) * pow(float(d["cost_growth"]), maxf(float(d["max_level"]) - 1.0, 0.0)) > ResourceSystem.MAX_AMOUNT:
		errors.append("%s: price at max_level exceeds ResourceSystem.MAX_AMOUNT" % p)
	if typeof(d.get("bonuses")) != TYPE_ARRAY:
		errors.append("%s: bonuses must be an array" % p)
		return
	for b in d["bonuses"]:
		if typeof(b) != TYPE_DICTIONARY or typeof(b.get("stat")) != TYPE_STRING or not GameState.is_number(b.get("per_level")) or float(b["per_level"]) < 0.0:
			errors.append("%s: bonus needs string 'stat' and numeric 'per_level' >= 0" % p)
		elif not _valid_stat(b["stat"]):
			errors.append("%s: unknown bonus stat '%s' (use yield.<resource>, speed.all, speed.<action>)" % [p, b["stat"]])


func _valid_stat(stat: String) -> bool:
	if stat == "speed.all":
		return true
	if stat.begins_with("speed."):
		return actions.has(stat.substr(6))
	if stat.begins_with("combat."):
		return ["hp", "atk", "def", "spd"].has(stat.substr(7))
	return stat.begins_with("yield.") and resources.has(stat.substr(6))


func _validate_action(d: Dictionary) -> void:
	var p: String = "action '%s'" % d["id"]
	if not ACTION_TYPES.has(d.get("type", "")):
		errors.append("%s: type must be one of %s" % [p, ACTION_TYPES])
	if not texts.is_empty() and not texts.has(d.get("name_key", "")):
		errors.append("%s: name_key missing in localization" % p)
	if d.has("group") and not texts.is_empty() and not texts.has("group." + str(d["group"])):
		errors.append("%s: group needs localization key group.%s" % [p, d["group"]])
	if d.has("visible_when"):  # UI only: hides the button until the condition holds
		errors.append_array(_conditions.validate(d["visible_when"], self, p + " visible_when"))
	var dur: Variant = d.get("duration", 0.0)
	if d.get("type", "") == "INSTANT":
		if d.has("duration") and (not GameState.is_number(dur) or float(dur) != 0.0):
			errors.append("%s: INSTANT duration must be 0" % p)
	elif not (GameState.is_number(dur) and float(dur) > 0.0):
		errors.append("%s: duration must be > 0" % p)
	if not COST_TIMINGS.has(d.get("cost_timing", "start")):
		errors.append("%s: cost_timing must be one of %s" % [p, COST_TIMINGS])
	if not (GameState.is_number(d.get("age_cost_years", 0.0)) and float(d.get("age_cost_years", 0.0)) >= 0.0):
		errors.append("%s: age_cost_years must be >= 0" % p)
	if typeof(d.get("offline_allowed", false)) != TYPE_BOOL:
		errors.append("%s: offline_allowed must be boolean" % p)
	var costs: Variant = d.get("costs", {})
	if typeof(costs) != TYPE_DICTIONARY:
		errors.append("%s: costs must be an object" % p)
	else:
		for rid in costs:
			if not resources.has(rid) or not GameState.is_number(costs[rid]) or float(costs[rid]) < 0.0:
				errors.append("%s: invalid cost '%s'" % [p, rid])
	if d.has("upgrade") and not upgrades.has(d["upgrade"]):
		errors.append("%s: unknown upgrade '%s'" % [p, d["upgrade"]])
	elif d.has("upgrade"):
		var grants: bool = false
		for e in d.get("effects", []):
			grants = grants or (typeof(e) == TYPE_DICTIONARY and e.get("type") == "add_upgrade_level" and e.get("upgrade") == d["upgrade"])
		if not grants:
			errors.append("%s: 'upgrade' action needs an add_upgrade_level effect for '%s'" % [p, d["upgrade"]])
	if d.get("breakthrough", false):
		var advances: bool = false
		for e in d.get("effects", []):
			advances = advances or (typeof(e) == TYPE_DICTIONARY and e.get("type") == "advance_realm")
		if realms.is_empty() or not advances or d.has("costs") or d.has("upgrade"):
			errors.append("%s: breakthrough action needs realms, an advance_realm effect, and no own costs/upgrade" % p)
	if d.has("automation_allowed") and typeof(d["automation_allowed"]) != TYPE_BOOL:
		errors.append("%s: automation_allowed must be boolean" % p)
	if d.get("breakthrough", false) and d.get("automation_allowed", false):
		errors.append("%s: a breakthrough can never be automated" % p)
	errors.append_array(_conditions.validate(d.get("requirements", {}), self, p + ".requirements"))
	if typeof(d.get("effects", [])) != TYPE_ARRAY:
		errors.append("%s: effects must be an array" % p)
	else:
		for e in d.get("effects", []):
			errors.append_array(EffectResolver.validate_effect(e, self, p))


func _validate_realms() -> void:
	var prev_life: float = 0.0
	var cores: int = 0
	for i in realm_order.size():
		var d: Dictionary = realms[realm_order[i]]
		var p: String = "realm '%s'" % d["id"]
		if not texts.is_empty() and not texts.has(d.get("name_key", "")):
			errors.append("%s: name_key missing in localization" % p)
		if not (GameState.is_number(d.get("lifespan_years")) and float(d["lifespan_years"]) > 0.0 and float(d["lifespan_years"]) >= prev_life):
			errors.append("%s: lifespan_years must be > 0 and never lower than the previous stage" % p)
		else:
			prev_life = float(d["lifespan_years"])
		if not (GameState.is_number(d.get("cultivation_cap")) and float(d["cultivation_cap"]) >= 0.0):
			errors.append("%s: cultivation_cap must be >= 0" % p)
		var is_last: bool = i == realm_order.size() - 1
		if is_last == d.has("breakthrough"):
			errors.append("%s: only the last stage has no 'breakthrough'" % p)
		elif not is_last:
			_validate_breakthrough(d["breakthrough"], p + ".breakthrough")
		if d.has("core"):
			cores += 1
			_validate_core(d["core"], p + ".core")
	if cores > 1:
		errors.append("realms: only one stage may have a 'core' block")


func _validate_core(c: Variant, p: String) -> void:
	if typeof(c) != TYPE_DICTIONARY or typeof(c.get("grades")) != TYPE_ARRAY or (c["grades"] as Array).is_empty():
		errors.append("%s: needs a non-empty 'grades' array" % p)
		return
	var prev: float = -INF
	var seen: Dictionary = {}
	for g in c["grades"]:
		if typeof(g) != TYPE_DICTIONARY or typeof(g.get("id")) != TYPE_STRING or seen.has(g["id"]) or not GameState.is_number(g.get("min_score")) or float(g["min_score"]) <= prev:
			errors.append("%s: grades need unique ids and strictly rising numeric min_score" % p)
			return
		seen[g["id"]] = true
		prev = float(g["min_score"])
		if not texts.is_empty() and not texts.has(g.get("name_key", "")):
			errors.append("%s: grade '%s' name_key missing in localization" % [p, g["id"]])
		for b in g.get("bonuses", []):
			if typeof(b) != TYPE_DICTIONARY or typeof(b.get("stat")) != TYPE_STRING or not GameState.is_number(b.get("value")):
				errors.append("%s: grade '%s' bonus needs stat and numeric value" % [p, g["id"]])
	if float((c["grades"] as Array)[0]["min_score"]) > 0.0:
		errors.append("%s: the first grade must start at score 0 or below so every core gets a grade" % p)
	for t in c.get("terms", []):
		if typeof(t) != TYPE_DICTIONARY or not t.has("when") or not GameState.is_number(t.get("weight")):
			errors.append("%s: a term needs 'when' and numeric 'weight'" % p)
		else:
			errors.append_array(_conditions.validate(t["when"], self, p + ".terms.when"))


func _validate_breakthrough(b: Variant, p: String) -> void:
	if typeof(b) != TYPE_DICTIONARY:
		errors.append("%s: must be an object" % p)
		return
	var costs: Variant = b.get("costs", {})
	if typeof(costs) != TYPE_DICTIONARY:
		errors.append("%s: costs must be an object" % p)
	else:
		for rid in costs:
			if not resources.has(rid) or not GameState.is_number(costs[rid]) or float(costs[rid]) < 0.0 or float(costs[rid]) > ResourceSystem.MAX_AMOUNT:
				errors.append("%s: invalid cost '%s'" % [p, rid])
	errors.append_array(_conditions.validate(b.get("requirements", {}), self, p + ".requirements"))
	if b.has("on_fail_flag") and typeof(b["on_fail_flag"]) != TYPE_STRING:
		errors.append("%s: on_fail_flag must be a string" % p)
	var refund: Variant = b.get("on_fail_refund", {})
	if typeof(refund) != TYPE_DICTIONARY:
		errors.append("%s: on_fail_refund must be an object" % p)
	else:
		for rid in refund:
			if not (b.get("costs", {}) as Dictionary).has(rid) or not GameState.is_number(refund[rid]) or float(refund[rid]) < 0.0 or float(refund[rid]) > 1.0:
				errors.append("%s: on_fail_refund '%s' must be a ratio in [0,1] of a breakthrough cost" % [p, rid])
	if not b.has("chance"):
		return
	var ch: Variant = b["chance"]
	if typeof(ch) != TYPE_DICTIONARY or not (GameState.is_number(ch.get("base")) and GameState.is_number(ch.get("min")) and GameState.is_number(ch.get("max"))) \
			or not (0.0 <= float(ch.get("min", -1)) and float(ch.get("min", 0)) <= float(ch.get("max", 0)) and float(ch.get("max", 2)) <= 1.0):
		errors.append("%s: chance needs numeric base/min/max with 0 <= min <= max <= 1" % p)
		return
	if not (GameState.is_number(ch.get("pity_failures", 0)) and int(ch.get("pity_failures", 0)) >= 0):
		errors.append("%s: pity_failures must be >= 0" % p)
	for term in ch.get("terms", []):
		if typeof(term) == TYPE_DICTIONARY and term.has("when"):
			if not GameState.is_number(term.get("weight")) or term.has("resource"):
				errors.append("%s: a 'when' term needs a numeric 'weight' and no 'resource'" % p)
			errors.append_array(_conditions.validate(term["when"], self, p + ".chance.terms.when"))
		elif typeof(term) != TYPE_DICTIONARY or not resources.has(term.get("resource", "")) or not GameState.is_number(term.get("weight")) or not (GameState.is_number(term.get("max")) and float(term["max"]) > 0.0):
			errors.append("%s: chance term needs known 'resource', numeric 'weight' and 'max' > 0, or 'when' and 'weight'" % p)


func _validate_migrations() -> void:
	var last: int = 1
	for m in migrations:
		var v: Variant = m.get("to_version") if typeof(m) == TYPE_DICTIONARY else null
		if not (GameState.is_number(v) and int(v) > last and int(v) <= content_version):
			errors.append("migration: to_version must be increasing, > 1 and <= content_version")
			return
		last = int(v)
		var rn: Variant = m.get("renames", {})
		if typeof(rn) != TYPE_DICTIONARY:
			errors.append("migration %d: renames must be an object" % last)
			continue
		for kind in rn:
			if not ["resources", "upgrades", "actions", "realms"].has(kind) or typeof(rn[kind]) != TYPE_DICTIONARY:
				errors.append("migration %d: bad rename group '%s'" % [last, kind])
				continue
			for old in rn[kind]:
				if typeof(rn[kind][old]) != TYPE_STRING or rn[kind][old] == "" or rn[kind][old] == old:
					errors.append("migration %d: bad rename for '%s'" % [last, old])
	if content_version < 1 or (not migrations.is_empty() and content_version != int(migrations[-1].get("to_version", 0))):
		errors.append("content_version must equal the newest migration's to_version (or 1 without migrations)")


# ---------- Phase 2B: relations, techniques, mastery, story, automation ----------

func _need_text(d: Dictionary, p: String, key: String) -> void:
	if not texts.is_empty() and not texts.has(d.get(key, "")):
		errors.append("%s: %s missing in localization" % [p, key])


func _validate_relations() -> void:
	for id in relations:
		var d: Dictionary = relations[id]
		var p: String = "relation '%s'" % id
		_need_text(d, p, "name_key")
		if not (GameState.is_int(d.get("min", -10)) and GameState.is_int(d.get("max", 10)) and int(d.get("min", -10)) <= 0 and int(d.get("max", 10)) >= 0):
			errors.append("%s: min/max must be integers with min <= 0 <= max" % p)


func _validate_knowledge() -> void:
	for id in knowledge:
		var d: Dictionary = knowledge[id]
		var p: String = "knowledge '%s'" % id
		_need_text(d, p, "name_key")
		_need_text(d, p, "desc_key")
		if d.has("legacy_when"):  # v3 -> v4 save migration: who already knew this
			errors.append_array(_conditions.validate(d["legacy_when"], self, p + " legacy_when"))


func _validate_techniques() -> void:
	for id in techniques:
		var d: Dictionary = techniques[id]
		var p: String = "technique '%s'" % id
		_need_text(d, p, "name_key")
		_need_text(d, p, "desc_key")
		_validate_bonus_list(d.get("bonuses", []), p)
		if d.has("insight_modifier") and not (GameState.is_number(d["insight_modifier"]) and float(d["insight_modifier"]) >= 0.0 and float(d["insight_modifier"]) <= 0.5):
			errors.append("%s: insight_modifier must be in [0, 0.5]" % p)
		if not ["base", "main"].has(d.get("role", "base")):
			errors.append("%s: role must be 'base' or 'main'" % p)
		if d.has("variant_of") and not (techniques.has(d["variant_of"]) and d["variant_of"] != id):
			errors.append("%s: variant_of must name another technique" % p)
		var traits: Variant = d.get("traits", {})
		if typeof(traits) != TYPE_DICTIONARY:
			errors.append("%s: traits must be an object" % p)
		else:
			for k in traits:
				if not TECHNIQUE_TRAITS.has(k) or not GameState.is_int(traits[k]) or int(traits[k]) < 0:
					errors.append("%s: trait '%s' must be one of %s with an integer >= 0" % [p, k, TECHNIQUE_TRAITS])
		if typeof(d.get("element", "")) != TYPE_STRING or typeof(d.get("grade", "")) != TYPE_STRING:
			errors.append("%s: element and grade must be strings" % p)


## Softlock guard (GDD 11.4, V7): every `required_for_main` resource has a source that needs nothing but renewable resources,
## and each failure state (damaged meridian, wounds) has a recovery action that needs only renewable resources.
## Action requirements are not simulated: a source behind an unreachable condition is still the designer's call.
func _validate_softlock() -> void:
	var renewable: Dictionary = {}
	var changed: bool = true
	while changed:
		changed = false
		for aid in actions:
			if not _all_renewable(actions[aid], renewable):
				continue
			for e in actions[aid].get("effects", []):
				if e.get("type") == "add_resource" and not renewable.has(e.get("resource")):
					renewable[e["resource"]] = true
					changed = true
	for rid in resources:
		if resources[rid].get("required_for_main", false) and not renewable.has(rid):
			errors.append("resource '%s': required_for_main but no action renews it without spending other non-renewable resources" % rid)
	var cures: Array = []
	for rid in realm_order:
		var flag: Variant = realms[rid].get("breakthrough", {}).get("on_fail_flag")
		if flag != null:
			cures.append({"type": "set_flag", "flag": flag, "value": false})
	if not dungeons.is_empty():
		cures.append({"type": "heal_wounds"})
	for cure in cures:
		var found: bool = false
		for aid in actions:
			for e in actions[aid].get("effects", []):
				if e.get("type") == cure["type"] and (cure["type"] == "heal_wounds" or (e.get("flag") == cure["flag"] and e.get("value") == false)) and _all_renewable(actions[aid], renewable):
					found = true
		if not found:
			errors.append("softlock: no renewable action recovers from %s" % JSON.stringify(cure))


func _all_renewable(action: Dictionary, renewable: Dictionary) -> bool:
	var costs: Variant = action.get("costs", {})
	if typeof(costs) != TYPE_DICTIONARY:
		return false
	for rid in costs:
		if not renewable.has(rid):
			return false
	return true


func _validate_research() -> void:
	for id in research:
		var d: Dictionary = research[id]
		var p: String = "research '%s'" % id
		_need_text(d, p, "name_key")
		_need_text(d, p, "desc_key")
		if not techniques.has(d.get("technique", "")):
			errors.append("%s: unknown technique" % p)
		var v: Dictionary = techniques.get(d.get("variant", ""), {})
		if v.is_empty() or v.get("role", "base") != "main" or v.get("variant_of", "") != d.get("technique", ""):
			errors.append("%s: variant must be a main technique with variant_of = technique" % p)
		var costs: Variant = d.get("costs", {})
		if typeof(costs) != TYPE_DICTIONARY or (costs as Dictionary).is_empty():
			errors.append("%s: costs must be a non-empty object" % p)
		else:
			for rid in costs:
				if not resources.has(rid) or not GameState.is_number(costs[rid]) or float(costs[rid]) <= 0.0:
					errors.append("%s: bad cost '%s'" % [p, rid])
		if not (GameState.is_number(d.get("chance")) and float(d["chance"]) > 0.0 and float(d["chance"]) <= 1.0):
			errors.append("%s: chance must be in (0, 1]" % p)
		if not (GameState.is_int(d.get("pity_failures", 0)) and int(d.get("pity_failures", 0)) >= 0):
			errors.append("%s: pity_failures must be an integer >= 0" % p)
		if not (GameState.is_number(d.get("on_fail_refund", 0.0)) and float(d.get("on_fail_refund", 0.0)) >= 0.0 and float(d.get("on_fail_refund", 0.0)) <= 1.0):
			errors.append("%s: on_fail_refund must be in [0, 1]" % p)
		if not (GameState.is_int(d.get("on_fail_wounds", 0)) and int(d.get("on_fail_wounds", 0)) >= 0):
			errors.append("%s: on_fail_wounds must be an integer >= 0" % p)
		if not (GameState.is_number(d.get("age_cost_years", 0.0)) and float(d.get("age_cost_years", 0.0)) >= 0.0):
			errors.append("%s: age_cost_years must be >= 0" % p)
		for k in ["visible_when", "requirements"]:
			errors.append_array(_conditions.validate(d.get(k, {}), self, "%s %s" % [p, k]))


func _validate_bonus_list(list: Variant, p: String) -> void:
	if typeof(list) != TYPE_ARRAY:
		errors.append("%s: bonuses must be an array" % p)
		return
	for b in list:
		if typeof(b) != TYPE_DICTIONARY or typeof(b.get("stat")) != TYPE_STRING or not GameState.is_number(b.get("value")) or float(b["value"]) < 0.0:
			errors.append("%s: bonus needs string 'stat' and numeric 'value' >= 0" % p)
		elif not _valid_stat(b["stat"]):
			errors.append("%s: unknown bonus stat '%s'" % [p, b["stat"]])


func _validate_effect_list(list: Variant, p: String, allow_promote: bool = false) -> void:
	if typeof(list) != TYPE_ARRAY:
		errors.append("%s: effects must be an array" % p)
		return
	for e in list:
		errors.append_array(EffectResolver.validate_effect(e, self, p, false, allow_promote))


func _validate_mastery() -> void:
	var seen: Dictionary = {}
	for id in mastery:
		var d: Dictionary = mastery[id]
		var p: String = "mastery '%s'" % id
		if not actions.has(d.get("action", "")):
			errors.append("%s: unknown action" % p)
		elif seen.has(d["action"]):
			errors.append("%s: action '%s' already has mastery '%s'" % [p, d["action"], seen[d["action"]]])
		else:
			seen[d["action"]] = id
		_need_text(d, p, "name_key")
		if not (GameState.is_number(d.get("xp_base")) and float(d["xp_base"]) > 0.0 \
				and GameState.is_number(d.get("xp_growth")) and float(d["xp_growth"]) >= 1.0 \
				and GameState.is_number(d.get("xp_per_completion")) and float(d["xp_per_completion"]) > 0.0):
			errors.append("%s: xp_base > 0, xp_growth >= 1, xp_per_completion > 0" % p)
		if not (GameState.is_int(d.get("max_level")) and int(d["max_level"]) >= 2 and int(d["max_level"]) <= 99):
			errors.append("%s: max_level must be an integer in [2, 99]" % p)
			continue
		var last: int = 1
		for m in d.get("milestones", []):
			if typeof(m) != TYPE_DICTIONARY or not GameState.is_int(m.get("level")) or int(m["level"]) <= last or int(m["level"]) > int(d["max_level"]):
				errors.append("%s: milestone levels must be increasing integers in (1, max_level]" % p)
				break
			last = int(m["level"])
			_need_text(m, p + " milestone %d" % last, "name_key")
			_validate_bonus_list(m.get("bonuses", []), "%s milestone %d" % [p, last])
			_validate_effect_list(m.get("effects", []), "%s milestone %d" % [p, last])


func _validate_path() -> void:
	for id in path_order:
		var d: Dictionary = path_entries[id]
		var p: String = "path '%s'" % id
		_need_text(d, p, "name_key")
		_need_text(d, p, "goal_key")
		for k in ["visible_when", "done_when"]:
			if d.has(k):
				errors.append_array(_conditions.validate(d[k], self, "%s.%s" % [p, k]))
		for kid in d.get("clues", []):
			if not knowledge.has(kid):
				errors.append("%s: unknown clue knowledge '%s'" % [p, kid])
		for b in d.get("blockers", []):
			if typeof(b) != TYPE_DICTIONARY or not b.has("needs"):
				errors.append("%s: blocker needs 'needs' and 'reason_key'" % p)
				continue
			errors.append_array(_conditions.validate(b["needs"], self, p + ".blockers.needs"))
			if b.has("visible_when"):
				errors.append_array(_conditions.validate(b["visible_when"], self, p + ".blockers.visible_when"))
			_need_text(b, p + " blocker", "reason_key")


func _validate_story() -> void:
	for id in story_order:
		var d: Dictionary = story[id]
		var p: String = "story '%s'" % id
		_need_text(d, p, "title_key")
		_need_text(d, p, "text_key")
		if typeof(d.get("chapter", "")) != TYPE_STRING or str(d.get("chapter", "")) == "":
			errors.append("%s: chapter required" % p)
		if d.has("trigger"):
			errors.append_array(_conditions.validate(d["trigger"], self, p + ".trigger"))
		for v in d.get("text_variants", []):  # later nodes recognise earlier choices
			if typeof(v) != TYPE_DICTIONARY or not v.has("when"):
				errors.append("%s: text_variants entries need 'when' and 'text_key'" % p)
				continue
			errors.append_array(_conditions.validate(v["when"], self, p + ".text_variants.when"))
			_need_text(v, p + " text_variant", "text_key")
		var choices: Variant = d.get("choices")
		if typeof(choices) != TYPE_ARRAY or (choices as Array).is_empty():
			errors.append("%s: needs at least one choice" % p)
			continue
		var ids: Dictionary = {}
		var has_fallback: bool = false
		for c in choices:
			if typeof(c) != TYPE_DICTIONARY or typeof(c.get("id")) != TYPE_STRING or ids.has(c["id"]):
				errors.append("%s: choice needs a unique string 'id'" % p)
				continue
			ids[c["id"]] = true
			var cp: String = "%s choice '%s'" % [p, c["id"]]
			_need_text(c, cp, "text_key")
			if c.has("result_key"):
				_need_text(c, cp, "result_key")
			if c.has("later_hint_key"):
				_need_text(c, cp, "later_hint_key")
			errors.append_array(_conditions.validate(c.get("requirements", {}), self, cp + ".requirements"))
			_validate_effect_list(c.get("effects", []), cp, true)
			_validate_rewind_last(c.get("effects", []), cp)
			var costs: Variant = c.get("costs", {})
			if typeof(costs) != TYPE_DICTIONARY:
				errors.append("%s: costs must be an object" % cp)
				costs = {"?": 1}
			else:
				for rid in costs:
					if not resources.has(rid) or not GameState.is_number(costs[rid]) or float(costs[rid]) <= 0.0:
						errors.append("%s: invalid cost '%s'" % [cp, rid])
			if c.has("next") and c["next"] != null and not story.has(c["next"]):
				errors.append("%s: unknown next node '%s'" % [cp, c["next"]])
			if (c.get("requirements", {}) as Dictionary).is_empty() and (costs as Dictionary).is_empty():
				has_fallback = true
		if not has_fallback:
			errors.append("%s: needs a choice with no requirements and no costs (softlock guard, GDD 11.4)" % p)
	_validate_story_cycles()


## rewind ends a choice's effects: nothing after it could rely on the old world, and nothing may run twice across it.
func _validate_rewind_last(effects: Variant, p: String) -> void:
	if typeof(effects) != TYPE_ARRAY:
		return
	for i in (effects as Array).size():
		var e: Variant = effects[i]
		if typeof(e) == TYPE_DICTIONARY and e.get("type") == "rewind" and i != (effects as Array).size() - 1:
			errors.append("%s: rewind must be the last effect" % p)


## `next` links must form a DAG: a cycle could chain events without the player ever leaving the story.
func _validate_story_cycles() -> void:
	var state: Dictionary = {}  # id -> 1 visiting, 2 done
	for id in story_order:
		if _story_cycle(id, state):
			errors.append("story: cycle through next links at '%s'" % id)
			return


func _story_cycle(id: String, state: Dictionary) -> bool:
	if state.get(id, 0) == 1:
		return true
	if state.get(id, 0) == 2 or not story.has(id):
		return false
	state[id] = 1
	for c in story[id].get("choices", []):
		if typeof(c) == TYPE_DICTIONARY and c.get("next") != null and _story_cycle(str(c["next"]), state):
			return true
	state[id] = 2
	return false


const COMBAT_STATS: Array = ["hp", "atk", "def", "spd", "hit", "crit"]


func _validate_combat() -> void:
	var cfg: Variant = config.get("combat")
	if cfg == null:
		if not dungeons.is_empty():
			errors.append("config.combat is required when dungeons exist")
		return
	if typeof(cfg) != TYPE_DICTIONARY or typeof(cfg.get("player")) != TYPE_DICTIONARY:
		errors.append("config.combat.player must be an object")
		return
	_validate_combatant(cfg["player"], "config.combat.player")
	for k in ["stage_bonus", "crit_multiplier", "interval_base", "heal_after_kill", "max_pills", "pill_threshold", "pill_heal", "tier_heal"]:
		if not (GameState.is_number(cfg.get(k)) and float(cfg[k]) >= 0.0):
			errors.append("config.combat.%s must be a number >= 0" % k)
	if GameState.is_number(cfg.get("interval_base")) and float(cfg["interval_base"]) < 1.0:
		errors.append("config.combat.interval_base must be >= 1")
	if GameState.is_number(cfg.get("heal_after_kill")) and float(cfg["heal_after_kill"]) > 1.0:
		errors.append("config.combat.heal_after_kill must be <= 1")
	for id in enemies:
		var e: Dictionary = enemies[id]
		var p: String = "enemy '%s'" % id
		if not texts.is_empty() and not texts.has(e.get("name_key", "")):
			errors.append("%s: name_key missing in localization" % p)
		_validate_combatant(e, p)
		_validate_effect_list(e.get("effects", []), p)
	for id in dungeons:
		var d: Dictionary = dungeons[id]
		var p: String = "dungeon '%s'" % id
		for k in ["name_key", "desc_key"]:
			if not texts.is_empty() and not texts.has(d.get(k, "")):
				errors.append("%s: %s missing in localization" % [p, k])
		errors.append_array(_conditions.validate(d.get("visible_when", {}), self, p + " visible_when"))
		errors.append_array(_conditions.validate(d.get("requirements", {}), self, p + ".requirements"))
		if not (GameState.is_number(d.get("age_cost_years", 0.0)) and float(d.get("age_cost_years", 0.0)) >= 0.0):
			errors.append("%s: age_cost_years must be >= 0" % p)
		if d.has("tiers") == d.has("enemies"):
			errors.append("%s: needs exactly one of enemies / tiers" % p)
		elif typeof(d.get("tiers", d.get("enemies"))) != TYPE_ARRAY or (d.get("tiers", d.get("enemies")) as Array).is_empty():
			errors.append("%s: enemies / tiers must be a non-empty array" % p)
		else:
			for t in dungeon_tiers(id):
				_validate_tier(t, p)
		for k in ["tier_age_years", "danger"]:
			if d.has(k) and not (GameState.is_number(d[k]) and float(d[k]) >= 0.0):
				errors.append("%s: %s must be >= 0" % [p, k])
		_validate_effect_list(d.get("clear_effects", []), p)


## A dungeon's tiers (V3). A flat `enemies` list is one tier with no scaling, so older dungeons need no change.
## enemy_scale raises hp/atk/def of the tier's enemies, loot_mult multiplies their add_resource amounts.
func dungeon_tiers(id: String) -> Array:
	var d: Dictionary = dungeons[id]
	if not d.has("tiers"):
		return [{"enemies": d["enemies"], "enemy_scale": 0.0, "loot_mult": 1.0, "clear_effects": []}]
	var out: Array = []
	for t in d["tiers"]:
		out.append({"enemies": t.get("enemies", []), "enemy_scale": float(t.get("enemy_scale", 0.0)),
			"loot_mult": float(t.get("loot_mult", 1.0)), "clear_effects": t.get("clear_effects", [])})
	return out


## The enemy as met in `tier`: hp/atk/def grow with the tier's enemy_scale, its loot with loot_mult.
func scaled_enemy(dungeon_id: String, tier: int, index: int) -> Dictionary:
	var t: Dictionary = dungeon_tiers(dungeon_id)[tier]
	var e: Dictionary = (enemies[t["enemies"][index]] as Dictionary).duplicate(true)
	var k: float = 1.0 + float(t["enemy_scale"])
	e["hp"] = maxi(int(round(float(e["hp"]) * k)), 1)
	e["atk"] = float(e["atk"]) * k
	e["def"] = float(e["def"]) * k
	for fx in e.get("effects", []):
		if fx["type"] == "add_resource":
			fx["amount"] = float(fx["amount"]) * float(t["loot_mult"])
	return e


func _validate_tier(t: Dictionary, p: String) -> void:
	if (t["enemies"] as Array).is_empty():
		errors.append("%s: a tier needs enemies" % p)
	for eid in t["enemies"]:
		if not enemies.has(eid):
			errors.append("%s: unknown enemy '%s'" % [p, eid])
	for k in ["enemy_scale", "loot_mult"]:
		if float(t[k]) < 0.0:
			errors.append("%s: %s must be >= 0" % [p, k])
	_validate_effect_list(t["clear_effects"], p)


func _validate_combatant(c: Dictionary, p: String) -> void:
	for k in COMBAT_STATS:
		if not (GameState.is_number(c.get(k)) and float(c[k]) >= 0.0):
			errors.append("%s: %s must be a number >= 0" % [p, k])
	if GameState.is_number(c.get("hp")) and not (GameState.is_int(c["hp"]) and int(c["hp"]) >= 1):
		errors.append("%s: hp must be an integer >= 1" % p)
	if GameState.is_number(c.get("spd")) and float(c["spd"]) <= 0.0:
		errors.append("%s: spd must be > 0" % p)
	for k in ["hit", "crit"]:
		if GameState.is_number(c.get(k)) and float(c[k]) > 1.0:
			errors.append("%s: %s must be <= 1" % [p, k])


const UI_TABS: Array = ["mastery", "automation", "cultivation"]  # pages of StoryPages


func _validate_ui_config() -> void:
	var ui: Variant = config.get("ui", {})
	if typeof(ui) == TYPE_DICTIONARY and ui.has("lifespan_visible_when"):
		errors.append_array(_conditions.validate(ui["lifespan_visible_when"], self, "config.ui.lifespan_visible_when"))
	var rules: Variant = ui.get("tab_visible_when", {}) if typeof(ui) == TYPE_DICTIONARY else null
	if typeof(rules) != TYPE_DICTIONARY:
		errors.append("config.ui.tab_visible_when must be an object")
		return
	for page in rules:
		if not UI_TABS.has(page):
			errors.append("config.ui.tab_visible_when: unknown page '%s'" % page)
		else:
			errors.append_array(_conditions.validate(rules[page], self, "config.ui.tab_visible_when." + page))


func _validate_automation_config() -> void:
	var a: Variant = config.get("automation")
	if a == null:
		return
	if typeof(a) != TYPE_DICTIONARY or not (GameState.is_int(a.get("max_slots")) and int(a["max_slots"]) >= 1 and int(a["max_slots"]) <= 3):
		errors.append("config.automation: max_slots must be an integer in [1, 3] (GDD 9.1)")
		return
	errors.append_array(_conditions.validate(a.get("requirements", {}), self, "config.automation.requirements"))
	errors.append_array(_conditions.validate(a.get("wait_requirements", {}), self, "config.automation.wait_requirements"))
