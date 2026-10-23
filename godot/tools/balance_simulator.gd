class_name BalanceSimulator
extends RefCounted
## Headless balance simulator (GDD §15.2 / §11.3). Plays a whole life with a scripted strategy through the
## same commands the UI uses (ActionSystem), so what it measures is what a player gets.
## Strategies: casual (looks at the screen every CHECK seconds, manual play), optimizer (reacts at once),
## idle (short sessions, then away for the 8 h offline cap through OfflineSystem).

const STRATEGIES: Array = ["casual", "optimizer", "idle"]
const TPS: int = SimulationClock.TICKS_PER_SECOND
## Casual attention span: how long a loop may run before the player looks again.
const CASUAL_CHECK_SECONDS: float = 30.0
## Idle: one active session, then away. Offline time is wall-clock but not "active" time.
const IDLE_SESSION_SECONDS: float = 300.0
const MAX_ACTIVE_HOURS: float = 40.0
const MILESTONES: Array = ["first_upgrade", "luyen_khi_1", "luyen_khi_5", "luyen_khi_9", "truc_co_so"]

var registry: ContentRegistry


func _init(p_registry: ContentRegistry = null) -> void:
	registry = p_registry if p_registry != null else _load_registry()


static func _load_registry() -> ContentRegistry:
	var r := ContentRegistry.new()
	r.load_all()
	return r


## Plays one life. Returns a plain Dictionary (see _result).
func run(strategy: String, seed_value: int, main: String = "", explore: bool = false) -> Dictionary:
	var act := ActionSystem.new(registry)
	var s := GameState.new_game(seed_value)
	for id in registry.resources:
		s.resources[id] = float(registry.resources[id].get("initial", 0.0))
	s.content_version = registry.content_version
	var m := {
		"active_ticks": 0, "offline_ticks": 0, "idle_ticks": 0, "by_action": {}, "milestones": {},
		"failed_breakthroughs": 0, "burned": {}, "decisions": 0, "blocked": {}, "stuck": false,
		"dungeon_attempts": 0, "research_attempts": 0, "wounds_at_breakthrough": -1,
	}
	act.realms.breakthrough_resolved.connect(func(ok: bool, _from: String, _to: String) -> void:
		if ok:
			return
		m["failed_breakthroughs"] += 1
		for rid in m.get("_cost", {}):  # net of on_fail_refund (cost handed back by EffectResolver)
			var kept: float = 1.0 - float(m.get("_refund", {}).get(rid, 0.0))
			m["burned"][rid] = float(m["burned"].get(rid, 0.0)) + float(m["_cost"][rid]) * kept)
	act.action_stopped.connect(func(_id: String, why: String) -> void: m["blocked"][why] = int(m["blocked"].get(why, 0)) + 1)
	var limit_ticks: int = int(MAX_ACTIVE_HOURS * 3600.0 * TPS)
	var session_ticks: int = 0
	while m["active_ticks"] < limit_ticks and s.realm_id != "truc_co_so" and act.lifespan.is_alive(s):
		m["decisions"] += 1
		_mark(m, act, s)
		var before_tick: int = s.game_time_ticks
		resolve_story(act, s, main)
		if main != "" and s.techniques.has(main) and s.main_technique != main:
			act.set_main_technique(s, main)
		if explore and s.knowledge.has("flaw_dan_khi") and not s.techniques.has("dan_khi_on_dinh") and s.resources.get("technique_fragment", 0.0) >= 3.0 and s.resources.get("silver", 0.0) >= 20.0:
			m["research_attempts"] += 1
			act.research(s, "fix_stable")
		if explore and _prepare_exploration(act, s, m):
			continue
		var id: String = policy(act, s, main, explore)
		if id == "breakthrough" and s.realm_id == "luyen_khi_9":
			m["wounds_at_breakthrough"] = s.wounds
			if not m.has("first_chance"):
				m["first_chance"] = act.realms.success_chance(s)
		if id != "" and (s.active_action.is_empty() or str(s.active_action["id"]) != id):
			var bt: bool = registry.actions[id].get("breakthrough", false)
			m["_cost"] = act.realms.breakthrough_costs(s).duplicate() if bt else {}
			m["_refund"] = act.realms.breakthrough_def(s).get("on_fail_refund", {}) if bt else {}
			var r: Dictionary = act.start_action(s, id)
			if not r["ok"] and s.active_action.is_empty():
				m["stuck"] = true
				m["stuck_reason"] = "%s: %s" % [id, r["reason"]]
				break
		var step: int = _step_ticks(strategy, act, s)
		if step <= 0:
			if registry.actions.get(id, {}).get("type", "") == "INSTANT":
				continue  # instant actions resolve inside start_action; decide again
			m["stuck"] = true
			break
		_advance(m, act, s, step)
		session_ticks += s.game_time_ticks - before_tick
		if strategy == "idle" and session_ticks >= int(IDLE_SESSION_SECONDS * TPS):
			session_ticks = 0
			_go_away(m, act, s)
	_mark(m, act, s)
	var result: Dictionary = _result(strategy, seed_value, s, m)
	result.merge({"main": main, "explore": explore, "dungeon_attempts": m["dungeon_attempts"],
		"research_attempts": m["research_attempts"], "wounds_at_breakthrough": m["wounds_at_breakthrough"],
		"first_chance": m.get("first_chance", -1.0),
		"actual_main": s.main_technique, "techniques": s.techniques.duplicate(),
		"cave_cleared": s.dungeon_clears.has("black_rock_cave"),
		"echo": s.story["done"].get("ch6_rock_echo", ""), "variant": s.techniques.has("dan_khi_on_dinh")})
	return result


func _prepare_exploration(act: ActionSystem, s: GameState, m: Dictionary) -> bool:
	if not s.combat.is_empty():
		if act.combat.is_paused(s):
			act.continue_run(s)
		else:
			_advance(m, act, s, 1)
		return true
	if s.wounds > 0:
		return false  # policy heals before the next expedition
	if act.registry.realm_index(s.realm_id) < act.registry.realm_index("luyen_khi_5"):
		return false
	var dungeon: String = "bamboo_forest" if not s.dungeon_clears.has("bamboo_forest") else "black_rock_cave"
	if dungeon == "black_rock_cave" and not _needs_cave(s):
		return false
	if not act.combat.check_enter(s, dungeon)["ok"]:
		return false
	if dungeon == "black_rock_cave" and s.resources.get("healing_pill", 0.0) < 5.0:
		return false  # policy gathers herbs and brews five pills
	if act.enter_dungeon(s, dungeon, {"pills": 5 if dungeon == "black_rock_cave" else 0})["ok"]:
		m["dungeon_attempts"] += 1
	return true


static func _needs_cave(s: GameState) -> bool:
	if not s.dungeon_clears.has("black_rock_cave"):
		return true
	if s.techniques.has("dan_khi_on_dinh"):
		return false
	return s.resources.get("technique_fragment", 0.0) < (3.0 if s.knowledge.has("flaw_dan_khi") else 2.0)


func _mark(m: Dictionary, act: ActionSystem, s: GameState) -> void:
	var ms: Dictionary = m["milestones"]
	var t: float = float(m["active_ticks"]) / TPS
	if not ms.has("first_upgrade") and not s.upgrades.is_empty():
		ms["first_upgrade"] = t
	if not ms.has("luyen_khi_1") and registry.realm_index(s.realm_id) >= registry.realm_index("luyen_khi_1"):
		ms["luyen_khi_1"] = t
	if not ms.has("luyen_khi_5") and registry.realm_index(s.realm_id) >= registry.realm_index("luyen_khi_5"):
		ms["luyen_khi_5"] = t
	if not ms.has("luyen_khi_9") and registry.realm_index(s.realm_id) >= registry.realm_index("luyen_khi_9"):
		ms["luyen_khi_9"] = t
	if not ms.has("truc_co_so") and s.realm_id == "truc_co_so":
		ms["truc_co_so"] = t


## Seconds of simulation until the strategy looks at the game again.
func _step_ticks(strategy: String, act: ActionSystem, s: GameState) -> int:
	if s.active_action.is_empty():
		return 0
	var left: int = int(s.active_action["duration_ticks"]) - int(s.active_action["progress_ticks"])
	if strategy == "casual":
		return maxi(left, int(CASUAL_CHECK_SECONDS * TPS))
	return maxi(left, 1)


## Advances time and attributes it to the running action. Tracks burned breakthrough costs.
func _advance(m: Dictionary, act: ActionSystem, s: GameState, ticks: int) -> void:
	var remaining: int = ticks
	while remaining > 0:
		var id: String = "idle" if s.active_action.is_empty() else str(s.active_action["id"])
		var chunk: int = remaining
		if not s.active_action.is_empty():
			chunk = mini(remaining, maxi(int(s.active_action["duration_ticks"]) - int(s.active_action["progress_ticks"]), 1))
		var t0: int = s.game_time_ticks
		act.advance(s, chunk)
		var dt: int = s.game_time_ticks - t0
		if dt <= 0:
			break
		m["by_action"][id] = int(m["by_action"].get(id, 0)) + dt
		m["active_ticks"] += dt
		remaining -= dt


func _go_away(m: Dictionary, act: ActionSystem, s: GameState) -> void:
	var before: int = s.game_time_ticks
	OfflineSystem.apply(s, act, SimulationClock.MAX_OFFLINE_SECONDS)
	m["offline_ticks"] += s.game_time_ticks - before


## Picks the first affordable choice of every pending story event (a deliberately uncreative player).
static func resolve_story(act: ActionSystem, s: GameState, main: String = "") -> void:
	while act.story.pending(s) != "":
		var picked: bool = false
		var node: String = act.story.pending(s)
		var choices: Array = act.registry.story[node]["choices"].duplicate()
		var preferred: String = ""
		if main == "ngu_hanh_dan_khi" and node == "ch1_mountain_incident":
			preferred = "watch_hunter"
		elif main == "ngu_hanh_dan_khi" and node == "ch1_return":
			preferred = "trace_hunter"
		for c in choices:
			if c["id"] == preferred:
				choices.erase(c)
				choices.push_front(c)
				break
		for c in choices:
			if act.story.choose(s, c["id"])["ok"]:
				picked = true
				break
		if not picked:
			return


static func policy(act: ActionSystem, s: GameState, main: String = "", explore: bool = false) -> String:
	if s.wounds > 0:
		return "rest_heal"
	if main != "" and s.techniques.has("dan_khi_nhap_mon") and not s.techniques.has(main) and act.registry.realm_index(s.realm_id) >= act.registry.realm_index("luyen_khi_2"):
		var learn: String = "learn_" + main
		if act.check_can_start(s, learn)["ok"]:
			return learn
		if s.resources.get("herb", 0.0) < act.registry.actions[learn].get("costs", {}).get("herb", 0):
			return "gather_herbs"
		if s.resources.get("silver", 0.0) < act.registry.actions[learn].get("costs", {}).get("silver", 0):
			return _earn_silver(act, s)
	if explore and s.dungeon_clears.has("bamboo_forest") and act.registry.realm_index(s.realm_id) >= act.registry.realm_index("luyen_khi_5") and _needs_cave(s):
		if s.resources.get("healing_pill", 0.0) < 5.0:
			return "gather_herbs" if s.resources.get("herb", 0.0) < 2.0 else "brew_pill"
	if explore and s.dungeon_clears.has("black_rock_cave") and not s.knowledge.has("flaw_dan_khi") and act.check_can_start(s, "study_flaw")["ok"]:
		return "study_flaw"
	if explore and s.knowledge.has("flaw_dan_khi") and not s.techniques.has("dan_khi_on_dinh") and s.resources.get("technique_fragment", 0.0) >= 3.0 and s.resources.get("silver", 0.0) < 20.0:
		return _earn_silver(act, s)
	if act.check_can_start(s, "breakthrough")["ok"]:
		return "breakthrough"
	if s.flags.get("meridian_damaged", false):
		if s.resources.get("silver", 0.0) >= 50.0:
			return "treat_meridian"
		return _earn_silver(act, s)
	var herb: float = s.resources.get("herb", 0.0)
	if s.realm_id == "cam_khi" and not s.flags.get("qi_sensed", false):
		if act.check_can_start(s, "sense_qi")["ok"]:
			return "sense_qi"
		if herb < 3.0 and act.check_can_start(s, "gather_herbs")["ok"]:
			return "gather_herbs"
	if not s.techniques.has("dan_khi_nhap_mon") and act.registry.realm_index(s.realm_id) >= act.registry.realm_index("luyen_khi_1"):
		if act.check_can_start(s, "learn_dan_khi")["ok"]:
			return "learn_dan_khi"
		if herb < 2.0 and act.check_can_start(s, "gather_herbs")["ok"]:
			return "gather_herbs"
	var cost: Dictionary = act.realms.breakthrough_costs(s)
	for rid in cost:
		if s.resources.get(rid, 0.0) < cost[rid]:
			match rid:
				"body": return "train_body"
				"silver": return _earn_silver(act, s)
				"cultivation": return "refine_qi" if s.resources.get("spirit_qi", 0.0) >= 8.0 else "absorb_qi"
	return "gather_wood"


static func _earn_silver(_act: ActionSystem, s: GameState) -> String:
	if s.resources.get("wood", 0.0) >= 10.0:
		return "sell_wood"
	return "gather_wood"


func _result(strategy: String, seed_value: int, s: GameState, m: Dictionary) -> Dictionary:
	var by: Dictionary = {}
	for id in m["by_action"]:
		by[id] = float(m["by_action"][id]) / TPS
	return {
		"strategy": strategy, "seed": seed_value, "realm": s.realm_id,
		"reached": s.realm_id == "truc_co_so", "alive": s.life["status"] == "alive",
		"age": s.age_years, "active_hours": float(m["active_ticks"]) / TPS / 3600.0,
		"offline_hours": float(m["offline_ticks"]) / TPS / 3600.0,
		"failed_breakthroughs": m["failed_breakthroughs"], "milestones": m["milestones"],
		"seconds_by_action": by, "burned": m["burned"], "stop_reasons": m["blocked"], "stuck": m["stuck"],
		"decisions": m["decisions"], "upgrades": s.upgrades.duplicate(),
		"stuck_reason": m.get("stuck_reason", ""),
	}


## Median / worst over seeds, per strategy -> markdown table lines.
static func summarize(results: Array) -> String:
	var by_strategy: Dictionary = {}
	for r in results:
		if not by_strategy.has(r["strategy"]):
			by_strategy[r["strategy"]] = []
		by_strategy[r["strategy"]].append(r)
	var out: PackedStringArray = []
	out.append("| Chiến lược | Seeds | Tới Trúc Cơ | Median (giờ chủ động) | Worst | Best | Thất bại đột phá TB | Tuổi cuối TB |")
	out.append("|---|---|---|---|---|---|---|---|")
	for strat in by_strategy:
		var rs: Array = by_strategy[strat]
		var hours: Array = []
		var fails: float = 0.0
		var age: float = 0.0
		var ok: int = 0
		for r in rs:
			if r["reached"]:
				ok += 1
				hours.append(r["active_hours"])
			fails += r["failed_breakthroughs"]
			age += r["age"]
		hours.sort()
		out.append("| %s | %d | %d/%d | %s | %s | %s | %.2f | %.1f |" % [
			strat, rs.size(), ok, rs.size(),
			"%.2f" % hours[hours.size() / 2] if not hours.is_empty() else "—",
			"%.2f" % hours[-1] if not hours.is_empty() else "—",
			"%.2f" % hours[0] if not hours.is_empty() else "—",
			fails / rs.size(), age / rs.size()])
	return "\n".join(out)


static func _median(a: Array) -> float:
	if a.is_empty():
		return -1.0
	var b: Array = a.duplicate()
	b.sort()
	return float(b[b.size() / 2])


## Full markdown report: summary, milestones (median minutes), where the time goes, what failures burned.
static func report(results: Array) -> String:
	var out: PackedStringArray = []
	out.append("## Tổng hợp\n")
	out.append(summarize(results))
	var strategies: Array = []
	for r in results:
		if not strategies.has(r["strategy"]):
			strategies.append(r["strategy"])
	out.append("\n## Mốc thời gian (median, phút chủ động)\n")
	out.append("| Chiến lược | " + " | ".join(MILESTONES) + " |")
	out.append("|---|" + "---|".repeat(MILESTONES.size()))
	for st in strategies:
		var cells: PackedStringArray = []
		for ms in MILESTONES:
			var xs: Array = []
			for r in results:
				if r["strategy"] == st and r["milestones"].has(ms):
					xs.append(float(r["milestones"][ms]) / 60.0)
			cells.append("%.1f" % _median(xs) if not xs.is_empty() else "—")
		out.append("| %s | %s |" % [st, " | ".join(cells)])
	out.append("\n## Thời gian theo hành động (median, giây chủ động)\n")
	for st in strategies:
		var ids: Dictionary = {}
		for r in results:
			if r["strategy"] == st:
				for id in r["seconds_by_action"]:
					ids[id] = true
		var rows: Array = []
		for id in ids:
			var xs: Array = []
			for r in results:
				if r["strategy"] == st:
					xs.append(float(r["seconds_by_action"].get(id, 0.0)))
			rows.append([id, _median(xs)])
		rows.sort_custom(func(a: Array, b: Array) -> bool: return a[1] > b[1])
		var total: float = 0.0
		for row in rows:
			total += row[1]
		var parts: PackedStringArray = []
		for row in rows:
			parts.append("%s %.0fs (%.0f%%)" % [row[0], row[1], 100.0 * row[1] / maxf(total, 1.0)])
		out.append("- **%s**: %s" % [st, "; ".join(parts)])
	out.append("\n## Tài nguyên bị đốt bởi đột phá thất bại (trung bình mỗi seed)\n")
	for st in strategies:
		var sums: Dictionary = {}
		var n: int = 0
		for r in results:
			if r["strategy"] == st:
				n += 1
				for rid in r["burned"]:
					sums[rid] = float(sums.get(rid, 0.0)) + float(r["burned"][rid])
		var parts2: PackedStringArray = []
		for rid in sums:
			parts2.append("%s %.0f" % [rid, sums[rid] / maxf(n, 1)])
		out.append("- **%s**: %s" % [st, ", ".join(parts2) if not parts2.is_empty() else "không có"])
	return "\n".join(out)
