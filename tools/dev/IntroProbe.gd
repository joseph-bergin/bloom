extends SceneTree
## Checks that the first run routes into the cutscene and later runs do not.
##   godot --headless --script res://tools/dev/IntroProbe.gd
##
## Split in two like PauseProbe: a --script main loop compiles before the
## autoloads register, so it cannot name them directly.

func _process(_d: float) -> bool:
	var script: Variant = load("res://tools/dev/intro_checks.gd")
	if script == null or not (script is GDScript):
		printerr("intro_checks.gd failed to load")
		quit(1)
		return true
	quit(int((script as GDScript).new().call("run", self)))
	return true
