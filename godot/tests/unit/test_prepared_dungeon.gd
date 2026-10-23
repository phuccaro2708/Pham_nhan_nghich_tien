extends GutTest
## V3 thám hiểm có chuẩn bị: tầng, tạm dừng chờ lệnh người chơi, thuốc hồi phục, ghi nhận lần chạy, save v8.

const CAVE: String = "black_rock_cave"
const MAX_TICKS: int = 20000

var act: ActionSystem
var s: GameState
var reg: ContentRegistry


func before_each() -> void:
	var w: Dictionary = TestHelpers.world(31, true)
	act = w["act"]
	s = w["state"]
	reg = act.registry
	s.flags["tutorial_started"] = true
	s.flags["bamboo_forest_cleared"] = true
	s.realm_id = "luyen_khi_3"
	for id in reg.resources:
		s.resources[id] = float(reg.resources[id].get("initial", 0.0))


func _strong() -> void:
	reg.config["combat"]["player"]["atk"] = 1000
	reg.config["combat"]["player"]["hp"] = 100000


func _until_paused() -> void:
	for i in MAX_TICKS:
		if s.combat.is_empty() or s.combat.get("paused", false):
			return
		act.advance(s, 1)


func test_dungeon_tiers_are_data() -> void:
	assert_eq(reg.dungeon_tiers(CAVE).size(), 3)
	assert_eq(reg.dungeon_tiers("bamboo_forest").size(), 1, "a flat enemy list is one tier")
	var t: Array = reg.dungeon_tiers(CAVE)
	assert_gt(float(t[2]["enemy_scale"]), float(t[0]["enemy_scale"]))
	assert_gt(float(t[2]["loot_mult"]), float(t[0]["loot_mult"]))


func test_entry_needs_progress_and_realm() -> void:
	s.flags.erase("bamboo_forest_cleared")
	assert_eq(act.enter_dungeon(s, CAVE)["reason"], "not_discovered")
	s.flags["bamboo_forest_cleared"] = true
	s.realm_id = "cam_khi"
	assert_eq(act.enter_dungeon(s, CAVE)["reason"], "requirements_not_met")


func test_deeper_tier_raises_yield_and_risk() -> void:
	var e0: Dictionary = act.combat.enemy_at(CAVE, 0, 0)
	var e2: Dictionary = act.combat.enemy_at(CAVE, 2, 0)
	assert_gt(int(e2["hp"]), int(e0["hp"]))
	assert_gt(float(e2["atk"]), 0.0)
	_strong()
	act.enter_dungeon(s, CAVE)
	var silver0: float = float(s.resources["silver"])
	_until_paused()
	var gain0: float = float(s.resources["silver"]) - silver0
	act.continue_run(s)
	var silver1: float = float(s.resources["silver"])
	_until_paused()
	var gain1: float = float(s.resources["silver"]) - silver1
	assert_gt(gain1, gain0, "deeper tiers pay more")


func test_run_pauses_for_the_player_and_offline_never_decides() -> void:
	_strong()
	act.enter_dungeon(s, CAVE)
	_until_paused()
	assert_true(s.combat["paused"])
	var tier: int = s.combat["tier"]
	var age: float = s.age_years
	act.advance(s, 2000)
	assert_eq(s.combat["tier"], tier)
	assert_eq(s.age_years, age, "waiting costs no life")
	assert_eq(act.start_action(s, "gather_wood")["reason"], "in_dungeon")
	var silver: float = float(s.resources["silver"])
	OfflineSystem.apply(s, act, 3600.0)
	assert_true(s.combat.is_empty())
	assert_eq(s.age_years, age)
	assert_eq(float(s.resources["silver"]), silver, "loot already earned is kept")
	assert_false(s.flags.has("black_rock_cleared"))


func test_leave_run_keeps_loot_and_charges_age() -> void:
	_strong()
	act.enter_dungeon(s, CAVE)
	_until_paused()
	var silver: float = float(s.resources["silver"])
	var age: float = s.age_years
	assert_true(act.leave_run(s)["ok"])
	assert_true(s.combat.is_empty())
	assert_eq(float(s.resources["silver"]), silver)
	var def: Dictionary = reg.dungeons[CAVE]
	assert_almost_eq(s.age_years - age, float(def["age_cost_years"]) + float(def["tier_age_years"]), 1e-6)
	assert_eq(s.last_run["result"], "left")
	assert_eq(s.last_run["depth"], 1)
	assert_false(s.dungeon_clears.has(CAVE))
	assert_eq(act.leave_run(s)["reason"], "not_paused")


func test_continue_needs_a_pause() -> void:
	_strong()
	act.enter_dungeon(s, CAVE)
	assert_eq(act.continue_run(s)["reason"], "not_paused")
	assert_eq(act.leave_run(s)["reason"], "not_paused", "mid-fight you retreat, not leave")


func test_full_clear_pays_once_and_records_the_run() -> void:
	_strong()
	act.enter_dungeon(s, CAVE)
	for i in 5:
		_until_paused()
		if s.combat.is_empty():
			break
		assert_true(act.continue_run(s)["ok"])
	assert_true(s.combat.is_empty())
	assert_true(s.flags["black_rock_cleared"])
	assert_eq(int(s.dungeon_clears[CAVE]), 1)
	assert_eq(s.last_run["result"], "cleared")
	assert_eq(s.last_run["depth"], 3)
	var snap: Dictionary = s.to_dict()
	act.advance(s, 600)
	assert_eq(s.resources, snap["resources"])
	assert_eq(int(s.dungeon_clears[CAVE]), 1)


func test_pills_are_consumed_on_entry_and_validated() -> void:
	s.resources["healing_pill"] = 3.0
	assert_eq(act.enter_dungeon(s, CAVE, {"pills": 4})["reason"], "no_pills")
	assert_eq(act.enter_dungeon(s, CAVE, {"pills": 99})["reason"], "too_many_pills")
	assert_eq(float(s.resources["healing_pill"]), 3.0, "a refused entry costs nothing")
	assert_true(act.enter_dungeon(s, CAVE, {"pills": 2})["ok"])
	assert_eq(float(s.resources["healing_pill"]), 1.0)
	assert_eq(s.combat["pills"], 2)


func test_a_pill_is_drunk_when_hp_is_low() -> void:
	s.resources["healing_pill"] = 2.0
	act.enter_dungeon(s, CAVE, {"pills": 2})
	var max_hp: int = int(act.combat.player_stats(s)["hp"])
	s.combat["player_hp"] = 5
	s.combat["enemy_cd"] = 9999
	act.combat.step(s)
	assert_eq(s.combat["pills"], 1)
	assert_gt(int(s.combat["player_hp"]), 5)
	assert_lte(int(s.combat["player_hp"]), max_hp)


func test_defeat_records_cause_and_wounds() -> void:
	reg.config["combat"]["player"]["hp"] = 1
	act.enter_dungeon(s, CAVE)
	act.advance(s, MAX_TICKS)
	assert_eq(s.last_run["result"], "defeated")
	assert_eq(s.last_run["cause"], "out_of_pills")
	assert_eq(s.wounds, 1)
	s.wounds = 3
	s.story["pending"] = ""  # an unrelated story event may have fired after the first defeat
	act.enter_dungeon(s, CAVE)
	act.advance(s, MAX_TICKS)
	assert_eq(s.last_run["cause"], "wounded")


func test_run_is_deterministic_with_prep() -> void:
	var w2: Dictionary = TestHelpers.world(31, true)
	var b: GameState = w2["state"]
	b.flags = s.flags.duplicate()
	b.realm_id = s.realm_id
	b.resources = s.resources.duplicate()
	s.resources["healing_pill"] = 3.0
	b.resources["healing_pill"] = 3.0
	act.enter_dungeon(s, CAVE, {"pills": 3})
	(w2["act"] as ActionSystem).enter_dungeon(b, CAVE, {"pills": 3})
	for i in 3000:
		act.advance(s, 1)
		if s.combat.get("paused", false):
			act.leave_run(s)
	for i in 3000:
		(w2["act"] as ActionSystem).advance(b, 1)
		if b.combat.get("paused", false):
			(w2["act"] as ActionSystem).leave_run(b)
	assert_eq(b.to_dict(), s.to_dict())


func test_preparation_changes_the_outcome() -> void:
	var wins_bare: int = 0
	var wins_ready: int = 0
	for seed_value in range(1, 21):
		for pills in [0, 5]:
			var w: Dictionary = TestHelpers.world(seed_value, true)
			var a: ActionSystem = w["act"]
			var st: GameState = w["state"]
			st.flags["bamboo_forest_cleared"] = true
			st.realm_id = "luyen_khi_3"
			st.resources["healing_pill"] = 5.0
			a.enter_dungeon(st, CAVE, {"pills": pills})
			for i in 30000:
				if st.combat.is_empty():
					break
				if st.combat.get("paused", false):
					a.continue_run(st)
				a.advance(st, 1)
			var won: int = 1 if st.dungeon_clears.has(CAVE) else 0
			if pills == 0:
				wins_bare += won
			else:
				wins_ready += won
	assert_gt(wins_ready, wins_bare, "pills must matter (bare %d, ready %d of 20)" % [wins_bare, wins_ready])
	assert_gt(wins_ready, 3, "a prepared character can clear it (%d/20)" % wins_ready)
	assert_lt(wins_bare, 20, "going in bare is not a sure thing")


func test_brew_pill_turns_herbs_into_pills() -> void:
	s.resources["herb"] = 10.0
	assert_true(act.start_action(s, "brew_pill")["ok"])
	act.advance(s, 400)
	assert_eq(float(s.resources["healing_pill"]), 1.0)
	assert_lt(float(s.resources["herb"]), 10.0)


func test_save_round_trip_while_paused_and_validation() -> void:
	_strong()
	s.resources["healing_pill"] = 2.0
	act.enter_dungeon(s, CAVE, {"pills": 1})
	_until_paused()
	var sm: Node = load("res://autoload/save_manager.gd").new()
	var parsed: Variant = JSON.parse_string(JSON.stringify(s.to_dict()))
	assert_eq(sm.validate_state(parsed, reg), [])
	var b: GameState = GameState.from_dict(parsed)
	assert_eq(b.to_dict(), s.to_dict())
	for mut in [{"tier": 9}, {"tier": -1}, {"pills": 99}, {"pills": -1}, {"index": 0}]:
		var d: Dictionary = (parsed as Dictionary).duplicate(true)
		d["combat"].merge(mut, true)
		assert_false(sm.validate_state(d, reg).is_empty(), str(mut))
	var d2: Dictionary = (parsed as Dictionary).duplicate(true)
	d2["last_run"] = {"dungeon": "nope", "result": "cleared", "depth": 1, "cause": ""}
	assert_false(sm.validate_state(d2, reg).is_empty())
	d2["last_run"] = {"dungeon": CAVE, "result": "cleared", "depth": 9, "cause": ""}
	assert_false(sm.validate_state(d2, reg).is_empty())
	sm.free()


func test_v7_save_migrates_to_v8() -> void:
	var sm: Node = load("res://autoload/save_manager.gd").new()
	var old: Dictionary = s.to_dict()
	old.erase("last_run")
	old["schema_version"] = 7
	old["combat"] = {"dungeon": "bamboo_forest", "index": 0, "player_hp": 50, "enemy_hp": 10, "player_cd": 5, "enemy_cd": 5}
	var m: Dictionary = sm.migrate(old)
	assert_eq(m["schema_version"], GameState.SCHEMA_VERSION)
	assert_eq(m["last_run"], {})
	assert_eq(m["combat"]["tier"], 0)
	assert_eq(m["combat"]["paused"], false)
	assert_eq(m["combat"]["pills"], 0)
	assert_eq(sm.validate_state(m, reg), [])
	sm.free()


func test_content_validation_rejects_bad_tiers() -> void:
	var r := TestHelpers.real_registry()
	r.dungeons[CAVE]["tiers"][1]["enemies"] = ["nope"]
	r.errors.clear()
	r.validate()
	assert_string_contains(str(r.errors), "nope")
	r = TestHelpers.real_registry()
	r.dungeons[CAVE]["tiers"][0]["loot_mult"] = -1
	r.errors.clear()
	r.validate()
	assert_false(r.errors.is_empty())
