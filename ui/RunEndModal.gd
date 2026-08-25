extends Control
## Run end and voluntary retire share one screen, because they are the same
## decision made at different times.

signal confirmed()

var _body: VBoxContainer

func _ready() -> void:
	visible = false
	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.01, 0.012, 0.02, 0.93)
	add_child(dim)
	var panel := UITheme.make_panel()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.position = Vector2(-250, -180)
	panel.custom_minimum_size = Vector2(500, 0)
	add_child(panel)
	_body = VBoxContainer.new()
	_body.add_theme_constant_override("separation", 6)
	panel.add_child(_body)

func open_modal(died: bool, reason: String = "") -> void:
	for c in _body.get_children():
		c.queue_free()
	visible = true
	var s: GameStateData = GameState.s

	if died:
		_body.add_child(UITheme.label("RUN OVER", UITheme.BAD, 24))
		_body.add_child(UITheme.label(reason, UITheme.TEXT, 13))
	else:
		_body.add_child(UITheme.label("END THIS RUN?", UITheme.EMBERS, 24))
	var blurb := UITheme.label(
		"Your skill tree resets and you start again at level 1. Embers do not "
		+ "reset — they buy permanent upgrades that make every future run "
		+ "stronger, and each run opens a new part of the ember tree.",
		UITheme.TEXT_DIM, 12)
	blurb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	blurb.custom_minimum_size = Vector2(476, 0)
	_body.add_child(blurb)
	_body.add_child(HSeparator.new())

	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 40)
	_body.add_child(grid)
	grid.add_child(UITheme.label("Level reached", UITheme.TEXT_DIM, 12))
	grid.add_child(UITheme.label("%d   (best %d)" % [s.level, s.best_level],
		UITheme.TEXT_BRIGHT, 13))
	grid.add_child(UITheme.label("Time played", UITheme.TEXT_DIM, 12))
	grid.add_child(UITheme.label(UITheme.fmt_time(s.t), UITheme.TEXT, 12))
	grid.add_child(UITheme.label("Motes this run", UITheme.TEXT_DIM, 12))
	grid.add_child(UITheme.label(UITheme.fmt(s.total_motes_this_run), UITheme.MOTES, 12))
	grid.add_child(UITheme.label("Peak luminance", UITheme.TEXT_DIM, 12))
	grid.add_child(UITheme.label(UITheme.fmt(s.luminance), UITheme.LUM, 12))

	var gained: float = GameState.embers_on_retire() if not died else GameState.embers_on_death()
	grid.add_child(UITheme.label("Embers you keep", UITheme.TEXT_DIM, 13))
	grid.add_child(UITheme.label("+" + UITheme.fmt(gained), UITheme.EMBERS, 16))
	if not died:
		grid.add_child(UITheme.label("If you died instead", UITheme.TEXT_DIM, 11))
		grid.add_child(UITheme.label(UITheme.fmt(GameState.embers_on_death()),
			UITheme.TEXT_DIM, 11))

	if GameState.next_section() != &"":
		_body.add_child(UITheme.label(
			"A new section of the ember tree opens.", UITheme.GOOD, 12))

	_body.add_child(HSeparator.new())
	var go := UITheme.button("Spend embers and start a new run", UITheme.TEXT_BRIGHT)
	go.custom_minimum_size = Vector2(0, 34)
	go.pressed.connect(func():
		visible = false
		confirmed.emit())
	_body.add_child(go)

	if not died:
		var stay := UITheme.button("Not yet — keep playing this run", UITheme.TEXT_DIM)
		stay.custom_minimum_size = Vector2(0, 28)
		stay.pressed.connect(func(): visible = false)
		_body.add_child(stay)
