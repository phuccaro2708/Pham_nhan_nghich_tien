extends Node
## Crash-safe JSON persistence (GDD §13.6): temp file -> verify -> rotate backup -> replace.
## The state is stored as a JSON string inside an envelope with a SHA-256 checksum, so
## corruption (truncation, hand edits) is detected without relying on float re-serialisation.
## The checksum detects accidents only; it is NOT anti-cheat.

const CURRENT_VERSION: int = GameState.SCHEMA_VERSION

var save_path: String = "user://saves/save.json"


func _tmp() -> String: return save_path + ".tmp"
func _bak() -> String: return save_path + ".bak"


## Returns OK or an Error code. `now_unix` is injectable for tests.
func save_game(state: GameState, registry: ContentRegistry, now_unix: int = -1) -> int:
	state.save_metadata["saved_at_unix"] = int(Time.get_unix_time_from_system()) if now_unix < 0 else now_unix
	var errs: Array = validate_state(state.to_dict(), registry)
	if not errs.is_empty():
		push_error("SaveManager: refusing to save invalid state: %s" % [errs])
		return ERR_INVALID_DATA
	var payload: String = JSON.stringify(state.to_dict(), "", true)
	var envelope: String = JSON.stringify({
		"schema_version": state.schema_version,
		"checksum": payload.sha256_text(),
		"payload": payload,
	}, "\t")
	DirAccess.make_dir_recursive_absolute(save_path.get_base_dir())
	var f := FileAccess.open(_tmp(), FileAccess.WRITE)
	if f == null:
		return FileAccess.get_open_error()
	f.store_string(envelope)
	f.close()
	if _read_envelope(_tmp(), registry).has("error"):  # verify before touching the good save
		DirAccess.remove_absolute(_tmp())
		return ERR_FILE_CORRUPT
	# Only a verified-good main may replace the backup; a corrupt main must not destroy a good .bak.
	if FileAccess.file_exists(save_path) and _checksum_ok(save_path):
		if FileAccess.file_exists(_bak()):
			DirAccess.remove_absolute(_bak())
		DirAccess.rename_absolute(save_path, _bak())
	return DirAccess.rename_absolute(_tmp(), save_path)


## {"state": GameState, "source": "main"|"backup"} or {"error": String}.
func load_game(registry: ContentRegistry) -> Dictionary:
	var last_err: String = "no_save"
	for pair in [["main", save_path], ["backup", _bak()]]:
		if not FileAccess.file_exists(pair[1]):
			continue
		var r: Dictionary = _read_envelope(pair[1], registry)
		if r.has("error"):
			last_err = "%s: %s" % [pair[0], r["error"]]
			continue
		return {"state": r["state"], "source": pair[0]}
	return {"error": last_err}


func has_save() -> bool:
	return FileAccess.file_exists(save_path) or FileAccess.file_exists(_bak())


## Cheap integrity check (no payload parse / validation) for deciding whether main may become .bak.
func _checksum_ok(path: String) -> bool:
	var env: Variant = _parse(FileAccess.get_file_as_string(path))
	return typeof(env) == TYPE_DICTIONARY and typeof(env.get("payload")) == TYPE_STRING 			and str(env["payload"]).sha256_text() == env.get("checksum", "")


func _read_envelope(path: String, registry: ContentRegistry) -> Dictionary:
	var text: String = FileAccess.get_file_as_string(path)
	var env: Variant = _parse(text)
	if typeof(env) != TYPE_DICTIONARY or typeof(env.get("payload")) != TYPE_STRING:
		return {"error": "unreadable envelope"}
	if str(env["payload"]).sha256_text() != env.get("checksum", ""):
		return {"error": "checksum mismatch"}
	var data: Variant = _parse(env["payload"])
	if typeof(data) != TYPE_DICTIONARY:
		return {"error": "payload not an object"}
	var migrated: Dictionary = migrate(data)
	if migrated.has("error"):
		return migrated
	if not GameState.is_int(migrated.get("content_version")):
		return {"error": "bad content_version"}
	if int(migrated["content_version"]) > registry.content_version:
		return {"error": "save was made with newer content (%d)" % int(migrated["content_version"])}
	migrated = ContentMigration.apply(migrated, registry)
	var errs: Array = validate_state(migrated, registry)
	if not errs.is_empty():
		return {"error": "invalid state: %s" % [errs]}
	return {"state": GameState.from_dict(migrated)}


## Silent parse (JSON.parse_string would log an engine error on corrupt files).
func _parse(text: String) -> Variant:
	var j := JSON.new()
	return j.data if j.parse(text) == OK else null


## Upgrades old dictionaries step by step. Add one function per version bump.
func migrate(data: Dictionary) -> Dictionary:
	if not GameState.is_int(data.get("schema_version", 0)):
		return {"error": "bad schema_version"}
	var v: int = int(data.get("schema_version", 0))
	if v > CURRENT_VERSION:
		return {"error": "save is from a newer version (%d)" % v}
	var d: Dictionary = data.duplicate(true)
	while v < CURRENT_VERSION:
		match v:
			0:  # v0 stored `age`; v1 calls it `age_years`
				if d.has("age"):
					d["age_years"] = d["age"]
					d.erase("age")
			1:  # v2 adds Phase 2A fields; ContentMigration fills content_version/orphans afterwards
				d["realm_id"] = ""
				d["breakthrough_failures"] = 0
				d["life"] = {"status": "alive", "warned": false, "ended": {}}
				d["orphans"] = {}
				d["content_version"] = 1
			2:  # v3 adds Phase 2B: mastery, story, relations, techniques, automation
				d["mastery"] = {}
				d["story"] = {"done": {}, "pending": ""}
				d["relations"] = {}
				d["techniques"] = []
				d["automation"] = GameState.new().automation.duplicate(true)
			3:  # v4 adds knowledge; ContentMigration infers it (knowledge `legacy_when`) so an old save keeps every action it could use
				d["knowledge"] = []
				d["infer_knowledge"] = true
			4:  # v5 adds luân hồi: no rewind has happened and no mốc is stored yet
				d["loop"] = 0
				d["checkpoint"] = {}
			5:  # v6 adds dungeons: no run in progress, nothing cleared
				d["combat"] = {}
				d["dungeon_clears"] = {}
			_:
				return {"error": "no migration from version %d" % v}
		v += 1
		d["schema_version"] = v
	return d


## Rejects NaN/inf, negatives, unknown ids and impossible progress. Returns error strings.
func validate_state(d: Dictionary, registry: ContentRegistry) -> Array:
	var errs: Array = []
	if int(d.get("schema_version", -1)) != CURRENT_VERSION:
		errs.append("schema_version")
	for key in ["game_time_ticks", "rng_seed", "rng_state"]:
		if not GameState.is_int(d.get(key)) or (key != "rng_seed" and float(d[key]) < 0.0):
			errs.append("bad %s" % key)
	if not GameState.is_number(d.get("age_years")) or float(d["age_years"]) < 0.0:
		errs.append("bad age_years")
	for key in ["resources", "upgrades", "flags", "action_counts", "active_action", "save_metadata", "life", "orphans",
			"mastery", "story", "relations", "automation", "combat", "dungeon_clears"]:
		if typeof(d.get(key)) != TYPE_DICTIONARY:
			errs.append("%s must be an object" % key)
	if typeof(d.get("techniques")) != TYPE_ARRAY:
		errs.append("techniques must be an array")
	if typeof(d.get("knowledge")) != TYPE_ARRAY:
		errs.append("knowledge must be an array")
	if typeof(d.get("checkpoint")) != TYPE_DICTIONARY:
		errs.append("checkpoint must be an object")
	if not GameState.is_int(d.get("loop")) or int(d.get("loop", 0)) < 0:
		errs.append("bad loop")
	if not errs.is_empty():
		return errs
	for id in d["resources"]:
		var v: Variant = d["resources"][id]
		if not registry.has_resource(id):
			errs.append("unknown resource %s" % id)
		elif not GameState.is_number(v) or float(v) < 0.0:
			errs.append("bad amount for %s" % id)
		elif float(v) > ResourceSystem.MAX_AMOUNT:
			errs.append("%s above MAX_AMOUNT" % id)
	for id in d["upgrades"]:
		if not registry.has_upgrade(id):
			errs.append("unknown upgrade %s" % id)
		elif not GameState.is_int(d["upgrades"][id]) or int(d["upgrades"][id]) < 0 or int(d["upgrades"][id]) > int(registry.upgrades[id]["max_level"]):
			errs.append("bad level for %s" % id)
	for id in d["action_counts"]:
		if not registry.has_action(id) or not GameState.is_int(d["action_counts"][id]) or int(d["action_counts"][id]) < 0:
			errs.append("bad action_counts %s" % id)
	_validate_progression(d, registry, errs)
	_validate_phase2b(d, registry, errs)
	_validate_combat(d, registry, errs)
	if not (d["checkpoint"] as Dictionary).is_empty():
		errs.append_array(_validate_checkpoint(d, registry))
	var a: Dictionary = d["active_action"]
	if not a.is_empty():
		if not registry.has_action(a.get("id", "")):
			errs.append("unknown active action")
		elif not (GameState.is_int(a.get("progress_ticks")) and GameState.is_int(a.get("duration_ticks"))
				and int(a["duration_ticks"]) >= 1 and int(a["progress_ticks"]) >= 0
				and int(a["progress_ticks"]) < int(a["duration_ticks"])):
			errs.append("bad active action progress")
		elif typeof(a.get("costs_paid", {})) != TYPE_DICTIONARY:
			errs.append("bad costs_paid")
		else:
			for id in a.get("costs_paid", {}):
				if not registry.has_resource(id) or not GameState.is_number(a["costs_paid"][id]) or float(a["costs_paid"][id]) < 0.0:
					errs.append("bad costs_paid entry %s" % id)
	return errs


func _validate_combat(d: Dictionary, registry: ContentRegistry, errs: Array) -> void:
	for id in d["dungeon_clears"]:
		if not registry.has_dungeon(id) or not GameState.is_int(d["dungeon_clears"][id]) or int(d["dungeon_clears"][id]) < 0:
			errs.append("bad dungeon_clears %s" % id)
	var c: Dictionary = d["combat"]
	if c.is_empty():
		return
	var dg: Dictionary = registry.dungeons.get(c.get("dungeon", ""), {})
	if dg.is_empty():
		errs.append("unknown dungeon in combat")
		return
	for k in ["index", "player_hp", "enemy_hp", "player_cd", "enemy_cd"]:
		if not GameState.is_int(c.get(k)):
			errs.append("bad combat %s" % k)
			return
	var n: int = (dg["enemies"] as Array).size()
	if int(c["index"]) < 0 or int(c["index"]) >= n or int(c["player_hp"]) < 1 or int(c["enemy_hp"]) < 1 			or int(c["player_cd"]) < 1 or int(c["enemy_cd"]) < 1:
		errs.append("impossible combat progress")
	elif int(c["enemy_hp"]) > int(registry.enemies[dg["enemies"][int(c["index"])]]["hp"]):
		errs.append("enemy_hp above the enemy's maximum")
	elif not (d["active_action"] as Dictionary).is_empty():
		errs.append("action running during a dungeon run")
	elif (d["life"] as Dictionary).get("status") != "alive":
		errs.append("deceased character in a dungeon")


## A checkpoint is a world snapshot: validate it by swapping it into a copy of the state and running the same checks.
func _validate_checkpoint(d: Dictionary, registry: ContentRegistry) -> Array:
	var cp: Dictionary = d["checkpoint"]
	if cp.size() != GameState.WORLD_KEYS.size():
		return ["bad checkpoint keys"]
	var probe: Dictionary = d.duplicate(true)
	for k in GameState.WORLD_KEYS:
		if not cp.has(k):
			return ["bad checkpoint keys"]
		if k != "life_warned":
			probe[k] = cp[k]
	probe["life"] = {"status": "alive", "warned": cp["life_warned"], "ended": {}}
	probe["active_action"] = {}
	probe["checkpoint"] = {}
	var out: Array = []
	for e in validate_state(probe, registry):
		out.append("checkpoint: %s" % e)
	return out


func _validate_progression(d: Dictionary, registry: ContentRegistry, errs: Array) -> void:
	if not GameState.is_int(d.get("content_version")) or int(d["content_version"]) < 1:
		errs.append("bad content_version")
	elif int(d["content_version"]) > registry.content_version:
		errs.append("content_version newer than the game content")
	if not GameState.is_int(d.get("breakthrough_failures")) or int(d["breakthrough_failures"]) < 0:
		errs.append("bad breakthrough_failures")
	var life: Dictionary = d["life"]
	if not ["alive", "deceased"].has(life.get("status")) or typeof(life.get("warned")) != TYPE_BOOL or typeof(life.get("ended")) != TYPE_DICTIONARY:
		errs.append("bad life")
	elif life["status"] == "alive" and not (life["ended"] as Dictionary).is_empty():
		errs.append("living character with an end record")
	var rid: Variant = d.get("realm_id")
	if typeof(rid) != TYPE_STRING or (rid != "" and not registry.has_realm(rid)):
		errs.append("unknown realm_id")
	elif not registry.realm_order.is_empty():
		var limit: float = float(registry.stage_of(rid)["lifespan_years"])
		if float(d["age_years"]) > limit + 1e-6 or (life["status"] == "alive" and float(d["age_years"]) >= limit):
			errs.append("age_years at or above the realm's lifespan but the character is alive")


func _validate_phase2b(d: Dictionary, registry: ContentRegistry, errs: Array) -> void:
	for aid in d["mastery"]:
		var m: Variant = d["mastery"][aid]
		var def: Dictionary = registry.mastery_for_action(aid)
		if def.is_empty() or typeof(m) != TYPE_DICTIONARY:
			errs.append("unknown mastery %s" % aid)
		elif not (GameState.is_int(m.get("level")) and int(m["level"]) >= 1 and int(m["level"]) <= int(def["max_level"])
				and GameState.is_number(m.get("xp")) and float(m["xp"]) >= 0.0 and typeof(m.get("claimed")) == TYPE_ARRAY):
			errs.append("bad mastery %s" % aid)
		else:
			for lv in m["claimed"]:
				if not GameState.is_int(lv) or int(lv) < 2 or int(lv) > int(m["level"]):
					errs.append("bad claimed level for mastery %s" % aid)
	var st: Dictionary = d["story"]
	if typeof(st.get("done")) != TYPE_DICTIONARY or typeof(st.get("pending")) != TYPE_STRING:
		errs.append("bad story")
	else:
		for nid in st["done"]:
			if not registry.has_story_node(nid) or typeof(st["done"][nid]) != TYPE_STRING:
				errs.append("unknown story node %s" % nid)
		if st["pending"] != "" and (not registry.has_story_node(st["pending"]) or st["done"].has(st["pending"])):
			errs.append("bad pending story node")
	for rid in d["relations"]:
		if not registry.has_relation(rid) or not GameState.is_int(d["relations"][rid]):
			errs.append("bad relation %s" % rid)
	for tid in d["techniques"]:
		if typeof(tid) != TYPE_STRING or not registry.has_technique(tid):
			errs.append("unknown technique %s" % tid)
	for kid in d["knowledge"]:
		if typeof(kid) != TYPE_STRING or not registry.has_knowledge(kid):
			errs.append("unknown knowledge %s" % kid)
	var au: Dictionary = d["automation"]
	if typeof(au.get("slots")) != TYPE_ARRAY or not ["idle", "running", "stopped", "finished", "deadlock"].has(au.get("status")) 			or typeof(au.get("loop")) != TYPE_BOOL or typeof(au.get("reason")) != TYPE_STRING 			or not GameState.is_int(au.get("cursor")) or not GameState.is_int(au.get("instant_streak")) 			or int(au["cursor"]) < 0 or int(au["instant_streak"]) < 0:
		errs.append("bad automation")
		return
	if (au["slots"] as Array).size() > 3:
		errs.append("automation has too many slots")
	for s in au["slots"]:
		if typeof(s) != TYPE_DICTIONARY or not registry.has_action(s.get("action", "")) or not GameState.is_int(s.get("repeat")) 				or int(s["repeat"]) < 0 or not GameState.is_int(s.get("done")) or int(s["done"]) < 0 				or not ["skip", "wait", "stop"].has(s.get("on_block")) or typeof(s.get("until")) != TYPE_DICTIONARY:
			errs.append("bad automation slot")
	var qs: Variant = d["active_action"].get("queue_slot")
	if qs != null and (not GameState.is_int(qs) or int(qs) < 0 or int(qs) >= (au["slots"] as Array).size()):
		errs.append("bad queue_slot")
