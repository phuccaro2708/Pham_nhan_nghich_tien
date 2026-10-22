extends Node
## Owns the live GameState and drives the simulation from a single _process().
## UI talks to this node through commands only.

const AUTOSAVE_SECONDS: float = 30.0
const SETTINGS_PATH: String = "user://settings.cfg"
const LANGUAGES: Dictionary = {"vi": "Tiếng Việt", "en": "English"}  # native names, never translated

var registry := ContentRegistry.new()
var state: GameState
var actions: ActionSystem
var clock := SimulationClock.new()
var ready_ok: bool = false
## True when a save exists but could not be loaded: never overwrite it with a fresh game.
var save_blocked: bool = false
## The autoload finishes _ready before the main scene exists, so the UI reads this instead of the signal.
var last_offline_report: Dictionary = {}

## True while the main menu is shown: the simulation and autosave stand still so "Continue" resumes exactly where the player left.
var menu_open: bool = false
var _since_autosave: float = 0.0


func _ready() -> void:
	get_tree().set_auto_accept_quit(false)
	if not registry.load_all():
		for e in registry.errors:
			push_error("Content error: " + e)
		return
	actions = ActionSystem.new(registry)
	actions.action_completed.connect(func(id: String) -> void: EventBus.action_completed.emit(id))
	actions.action_stopped.connect(func(id: String, why: String) -> void: EventBus.action_stopped.emit(id, why))
	actions.lifespan.lifespan_warning.connect(func(r: float) -> void: EventBus.lifespan_warning.emit(r))
	actions.lifespan.life_ended.connect(func(a: float) -> void: EventBus.life_ended.emit(a))
	actions.realms.breakthrough_resolved.connect(func(ok: bool, f: String, t: String) -> void: EventBus.breakthrough_resolved.emit(ok, f, t))
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) == OK:
		set_language(str(cfg.get_value("game", "language", "vi")), false)
	ready_ok = true
	_start_session()


func _start_session() -> void:
	var loaded: Dictionary = SaveManager.load_game(registry)
	if loaded.has("state"):
		state = loaded["state"]
		if not state.orphans.is_empty():
			push_warning("Save keeps data for unknown content ids (preserved): %s" % [state.orphans.keys()])
		var elapsed: float = float(Time.get_unix_time_from_system()) - float(state.save_metadata["saved_at_unix"])
		var report: Dictionary = OfflineSystem.apply(state, actions, elapsed)
		last_offline_report = report
		EventBus.game_loaded.emit(report)
	else:
		save_blocked = SaveManager.has_save()
		if save_blocked:
			push_error("Save not loadable (%s); autosave disabled to keep the files." % loaded.get("error", ""))
		new_game()
		EventBus.game_loaded.emit({})


func new_game(seed_value: int = -1) -> void:
	var s: int = int(Time.get_unix_time_from_system()) if seed_value < 0 else seed_value
	var kept: Dictionary = state.orphans if state != null else {}  # unrecognised data is never dropped
	state = GameState.new_game(s)
	clock.paused = false  # the clock outlives the state; a new life must not inherit pause/speed
	clock.speed = 1.0
	state.orphans = kept
	state.content_version = registry.content_version
	for id in registry.resources:
		state.resources[id] = float(registry.resources[id].get("initial", 0.0))


func _process(delta: float) -> void:
	if not ready_ok or menu_open:
		return
	var ticks: int = clock.feed(delta)
	if ticks > 0:
		actions.advance(state, ticks)
	_since_autosave += delta
	if _since_autosave >= AUTOSAVE_SECONDS:
		save()


# Commands for the UI (UI -> command -> simulation).
func start_action(id: String) -> Dictionary:
	return actions.start_action(state, id)


func set_language(lang: String, persist: bool = true) -> void:
	if not LANGUAGES.has(lang) or not registry.translations.has(lang):
		return
	registry.language = lang
	if persist:
		var cfg := ConfigFile.new()
		cfg.load(SETTINGS_PATH)
		cfg.set_value("game", "language", lang)
		cfg.save(SETTINGS_PATH)


func stop_action() -> void:
	actions.stop_action(state)


func set_paused(on: bool) -> void:
	clock.paused = on


func set_speed(speed: float) -> void:
	clock.speed = speed


func save() -> bool:
	_since_autosave = 0.0
	if save_blocked:
		return false
	var ok: bool = SaveManager.save_game(state, registry) == OK
	EventBus.game_saved.emit(ok)
	return ok


func load_save() -> bool:
	var loaded: Dictionary = SaveManager.load_game(registry)
	if not loaded.has("state"):
		return false
	state = loaded["state"]  # manual load restores exactly; no offline catch-up
	save_blocked = false
	clock.reset()
	_since_autosave = 0.0
	EventBus.game_loaded.emit({})
	return true


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		if ready_ok:
			save()
		get_tree().quit()
