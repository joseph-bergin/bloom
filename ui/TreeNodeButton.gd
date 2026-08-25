class_name TreeNodeButton
extends Control
## One node: a hexagonal cell with the upgrade's own glyph inside and its
## rank drawn as an arc around the rim. Owned nodes are drawn above 1.0 so
## the glow rig lights them — a well-invested tree should read as a lit
## circuit rather than a diagram.

signal clicked(id: StringName)
signal hovered(id: StringName)

const R := 21.0
const HIT := 24.0

var node_def: TreeNode = null
var rank: int = 0
var state: int = 0        # 0 hidden, 1 silhouette, 2 available, 3 owned
var affordable: bool = false
var show_label: bool = true
var _hover: bool = false
var _kind: TreeIcons.Kind = TreeIcons.Kind.GENERIC
var _t: float = 0.0

func _ready() -> void:
	custom_minimum_size = Vector2(HIT * 2.0, HIT * 2.0)
	size = Vector2(HIT * 2.0, HIT * 2.0)
	mouse_filter = Control.MOUSE_FILTER_STOP

func _process(delta: float) -> void:
	if _hover:
		_t += delta
		queue_redraw()

func bind(n: TreeNode, p_rank: int, p_state: int, p_afford: bool) -> void:
	node_def = n
	rank = p_rank
	state = p_state
	affordable = p_afford
	_kind = TreeIcons.kind_for(n)
	position = n.pos - Vector2(HIT, HIT)
	visible = true
	tooltip_text = _tip()
	queue_redraw()

func _tip() -> String:
	if node_def == null or state <= 1:
		return "Unrevealed"
	var cap: String = "inf" if node_def.is_infinite() else str(node_def.max_rank)
	var s: String = "%s  %d/%s\n%s" % [node_def.display_name, rank, cap, node_def.desc]
	s += "\n" + ("+%.1f light per rank" % node_def.lum if node_def.lum > 0.0 else "no light")
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

func _hex(c: Vector2, r: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in range(6):
		var a: float = TAU * float(i) / 6.0 - PI * 0.5
		pts.append(c + Vector2(cos(a), sin(a)) * r)
	return pts

func _closed(pts: PackedVector2Array) -> PackedVector2Array:
	var out: PackedVector2Array = pts.duplicate()
	out.append(pts[0])
	return out

func _draw() -> void:
	if node_def == null:
		return
	var c := Vector2(HIT, HIT)
	var base: Color = UITheme.branch_colour(node_def.branch)
	var maxed: bool = not node_def.is_infinite() and rank >= node_def.max_rank

	if not show_label:
		# Galaxy view: lit points only.
		draw_circle(c, 4.5 if state == 3 else 3.0,
			base * (1.7 if state == 3 else (0.55 if state == 2 else 0.24)))
		return

	var hex: PackedVector2Array = _hex(c, R)

	if state == 1:
		# Fog: the shape is there, the detail is not.
		draw_colored_polygon(hex, Color(0.048, 0.058, 0.076))
		draw_polyline(_closed(hex), base * 0.45, 1.2, true)
		return

	if state == 3:
		var depth: float = clampf(float(rank) / maxf(float(node_def.max_rank), 6.0), 0.0, 1.0)
		var glow: float = 0.95 + depth * 0.55 + (0.14 if maxed else 0.0)
		draw_colored_polygon(hex, base * (0.26 + depth * 0.20))
		draw_polyline(_closed(hex), base * (glow + 0.55), 2.0, true)
		# The glyph stays near 1.0 — a heavier multiplier clips the branch
		# colour out of it and every owned node comes out white.
		TreeIcons.draw_icon(self, _kind, c, R * 0.52,
			base.lerp(Color(1, 1, 1), 0.20) * (0.95 + depth * 0.35))
		if maxed:
			# A full node gets a second rim so it reads as done at a glance.
			draw_polyline(_closed(_hex(c, R + 5.0)), base * 0.9, 1.2, true)
	else:
		draw_colored_polygon(hex, Color(0.050, 0.062, 0.082))
		draw_polyline(_closed(hex), base * (1.5 if affordable else 0.7),
			1.8 if affordable else 1.2, true)
		TreeIcons.draw_icon(self, _kind, c, R * 0.52,
			base * (1.1 if affordable else 0.42))

	_draw_rank(c, base)

	if _hover:
		var pulse: float = 1.0 + 0.06 * sin(_t * 6.0)
		draw_polyline(_closed(_hex(c, (R + 7.0) * pulse)), Color(1, 1, 1) * 1.5, 1.4, true)

	var f: Font = ThemeDB.fallback_font
	var col: Color = UITheme.TEXT_BRIGHT if state == 3 else (
		UITheme.TEXT if affordable else UITheme.TEXT_FAINT)
	var txt: String = node_def.display_name
	var w: float = f.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, UITheme.TINY).x
	draw_string(f, Vector2(HIT - w * 0.5, HIT + R + 18.0), txt,
		HORIZONTAL_ALIGNMENT_LEFT, -1, UITheme.TINY, col)

## Rank as an arc gauge around the cell. A row of countable dots read as
## noise at any sensible zoom; a filled arc reads instantly.
func _draw_rank(c: Vector2, base: Color) -> void:
	if node_def.is_infinite():
		if rank > 0:
			var f: Font = ThemeDB.fallback_font
			var t: String = "x%d" % rank
			var w: float = f.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, UITheme.TINY).x
			draw_string(f, Vector2(HIT - w * 0.5, HIT + R + 32.0), t,
				HORIZONTAL_ALIGNMENT_LEFT, -1, UITheme.TINY, base * 1.3)
		return
	var total: int = node_def.max_rank
	if total <= 1:
		return
	var rr: float = R + 5.0
	var start: float = -PI * 0.5
	draw_arc(c, rr, start, start + TAU, 40, base * 0.22, 2.0, true)
	if rank > 0:
		draw_arc(c, rr, start, start + TAU * (float(rank) / float(total)), 40,
			base * 1.7, 2.6, true)
