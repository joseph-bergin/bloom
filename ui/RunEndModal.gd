extends Control
## Game over. The level you reached is the score.

signal restart_pressed()

var _body: VBoxContainer

func _ready() -> void:
	visible = false
	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.01, 0.012, 0.02, 0.93)
	add_child(dim)
	var panel := UITheme.make_panel()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.position = Vector2(-230, -170)
	panel.custom_minimum_size = Vector2(460, 0)
	add_child(panel)
	_body = VBoxContainer.new()
	_body.add_theme_constant_override("separation", 6)
	panel.add_child(_body)

func open_modal(reason: String) -> void:
	for c in _body.get_children():
		c.queue_free()
	visible = true
	var s: GameStateData = GameState.s

	_body.add_child(UITheme.label("RUN OVER", UITheme.BAD, 26))
	_body.add_child(UITheme.label(reason, UITheme.TEXT, 13))
	_body.add_child(HSeparator.new())

	var reached := UITheme.label("You reached level %d" % s.level, UITheme.TEXT_BRIGHT, 30)
	reached.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_body.add_child(reached)
	var best: int = maxi(s.best_level, s.level)
	var best_l := UITheme.label(
		"best ever: level %d" % best if best > s.level else "a new best",
		UITheme.GOOD if best <= s.level else UITheme.TEXT_DIM, 14)
	best_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_body.add_child(best_l)

	_body.add_child(HSeparator.new())
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 40)
	_body.add_child(grid)
	grid.add_child(UITheme.label("Time played", UITheme.TEXT_DIM, 12))
	grid.add_child(UITheme.label(UITheme.fmt_time(s.t), UITheme.TEXT, 12))
	grid.add_child(UITheme.label("Motes earned", UITheme.TEXT_DIM, 12))
	grid.add_child(UITheme.label(UITheme.fmt(s.total_motes_this_run), UITheme.MOTES, 12))
	grid.add_child(UITheme.label("Peak luminance", UITheme.TEXT_DIM, 12))
	grid.add_child(UITheme.label(UITheme.fmt(s.luminance), UITheme.LUM, 12))
	grid.add_child(UITheme.label("Nodes built", UITheme.TEXT_DIM, 12))
	grid.add_child(UITheme.label("%d" % s.purchased.size(), UITheme.TEXT, 12))

	_body.add_child(HSeparator.new())
	_body.add_child(UITheme.label(
		"Starting again unbuilds the tree and puts you back on level 1.",
		UITheme.TEXT_DIM, 11))
	var go := UITheme.button("Start again", UITheme.TEXT_BRIGHT)
	go.custom_minimum_size = Vector2(0, 36)
	go.pressed.connect(func():
		visible = false
		restart_pressed.emit())
	_body.add_child(go)
