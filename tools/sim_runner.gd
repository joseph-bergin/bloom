extends SceneTree
## Headless balance harness entry point.
##   godot --headless --script res://tools/sim_runner.gd -- --minutes=60
##
## Flags:
##   --minutes=N      simulated minutes (default 60)
##   --dt=F           tick length in seconds (default 0.0166667, i.e. 60Hz)
##   --sample=N       seconds between CSV rows (default 10)
##   --seed=N         RNG seed (default 12345)
##   --build=NAME     balanced | greedy | turtle | none (default balanced)
##   --out=PATH       CSV destination (default user://sweep.csv)
##   --backlight=N    instead of a run, roll N snuffs and report observed rate
##
## Under --script the engine loads this file before autoloads are attached to
## the tree, so nothing here may reference them — or any sim class, which
## would pull them in transitively. The worker is loaded at runtime and does
## its own initialisation.

func _initialize() -> void:
	var args: Dictionary = {}
	for a in OS.get_cmdline_user_args():
		var kv: PackedStringArray = a.lstrip("-").split("=")
		if kv.size() == 2:
			args[kv[0]] = kv[1]
	var started: int = Time.get_ticks_usec()
	var worker: Object = load("res://tools/sim_worker.gd").new()
	worker.call("run", args)
	print("elapsed: %.1f ms" % (float(Time.get_ticks_usec() - started) / 1000.0))
	quit()
