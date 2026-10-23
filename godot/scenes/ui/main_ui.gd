extends Control
## Main game screen: tab column | area | action columns by kind | resource panel | log.
## Everything is generated from the registry. Reads state for display only;
## all changes go through GameController commands.

const REFRESH_SECONDS: float = 0.1
const UiTheme = preload("res://scenes/ui/ui_theme.gd")
const PINK: Color = Color(UiTheme.FILL_PROGRESS, 0.6)  # translucent so the button label stays readable
const COL_ORDER: Array = ["instant", "loop", "upgrade"]
const StoryPages = preload("res://scenes/ui/story_pages.gd")

var _age_label: Label
var _new_life: Button
var _confirm_new_life: bool = false
var _active_label: Label
var _log: RichTextLabel
var _buttons: Dictionary = {}  # action_id -> Button
var _bars: Dictionary = {}  # action_id -> progress overlay on its button
var _res_rows: Dictionary = {}  # resource_id -> {"bar": ProgressBar, "value": Label}
var _groups: Dictionary = {}  # "column|group" -> VBoxContainer body
var _group_heads: Dictionary = {}  # same key -> header button, hidden while the group has nothing visible
var _vis_sig: String = ""  # action button visibility last applied to the group headers
var _since: float = 0.0
var _pages: StoryPages
var _dungeon_btns: Dictionary = {}  # dungeon_id -> Button
var _dungeon_info: Dictionary = {}  # dungeon_id -> Label (clears, age cost)
var _dungeon_none: Label  # shown while no dungeon is discovered
var _run_box: VBoxContainer  # the run in progress; hidden otherwise
var _run_enemy: Label
var _run_enemy_bar: ProgressBar
var _run_you: Label
var _run_you_bar: ProgressBar


func _ready() -> void:
	if not GameController.ready_ok:
		var l := Label.new()
		l.text = "Lỗi nạp dữ liệu / Data load error — xem Output / see Output."  # registry unavailable, so no localization: fixed bilingual text
		add_child(l)
		return
	_build()
	EventBus.game_loaded.connect(_on_loaded)
	EventBus.mastery_level_up.connect(func(id: String, lv: int) -> void:
		var r: ContentRegistry = GameController.registry
		_say(r.text("ui.log_mastery") % [r.text(r.actions[id]["name_key"]), lv], UiTheme.ACCENT_JADE))
	EventBus.story_pending.connect(func(n: String) -> void:
		var r: ContentRegistry = GameController.registry
		_say(r.text("ui.log_story_pending") % r.text(r.story[n]["title_key"]), UiTheme.ACCENT_CINNABAR)
		_pages.current_tab = 0  # bring the event to the player; the queue is already waiting for the choice
		_pages.focus_event())
	EventBus.action_stopped.connect(func(id: String, why: String) -> void: _say(GameController.registry.text("ui.stopped") % [GameController.registry.text(GameController.registry.actions[id]["name_key"]), _reason(why)]))
	EventBus.lifespan_warning.connect(func(r: float) -> void:
		if _lifespan_known():  # the warning would itself reveal the limit
			_say(GameController.registry.text("ui.log_warning") % r, UiTheme.ACCENT_CINNABAR))
	EventBus.life_ended.connect(func(a: float) -> void: _say(GameController.registry.text("ui.log_death") % a, UiTheme.ACCENT_CINNABAR))
	EventBus.breakthrough_resolved.connect(func(ok: bool, f: String, t: String) -> void:
		var r: ContentRegistry = GameController.registry
		_say(r.text("ui.breakthrough_ok") % [r.text(r.stage_of(f)["name_key"]), r.text(r.stage_of(t)["name_key"])] if ok else r.text("ui.breakthrough_fail")))
	EventBus.dungeon_enemy_defeated.connect(func(_d: String, e: String) -> void:
		var r: ContentRegistry = GameController.registry
		_say(r.text("ui.dungeon.log_kill") % r.text(r.enemies[e]["name_key"])))
	EventBus.dungeon_run_ended.connect(func(d: String, res: String) -> void:
		var r: ContentRegistry = GameController.registry
		_say(r.text("ui.dungeon.log_" + res) % r.text(r.dungeons[d]["name_key"]), UiTheme.ACCENT_JADE if res == "cleared" else UiTheme.ACCENT_CINNABAR))
	EventBus.game_loaded.connect(func(_r: Dictionary) -> void: _pages.reset())
	_on_loaded(GameController.last_offline_report)
	GameController.last_offline_report = {}  # shown once, not again on every return from the menu
	_refresh()


func _build() -> void:
	var reg: ContentRegistry = GameController.registry
	theme = UiTheme.make()
	add_child(UiTheme.page_background())
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 10)
	add_child(margin)
	var page := VBoxContainer.new()
	margin.add_child(page)

	# Header: area title + description (left), realm/age (right).
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 16)
	page.add_child(top)
	top.add_child(UiTheme.title_label(reg.text("area.village.name")))
	var desc := Label.new()
	desc.text = reg.text("area.village.desc")
	desc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	desc.size_flags_vertical = Control.SIZE_SHRINK_END
	top.add_child(desc)
	_age_label = Label.new()
	_age_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	top.add_child(_age_label)

	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page.add_child(body)
	_build_nav(body)

	_pages = StoryPages.new()
	_pages.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var main_page := HBoxContainer.new()
	_pages.setup(main_page)
	body.add_child(_pages)
	var area := _column(main_page, reg.text("ui.col_area"), 100)
	var area_btn := Button.new()
	area_btn.text = reg.text("area.village.name")
	area_btn.disabled = true  # the MVP has a single area; this column is the slot for future ones
	UiTheme.primary_button(area_btn)  # shown as the selected area, not as an unavailable button
	area.add_child(area_btn)

	var cols: Dictionary = {}
	for c in COL_ORDER:
		cols[c] = _column(main_page, reg.text("ui.col_" + c), 0)
	for id in reg.actions:
		var def: Dictionary = reg.actions[id]
		var col: String = "upgrade" if def.has("upgrade") else ("instant" if def["type"] == "INSTANT" else "loop")
		_add_action(_group_body("c|" + col, cols[col], str(def.get("group", ""))), id)

	var next := _column(main_page, reg.text("ui.col_next"), 0)
	_pages.attach_next(next)
	var dungeon := _column(main_page, reg.text("ui.col_dungeon"), 0)
	_build_dungeon(dungeon)

	var res := _column(main_page, "", 230)
	for id in reg.resources:
		_add_resource(_group_body("r", res, str(reg.resources[id].get("group", ""))), id)
	_pages.attach_history(res)

	_active_label = Label.new()
	page.add_child(_active_label)
	var log_panel := PanelContainer.new()
	log_panel.custom_minimum_size.y = 110
	page.add_child(log_panel)
	_log = RichTextLabel.new()
	_log.scroll_following = true
	log_panel.add_child(_log)


func _build_dungeon(col: VBoxContainer) -> void:
	var reg: ContentRegistry = GameController.registry
	_dungeon_none = Label.new()
	_dungeon_none.text = reg.text("ui.dungeon.locked")
	_dungeon_none.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(_dungeon_none)
	for id in reg.dungeons:
		var b := Button.new()
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		b.custom_minimum_size.y = 44
		b.pressed.connect(func() -> void:
			var r: Dictionary = GameController.enter_dungeon(id)
			if not r["ok"]:
				_say(reg.text("ui.dungeon.cannot") % _explain(r)))
		col.add_child(b)
		_dungeon_btns[id] = b
		var info := Label.new()
		info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		info.add_theme_font_size_override("font_size", UiTheme.SIZE_SMALL)
		col.add_child(info)
		_dungeon_info[id] = info
	_run_box = VBoxContainer.new()
	_run_box.visible = false
	col.add_child(_run_box)
	_run_enemy = Label.new()
	_run_enemy_bar = ProgressBar.new()
	_run_you = Label.new()
	_run_you_bar = ProgressBar.new()
	for n in [_run_enemy_bar, _run_you_bar]:
		n.show_percentage = false
	var retreat := Button.new()
	retreat.text = reg.text("ui.dungeon.retreat")
	retreat.pressed.connect(func() -> void: GameController.retreat())
	for n in [_run_enemy, _run_enemy_bar, _run_you, _run_you_bar, retreat]:
		_run_box.add_child(n)


func _refresh_dungeon(s: GameState) -> void:
	var reg: ContentRegistry = GameController.registry
	var combat: CombatSystem = GameController.actions.combat
	var any: bool = false
	for id in _dungeon_btns:
		var def: Dictionary = reg.dungeons[id]
		var shown: bool = GameController.actions.conditions.is_met(def.get("visible_when", {}), s)
		var chk: Dictionary = combat.check_enter(s, id)
		any = any or shown
		_dungeon_btns[id].visible = shown
		_dungeon_btns[id].text = "%s — %s" % [reg.text("ui.dungeon.enter"), reg.text(def["name_key"])]
		UiTheme.set_locked(_dungeon_btns[id], not chk["ok"])
		_dungeon_btns[id].tooltip_text = "" if chk["ok"] else _explain(chk)
		_dungeon_info[id].visible = shown
		_dungeon_info[id].text = "%s
%s
%s" % [reg.text(def["desc_key"]), reg.text("ui.dungeon.clears") % int(s.dungeon_clears.get(id, 0)),
			reg.text("ui.dungeon.age_cost") % _fmt(float(def.get("age_cost_years", 0.0)))]
	_dungeon_none.visible = not any
	_run_box.visible = combat.is_active(s)
	if not _run_box.visible:
		return
	var c: Dictionary = s.combat
	var enemies: Array = reg.dungeons[c["dungeon"]]["enemies"]
	var enemy: Dictionary = reg.enemies[enemies[int(c["index"])]]
	_run_enemy.text = reg.text("ui.dungeon.enemy") % [reg.text(enemy["name_key"]), int(c["enemy_hp"]), int(enemy["hp"])]
	_run_enemy_bar.max_value = float(enemy["hp"])
	_run_enemy_bar.value = float(c["enemy_hp"])
	var max_hp: int = int(combat.player_stats(s)["hp"])
	_run_you.text = reg.text("ui.dungeon.you") % [int(c["player_hp"]), max_hp]
	_run_you_bar.max_value = float(max_hp)
	_run_you_bar.value = float(c["player_hp"])


## Left tab-style column: game controls.
func _build_nav(parent: Control) -> void:
	var reg: ContentRegistry = GameController.registry
	var nav := _column(parent, reg.text("ui.col_menu"), 130)
	var help := Button.new()
	help.text = "?"
	help.pressed.connect(func() -> void:
		var d := AcceptDialog.new()
		d.title = reg.text("ui.col_menu")
		d.dialog_text = reg.text("ui.help.text")
		d.dialog_autowrap = true
		d.confirmed.connect(d.queue_free)
		d.canceled.connect(d.queue_free)
		add_child(d)
		d.popup_centered(Vector2i(480, 0)))
	nav.add_child(help)
	var stop := Button.new()
	stop.text = reg.text("ui.stop_action")
	stop.pressed.connect(func() -> void: GameController.stop_action())
	nav.add_child(stop)
	var pause := Button.new()
	pause.text = reg.text("ui.pause")
	pause.toggle_mode = true
	pause.set_pressed_no_signal(GameController.clock.paused)  # clock outlives this scene
	pause.toggled.connect(func(on: bool) -> void: GameController.set_paused(on))
	nav.add_child(pause)
	var speeds := HBoxContainer.new()
	nav.add_child(speeds)
	var speed_group := ButtonGroup.new()
	for sp in [1, 2, 5]:
		var sb := Button.new()
		sb.text = "×%d" % sp
		sb.toggle_mode = true
		sb.button_group = speed_group
		sb.set_pressed_no_signal(is_equal_approx(GameController.clock.speed, float(sp)))  # clock outlives this scene
		sb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		sb.pressed.connect(func() -> void: GameController.set_speed(float(sp)))
		speeds.add_child(sb)
	var save := Button.new()
	save.text = reg.text("ui.save")
	save.pressed.connect(func() -> void: _say(reg.text("ui.saved" if GameController.save() else "ui.save_failed")))
	nav.add_child(save)
	var load_b := Button.new()
	load_b.text = reg.text("ui.load")
	load_b.pressed.connect(func() -> void: _say(reg.text("ui.loaded" if GameController.load_save() else "ui.load_failed")))
	nav.add_child(load_b)
	var menu := Button.new()
	menu.text = reg.text("menu.to_menu")
	menu.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	menu.pressed.connect(func() -> void:
		GameController.save()
		get_tree().change_scene_to_file("res://scenes/main_menu.tscn"))
	nav.add_child(menu)
	_new_life = Button.new()
	_new_life.text = reg.text("ui.new_life")
	_new_life.visible = false
	_new_life.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_new_life.pressed.connect(func() -> void:
		if not _confirm_new_life:
			_confirm_new_life = true
			_new_life.text = reg.text("ui.new_life_confirm")
			return
		_confirm_new_life = false
		_new_life.text = reg.text("ui.new_life")
		GameController.new_game()
		GameController.clock.reset()
		_say(reg.text("ui.new_life_log")))
	nav.add_child(_new_life)


## Vertical scrollable column with an optional header. width 0 = expand.
func _column(parent: Control, header: String, width: int) -> VBoxContainer:
	var panel := PanelContainer.new()
	if width > 0:
		panel.custom_minimum_size.x = width
	else:
		panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(panel)
	var sc := ScrollContainer.new()
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(sc)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(v)
	if header != "":
		var l := Label.new()
		l.text = header
		l.add_theme_font_size_override("font_size", UiTheme.SIZE_HEADER)
		v.add_child(l)
	return v


## Body of a collapsible group inside `parent`; an empty group name means no header.
func _group_body(key: String, parent: VBoxContainer, group: String) -> VBoxContainer:
	if group == "":
		return parent
	var k: String = "%s|%s" % [key, group]
	if _groups.has(k):
		return _groups[k]
	var group_name: String = GameController.registry.text("group." + group)
	var head := Button.new()
	head.flat = true
	head.alignment = HORIZONTAL_ALIGNMENT_LEFT
	head.text = "▾ " + group_name
	parent.add_child(head)
	var body := VBoxContainer.new()
	parent.add_child(body)
	head.pressed.connect(func() -> void:
		body.visible = not body.visible
		head.text = ("▾ " if body.visible else "▸ ") + group_name)
	_groups[k] = body
	_group_heads[k] = head
	return body


func _add_action(parent: VBoxContainer, id: String) -> void:
	var b := Button.new()
	b.text = GameController.registry.text(GameController.registry.actions[id]["name_key"])
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	b.custom_minimum_size.y = 44
	b.pressed.connect(_on_action.bind(id))
	var bar := _fill_bar()
	b.add_child(bar)
	parent.add_child(b)
	_buttons[id] = b
	_bars[id] = bar


func _add_resource(parent: VBoxContainer, id: String) -> void:
	var bar := _fill_bar()
	bar.custom_minimum_size.y = 24
	var row := HBoxContainer.new()
	row.set_anchors_preset(Control.PRESET_FULL_RECT)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var name_l := Label.new()
	name_l.text = GameController.registry.text(GameController.registry.resources[id]["name_key"])
	name_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var val := Label.new()
	val.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(name_l)
	row.add_child(val)
	bar.add_child(row)
	parent.add_child(bar)
	_res_rows[id] = {"bar": bar, "value": val}


## Pink fill (no percentage text) that lets clicks through.
func _fill_bar() -> ProgressBar:
	var bar := ProgressBar.new()
	bar.show_percentage = false
	bar.set_anchors_preset(Control.PRESET_FULL_RECT)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var fill := StyleBoxFlat.new()
	fill.bg_color = PINK
	bar.add_theme_stylebox_override("fill", fill)
	bar.add_theme_stylebox_override("background", StyleBoxEmpty.new())
	return bar


func _on_action(id: String) -> void:
	var r: Dictionary = GameController.start_action(id)
	if not r["ok"]:
		_say(GameController.registry.text("ui.cannot") % _explain(r))


func _explain(r: Dictionary) -> String:
	return _reason(str(r["reason"]), r["detail"])


## Stop/refusal codes come from the simulation; the player only ever sees localized text.
func _reason(code: String, detail: Variant = null) -> String:
	var reg: ContentRegistry = GameController.registry
	var s: String = reg.text("reason." + code)
	if code == "insufficient_resources" and typeof(detail) == TYPE_DICTIONARY:
		var parts: PackedStringArray = []
		for id in detail:
			parts.append("%s %s" % [_fmt(float(detail[id])), reg.text(reg.resources[id]["name_key"]) if reg.resources.has(id) else str(id)])
		s += ": " + ", ".join(parts)
	return s


## Offline reports carry "action_id:reason".
func _stop_text(raw: String) -> String:
	if raw == "":
		return ""
	var parts: PackedStringArray = raw.split(":", true, 1)
	if parts.size() < 2:
		return _reason(raw)
	var reg: ContentRegistry = GameController.registry
	return "%s — %s" % [reg.text(reg.actions[parts[0]]["name_key"]) if reg.actions.has(parts[0]) else parts[0], _reason(parts[1])]


func _named(d: Dictionary, defs: Dictionary, signed: bool) -> String:
	var parts: PackedStringArray = []
	for id in d:
		var v: float = float(d[id])
		var n: String = GameController.registry.text(defs[id]["name_key"]) if defs.has(id) else str(id)
		parts.append("%s %s%s" % [n, ("+" if v > 0.0 else "") if signed else "×", _fmt(v)])
	return ", ".join(parts)


func _on_loaded(report: Dictionary) -> void:
	if report.is_empty() or float(report.get("seconds_simulated", 0.0)) <= 0.0:
		return
	var r: ContentRegistry = GameController.registry
	_say(r.text("ui.offline") % [
		report["seconds_simulated"], r.text("ui.offline_capped") if report["capped"] else "",
		_named(report["resources_delta"], r.resources, true) if not report["resources_delta"].is_empty() else "—",
		_named(report["completions"], r.actions, false) if not report["completions"].is_empty() else "—",
		report["age_delta"], _stop_text(str(report["stop_reason"]))])


func _say(t: String, color: Color = UiTheme.INK_PRIMARY) -> void:
	_log.push_color(color)
	_log.append_text(t + "\n")
	_log.pop()


func _process(delta: float) -> void:
	_since += delta
	if _since >= REFRESH_SECONDS:
		_since = 0.0
		_refresh()


func _lifespan_known() -> bool:
	return GameController.actions.conditions.is_met(GameController.registry.config.get("ui", {}).get("lifespan_visible_when", {}), GameController.state)


func _refresh() -> void:
	if not GameController.ready_ok:
		return
	var s: GameState = GameController.state
	var reg: ContentRegistry = GameController.registry
	var stage: Dictionary = GameController.actions.realms.stage(s)
	var life: LifespanSystem = GameController.actions.lifespan
	if not _lifespan_known():  # until the Way is taught nobody knows realms or a lifespan limit, whatever their stage
		_age_label.text = reg.text("ui.status_line") % [reg.text(reg.stage_of("")["name_key"]), int(s.age_years)]
	else:
		_age_label.text = reg.text("ui.realm_line") % [
			reg.text(stage["name_key"]), s.age_years, life.limit(s),
			reg.text("ui.deceased_suffix") if not life.is_alive(s) else (reg.text("ui.warning_suffix") if life.is_warning(s) else "")]
	_new_life.visible = not life.is_alive(s)
	var rs: ResourceSystem = GameController.actions.resources
	for id in _res_rows:
		var v: float = float(s.resources.get(id, 0.0))
		var cap: float = rs.cap_of(id, s)
		var capped: bool = cap < ResourceSystem.MAX_AMOUNT
		var bar: ProgressBar = _res_rows[id]["bar"]
		bar.visible = GameController.actions.conditions.is_met(GameController.registry.resources[id].get("visible_when", {}), s)
		bar.max_value = maxf(cap, 1.0) if capped else 1.0
		bar.value = v if capped else 0.0
		_res_rows[id]["value"].text = ("%s/%s" % [_fmt(v), _fmt(cap)]) if capped else _fmt(v)
	var active: String = str(s.active_action.get("id", ""))
	for id in _buttons:
		var chk: Dictionary = GameController.actions.check_can_start(s, id)
		var def: Dictionary = reg.actions[id]
		var label: String = reg.text(def["name_key"])
		if def.has("upgrade"):
			label += " (%s)" % (reg.text("ui.level_short") % int(s.upgrades.get(def["upgrade"], 0)))
		_buttons[id].text = label
		_buttons[id].visible = GameController.actions.conditions.is_met(def.get("visible_when", {}), s)
		UiTheme.set_locked(_buttons[id], not (chk["ok"] or id == active))
		_buttons[id].tooltip_text = "" if chk["ok"] else _explain(chk)
		var pbar: ProgressBar = _bars[id]
		if id == active:
			pbar.max_value = float(s.active_action["duration_ticks"])
			pbar.value = float(s.active_action["progress_ticks"])
		else:
			pbar.value = 0.0
	var vis: String = ""  # group headers only need work when some button/row visibility flipped
	for id in _buttons:
		vis += "1" if _buttons[id].visible else "0"
	for id in _res_rows:
		vis += "1" if _res_rows[id]["bar"].visible else "0"
	if vis != _vis_sig:
		_vis_sig = vis
		for k in _groups:
			_group_heads[k].visible = _groups[k].get_children().any(func(c: Control) -> bool: return c.visible)
	_pages.refresh()
	_refresh_dungeon(s)
	if GameController.actions.combat.is_active(s):
		_active_label.text = reg.text("ui.doing") % reg.text(reg.dungeons[s.combat["dungeon"]]["name_key"])
	else:
		_active_label.text = reg.text("ui.idle") if active == "" else reg.text("ui.doing") % reg.text(reg.actions[active]["name_key"])


func _fmt(v: float) -> String:
	return str(snappedf(v, 0.01))
