class_name TreeNodeButton
extends Control
## One pooled node marker. Purchased nodes draw with HDR colour so a
## well-invested tree looks like a lit constellation.

signal clicked(id: StringName)
signal hovered(id: StringName)

const R := 17.0

var node_def: TreeNode = null
var rank: int = 0
var state: int = 0        # 0 hidden, 1 silhouette, 2 available, 3 owned
var affordable: bool = false
var show_label: bool = true
var _hover: bool = false

func _ready() -> void:
	custom_minimum_size = Vector2(R * 2.0, R * 2.0)
	size = Vector2(R * 2.0, R * 2.0)
	mouse_filter = Control.MOUSE_FILTER_STOP

func bind(n: TreeNode, p_rank: int, p_state: int, p_afford: bool) -> void:
	node_def = n
	rank = p_rank
	state = p_state
	affordable = p_afford
	position = n.pos - Vector2(R, R)
	visible = true
	tooltip_text = _tip()
	queue_redraw()

func _tip() -> String:
	if node_def == null or state <= 1:
		return "Unrevealed"
	var cap: String = "inf" if node_def.is_infinite() else str(node_def.max_rank)
	var s: String = "%s  (%d/%s)\n%s" % [node_def.display_name, rank, cap, node_def.desc]
	if node_def.lum > 0.0:
		s += "\n+%.1f luminance per rank" % node_def.lum
	else:
		s += "\nno luminance"
	return s

func _gui_input(event: InputEvent) -> void:
	if node_def == null or state <= 1:
		return
	if event is InputEventMouseButton and event.pressed \
			and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		clicked.emit(node_def.id)
		accept_event()

func _notification(what: int) -> void:
	if what == NOTIFICATION_MOUSE_ENTER:
		_hover = true
		if node_def != null:
			hovered.emit(node_def.id)
		queue_redraw()
	elif what == NOTIFICATION_MOUSE_EXIT:
		_hover = false
		queue_redraw()

func _draw() -> void:
	if node_def == null:
		return
	var c := Vector2(R, R)
	var base: Color = UITheme.branch_colour(node_def.branch)

	if not show_label:
		# Galaxy view: no labels, no chrome, just lit points.
		draw_circle(c, 4.0 if state == 3 else 3.0,
			base * (1.5 if state == 3 else (0.5 if state == 2 else 0.22)))
		return

	if state == 1:
		# Fog with silhouettes — always half-see what's out there.
		draw_arc(c, R, 0.0, TAU, 22, base * 0.24, 1.0, true)
		return

	if state == 3:
		# Bright enough to bloom, restrained enough to keep its branch colour.
		# Bright enough to bloom, restrained enough that the branch colour
		# survives instead of clipping to white.
		var glow: float = 1.05 + minf(float(rank), 10.0) * 0.07
		draw_circle(c, R * 0.92, base * glow)
		draw_circle(c, R * 0.30, base.lerp(Color(1, 1, 1), 0.35) * glow * 1.2)
	else:
		draw_circle(c, R * 0.9, Color(0.06, 0.07, 0.10))
		draw_arc(c, R, 0.0, TAU, 26, base * (1.5 if affordable else 0.5),
			1.6 if affordable else 1.2, true)

	if node_def.keystone:
		_poly(c, R + 5.0, 6, base * (1.6 if state == 3 else 0.95))
	elif node_def.is_infinite():
		draw_arc(c, R + 3.0, 0.0, TAU, 18, base * 0.45, 1.0, true)

	if _hover:
		draw_arc(c, R + 7.0, 0.0, TAU, 26, Color(1, 1, 1) * 1.4, 1.2, true)

	var f: Font = ThemeDB.fallback_font
	var col: Color = UITheme.TEXT_BRIGHT if state == 3 else (
		UITheme.TEXT if affordable else UITheme.TEXT_DIM)
	var w: float = f.get_string_size(node_def.display_name,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x
	draw_string(f, Vector2(R - w * 0.5, R * 2.0 + 12.0), node_def.display_name,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 11, col)
	var rt: String = ("x%d" % rank) if node_def.is_infinite() \
		else "%d/%d" % [rank, node_def.max_rank]
	var rw: float = f.get_string_size(rt, HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x
	draw_string(f, Vector2(R - rw * 0.5, R * 2.0 + 23.0), rt,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 10, UITheme.TEXT_DIM)

func _poly(c: Vector2, r: float, sides: int, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in range(sides + 1):
		var a: float = -PI * 0.5 + TAU * float(i) / float(sides)
		pts.append(c + Vector2(cos(a), sin(a)) * r)
	draw_polyline(pts, col, 1.4, true)
