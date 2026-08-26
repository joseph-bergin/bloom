extends RefCounted
## What must hold between the menus and the sim. See PauseProbe.gd.

var _fails: int = 0

func run(main: Node) -> int:
	var settings: Control = main.get_node("UILayer/Modals/SettingsPanel")
	var field: Node2D = main.get_node("FieldView")

	settings.visible = false
	main._process(0.0)
	_ok(not GameState.paused, "no menu open: the sim runs")
	_ok(field.aiming_enabled, "no menu open: the player aims")

	settings.visible = true
	main._process(0.0)
	_ok(GameState.paused, "pause menu open: the sim is paused")
	_ok(not field.aiming_enabled, "pause menu open: aiming is off")
	# The bug this file exists for: aiming falls back to auto behind a menu,
	# so if the sim is still ticking the turret plays the game for you.
	_ok(not (GameState.s.aim_auto and not GameState.paused),
		"auto-aim never runs while the sim is live")

	settings.visible = false
	main._process(0.0)
	_ok(not GameState.paused, "menu closed: the sim resumes")

	print("%d checks failed" % _fails)
	return 1 if _fails > 0 else 0

func _ok(cond: bool, msg: String) -> void:
	if cond:
		print("  ok   ", msg)
	else:
		_fails += 1
		printerr("  FAIL ", msg)
