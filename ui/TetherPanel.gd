extends Control
## Slack meters, tribute rates, reassert buttons.
## Losing a tether must feel like a bill coming due, not bad luck — so the
## bill is always on screen.

signal reassert_requested(id: int)
signal release_requested(id: int)

var _rows: VBoxContainer
var _summary: Label
var _refresh: float = 0.0

func _ready() -> void:
	var panel := UITheme.make_panel()
	panel.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	panel.position = Vector2(14, -300)
	panel.custom_minimum_size = Vector2(252, 0)
	panel.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 3)
	panel.add_child(col)
	col.add_child(UITheme.label("TETHERS", UITheme.TEXT_DIM, 11))
	_summary = UITheme.label("", UITheme.TEXT_DIM, 11)
	col.add_child(_summary)
	_rows = VBoxContainer.new()
	_rows.add_theme_constant_override("separation", 4)
	col.add_child(_rows)

func _process(delta: float) -> void:
	visible = not GameState.data.tethers.is_empty()
	if not visible:
		return
	_refresh -= delta
	if _refresh <= 0.0:
		_refresh = 0.2
		_render()

func _render() -> void:
	for c in _rows.get_children():
		c.queue_free()
	var d: GameStateData = GameState.data
	var income: float = 0.0
	for t in d.tethers:
		income += Tethers.tribute_rate(t)
	_summary.text = "%d / %d capacity   %s motes/s   slack +%.3f/s" % [
		d.tethers.size(), Stats.tether_capacity, UITheme.fmt(income, 1), Tethers.slack_rate(d)]

	for t in d.tethers:
		_rows.add_child(_row(d, t))

func _row(d: GameStateData, t: Tether) -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 1)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 6)
	box.add_child(head)
	var col: Color = UITheme.TEXT
	if t.slack >= Constants.TETHER_WARN_2:
		col = UITheme.BAD
	elif t.slack >= Constants.TETHER_WARN_1:
		col = UITheme.WARN
	head.add_child(UITheme.label("#%d T%d  %s/s" % [t.contact_id, t.tier,
		UITheme.fmt(Tethers.tribute_rate(t), 1)], col, 12))

	var bar := ProgressBar.new()
	bar.custom_minimum_size = Vector2(228, 6)
	bar.show_percentage = false
	bar.max_value = 1.0
	bar.value = t.slack
	var fill := StyleBoxFlat.new()
	fill.bg_color = col
	bar.add_theme_stylebox_override("fill", fill)
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.10, 0.10, 0.12)
	bar.add_theme_stylebox_override("background", bg)
	box.add_child(bar)

	var acts := HBoxContainer.new()
	acts.add_theme_constant_override("separation", 4)
	box.add_child(acts)
	var cost: float = Tethers.reassert_cost(t)
	var re := UITheme.button("Reassert  %s sig" % UITheme.fmt(cost), UITheme.SIGNAL)
	re.custom_minimum_size = Vector2(150, 22)
	re.disabled = d.signal_c < cost
	re.tooltip_text = "Resets slack. Adds %d transient luminance." % int(Constants.TRANSIENT_REASSERT)
	re.pressed.connect(func(): reassert_requested.emit(t.contact_id))
	acts.add_child(re)
	var rel := UITheme.button("Drop", UITheme.TEXT_DIM)
	rel.custom_minimum_size = Vector2(60, 22)
	rel.pressed.connect(func(): release_requested.emit(t.contact_id))
	acts.add_child(rel)
	return box
