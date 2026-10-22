extends SceneTree
## CLI: godot --headless --path godot -s tools/balance_sim.gd -- --seeds=20 [--strategies=casual,optimizer,idle] [--out=path.md]

func _init() -> void:
	var seeds: int = 20
	var strategies: Array = BalanceSimulator.STRATEGIES.duplicate()
	var out: String = ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--seeds="):
			seeds = int(a.substr(8))
		elif a.begins_with("--strategies="):
			strategies = a.substr(13).split(",")
		elif a.begins_with("--out="):
			out = a.substr(6)
	var sim := BalanceSimulator.new()
	var results: Array = []
	for st in strategies:
		for sd in range(1, seeds + 1):
			results.append(sim.run(st, sd))
	var text: String = BalanceSimulator.report(results)
	print(text)
	if out != "":
		var f := FileAccess.open(out, FileAccess.WRITE)
		f.store_string(text)
		f.close()
	quit(0)
