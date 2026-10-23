extends GutTest
## V2 công pháp chủ tu + thương tích (GDD §6.4): only the main technique's bonuses apply, each build has a
## distinct trade-off, wounds hurt but never block progress, save v7.

const BUILDS: Array = ["thanh_moc_duong_khi", "huyet_luyen_than_kinh", "ngu_hanh_dan_khi"]

var act: ActionSystem
var s: GameState
var reg: ContentRegistry


func before_each() -> void:
	var w: Dictionary = TestHelpers.world(9, true)
	act = w["act"]
	s = w["state"]
	reg = act.registry
	s.flags["tutorial_started"] = true
	for id in reg.resources:
		s.resources[id] = float(reg.resources[id].get("initial", 0.0))
	act.effects.apply(s, [{"type": "learn_technique", "technique": "dan_khi_nhap_mon"}])
	for t in BUILDS:
		act.effects.apply(s, [{"type": "learn_technique", "technique": t}])


func _profile(tid: String) -> Dictionary:
	s.main_technique = tid
	return {
		"atk": act.effects.stat_bonus(s, "combat.atk"),
		"hp": act.effects.stat_bonus(s, "combat.hp"),
		"heal": act.effects.trait_total(s, "heal_bonus"),
		"injury": act.effects.trait_total(s, "injury_per_run"),
		"insight": reg.insight_total(s),
	}


func test_only_main_technique_bonuses_apply() -> void:
	assert_eq(act.effects.stat_bonus(s, "combat.atk"), 0.0, "known but not chosen: no bonus")
	assert_gt(act.effects.stat_bonus(s, "speed.absorb_qi"), 0.0, "the base technique always applies")
	var base_speed: float = act.effects.stat_bonus(s, "speed.absorb_qi")
	assert_gt(_profile("huyet_luyen_than_kinh")["atk"], 0.0)
	assert_eq(_profile("thanh_moc_duong_khi")["atk"], 0.0, "another main technique's attack bonus is off")
	assert_gt(act.effects.stat_bonus(s, "speed.absorb_qi"), base_speed)


func test_each_build_has_distinct_tradeoff() -> void:
	var p: Dictionary = {}
	for t in BUILDS:
		p[t] = _profile(t)
	assert_gt(p["huyet_luyen_than_kinh"]["atk"], p["thanh_moc_duong_khi"]["atk"])
	assert_gt(p["huyet_luyen_than_kinh"]["injury"], 0.0, "power costs a wound each run")
	assert_eq(p["thanh_moc_duong_khi"]["injury"], 0)
	assert_gt(p["thanh_moc_duong_khi"]["heal"], 0.0)
	assert_gt(p["thanh_moc_duong_khi"]["hp"], 0.0)
	assert_gt(p["ngu_hanh_dan_khi"]["insight"], p["thanh_moc_duong_khi"]["insight"])
	assert_gt(p["ngu_hanh_dan_khi"]["insight"], p["huyet_luyen_than_kinh"]["insight"])
	assert_eq(p["ngu_hanh_dan_khi"]["atk"], 0.0)


func test_set_main_technique_rules_and_switch_cost() -> void:
	assert_eq(act.set_main_technique(s, "nope")["reason"], "unknown_technique")
	assert_eq(act.set_main_technique(s, "dan_khi_nhap_mon")["reason"], "not_main_technique")
	var w: Dictionary = TestHelpers.world(1, true)
	assert_eq((w["act"] as ActionSystem).set_main_technique(w["state"], BUILDS[0])["reason"], "not_known")
	var age0: float = s.age_years
	assert_true(act.set_main_technique(s, BUILDS[0])["ok"])
	assert_eq(s.age_years, age0, "first choice is free")
	assert_eq(act.set_main_technique(s, BUILDS[0])["reason"], "already_main")
	assert_true(act.set_main_technique(s, BUILDS[1])["ok"])
	assert_almost_eq(s.age_years - age0, float(reg.config["technique"]["switch_age_years"]), 1e-6)
	act.enter_dungeon(s, "bamboo_forest")
	assert_eq(act.set_main_technique(s, BUILDS[2])["reason"], "in_dungeon")


func test_learn_actions_teach_each_build() -> void:
	var w: Dictionary = TestHelpers.world(2, true)
	var a: ActionSystem = w["act"]
	var st: GameState = w["state"]
	st.flags["tutorial_started"] = true
	st.realm_id = "luyen_khi_2"
	for rid in a.registry.resources:
		st.resources[rid] = 500.0
	a.effects.apply(st, [{"type": "learn_technique", "technique": "dan_khi_nhap_mon"}])
	for t in BUILDS:
		var aid: String = "learn_" + t
		assert_true(a.registry.actions.has(aid), aid)
		assert_true(a.start_action(st, aid)["ok"], aid)
		a.advance(st, 2)
		assert_true(st.techniques.has(t), t)
	assert_eq(a.start_action(st, "learn_" + BUILDS[0])["ok"], false, "learned once")


func test_wounds_from_defeat_and_from_huyet_luyen_runs() -> void:
	reg.config["combat"]["player"]["hp"] = 1
	act.enter_dungeon(s, "bamboo_forest")
	act.advance(s, 6000)
	assert_eq(s.wounds, 1, "defeat wounds the body")
	reg.config["combat"]["player"]["hp"] = 60
	s.wounds = 0
	s.main_technique = "huyet_luyen_than_kinh"
	act.enter_dungeon(s, "bamboo_forest")
	act.combat.retreat(s)
	assert_eq(s.wounds, 1, "Huyết Luyện wounds every run")
	s.main_technique = "thanh_moc_duong_khi"
	s.wounds = 0
	act.enter_dungeon(s, "bamboo_forest")
	act.combat.retreat(s)
	assert_eq(s.wounds, 0)
	act.enter_dungeon(s, "bamboo_forest")
	act.combat.abort(s)
	assert_eq(s.wounds, 0, "an aborted run (offline) never wounds")


func test_wounds_are_capped_and_cut_hp_but_never_block() -> void:
	var hp0: int = act.combat.player_stats(s)["hp"]
	act.combat.add_wounds(s, 99)
	var cap: int = int(reg.config["combat"]["max_wounds"])
	assert_eq(s.wounds, cap)
	assert_lt(act.combat.player_stats(s)["hp"], hp0)
	assert_gt(act.combat.player_stats(s)["hp"], 0)
	assert_true(act.enter_dungeon(s, "bamboo_forest")["ok"], "wounded characters can still go on")


func test_rest_heals_wounds_for_free_and_thanh_moc_heals_more() -> void:
	assert_false(act.start_action(s, "rest_heal")["ok"], "nothing to heal")
	s.wounds = 3
	var silver0: float = float(s.resources.get("silver", 0.0))
	assert_true(act.start_action(s, "rest_heal")["ok"])
	act.advance(s, 400)
	assert_eq(s.wounds, 2)
	assert_eq(float(s.resources.get("silver", 0.0)), silver0, "resting costs no resource")
	s.main_technique = "thanh_moc_duong_khi"
	assert_true(act.start_action(s, "rest_heal")["ok"])
	act.advance(s, 400)
	assert_eq(s.wounds, 0, "Thanh Mộc heals 1 extra")


func test_save_round_trip_and_validation() -> void:
	s.main_technique = BUILDS[1]
	s.wounds = 2
	var sm: Node = load("res://autoload/save_manager.gd").new()
	var parsed: Variant = JSON.parse_string(JSON.stringify(s.to_dict()))
	assert_eq(sm.validate_state(parsed, reg), [])
	assert_eq(GameState.from_dict(parsed).to_dict(), s.to_dict())
	for mut in [{"main_technique": "nope"}, {"main_technique": "dan_khi_nhap_mon"}, {"wounds": -1}, {"wounds": 99}, {"wounds": 1.5}]:
		var d: Dictionary = (parsed as Dictionary).duplicate(true)
		d.merge(mut, true)
		assert_false(sm.validate_state(d, reg).is_empty(), str(mut))
	var d2: Dictionary = (parsed as Dictionary).duplicate(true)
	d2["techniques"] = ["dan_khi_nhap_mon"]
	assert_false(sm.validate_state(d2, reg).is_empty(), "main technique must be a learned one")
	sm.free()


func test_v6_save_migrates_to_v7_including_checkpoint() -> void:
	var sm: Node = load("res://autoload/save_manager.gd").new()
	var old: Dictionary = s.to_dict()
	old.erase("main_technique")
	old.erase("wounds")
	old["schema_version"] = 6
	old["checkpoint"] = s.world_snapshot()
	(old["checkpoint"] as Dictionary).erase("main_technique")
	(old["checkpoint"] as Dictionary).erase("wounds")
	var m: Dictionary = sm.migrate(old)
	assert_eq(m["schema_version"], GameState.SCHEMA_VERSION)
	assert_eq(m["main_technique"], "")
	assert_eq(m["wounds"], 0)
	assert_eq(sm.validate_state(m, reg), [])
	sm.free()


func test_checkpoint_and_rewind_carry_build_and_wounds() -> void:
	s.main_technique = BUILDS[0]
	s.wounds = 1
	var snap: Dictionary = s.world_snapshot()
	assert_eq(snap["main_technique"], BUILDS[0])
	s.wounds = 4
	s.restore_world(snap)
	assert_eq(s.wounds, 1)


func test_content_validation_rejects_bad_traits() -> void:
	var r := TestHelpers.real_registry()
	r.techniques["huyet_luyen_than_kinh"]["traits"] = {"bogus": 1}
	r.errors.clear()
	r.validate()
	assert_string_contains(str(r.errors), "bogus")
	r = TestHelpers.real_registry()
	r.techniques["huyet_luyen_than_kinh"]["role"] = "weird"
	r.errors.clear()
	r.validate()
	assert_false(r.errors.is_empty())
