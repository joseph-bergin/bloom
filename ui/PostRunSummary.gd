extends Control
## Tells the causal story every time. If players cannot trace a run-ending
## strike back to a decision, the game reads as unfair.

signal ember_chosen()

var _body: VBoxContainer

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	visible = false
	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.01, 0.012, 0.02, 0.93)
	add_child(dim)
	var panel := UITheme.make_panel(Vector2(600, 0))
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.position = Vector2(-300, -230)
	add_child(panel)
	_body = VBoxContainer.new()
	_body.add_theme_constant_override("separation", 5)
	panel.add_child(_body)

func show_run(reason: String) -> void:
	for c in _body.get_children():
		c.queue_free()
	var d: GameStateData = GameState.data
	visible = true

	var t := UITheme.label("EVERYTHING ENDS", UITheme.BAD, 22)
	_body.add_child(t)
	_body.add_child(UITheme.label(reason, UITheme.TEXT, 14))
	_body.add_child(HSeparator.new())

	_body.add_child(UITheme.label("HOW IT HAPPENED", UITheme.TEXT_DIM, 11))
	var chain: Array = d.causal_log
	if chain.is_empty():
		_body.add_child(UITheme.label("Nothing was recorded. It was quiet, and then it wasn't.",
			UITheme.TEXT_DIM, 12))
	else:
		var start: int = maxi(chain.size() - 12, 0)
		for i in range(start, chain.size()):
			var e: Dictionary = chain[i]
			_body.add_child(UITheme.label("%s   %s" %
				[UITheme.fmt_time(float(e["t"])), str(e["text"])], UITheme.TEXT_DIM, 12))

	_body.add_child(HSeparator.new())
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 30)
	_body.add_child(grid)
	grid.add_child(UITheme.label("Time alight", UITheme.TEXT_DIM, 12))
	grid.add_child(UITheme.label(UITheme.fmt_time(d.t), UITheme.TEXT, 12))
	grid.add_child(UITheme.label("Motes earned", UITheme.TEXT_DIM, 12))
	grid.add_child(UITheme.label(UITheme.fmt(d.total_motes_earned), UITheme.MOTES, 12))
	grid.add_child(UITheme.label("Peak luminance", UITheme.TEXT_DIM, 12))
	grid.add_child(UITheme.label(UITheme.fmt(d.luminance_effective()), UITheme.LUM, 12))
	grid.add_child(UITheme.label("Field pressure", UITheme.TEXT_DIM, 12))
	grid.add_child(UITheme.label("%.2f" % d.field_pressure, UITheme.TEXT, 12))
	grid.add_child(UITheme.label("Embers carried out", UITheme.TEXT_DIM, 12))
	grid.add_child(UITheme.label(UITheme.fmt(Ember.embers_gained(d), 1), UITheme.EMBERS, 12))

	_body.add_child(HSeparator.new())
	var btn := UITheme.button("Catch somewhere deeper", UITheme.EMBERS)
	btn.custom_minimum_size = Vector2(0, 34)
	btn.pressed.connect(func():
		visible = false
		ember_chosen.emit())
	_body.add_child(btn)
