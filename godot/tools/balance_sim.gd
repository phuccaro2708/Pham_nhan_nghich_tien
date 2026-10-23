extends SceneTree
## CLI: godot --headless --path godot -s tools/balance_sim.gd -- --seeds=20 [--strategies=casual,optimizer,idle] [--out=path.md]

func _init() -> void:
	var seeds: int = 20
	var strategies: Array = BalanceSimulator.STRATEGIES.duplicate()
	var out: String = ""
	var matrix_v6: bool = false
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--seeds="):
			seeds = int(a.substr(8))
		elif a.begins_with("--strategies="):
			strategies = a.substr(13).split(",")
		elif a.begins_with("--out="):
			out = a.substr(6)
		elif a == "--matrix-v6":
			matrix_v6 = true
	var sim := BalanceSimulator.new()
	var results: Array = []
	if matrix_v6:
		for main in ["thanh_moc_duong_khi", "huyet_luyen_than_kinh", "ngu_hanh_dan_khi"]:
			for explore in [false, true]:
				for sd in range(1, seeds + 1):
					results.append(sim.run("optimizer", sd, main, explore))
	else:
		for st in strategies:
			for sd in range(1, seeds + 1):
				results.append(sim.run(st, sd))
	var text: String = JSON.stringify(results) if matrix_v6 else BalanceSimulator.report(results)
	print(text)
	if out != "":
		var f := FileAccess.open(out, FileAccess.WRITE)
		f.store_string(text)
		f.close()
	quit(0)
