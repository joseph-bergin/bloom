extends SceneTree
## godot --headless --script res://tests/test_runner.gd

func _initialize() -> void:
	var script: Variant = load("res://tests/suite.gd")
	# can_instantiate(), not just a null check: load() hands back a GDScript
	# object even when the file failed to parse, so the null guard passed and
	# the SceneTree kept running — a parse error looked exactly like a hang.
	if script == null or not (script is GDScript) \
			or not (script as GDScript).can_instantiate():
		printerr("suite.gd failed to load — see the parse errors above")
		quit(1)
		return
	quit(1 if int((script as GDScript).new().call("run_all")) > 0 else 0)
