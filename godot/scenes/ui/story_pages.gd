extends TabContainer
## Phase 2B pages (Mastery, Automation, Cultivation) plus the story event card on the main page. Display + commands only: every change goes through
## GameController. Pages are rebuilt only when what they show changes, so buttons are never replaced mid-click.

const UiTheme = preload("res://scenes/ui/ui_theme.gd")

var _pages: Dictionary = {}  # name -> {"box": VBoxContainer, "sig": String}
var _slot_ui: Array = []  # automation draft controls, built once per load
var _auto_status: Label
var _auto_warn: Label
var _auto_loop: CheckBox
var _auto_start: Button
var _auto_built: bool = false
var _auto_ids: Array = []  # automatable actions the draft was built for
var _tab_shown: Dictionary = {}  # page -> last applied visibility
var _event_panel: PanelContainer  # pending story event, above the main columns; hidden when nothing is pending
const REPEATS: Array = [1, 2, 3, 5, 10, 20, 50, 0]  # 0 = until blocked / forever


func setup(main_page: Control) -> void:
	var reg: ContentRegistry = GameController.registry
	add_theme_stylebox_override("panel", UiTheme.box(UiTheme.SURFACE_PANEL, UiTheme.BORDER_INK))
	add_theme_stylebox_override("tab_selected", UiTheme.box(UiTheme.SURFACE_PANEL, UiTheme.BORDER_INK))
	add_theme_stylebox_override("tab_unselected", UiTheme.box(UiTheme.STATE_DISABLED, UiTheme.BORDER_INK))
	add_theme_stylebox_override("tab_hovered", UiTheme.box(UiTheme.FILL_PROGRESS, UiTheme.BORDER_INK))
	for c in ["font_selected_color", "font_unselected_color", "font_hovered_color"]:
		add_theme_color_override(c, UiTheme.INK_PRIMARY)
	var wrap := VBoxContainer.new()
	_event_panel = PanelContainer.new()
	_event_panel.add_theme_stylebox_override("panel", UiTheme.box(UiTheme.SURFACE_PANEL, UiTheme.ACCENT_CINNABAR))
	_event_panel.visible = false
	var event_scroll := ScrollContainer.new()
	event_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	event_scroll.follow_focus = true
	event_scroll.custom_minimum_size.y = 215
	var event_box := VBoxContainer.new()
	event_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	event_box.add_theme_constant_override("separation", 6)
	event_scroll.add_child(event_box)
	_event_panel.add_child(event_scroll)
	_pages["event"] = {"box": event_box, "sig": ""}
	wrap.add_child(_event_panel)
	main_page.size_flags_vertical = Control.SIZE_EXPAND_FILL
	wrap.add_child(main_page)
	add_child(wrap)
	set_tab_title(0, reg.text("ui.nav_main"))
	for p in ["mastery", "automation", "cultivation"]:
		var sc := ScrollContainer.new()
		sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		sc.follow_focus = true
		var box := VBoxContainer.new()
		box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		box.add_theme_constant_override("separation", 8)
		sc.add_child(box)
		add_child(sc)
		set_tab_title(get_tab_count() - 1, reg.text("ui.tab." + p))
		_pages[p] = {"box": box, "sig": ""}


## Relations and story history live at the bottom of the right-hand column of the main page.
func attach_history(parent: VBoxContainer) -> void:
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 4)
	parent.add_child(box)
	_pages["history"] = {"box": box, "sig": ""}


## Keyboard / gamepad can pick a choice right away when an event arrives.
func focus_event() -> void:
	var box: VBoxContainer = _pages["event"]["box"]
	for c in box.get_children():
		if c is Button and not c.disabled:
			c.grab_focus.call_deferred()
			return


## Forget drafts and signatures after a load / new life.
func reset() -> void:
	_auto_built = false
	_tab_shown.clear()
	for p in _pages:
		_pages[p]["sig"] = ""


func refresh() -> void:
	var s: GameState = GameController.state
	_event(s)
	_history(s)
	_mastery(s)
	_automation(s)
	_cultivation(s)
	_tab_visibility(s)


## Tabs listed in config ui.tab_visible_when stay hidden until their condition holds.
func _tab_visibility(s: GameState) -> void:
	var rules: Dictionary = GameController.registry.config.get("ui", {}).get("tab_visible_when", {})
	for p in rules:
		var shown: bool = GameController.actions.conditions.is_met(rules[p], s)
		if _tab_shown.get(p) != shown:  # tab bar is only touched when the state changes
			_tab_shown[p] = shown
			set_tab_hidden(page_index(p), not shown)
		if not shown and current_tab == page_index(p):
			current_tab = 0


## Tab index of a page by name ("mastery", ...), so callers never hardcode positions.
func page_index(page: String) -> int:
	return get_tab_idx_from_control(_pages[page]["box"].get_parent())


func _t(key: String) -> String:
	return GameController.registry.text(key)


func _sync(page: String, sig: String) -> VBoxContainer:
	## Returns the emptied box when `sig` changed, else null.
	if _pages[page]["sig"] == sig:
		return null
	_pages[page]["sig"] = sig
	var box: VBoxContainer = _pages[page]["box"]
	for c in box.get_children():
		box.remove_child(c)
		c.queue_free()
	return box


func _label(parent: Control, text: String, size: int = UiTheme.SIZE_BODY, color: Color = UiTheme.INK_PRIMARY) -> Label:
	var l := Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(l)
	return l


func _row_label(row: HBoxContainer, text: String) -> void:
	var l := Label.new()
	l.text = text
	row.add_child(l)


func _reason(code: String, detail: Variant = null) -> String:
	var reg: ContentRegistry = GameController.registry
	var s: String = reg.text("reason." + code)
	if code == "insufficient_resources" and typeof(detail) == TYPE_DICTIONARY:
		var parts: PackedStringArray = []
		for id in detail:
			parts.append("%s %s" % [snappedf(float(detail[id]), 0.01), reg.text(reg.resources[id]["name_key"]) if reg.resources.has(id) else str(id)])
		s += ": " + ", ".join(parts)
	return s


# ---------- story (event card on the main page + history column) ----------

func _event(s: GameState) -> void:
	var reg: ContentRegistry = GameController.registry
	var pending: String = GameController.actions.story.pending(s)
	_event_panel.visible = pending != ""
	var sig: String = "%s|%s" % [pending, reg.language]
	if pending != "":  # affordability changes while the player waits
		for c in reg.story[pending]["choices"]:
			sig += str(GameController.actions.story.check_choice(s, c["id"])["ok"])
	var box := _sync("event", sig)
	if box == null or pending == "":
		return
	var node_def: Dictionary = reg.story[pending]
	_label(box, _t("ui.story.pending"), UiTheme.SIZE_SMALL, UiTheme.ACCENT_CINNABAR)
	_label(box, _t(node_def["title_key"]), UiTheme.SIZE_HEADER)
	_label(box, _t(node_def["text_key"]))
	for c in node_def["choices"]:
		var chk: Dictionary = GameController.actions.story.check_choice(s, c["id"])
		var b := Button.new()
		b.text = _t(c["text_key"])
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		b.custom_minimum_size.y = 36
		UiTheme.set_locked(b, not chk["ok"])
		b.tooltip_text = "" if chk["ok"] else _reason(str(chk["reason"]), chk["detail"])
		b.pressed.connect(func() -> void: GameController.choose_story(str(c["id"])))
		box.add_child(b)
		if c == node_def["choices"][0] and get_viewport().gui_get_focus_owner() == null:
			b.grab_focus.call_deferred()
		if not chk["ok"]:
			_label(box, "   " + _t("ui.story.locked_choice") + ": " + _reason(str(chk["reason"]), chk["detail"]), UiTheme.SIZE_SMALL, UiTheme.INK_SECONDARY)


func _history(s: GameState) -> void:
	if not _pages.has("history"):
		return
	var reg: ContentRegistry = GameController.registry
	var box := _sync("history", "%s|%s|%s" % [s.story["done"], s.relations, reg.language])
	if box == null:
		return
	_label(box, _t("ui.story.relations"), UiTheme.SIZE_HEADER)
	for rid in reg.relations:
		_label(box, "%s: %d" % [_t(reg.relations[rid]["name_key"]), int(s.relations.get(rid, 0))])
	_label(box, _t("ui.story.history"), UiTheme.SIZE_HEADER)
	for nid in reg.story_order:
		if not (s.story["done"] as Dictionary).has(nid):
			continue
		var done_def: Dictionary = reg.story[nid]
		var picked: String = str(s.story["done"][nid])
		var line: String = _t(done_def["title_key"])
		for c in done_def["choices"]:
			if c["id"] == picked:
				line += " — " + _t(c["text_key"])
				_label(box, line, UiTheme.SIZE_SMALL, UiTheme.INK_PRIMARY)
				_label(box, "   " + _t(c["result_key"]), UiTheme.SIZE_SMALL, UiTheme.INK_SECONDARY)


# ---------- mastery ----------

func _mastery(s: GameState) -> void:
	var reg: ContentRegistry = GameController.registry
	var sig: String = "%s|%s" % [s.mastery, GameController.registry.language]
	var box := _sync("mastery", sig)
	if box == null:
		return
	for did in reg.mastery:
		var def: Dictionary = reg.mastery[did]
		var aid: String = def["action"]
		var m: Dictionary = GameController.actions.mastery.progress(s, aid)
		var claimed: Array = (s.mastery.get(aid, {}) as Dictionary).get("claimed", [])
		_label(box, "%s — %s" % [_t(def["name_key"]), _t("ui.mastery.level") % [m["level"], m["max_level"]]], UiTheme.SIZE_HEADER)
		var bar := ProgressBar.new()
		bar.show_percentage = false
		bar.custom_minimum_size.y = 10
		bar.max_value = maxf(float(m["required"]), 1.0)
		bar.value = float(m["xp"]) if float(m["required"]) > 0.0 else bar.max_value
		box.add_child(bar)
		_label(box, _t("ui.mastery.xp") % [snappedf(m["xp"], 0.1), snappedf(m["required"], 0.1)] if float(m["required"]) > 0.0 else _t("ui.mastery.max"), UiTheme.SIZE_SMALL, UiTheme.INK_SECONDARY)
		for ms in def["milestones"]:
			var got: bool = claimed.has(int(ms["level"]))
			if got:
				_label(box, _t("ui.mastery.claimed") % _t(ms["name_key"]), UiTheme.SIZE_SMALL, UiTheme.ACCENT_JADE)
			else:
				_label(box, _t("ui.mastery.next_milestone") % [int(ms["level"]), _t(ms["name_key"])], UiTheme.SIZE_SMALL, UiTheme.INK_SECONDARY)
				break


# ---------- automation ----------

func _automatable(s: GameState) -> Array:
	var out: Array = []
	var reg: ContentRegistry = GameController.registry
	for id in reg.actions:
		var d: Dictionary = reg.actions[id]
		if not d.get("breakthrough", false) and d.get("automation_allowed", true) and not d.has("upgrade") 				and GameController.actions.conditions.is_met(d.get("visible_when", {}), s):
			out.append(id)
	return out


func _automation(s: GameState) -> void:
	var q: AutomationQueue = GameController.actions.automation
	var box: VBoxContainer = _pages["automation"]["box"]
	if not q.is_unlocked(s):
		var sigl: String = "locked" + GameController.registry.language
		var b := _sync("automation", sigl)
		if b != null:
			_auto_built = false
			_label(b, _t("ui.auto.locked"), UiTheme.SIZE_BODY, UiTheme.INK_SECONDARY)
		return
	if not _auto_built or _auto_ids != _automatable(s):
		_build_automation(s, box)
	var running: bool = q.status(s) == "running"
	_auto_status.text = _t("ui.auto.status") % _t("ui.auto.status." + q.status(s))
	var why: String = str(s.automation["reason"])
	if why != "":
		_auto_status.text += " — " + _auto_reason(why)
	for row in _slot_ui:
		row["act"].disabled = running
		row["blk"].disabled = running
		row["rep"].disabled = running
	_auto_loop.disabled = running
	_auto_start.text = _t("ui.auto.stop") if running else _t("ui.auto.start")
	var warn: PackedStringArray = []
	for a in q.analyze(s):
		if a["reason"] == "deadlock_risk":
			warn.append("%s: %s" % [_t("ui.auto.slot") % (int(a["slot"]) + 1), _t("ui.auto.warn.deadlock_risk")])
		elif not a["ok"]:
			warn.append("%s: %s" % [_t("ui.auto.slot") % (int(a["slot"]) + 1), _t("ui.auto.warn.blocked_now") + " (" + _reason(str(a["reason"])) + ")"])
	_auto_warn.text = "\n".join(warn)


func _auto_reason(why: String) -> String:
	var head: String = why.split(":")[0]
	var key: String = "ui.auto.reason." + head
	var t: String = _t(key)
	return t if t != key else why


func _build_automation(s: GameState, box: VBoxContainer) -> void:
	var reg: ContentRegistry = GameController.registry
	var q: AutomationQueue = GameController.actions.automation
	_pages["automation"]["sig"] = "built"
	for c in box.get_children():
		box.remove_child(c)
		c.queue_free()
	_slot_ui.clear()
	_auto_built = true
	var ids: Array = _automatable(s)
	_auto_ids = ids
	var saved: Array = s.automation["slots"]
	for i in q.max_slots():
		var row := HBoxContainer.new()
		box.add_child(row)
		_row_label(row, _t("ui.auto.slot") % (i + 1))
		var act := OptionButton.new()
		act.add_item(_t("ui.auto.none"))
		for id in ids:
			act.add_item(_t(reg.actions[id]["name_key"]))
			act.set_item_metadata(act.item_count - 1, id)
		act.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(act)
		_row_label(row, _t("ui.auto.repeat"))
		var rep := OptionButton.new()
		for n in REPEATS:
			rep.add_item(_t("ui.auto.repeat_inf") if n == 0 else "×%d" % n)
			rep.set_item_metadata(rep.item_count - 1, n)
		row.add_child(rep)
		var blk := OptionButton.new()
		for ob in AutomationQueue.ON_BLOCK:
			blk.add_item(_t("ui.auto.on_block." + ob))
			blk.set_item_metadata(blk.item_count - 1, ob)
		row.add_child(blk)
		if i < saved.size():
			for j in act.item_count:
				if act.get_item_metadata(j) == saved[i]["action"]:
					act.select(j)
			for j in rep.item_count:
				if rep.get_item_metadata(j) == int(saved[i]["repeat"]):
					rep.select(j)
			for j in blk.item_count:
				if blk.get_item_metadata(j) == saved[i]["on_block"]:
					blk.select(j)
		_slot_ui.append({"act": act, "rep": rep, "blk": blk, "controls": [act, rep, blk]})
	_auto_loop = CheckBox.new()
	_auto_loop.text = _t("ui.auto.loop")
	_auto_loop.button_pressed = bool(s.automation["loop"])
	box.add_child(_auto_loop)
	_auto_start = Button.new()
	_auto_start.custom_minimum_size.y = 40
	_auto_start.pressed.connect(_on_auto_toggle)
	box.add_child(_auto_start)
	_auto_status = _label(box, "")
	_auto_warn = _label(box, "", UiTheme.SIZE_SMALL, UiTheme.ACCENT_CINNABAR)


func _on_auto_toggle() -> void:
	var s: GameState = GameController.state
	if GameController.actions.automation.status(s) == "running":
		GameController.stop_queue()
		return
	var slots: Array = []
	for row in _slot_ui:
		var id: Variant = row["act"].get_item_metadata(row["act"].selected) if row["act"].selected > 0 else null
		if id != null:
			slots.append({"action": id, "repeat": int(row["rep"].get_item_metadata(row["rep"].selected)), "on_block": row["blk"].get_item_metadata(row["blk"].selected)})
	var r: Dictionary = GameController.set_queue(slots)
	if r["ok"]:
		GameController.set_queue_loop(_auto_loop.button_pressed)
		r = GameController.start_queue()
	if not r["ok"]:
		_auto_status.text = str(r["error"])


# ---------- cultivation ----------

func _cultivation(s: GameState) -> void:
	var reg: ContentRegistry = GameController.registry
	var rs: RealmSystem = GameController.actions.realms
	var costs: Dictionary = rs.breakthrough_costs(s)
	var chk: Dictionary = GameController.actions.check_can_start(s, "breakthrough")
	var sig: String = "%s|%s|%s|%s|%s|%s" % [s.realm_id, s.techniques, s.flags, snappedf(rs.success_chance(s), 0.001), chk["ok"], GameController.registry.language]
	for rid in costs:
		sig += "|%d" % int(float(s.resources.get(rid, 0.0)) / maxf(float(costs[rid]) / 50.0, 1.0))  # coarse: redraw per 2%
	var box := _sync("cultivation", sig)
	if box == null:
		return
	_label(box, _t("ui.cult.chain"), UiTheme.SIZE_SMALL, UiTheme.INK_SECONDARY)
	_label(box, "%s: %s" % [_t("ui.cult.stage"), _t(rs.stage(s)["name_key"])], UiTheme.SIZE_HEADER)
	if not costs.is_empty():
		for rid in costs:
			var have: float = float(s.resources.get(rid, 0.0))
			var need: float = float(costs[rid])
			var bar := ProgressBar.new()
			bar.show_percentage = false
			bar.max_value = maxf(need, 1.0)
			bar.value = minf(have, need)
			bar.custom_minimum_size.y = 14
			_label(box, "%s: %s / %s" % [_t(reg.resources[rid]["name_key"]), snappedf(have, 0.1), snappedf(need, 0.1)])
			box.add_child(bar)
		_label(box, _t("ui.cult.chance") % int(round(rs.success_chance(s) * 100.0)))
		if not chk["ok"]:
			_label(box, _reason(str(chk["reason"]), chk["detail"]), UiTheme.SIZE_SMALL, UiTheme.ACCENT_CINNABAR)
	if not s.flags.get("knows_qi_method", false):
		_label(box, _t("ui.cult.need_method"), UiTheme.SIZE_SMALL, UiTheme.ACCENT_CINNABAR)
	_label(box, _t("ui.cult.technique"), UiTheme.SIZE_HEADER)
	if s.techniques.is_empty():
		_label(box, _t("ui.cult.no_technique"), UiTheme.SIZE_BODY, UiTheme.INK_SECONDARY)
	for tid in s.techniques:
		if reg.techniques.has(tid):
			_label(box, _t(reg.techniques[tid]["name_key"]))
			_label(box, _t(reg.techniques[tid]["desc_key"]), UiTheme.SIZE_SMALL, UiTheme.INK_SECONDARY)
