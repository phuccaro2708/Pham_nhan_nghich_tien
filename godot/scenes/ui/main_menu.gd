extends Control
## Main menu. Only navigates and issues GameController commands; owns no game state.

const UiTheme = preload("res://scenes/ui/ui_theme.gd")
const GAME_SCENE: String = "res://scenes/main.tscn"

var _confirm_new: bool = false
var _status: Label


func _ready() -> void:
	GameController.menu_open = true
	_build()


func _build() -> void:
	for c in get_children():
		c.queue_free()
	_confirm_new = false
	theme = UiTheme.make()
	add_child(UiTheme.page_background())
	var txt: Callable = GameController.registry.text
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var box := VBoxContainer.new()
	box.custom_minimum_size.x = 320
	box.add_theme_constant_override("separation", 12)
	center.add_child(box)

	var title := UiTheme.title_label(txt.call("menu.title"))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	var sub := Label.new()
	sub.text = txt.call("menu.subtitle")
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(sub)
	box.add_child(Control.new())

	var can_continue: bool = GameController.ready_ok and SaveManager.has_save() and not GameController.save_blocked
	if can_continue:
		var cont := _button(box, txt.call("menu.continue"))
		UiTheme.primary_button(cont)
		cont.pressed.connect(_start_game)
		cont.grab_focus()
	var new_btn := _button(box, txt.call("menu.new_game"))
	new_btn.disabled = not GameController.ready_ok or GameController.save_blocked
	new_btn.pressed.connect(func() -> void:
		# A save already exists -> ask twice so progress is never wiped by one stray click.
		if can_continue and not _confirm_new:
			_confirm_new = true
			new_btn.text = txt.call("menu.new_game_confirm")
			return
		var old: GameState = GameController.state
		GameController.new_game()
		if not GameController.save():
			GameController.state = old  # keep the playable state consistent with what is on disk
			_status.text = txt.call("menu.save_failed")
			return
		GameController.clock.reset()
		GameController.last_offline_report = {}  # belongs to the previous life
		_start_game())
	if not can_continue:
		new_btn.grab_focus()
	var lang := _button(box, "%s: %s" % [txt.call("menu.language"), GameController.LANGUAGES[GameController.registry.language]])
	lang.pressed.connect(_next_language)
	var quit := _button(box, txt.call("menu.quit"))
	quit.pressed.connect(func() -> void: get_tree().root.propagate_notification(NOTIFICATION_WM_CLOSE_REQUEST))

	_status = Label.new()
	_status.add_theme_color_override("font_color", UiTheme.ACCENT_CINNABAR)
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if GameController.save_blocked:
		_status.text = txt.call("menu.save_blocked")
	box.add_child(_status)

	var ver := Label.new()
	ver.text = "v" + str(ProjectSettings.get_setting("application/config/version", ""))
	ver.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	ver.position = Vector2(12, -32)
	add_child(ver)


func _next_language() -> void:
	var langs: Array = GameController.LANGUAGES.keys()
	GameController.set_language(langs[(langs.find(GameController.registry.language) + 1) % langs.size()])
	_build()


func _button(parent: Control, text: String) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size.y = 48
	parent.add_child(b)
	return b


func _start_game() -> void:
	GameController.menu_open = false
	get_tree().change_scene_to_file(GAME_SCENE)
