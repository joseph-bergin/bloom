class_name TreeNodeButton
extends Control
## One pooled node marker. Purchased nodes draw with HDR colour so they glow
## inside the tree view too — a heavily-invested tree should look like a lit
## constellation, and that image is the reward.

signal clicked(id: StringName)
signal hovered(id: StringName)

const R := 17.0

var node_def: TreeNode = null
var rank: int = 0
var state: int = 0        # 0 hidden, 1 silhouette, 2 available, 3 owned, 4 blighted, 5 locked
var affordable: bool = false
var show_label: bool = true
var dot_mode: bool = false
var _hover: bool = false

func _ready() -> void:
	custom_minimum_size = Vector2(R * 2.0, R * 2.0)
	size = Vector2(R * 2.0, R * 2.0)
	pivot_offset = Vector2(R, R)
	mouse_filter = Control.MOUSE_FILTER_STOP

func bind(n: TreeNode, p_rank: int, p_state: int, p_afford: bool) -> void:
	node_def = n
	rank = p_rank
	state = p_state
	affordable = p_afford
	position = n.pos - Vector2(R, R)
	visible = true
	tooltip_text = _tooltip()
	queue_redraw()

func _tooltip() -> String:
	if node_def == null:
		return ""
	if state <= 1:
		return "Unrevealed"
	var cap: String = "inf" if node_def.is_infinite() else str(node_def.max_rank)
	var s: String = "%s  (%d/%s)\n%s" % [node_def.display_name, rank, cap, node_def.desc]
	if node_def.lum > 0.0:
		s += "\n+%.1f luminance per rank" % node_def.lum
	if state == 4:
		s += "\nBLIGHTED — effects suspended"
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
	var c: Vector2 = Vector2(R, R)
	var base: Color = UITheme.constellation_colour(node_def.constellation)

	if dot_mode:
		# Readable galaxy view: no labels, no chrome, just lit points.
		var lit: float = 1.5 if state == 3 else (0.5 if state == 2 else 0.22)
		draw_circle(c, 4.0 if state == 3 else 3.0, base * lit)
		return

	match state:
		1:
			# Fog with silhouettes. The player should always half-see what's
			# out there and want it.
			draw_arc(c, R, 0.0, TAU, 24, base * 0.22, 1.0, true)
			return
		4:
			# Necrotic: desaturated, cracked, no glow.
			draw_circle(c, R * 0.85, UITheme.NECROTIC)
			draw_arc(c, R, 0.0, TAU, 24, UITheme.NECROTIC * 1.4, 1.4, true)
			for i in range(3):
				var a: float = float(i) * 2.1
				draw_line(c + Vector2(cos(a), sin(a)) * 4.0,
					c + Vector2(cos(a + 1.0), sin(a + 1.0)) * R, Color(0.15, 0.12, 0.16), 1.6, true)
			return
		5:
			draw_arc(c, R, 0.0, TAU, 24, UITheme.NECROTIC * 0.9, 1.0, true)
			draw_line(c + Vector2(-5, -5), c + Vector2(5, 5), UITheme.NECROTIC * 1.2, 1.4, true)
			return

	var owned: bool = state == 3
	if owned:
		# Bright enough to bloom, restrained enough that the constellation
		# colour survives instead of clipping to white. A heavily-invested
		# tree should read as a lit constellation, not a field of dots.
		var glow: float = 1.15 + minf(float(rank), 8.0) * 0.09
		draw_circle(c, R * 0.92, base * glow)
		draw_circle(c, R * 0.34, base.lerp(Color(1, 1, 1), 0.6) * (glow * 1.15))
	else:
		draw_circle(c, R * 0.9, Color(0.06, 0.07, 0.10))
		draw_arc(c, R, 0.0, TAU, 28,
			base * (1.6 if affordable else 0.55), 1.6 if affordable else 1.2, true)

	# Kind is shape, not colour: keystones are hexes, bridges diamonds.
	match node_def.kind:
		TreeNode.Kind.KEYSTONE:
			_poly(c, R + 4.0, 6, base * (1.5 if owned else 0.9))
		TreeNode.Kind.BRIDGE:
			_poly(c, R + 4.0, 4, UITheme.FACETS * (1.4 if owned else 0.9))
		TreeNode.Kind.SINK:
			draw_arc(c, R + 3.0, 0.0, TAU, 20, base * 0.5, 1.0, true)
		_:
			pass

	if _hover:
		draw_arc(c, R + 6.0, 0.0, TAU, 28, Color(1, 1, 1) * 1.4, 1.2, true)

	if show_label:
		var f: Font = ThemeDB.fallback_font
		var txt: String = node_def.display_name
		var col: Color = UITheme.TEXT_BRIGHT if owned else (
			UITheme.TEXT if affordable else UITheme.TEXT_DIM)
		var w: float = f.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x
		draw_string(f, Vector2(R - w * 0.5, R * 2.0 + 12.0), txt,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 11, col)
		if not node_def.is_infinite() and node_def.max_rank > 1:
			var rt: String = "%d/%d" % [rank, node_def.max_rank]
			var rw: float = f.get_string_size(rt, HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x
			draw_string(f, Vector2(R - rw * 0.5, R * 2.0 + 23.0), rt,
				HORIZONTAL_ALIGNMENT_LEFT, -1, 10, UITheme.TEXT_DIM)
		elif node_def.is_infinite():
			draw_string(f, Vector2(R - 8.0, R * 2.0 + 23.0), "x%d" % rank,
				HORIZONTAL_ALIGNMENT_LEFT, -1, 10, UITheme.TEXT_DIM)

func _poly(c: Vector2, r: float, sides: int, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in range(sides + 1):
		var a: float = -PI * 0.5 + TAU * float(i) / float(sides)
		pts.append(c + Vector2(cos(a), sin(a)) * r)
	draw_polyline(pts, col, 1.4, true)
