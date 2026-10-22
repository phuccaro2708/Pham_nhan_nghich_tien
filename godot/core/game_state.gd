class_name GameState
extends RefCounted
## Pure runtime data. No Node references, no behaviour beyond (de)serialisation.

const SCHEMA_VERSION: int = 2
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
	s.save_metadata = {"saved_at_unix": int((d.get("save_metadata", {}) as Dictionary).get("saved_at_unix", 0))}
	s.content_version = int(d.get("content_version", 1))
	s.realm_id = str(d.get("realm_id", ""))
	s.breakthrough_failures = int(d.get("breakthrough_failures", 0))
	var lf: Dictionary = d.get("life", {})
	s.life = {"status": str(lf.get("status", "alive")), "warned": bool(lf.get("warned", false)),
		"ended": (lf.get("ended", {}) as Dictionary).duplicate(true)}
	s.orphans = (d.get("orphans", {}) as Dictionary).duplicate(true)
	return s
