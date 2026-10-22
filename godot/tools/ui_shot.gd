extends SceneTree
## Dev tool (windowed, not headless): godot --path godot --resolution 1280x720 -s tools/ui_shot.gd -- --out=DIR
## Loads the main scene in a few staged states and saves one PNG per page.

var out_dir: String = "user://shots"


func _init() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out_dir = a.substr(6)
	DirAccess.make_dir_recursive_absolute(out_dir)
	_run.call_deferred()


func _shot(name: String) -> void:
	await process_frame
	await process_frame
	await create_timer(0.4).timeout
	root.get_texture().get_image().save_png("%s/%s.png" % [out_dir, name])


func _run() -> void:
	await process_frame
	var gc: Node = root.get_node("GameController")
	gc.new_game(5)
	change_scene_to_file("res://scenes/main.tscn")
	await create_timer(0.6).timeout
	var ui: Node = current_scene
	var pages: TabContainer = ui.find_child("*", true, false) if false else _find_tabs(ui)
	var s: GameState = gc.state
	s.flags["tutorial_started"] = true
	for id in gc.registry.resources:
		s.resources[id] = float(gc.registry.resources[id].get("initial", 0.0))
	s.resources["wood"] = 12.0
	gc.start_action("gather_wood")
	gc.actions.advance(s, 120)
	await _shot("1_main")
	s.action_counts["gather_wood"] = 3
	gc.actions.story.scan(s)
	await _shot("2_story_pending")
	gc.choose_story("give_wood")
	pages.current_tab = 1
	await _shot("3_story_history")
	s.mastery["gather_wood"] = {"level": 4, "xp": 12.0, "claimed": [3]}
	s.mastery["train_body"] = {"level": 2, "xp": 5.0, "claimed": []}
	pages.current_tab = 2
	await _shot("4_mastery")
	pages.current_tab = 3
	await _shot("5_auto_locked")
	s.mastery["gather_wood"]["level"] = 5
	pages.current_tab = 3
	await _shot("6_auto")
	s.realm_id = "luyen_khi_1"
	s.techniques.append("dan_khi_nhap_mon")
	s.resources["cultivation"] = 120.0
	pages.current_tab = 4
	await _shot("7_cultivation")
	quit(0)


func _find_tabs(n: Node) -> TabContainer:
	if n is TabContainer:
		return n
	for c in n.get_children():
		var r: TabContainer = _find_tabs(c)
		if r != null:
			return r
	return null
