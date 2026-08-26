extends SceneTree
## Boots the real Main scene and checks the menu/sim wiring, which the unit
## suite cannot reach — its runner is synchronous and never runs a frame.
##   godot --headless --script res://tools/dev/PauseProbe.gd
##
## The checks live in a script this one load()s: a --script main loop is
## compiled before the autoloads register, so naming GameState here is a
## compile error even though it exists by the time a frame runs.

func _initialize() -> void:
	var packed: Variant = load("res://scenes/Main.tscn")
	if packed == null:
		printerr("Main.tscn failed to load")
		quit(1)
		return
	root.add_child((packed as PackedScene).instantiate())

func _process(_d: float) -> bool:
	var script: Variant = load("res://tools/dev/pause_checks.gd")
	if script == null or not (script is GDScript):
		printerr("pause_checks.gd failed to load")
		quit(1)
		return true
	var main: Node = root.get_child(root.get_child_count() - 1)
	quit(int((script as GDScript).new().call("run", main)))
	return true
