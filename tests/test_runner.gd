extends SceneTree
## godot --headless --script res://tests/test_runner.gd

func _initialize() -> void:
	var script: Variant = load("res://tests/suite.gd")
	if script == null or not (script is GDScript):
		# Otherwise the SceneTree just keeps running and a parse error looks
		# exactly like a hang.
		printerr("suite.gd failed to load — see the parse errors above")
		quit(1)
		return
	quit(1 if int((script as GDScript).new().call("run_all")) > 0 else 0)
