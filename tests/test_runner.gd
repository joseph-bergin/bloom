extends SceneTree
## godot --headless --script res://tests/test_runner.gd

func _initialize() -> void:
	var suite: Object = load("res://tests/suite.gd").new()
	quit(1 if int(suite.call("run_all")) > 0 else 0)
