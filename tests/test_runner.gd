extends SceneTree
## godot --headless --script res://tests/test_runner.gd
##
## Same bootstrap constraint as tools/sim_runner.gd: this file loads before
## autoloads are attached, so it may not reference them or any sim class.

func _initialize() -> void:
	var suite: Object = load("res://tests/suite.gd").new()
	var failures: int = int(suite.call("run_all"))
	quit(1 if failures > 0 else 0)
