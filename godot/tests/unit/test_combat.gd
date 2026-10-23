extends GutTest
## Dungeon / auto-combat (GDD VIII): entry rules, determinism, one-time rewards, save v6, offline.

const DUNGEON: String = "bamboo_forest"
const MAX_RUN_TICKS: int = 6000

var act: ActionSystem
var s: GameState
var reg: ContentRegistry


func before_each() -> void:
	var w: Dictionary = TestHelpers.world(21, true)
	act = w["act"]
	s = w["state"]
	reg = act.registry
	s.flags["tutorial_started"] = true
	for id in reg.resources:
		s.resources[id] = float(reg.resources[id].get("initial", 0.0))


func _strong() -> void:
	reg.config["combat"]["player"]["atk"] = 1000  # a registry copy private to this test


func test_entry_needs_discovery() -> void:
	var w: Dictionary = TestHelpers.world(3, false)
	var a: ActionSystem = w["act"]
	assert_eq(a.enter_dungeon(w["state"], DUNGEON)["reason"], "not_discovered")
	assert_true(act.enter_dungeon(s, DUNGEON)["ok"])
	assert_eq(act.enter_dungeon(s, DUNGEON)["reason"], "in_dungeon")
	assert_eq(act.enter_dungeon(s, "nope")["reason"], "unknown_dungeon")


func test_entering_stops_the_running_action_and_blocks_new_ones() -> void:
	act.start_action(s, "gather_wood")
	act.advance(s, 3)
	assert_true(act.enter_dungeon(s, DUNGEON)["ok"])
	assert_true(s.active_action.is_empty())
	assert_eq(act.start_action(s, "gather_wood")["reason"], "in_dungeon")


func test_run_is_deterministic_and_stays_valid() -> void:
	var w2: Dictionary = TestHelpers.world(21, true)
	var b: GameState = w2["state"]
	b.flags["tutorial_started"] = true
	b.resources = s.resources.duplicate()
	act.enter_dungeon(s, DUNGEON)
	(w2["act"] as ActionSystem).enter_dungeon(b, DUNGEON)
	for i in MAX_RUN_TICKS:
		if s.combat.is_empty():
			break
		act.advance(s, 1)
		assert_true(int(s.combat.get("player_hp", 1)) >= 0 and int(s.combat.get("enemy_hp", 1)) >= 0)
	(w2["act"] as ActionSystem).advance(b, s.game_time_ticks)
	assert_true(s.combat.is_empty(), "a run always ends")
	assert_eq(b.to_dict(), s.to_dict())


func test_clear_pays_each_reward_once() -> void:
	_strong()
	var herb0: float = float(s.resources.get("herb", 0.0))
	var age0: float = s.age_years
	act.enter_dungeon(s, DUNGEON)
	act.advance(s, MAX_RUN_TICKS)
	assert_eq(int(s.dungeon_clears[DUNGEON]), 1)
	assert_true(s.flags["bamboo_forest_cleared"])
	assert_eq(float(s.resources["herb"]) - herb0, 3.0 + 5.0)  # snake loot + clear reward
	assert_almost_eq(s.age_years - age0, 0.02, 1e-6)
	var snap: Dictionary = s.to_dict()
	act.advance(s, 500)
	assert_eq(s.resources, snap["resources"])
	assert_eq(int(s.dungeon_clears[DUNGEON]), 1)


func test_defeat_and_retreat_cost_age_but_give_no_clear_reward() -> void:
	reg.config["combat"]["player"]["hp"] = 1
	act.enter_dungeon(s, DUNGEON)
	act.advance(s, MAX_RUN_TICKS)
	assert_true(s.combat.is_empty())
	assert_false(s.dungeon_clears.has(DUNGEON))
	assert_false(s.flags.has("bamboo_forest_cleared"))
	assert_almost_eq(s.age_years, GameState.START_AGE_YEARS + 0.02, 1e-6)
	act.enter_dungeon(s, DUNGEON)
	act.combat.retreat(s)
	assert_almost_eq(s.age_years, GameState.START_AGE_YEARS + 0.04, 1e-6)


func test_base_character_can_clear_the_first_dungeon() -> void:
	var wins: int = 0
	for seed_value in range(1, 21):
		var w: Dictionary = TestHelpers.world(seed_value, true)
		var st: GameState = w["state"]
		var a: ActionSystem = w["act"]
		a.enter_dungeon(st, DUNGEON)
		a.advance(st, MAX_RUN_TICKS)
		wins += st.dungeon_clears.get(DUNGEON, 0)
	assert_true(wins >= 8 and wins <= 19, "base win rate should be neither hopeless nor certain, got %d/20" % wins)


func test_save_round_trip_mid_run_continues_identically() -> void:
	act.enter_dungeon(s, DUNGEON)
	act.advance(s, 25)
	assert_false(s.combat.is_empty())
	var sm: Node = load("res://autoload/save_manager.gd").new()
	var parsed: Variant = JSON.parse_string(JSON.stringify(s.to_dict()))
	assert_eq(sm.validate_state(parsed, reg), [])
	var b: GameState = GameState.from_dict(parsed)
	sm.free()
	act.advance(s, 400)
	act.advance(b, 400)
	assert_eq(b.to_dict(), s.to_dict())


func test_save_validation_rejects_bad_combat() -> void:
	var sm: Node = load("res://autoload/save_manager.gd").new()
	act.enter_dungeon(s, DUNGEON)
	var good: Dictionary = s.to_dict()
	for mut in [{"dungeon": "nope"}, {"index": 9}, {"player_hp": 0}, {"enemy_hp": 999}, {"player_cd": 0}]:
		var d: Dictionary = good.duplicate(true)
		d["combat"].merge(mut, true)
		assert_false(sm.validate_state(d, reg).is_empty(), str(mut))
	var d2: Dictionary = good.duplicate(true)
	d2["dungeon_clears"] = {"nope": -1}
	assert_false(sm.validate_state(d2, reg).is_empty())
	sm.free()


func test_v5_save_migrates_to_v6() -> void:
	var sm: Node = load("res://autoload/save_manager.gd").new()
	var old: Dictionary = GameState.new_game().to_dict()
	old.erase("combat")
	old.erase("dungeon_clears")
	old["schema_version"] = 5
	var m: Dictionary = sm.migrate(old)
	assert_eq(m["schema_version"], 6)
	assert_eq(m["combat"], {})
	assert_eq(m["dungeon_clears"], {})
	sm.free()


func test_offline_drops_a_run_without_cost() -> void:
	act.enter_dungeon(s, DUNGEON)
	act.advance(s, 15)
	var age: float = s.age_years
	OfflineSystem.apply(s, act, 600.0)
	assert_true(s.combat.is_empty())
	assert_eq(s.age_years, age)
	assert_false(s.dungeon_clears.has(DUNGEON))


func test_stats_scale_with_realm_and_technique_bonus() -> void:
	var base_hp: int = act.combat.player_stats(s)["hp"]
	reg.techniques["t_test"] = {"id": "t_test", "bonuses": [{"stat": "combat.atk", "value": 10}, {"stat": "combat.spd", "value": -1000}]}
	var atk0: float = act.combat.player_stats(s)["atk"]
	s.techniques.append("t_test")
	var ps: Dictionary = act.combat.player_stats(s)
	assert_eq(ps["atk"], atk0 + 10.0)
	assert_true(ps["spd"] > 0.0, "a negative speed bonus is clamped")
	assert_true(act.combat.interval_ticks(ps["spd"]) >= 1)
	s.realm_id = reg.realm_order[1]
	assert_true(act.combat.player_stats(s)["hp"] > base_hp, "a higher realm stage grows hp")


func test_entering_stops_a_running_automation_queue() -> void:
	s.mastery["gather_wood"] = {"level": 3, "xp": 0.0, "claimed": []}
	s.story["done"]["ch1_morning_smoke"] = "ignore"
	assert_true(act.automation.set_slots(s, [{"action": "gather_wood", "repeat": 0, "on_block": "skip"}])["ok"])
	act.automation.start(s)
	act.advance(s, 2)
	assert_true(act.enter_dungeon(s, DUNGEON)["ok"])
	act.advance(s, 3)
	assert_true(s.active_action.is_empty(), "the queue does not start actions during a run")
	assert_false(s.combat.is_empty())


func test_rewind_ends_the_run_through_the_normal_path() -> void:
	s.checkpoint = s.world_snapshot()
	act.enter_dungeon(s, DUNGEON)
	var res: Array = []
	act.combat.run_ended.connect(func(_d: String, r: String) -> void: res.append(r))
	act.effects.apply(s, [{"type": "rewind"}])
	assert_true(s.combat.is_empty())
	assert_eq(res, ["aborted"])


func test_player_hp_above_maximum_is_clamped_and_unknown_dungeon_clears_load() -> void:
	act.enter_dungeon(s, DUNGEON)
	s.combat["player_hp"] = 999999
	s.combat["enemy_cd"] = 1
	act.advance(s, 1)
	assert_true(s.combat.is_empty() or int(s.combat["player_hp"]) <= act.combat.player_stats(s)["hp"])
	var sm: Node = load("res://autoload/save_manager.gd").new()
	s.combat = {}
	s.dungeon_clears["gone_dungeon"] = 2
	assert_eq(sm.validate_state(s.to_dict(), reg), [])
	sm.free()
