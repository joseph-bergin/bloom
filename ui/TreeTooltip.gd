extends Control
## The node readout: sprite and name, what it does, the rank you are on,
## and a bar showing what you hold against what the next rank costs.
##
## It follows the cursor rather than living in a corner, so the thing you
## are reading about is never across the screen from the words.

const W := 300.0
const OFFSET := Vector2(20, 14)

var _panel: PanelContainer
var _icon: Control
var _name: Label
var _desc: Label
var _light: Label
var _level: Label
var _bar: ProgressBar
var _cost: Label
var _kind: TreeIcons.Kind = TreeIcons.Kind.GENERIC
var _colour: Color = UITheme.TEXT
var _node: TreeNode = null

func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel = UITheme.make_panel(UITheme.LIGHT)
	_panel.custom_minimum_size = Vector2(W, 0)
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_panel)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 5)
	_panel.add_child(col)

	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 8)
	col.add_child(head)
	_icon = Control.new()
	_icon.custom_minimum_size = Vector2(26, 26)
	_icon.draw.connect(_draw_icon)
	head.add_child(_icon)
	_name = UITheme.label("", UITheme.TEXT_BRIGHT, UITheme.BODY)
	_name.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(_name)

	col.add_child(UITheme.rule())
	_desc = UITheme.wrapped("", UITheme.TEXT, UITheme.TINY, W - 32.0)
	col.add_child(_desc)
	_light = UITheme.label("", UITheme.LIGHT, UITheme.TINY)
	col.add_child(_light)
	col.add_child(UITheme.rule())
	_level = UITheme.label("", UITheme.TEXT_DIM, UITheme.TINY)
	_level.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(_level)
	_bar = UITheme.meter(UITheme.GOOD, 16)
	col.add_child(_bar)
	_cost = UITheme.label("", UITheme.TEXT_BRIGHT, UITheme.TINY)
	_cost.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_cost)

func _draw_icon() -> void:
	TreeIcons.draw_icon(_icon, _kind, Vector2.ZERO, 26.0, _colour * 1.3)

func show_node(n: TreeNode) -> void:
	_node = n
	var s: GameStateData = GameState.s
	var rank: int = int(s.purchased.get(String(n.id), 0))
	_kind = TreeIcons.kind_for(n)
	_colour = UITheme.branch_colour(n.branch)
	_icon.queue_redraw()

	_name.text = n.display_name
	_name.add_theme_color_override("font_color", _colour * 1.3)
	_desc.text = n.desc
	_light.text = ("+%.1f light per rank" % n.lum) if n.lum > 0.0 else "no light"
	_light.add_theme_color_override("font_color",
		UITheme.LIGHT if n.lum > 0.0 else UITheme.GOOD)

	var maxed: bool = not n.is_infinite() and rank >= n.max_rank
	_level.text = "Lv. %d / %s" % [rank, "inf" if n.is_infinite() else str(n.max_rank)]

	if maxed:
		_bar.value = 1.0
		_set_bar(UITheme.LIGHT)
		_cost.text = "MAXED"
		_cost.add_theme_color_override("font_color", UITheme.LIGHT)
	else:
		var cost: float = GameState.next_cost(n)
		var have: float = s.motes
		_bar.value = clampf(have / maxf(cost, 1.0), 0.0, 1.0)
		var can: bool = have >= cost and GameState.requirements_met(n)
		_set_bar(UITheme.GOOD if can else UITheme.BAD)
		# Floored: motes are spent whole, and "862.7" is noise in a pixel panel.
		_cost.text = "%s / %s" % [UITheme.fmt(floorf(have)), UITheme.fmt(cost)]
		_cost.add_theme_color_override("font_color",
			UITheme.TEXT_BRIGHT if can else UITheme.TEXT_DIM)

	if not GameState.requirements_met(n):
		var missing: PackedStringArray = []
		for r in n.requires:
			if int(s.purchased.get(String(r), 0)) <= 0:
				var rn: TreeNode = TreeDB.get_node_def(r)
				missing.append(rn.display_name if rn != null else String(r))
		_level.text = "needs " + ", ".join(missing)
		_level.add_theme_color_override("font_color", UITheme.BAD)
	else:
		_level.add_theme_color_override("font_color", UITheme.TEXT_DIM)

	visible = true

func _set_bar(col: Color) -> void:
	var fill: StyleBoxFlat = _bar.get_theme_stylebox("fill")
	fill.bg_color = col

func hide_node() -> void:
	visible = false
	_node = null

func _process(_delta: float) -> void:
	if not visible:
		return
	# Keep it on screen: flip to the other side of the cursor near an edge.
	var vp: Vector2 = get_viewport_rect().size
	var m: Vector2 = get_viewport().get_mouse_position()
	var s: Vector2 = _panel.size
	var p: Vector2 = m + OFFSET
	if p.x + s.x > vp.x - 8.0:
		p.x = m.x - s.x - OFFSET.x
	if p.y + s.y > vp.y - 8.0:
		p.y = maxf(vp.y - s.y - 8.0, 8.0)
	_panel.position = p.round()
	# The cost sits on the bar, which is the last thing in the panel.
	_cost.position = (p + Vector2(0, s.y - 24.0)).round()
	_cost.size = Vector2(s.x, 16.0)
