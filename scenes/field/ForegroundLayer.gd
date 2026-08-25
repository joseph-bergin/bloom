extends Node2D
## What stays visible in the dark: the arena and the boss.
##
## Blacking out enemy positions is the point of the darkness. Blacking out
## the walls is just disorienting, so the boundary and its cardinals are
## drawn faintly over the top as a fixed reference — they say where you
## are, never what is coming.

var _t: float = 0.0

func _process(delta: float) -> void:
	_t += delta
	queue_redraw()

func _draw() -> void:
	_draw_horizon()
	_draw_boss()

func _draw_horizon() -> void:
	var R: float = Constants.FIELD_RADIUS
	draw_arc(Vector2.ZERO, R, 0.0, TAU, 96, Color(0.13, 0.20, 0.26, 0.55), 1.4, true)
	var spokes := PackedVector2Array()
	var cols := PackedColorArray()
	for i in range(4):
		var a: float = TAU * float(i) / 4.0
		var d := Vector2(cos(a), sin(a))
		spokes.append(d * (R * 0.90))
		spokes.append(d * R)
		cols.append(Color(0.16, 0.24, 0.30, 0.5))
	draw_multiline_colors(spokes, cols, 1.0)

func _draw_boss() -> void:
	var c: Contact = GameState.s.boss()
	if c == null:
		return
	var hurt: float = c.hp / maxf(c.max_hp, 0.001)
	var col: Color = UITheme.tier_colour(c.tier) * (0.70 + hurt * 0.55)
	if c.flash > 0.0:
		col = col.lerp(Color(1.0, 0.98, 0.9), c.flash * 0.6) * (1.0 + c.flash * 0.7)
	var r: float = c.radius

	# Its own glow, so it lights itself out in the black.
	for i in range(5):
		var t: float = float(i) / 5.0
		draw_circle(c.pos, r * (1.6 + t * 2.4), col * (0.06 * (1.0 - t)))

	var body := PackedVector2Array()
	for i in range(4):
		var a: float = _t * 0.6 + float(i) * PI * 0.5 + PI * 0.25
		body.append(c.pos + Vector2(cos(a), sin(a)) * r)
	draw_colored_polygon(body, col)
	body.append(body[0])
	draw_polyline(body, Color(1.0, 0.72, 0.45) * 1.15, 2.4, true)

	var pulse: float = 1.0 + 0.06 * sin(_t * 4.0)
	var ring: float = r * 1.5 * pulse
	draw_arc(c.pos, ring, 0.0, TAU, 40, Color(0.5, 0.16, 0.14), 2.0, true)
	draw_arc(c.pos, ring, -PI * 0.5, -PI * 0.5 + TAU * hurt, 40,
		Color(1.0, 0.55, 0.35) * 1.25, 3.0, true)
