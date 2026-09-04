extends RefCounted
## First-run routing: a new player must land on the cutscene, and a
## returning one must not. See IntroProbe.gd.

var _fails: int = 0

func run(tree: SceneTree) -> int:
	var was: bool = SettingsPanel.intro_seen()

	SettingsPanel.mark_intro_seen(false)
	_ok(_lands_on(tree) == "Intro", "a fresh player is routed to the cutscene")

	SettingsPanel.mark_intro_seen(true)
	_ok(_lands_on(tree) == "TitleScreen", "a returning player goes straight to the menu")

	# Skipping used to throw: _finish() changed the scene and the next line
	# called get_viewport() on a node that no longer had one.
	SettingsPanel.mark_intro_seen(false)
	var intro: Node = load("res://scenes/Intro.tscn").instantiate()
	tree.root.add_child(intro)
	var key := InputEventKey.new()
	key.keycode = KEY_SPACE
	key.pressed = true
	intro.call("_unhandled_input", key)
	_ok(bool(intro.get("_done")), "a keypress skips the cutscene")
	intro.queue_free()

	SettingsPanel.mark_intro_seen(was)
	print("%d checks failed" % _fails)
	return 1 if _fails > 0 else 0

## Builds a title screen and reports where it decided to send the player.
func _lands_on(tree: SceneTree) -> String:
	# The guard is per-session, so clear it between the two cases.
	var title_script: GDScript = load("res://scenes/TitleScreen.gd")
	title_script.set("_intro_done", false)
	var title: Node = load("res://scenes/TitleScreen.tscn").instantiate()
	tree.root.add_child(title)
	var redirecting: bool = not title.visible
	title.queue_free()
	return "Intro" if redirecting else "TitleScreen"

func _ok(cond: bool, msg: String) -> void:
	if cond:
		print("  ok   ", msg)
	else:
		_fails += 1
		printerr("  FAIL ", msg)
