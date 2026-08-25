extends Control
## Game over. The level you reached is the score.

signal restart_pressed()

var _body: VBoxContainer

func _ready() -> void:
	visible = false
	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(UITheme.VOID.r, UITheme.VOID.g, UITheme.VOID.b, 0.94)
	add_child(dim)
	var pair: Array = UITheme.make_section("run over", UITheme.BAD)
	var panel: PanelContainer = pair[0]
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.position = Vector2(-240, -180)
	panel.custom_minimum_size = Vector2(480, 0)
	add_child(panel)
	_body = pair[1]
	_body.add_theme_constant_override("separation", 6)

func open_modal(reason: String) -> void:
	for c in _body.get_children():
		c.queue_free()
	visible = true
	var s: GameStateData = GameState.s

	_body.add_child(UITheme.label(reason, UITheme.TEXT, UITheme.BODY))
	_body.add_child(UITheme.rule())

	var reached := UITheme.label("You reached level %d" % s.level, UITheme.TEXT_BRIGHT, UITheme.HUGE)
	reached.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_body.add_child(reached)
	var best: int = maxi(s.best_level, s.level)
	var best_l := UITheme.label(
		"best ever: level %d" % best if best > s.level else "a new best",
		UITheme.GOOD if best <= s.level else UITheme.TEXT_DIM, 14)
	best_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_body.add_child(best_l)

	_body.add_child(UITheme.rule())
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 40)
	_body.add_child(grid)
	grid.add_child(UITheme.label("Time played", UITheme.TEXT_DIM, UITheme.TINY))
	grid.add_child(UITheme.label(UITheme.fmt_time(s.t), UITheme.TEXT, UITheme.TINY))
	grid.add_child(UITheme.label("Motes earned", UITheme.TEXT_DIM, UITheme.TINY))
	grid.add_child(UITheme.label(UITheme.fmt(s.total_motes_this_run), UITheme.MOTES, UITheme.TINY))
	grid.add_child(UITheme.label("Peak luminance", UITheme.TEXT_DIM, UITheme.TINY))
	grid.add_child(UITheme.label(UITheme.fmt(s.luminance), UITheme.LUM, UITheme.TINY))
	grid.add_child(UITheme.label("Nodes built", UITheme.TEXT_DIM, UITheme.TINY))
	grid.add_child(UITheme.label("%d" % s.purchased.size(), UITheme.TEXT, UITheme.TINY))

	_body.add_child(UITheme.rule())
	_body.add_child(UITheme.wrapped(
		"Starting again unbuilds the tree and puts you back on level 1.",
		UITheme.TEXT_DIM, 11, 452))
	var go := UITheme.cta("Start again", UITheme.GOOD)
	go.custom_minimum_size = Vector2(0, 40)
	go.pressed.connect(func():
		visible = false
		restart_pressed.emit())
	_body.add_child(go)
