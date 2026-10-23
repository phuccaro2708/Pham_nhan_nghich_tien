class_name GameState
extends RefCounted
## Pure runtime data. No Node references, no behaviour beyond (de)serialisation.

const SCHEMA_VERSION: int = 9
const START_AGE_YEARS: float = 16.0
## Fixed precision so values survive a JSON round trip and never drift.
const SNAP_SCALE: float = 1000000.0
## Godot prints ~15 significant digits. Below SNAP_LIMIT we keep 6 decimals (<= 14 digits); at or
## above it values are whole numbers (<= ResourceSystem.MAX_AMOUNT = 1e15, 15 digits). Both round-trip exactly.
const SNAP_LIMIT: float = 100000000.0

var schema_version: int = SCHEMA_VERSION
var game_time_ticks: int = 0
var age_years: float = START_AGE_YEARS
var rng_seed: int = 1
var rng_state: int = 1
var resources: Dictionary = {}      # resource_id -> float
var upgrades: Dictionary = {}       # upgrade_id -> int level
var flags: Dictionary = {}          # flag -> bool/int/String
var action_counts: Dictionary = {}  # action_id -> int completions
## {} when idle, else {id, progress_ticks, duration_ticks, costs_paid}
var active_action: Dictionary = {}
var save_metadata: Dictionary = {"saved_at_unix": 0}
## Version of the content data this save was last migrated to (see ContentMigration).
var content_version: int = 1
## "" means the first realm of the registry (so a fresh GameState needs no content lookup).
var realm_id: String = ""
var breakthrough_failures: int = 0
## status: "alive" | "deceased" (tọa hóa); warned: lifespan warning already sent for the current limit.
var life: Dictionary = {"status": "alive", "warned": false, "ended": {}}
## Action mastery (Phase 2B): action_id -> {level, xp (progress inside the level), claimed (milestone levels already paid)}.
var mastery: Dictionary = {}
## Story graph progress: done = node_id -> chosen choice id; pending = node waiting for the player's choice ("" = none).
var story: Dictionary = {"done": {}, "pending": ""}
## relation_id -> int. Causality data (GDD 7.4); there is no global good/evil stat.
var relations: Dictionary = {}
## Learned technique ids (công pháp), sorted.
var techniques: Array = []
## Công pháp chủ tu (V2): the one learned `main` technique whose bonuses apply ("" = none). Base techniques always apply.
var main_technique: String = ""
## Thương tích (V2): 0..combat.max_wounds. Cut max HP in dungeons, healed by resting; never blocks an action.
var wounds: int = 0
## Learned knowledge ids (Phase 3): what the character knows decides which actions, stats and concepts the UI may show.
var knowledge: Array = []
## Luân hồi (GDD X): `checkpoint` is the world as it stood at a mốc the character lived through ({} = none);
## `loop` counts completed rewinds. What the character remembers is `knowledge` (group "memory") and `story.done`; both survive a rewind.
var loop: int = 0
var checkpoint: Dictionary = {}
## Automation queue (see AutomationQueue). Never holds a story choice or a breakthrough.
var automation: Dictionary = {"slots": [], "cursor": 0, "loop": false, "status": "idle", "reason": "", "instant_streak": 0}
## Dungeon run in progress ({} = none): {dungeon, tier, paused (waiting for the player after a tier), pills (prepared, left),
## index (enemy being fought in the tier), player_hp, enemy_hp, player_cd, enemy_cd} (see CombatSystem).
var combat: Dictionary = {}
## How the last finished run ended ({} = none yet): {dungeon, result, depth (tiers cleared), cause}. Drives the "change your preparation" hint.
var last_run: Dictionary = {}
## dungeon_id -> number of cleared runs.
var dungeon_clears: Dictionary = {}
## Nghịch Mệnh Tàn Kinh (V4): research route id -> failed attempts since the last success (drives pity). Character continuity, not rewound.
var research_failures: Dictionary = {}
## Data the running content does not recognise. Preserved, never deleted: {resources, upgrades, action_counts, active_action}.
var orphans: Dictionary = {}


static func new_game(seed_value: int = 1) -> GameState:
	var s := GameState.new()
	s.rng_seed = seed_value
	s.rng_state = SimRng.seed_to_state(seed_value)
	s.flags["tutorial_started"] = true
	return s


## Finite JSON number (int or float).
static func is_number(v: Variant) -> bool:
	return (typeof(v) == TYPE_FLOAT or typeof(v) == TYPE_INT) and is_finite(float(v))


static func is_int(v: Variant) -> bool:
	return is_number(v) and float(v) == floor(float(v))


static func snap(v: float) -> float:
	# round(v*1e6)/1e6 is the double nearest to the decimal, so it prints and parses back identically
	# (snappedf multiplies by 1e-6 instead, which can land 1 ulp off).
	if absf(v) >= SNAP_LIMIT:
		return roundf(v)
	return roundf(v * SNAP_SCALE) / SNAP_SCALE


func to_dict() -> Dictionary:
	return {
		"schema_version": schema_version,
		"game_time_ticks": game_time_ticks,
		"age_years": age_years,
		"rng_seed": rng_seed,
		"rng_state": rng_state,
		"resources": resources.duplicate(true),
		"upgrades": upgrades.duplicate(true),
		"flags": flags.duplicate(true),
		"action_counts": action_counts.duplicate(true),
		"active_action": active_action.duplicate(true),
		"save_metadata": save_metadata.duplicate(true),
		"content_version": content_version,
		"realm_id": realm_id,
		"breakthrough_failures": breakthrough_failures,
		"life": life.duplicate(true),
		"orphans": orphans.duplicate(true),
		"mastery": mastery.duplicate(true),
		"story": story.duplicate(true),
		"relations": relations.duplicate(true),
		"techniques": techniques.duplicate(),
		"main_technique": main_technique,
		"wounds": wounds,
		"knowledge": knowledge.duplicate(),
		"loop": loop,
		"checkpoint": checkpoint.duplicate(true),
		"automation": automation.duplicate(true),
		"combat": combat.duplicate(true),
		"last_run": last_run.duplicate(true),
		"dungeon_clears": dungeon_clears.duplicate(true),
		"research_failures": research_failures.duplicate(true),
	}


## Expects data that already passed SaveManager.validate_state.
static func from_dict(d: Dictionary) -> GameState:
	var s := GameState.new()
	s.schema_version = int(d.get("schema_version", SCHEMA_VERSION))
	s.game_time_ticks = int(d.get("game_time_ticks", 0))
	s.age_years = float(d.get("age_years", START_AGE_YEARS))
	s.rng_seed = int(d.get("rng_seed", 1))
	s.rng_state = int(d.get("rng_state", 1))
	for k in d.get("resources", {}):
		s.resources[str(k)] = float(d["resources"][k])
	for k in d.get("upgrades", {}):
		s.upgrades[str(k)] = int(d["upgrades"][k])
	s.flags = (d.get("flags", {}) as Dictionary).duplicate(true)
	for k in d.get("action_counts", {}):
		s.action_counts[str(k)] = int(d["action_counts"][k])
	var a: Dictionary = d.get("active_action", {})
	if not a.is_empty():
		var paid: Dictionary = {}
		for k in a.get("costs_paid", {}):
			paid[str(k)] = float(a["costs_paid"][k])
		s.active_action = {
			"id": str(a["id"]),
			"progress_ticks": int(a["progress_ticks"]),
			"duration_ticks": int(a["duration_ticks"]),
			"costs_paid": paid,
		}
		if a.has("queue_slot"):
			s.active_action["queue_slot"] = int(a["queue_slot"])
	s.save_metadata = {"saved_at_unix": int((d.get("save_metadata", {}) as Dictionary).get("saved_at_unix", 0))}
	s.content_version = int(d.get("content_version", 1))
	s.realm_id = str(d.get("realm_id", ""))
	s.breakthrough_failures = int(d.get("breakthrough_failures", 0))
	var lf: Dictionary = d.get("life", {})
	s.life = {"status": str(lf.get("status", "alive")), "warned": bool(lf.get("warned", false)),
		"ended": (lf.get("ended", {}) as Dictionary).duplicate(true)}
	s.orphans = (d.get("orphans", {}) as Dictionary).duplicate(true)
	for k in d.get("mastery", {}):
		var m: Dictionary = d["mastery"][k]
		s.mastery[str(k)] = {"level": int(m.get("level", 1)), "xp": float(m.get("xp", 0.0)), "claimed": _int_array(m.get("claimed", []))}
	var st: Dictionary = d.get("story", {})
	s.story = {"done": (st.get("done", {}) as Dictionary).duplicate(true), "pending": str(st.get("pending", ""))}
	for k in d.get("relations", {}):
		s.relations[str(k)] = int(d["relations"][k])
	for tid in d.get("techniques", []):
		s.techniques.append(str(tid))
	s.main_technique = str(d.get("main_technique", ""))
	s.wounds = int(d.get("wounds", 0))
	for kid in d.get("knowledge", []):
		s.knowledge.append(str(kid))
	s.loop = int(d.get("loop", 0))
	var cp: Dictionary = d.get("checkpoint", {})
	if not cp.is_empty():
		# JSON gives back floats for ints; run the snapshot through the same normalisation as the live fields.
		var w := from_dict(cp.merged({"life": {"warned": cp.get("life_warned", false)}}))
		s.checkpoint = w.world_snapshot()
	var cb: Dictionary = d.get("combat", {})
	if not cb.is_empty():
		s.combat = {"dungeon": str(cb["dungeon"]), "paused": bool(cb.get("paused", false))}
		for k in ["tier", "pills", "index", "player_hp", "enemy_hp", "player_cd", "enemy_cd"]:
			s.combat[k] = int(cb.get(k, 0))
	var lr: Dictionary = d.get("last_run", {})
	if not lr.is_empty():
		s.last_run = {"dungeon": str(lr["dungeon"]), "result": str(lr["result"]), "depth": int(lr["depth"]), "cause": str(lr.get("cause", ""))}
	for k in d.get("dungeon_clears", {}):
		s.dungeon_clears[str(k)] = int(d["dungeon_clears"][k])
	for k in d.get("research_failures", {}):
		s.research_failures[str(k)] = int(d["research_failures"][k])
	var au: Dictionary = d.get("automation", {})
	if not au.is_empty():
		s.automation = {"slots": [], "cursor": int(au.get("cursor", 0)), "loop": bool(au.get("loop", false)),
			"status": str(au.get("status", "idle")), "reason": str(au.get("reason", "")), "instant_streak": int(au.get("instant_streak", 0))}
		for sl in au.get("slots", []):
			s.automation["slots"].append({"action": str(sl.get("action", "")), "repeat": int(sl.get("repeat", 1)),
				"on_block": str(sl.get("on_block", "skip")), "until": (sl.get("until", {}) as Dictionary).duplicate(true),
				"done": int(sl.get("done", 0))})
	return s


## World fields a checkpoint stores and a rewind restores. Everything else (story, knowledge, clock, rng, orphans, save
## metadata) is the character's own continuity and is never rewound.
const WORLD_KEYS: Array = ["resources", "upgrades", "flags", "action_counts", "mastery", "relations", "techniques",
		"main_technique", "wounds", "realm_id", "age_years", "breakthrough_failures", "life_warned"]


func world_snapshot() -> Dictionary:
	var snap: Dictionary = {}
	for k in WORLD_KEYS:
		snap[k] = life["warned"] if k == "life_warned" else get(k)
		if typeof(snap[k]) == TYPE_DICTIONARY or typeof(snap[k]) == TYPE_ARRAY:
			snap[k] = snap[k].duplicate(true)
	# A running action has already paid its costs; the snapshot is the world before it started, because restore drops it.
	for rid in active_action.get("costs_paid", {}):
		snap["resources"][rid] = float(snap["resources"].get(rid, 0.0)) + float(active_action["costs_paid"][rid])
	return snap


## Puts the world back to `snap`. The running action is dropped WITHOUT refunding its paid costs (the snapshot already
## holds the pre-payment world; refunding would add the old life's resources to it) and the automation queue is reset.
func restore_world(snap: Dictionary) -> void:
	for k in WORLD_KEYS:
		var v: Variant = snap[k]
		if typeof(v) == TYPE_DICTIONARY or typeof(v) == TYPE_ARRAY:
			v = v.duplicate(true)
		if k == "life_warned":
			life["warned"] = v
		else:
			set(k, v)
	active_action = {}
	combat = {}
	automation = GameState.new().automation.duplicate(true)


static func _int_array(a: Array) -> Array:
	var out: Array = []
	for v in a:
		out.append(int(v))
	return out
