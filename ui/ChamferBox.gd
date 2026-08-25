class_name ChamferBox
extends StyleBox
## The frame every panel in the game shares: a chamfered rectangle with
## corner ticks and an accent rule down the left edge. One shape, used
## everywhere, is what makes the interface read as a single system rather
## than a pile of boxes.

@export var fill: Color = Color(0.043, 0.055, 0.075, 0.93)
@export var edge: Color = Color(0.24, 0.36, 0.44, 0.90)
@export var accent: Color = Color(0.40, 0.88, 0.78)
@export var chamfer: float = 9.0
@export var accent_width: float = 2.0
@export var ticks: bool = true
@export var pad: float = 11.0

func _init(p_fill: Color = fill, p_edge: Color = edge, p_accent: Color = accent) -> void:
	fill = p_fill
	edge = p_edge
	accent = p_accent
	_apply_padding()

## The built-in content margins take priority over _get_style_margin, so set
## them directly or the frame draws over its own contents.
func _apply_padding() -> void:
	content_margin_left = pad + accent_width + 4.0
	content_margin_right = pad
	content_margin_top = pad * 0.85
	content_margin_bottom = pad * 0.85

func set_pad(v: float) -> void:
	pad = v
	_apply_padding()

func _outline(r: Rect2) -> PackedVector2Array:
	var c: float = minf(chamfer, minf(r.size.x, r.size.y) * 0.4)
	var x0: float = r.position.x
	var y0: float = r.position.y
	var x1: float = r.position.x + r.size.x
	var y1: float = r.position.y + r.size.y
	# Top-left and bottom-right are cut; the other two stay square, which
	# gives the frame a direction instead of looking like a stadium.
	return PackedVector2Array([
		Vector2(x0 + c, y0), Vector2(x1, y0), Vector2(x1, y1 - c),
		Vector2(x1 - c, y1), Vector2(x0, y1), Vector2(x0, y0 + c)])

func _draw(to_canvas_item: RID, rect: Rect2) -> void:
	var pts: PackedVector2Array = _outline(rect)
	# A triangle fan, not add_polygon — the latter silently drops concave or
	# degenerate input and the panels came out unfilled.
	var verts := PackedVector2Array()
	var cols := PackedColorArray()
	var idx := PackedInt32Array()
	var centre: Vector2 = rect.position + rect.size * 0.5
	verts.append(centre)
	cols.append(fill)
	for p in pts:
		verts.append(p)
		cols.append(fill)
	for i in range(pts.size()):
		idx.append(0)
		idx.append(1 + i)
		idx.append(1 + (i + 1) % pts.size())
	RenderingServer.canvas_item_add_triangle_array(to_canvas_item, idx, verts, cols)

	var loop: PackedVector2Array = pts.duplicate()
	loop.append(pts[0])
	var edges := PackedColorArray()
	for _i in range(loop.size()):
		edges.append(edge)
	RenderingServer.canvas_item_add_polyline(to_canvas_item, loop, edges, 1.0, true)

	# Accent rule down the left, stopping short of the chamfer.
	var c: float = minf(chamfer, minf(rect.size.x, rect.size.y) * 0.4)
	var ax: float = rect.position.x + 2.0
	RenderingServer.canvas_item_add_line(to_canvas_item,
		Vector2(ax, rect.position.y + c + 2.0),
		Vector2(ax, rect.position.y + rect.size.y - 3.0),
		accent, accent_width, true)

	if not ticks:
		return
	# Corner ticks on the two square corners.
	var t: float = 7.0
	var tc: Color = accent
	tc.a = 0.8
	var tr := Vector2(rect.position.x + rect.size.x, rect.position.y)
	RenderingServer.canvas_item_add_line(to_canvas_item, tr - Vector2(t, 0), tr, tc, 1.0, true)
	RenderingServer.canvas_item_add_line(to_canvas_item, tr, tr + Vector2(0, t), tc, 1.0, true)
	var bl := Vector2(rect.position.x, rect.position.y + rect.size.y)
	RenderingServer.canvas_item_add_line(to_canvas_item, bl - Vector2(0, t), bl, tc, 1.0, true)
	RenderingServer.canvas_item_add_line(to_canvas_item, bl, bl + Vector2(t, 0), tc, 1.0, true)
