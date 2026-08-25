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
		_body.add_child(UITheme.label("THE LIGHT GOES OUT", UITheme.BAD, 22))
		_body.add_child(UITheme.label(reason, UITheme.TEXT, 13))
	else:
		_body.add_child(UITheme.label("RETIRE", UITheme.EMBERS, 22))
		_body.add_child(UITheme.label(
			"Bank what you have and start again in a darker, denser field.",
			UITheme.TEXT, 13))
	_body.add_child(HSeparator.new())

	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 40)
	_body.add_child(grid)
	grid.add_child(UITheme.label("Time alight", UITheme.TEXT_DIM, 12))
	grid.add_child(UITheme.label(UITheme.fmt_time(s.t), UITheme.TEXT, 12))
	grid.add_child(UITheme.label("Motes this run", UITheme.TEXT_DIM, 12))
	grid.add_child(UITheme.label(UITheme.fmt(s.total_motes_this_run), UITheme.MOTES, 12))
	grid.add_child(UITheme.label("Peak luminance", UITheme.TEXT_DIM, 12))
	grid.add_child(UITheme.label(UITheme.fmt(s.luminance), UITheme.LUM, 12))

	var gained: float = GameState.embers_on_retire() if not died else GameState.embers_on_death()
	grid.add_child(UITheme.label("Embers banked", UITheme.TEXT_DIM, 13))
	grid.add_child(UITheme.label("+" + UITheme.fmt(gained), UITheme.EMBERS, 15))
	if not died:
		var lost: float = GameState.embers_on_death()
		grid.add_child(UITheme.label("Had you died", UITheme.TEXT_DIM, 11))
		grid.add_child(UITheme.label(UITheme.fmt(lost), UITheme.TEXT_DIM, 11))

	var section: StringName = GameState.next_section()
	if section != &"":
		_body.add_child(UITheme.label(
			"A new section of the tree opens.", UITheme.GOOD, 12))

	_body.add_child(HSeparator.new())
	var go := UITheme.button("Begin again", UITheme.TEXT_BRIGHT)
	go.custom_minimum_size = Vector2(0, 34)
	go.pressed.connect(func():
		visible = false
		confirmed.emit())
	_body.add_child(go)

	if not died:
		var stay := UITheme.button("Keep burning", UITheme.TEXT_DIM)
		stay.custom_minimum_size = Vector2(0, 28)
		stay.pressed.connect(func(): visible = false)
		_body.add_child(stay)
