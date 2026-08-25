extends Control
## Incoming strike warnings and the evasive dispersal option. Only exists
## once Optics can see them coming — before that, this panel is empty and
## strikes arrive out of nowhere.

var _rows: VBoxContainer
var _root: PanelContainer

func _ready() -> void:
	_root = UITheme.make_panel(Vector2(300, 0))
	_root.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_root.position = Vector2(-150, 14)
	_root.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(_root)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 3)
	_root.add_child(col)
	col.add_child(UITheme.label("INCOMING", UITheme.BAD, 12))
	_rows = VBoxContainer.new()
	_rows.add_theme_constant_override("separation", 3)
	col.add_child(_rows)
	visible = false

func _process(_delta: float) -> void:
	var d: GameStateData = GameState.data
	var any: bool = false
	for s in d.incoming:
		if s.detected:
			any = true
			break
	visible = any
	if any:
		_render(d)

func _render(d: GameStateData) -> void:
	for c in _rows.get_children():
		c.queue_free()
	for s in d.incoming:
		if not s.detected:
			continue
		var left: float = s.arrives_at - d.t
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		row.add_child(UITheme.label("T%d  bearing %d  %.1fs" %
			[s.tier, int(rad_to_deg(fposmod(s.bearing, TAU))), maxf(left, 0.0)], UITheme.BAD, 12))
		var b := UITheme.button("Disperse  %d sig" % int(Constants.DISPERSAL_COST_SIGNAL),
			UITheme.SIGNAL)
		b.custom_minimum_size = Vector2(112, 22)
		b.disabled = not Threat.can_disperse(d, s)
		b.pressed.connect(func(): GameState.try_disperse(s))
		row.add_child(b)
		_rows.add_child(row)
