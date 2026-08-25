extends SceneTree
## In-engine bulk tree editing, from templates.
##   godot --headless --script res://tools/tree_generator.gd -- --report
##   godot --headless --script res://tools/tree_generator.gd -- --retune --write
##
## Flags:
##   --report          print per-constellation statistics and exit
##   --validate        run the validator and exit non-zero on failure
##   --retune          apply the RETUNE table below to every matching node
##   --write           actually write the JSON back (otherwise it is a dry run)
##
## The first-pass generation that produced the committed tree lives in
## tools/gen_tree.py — one generator, run once. This is the tool for the
## thing that actually happens repeatedly: sweeping costs and luminance
## across 290 nodes without hand-editing 290 entries.

func _initialize() -> void:
	var args: Dictionary = {}
	for a in OS.get_cmdline_user_args():
		var kv: PackedStringArray = a.lstrip("-").split("=")
		args[kv[0]] = kv[1] if kv.size() == 2 else "1"
	var worker: Object = load("res://tools/tree_generator_worker.gd").new()
	var code: int = int(worker.call("run", args))
	quit(code)
