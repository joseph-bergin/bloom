extends SceneTree
## Headless balance runner.
##   godot --headless --script res://tools/sim_runner.gd -- --minutes=30
##
## Flags:
##   --minutes=N   simulated minutes per run (default 30)
##   --seed=N      RNG seed (default 1234)
##   --runs=N      runs per build, averaged (default 1)
##   --build=NAME  mixed | burn | shroud | reach | root | none | all
##   --out=PATH    CSV destination (default user://sweep.csv)
##   --set=KEY=VAL override any value in Constants for this run
##
## Under --script the engine loads this file before autoloads attach, so it
## may not reference them or any sim class. The worker does its own setup.

func _initialize() -> void:
	var args: Dictionary = {}
	for a in OS.get_cmdline_user_args():
		var kv: PackedStringArray = a.lstrip("-").split("=")
		if kv.size() == 2:
			args[kv[0]] = kv[1]
		elif kv.size() == 3 and kv[0] == "set":
			# --set=KEY=VALUE
			args["set:" + kv[1]] = kv[2]
	var started: int = Time.get_ticks_usec()
	var script: Variant = load("res://tools/sim_worker.gd")
	if script == null or not (script is GDScript):
		# Without this the SceneTree just keeps running and the whole thing
		# looks like a hang instead of the compile error it is.
		printerr("sim_worker.gd failed to load — see the parse errors above")
		quit(1)
		return
	var worker: Object = (script as GDScript).new()
	worker.call("run", args)
	print("elapsed: %.0f ms" % (float(Time.get_ticks_usec() - started) / 1000.0))
	quit()
