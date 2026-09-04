extends SceneTree
## Checks the music layers and the live mix against the real Audio autoload.
##   godot --headless --script res://tools/dev/MusicProbe.gd
##
## Split in two like the other probes: a --script main loop is compiled
## before the autoloads register, so it cannot name them directly.

var _started: bool = false

func _process(_d: float) -> bool:
	if _started:
		return false
	_started = true
	var script: Variant = load("res://tools/dev/music_checks.gd")
	if script == null or not (script is GDScript):
		printerr("music_checks.gd failed to load")
		quit(1)
		return true
	quit(int((script as GDScript).new().call("run", self)))
	return true
