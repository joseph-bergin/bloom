extends Node2D
## Red squares that move inward. One layer, one batched draw — no node per
## contact, which is what lets a few hundred of them stay cheap.

var _t: float = 0.0

func _process(delta: float) -> void:
	_t += delta
	queue_redraw()

func _draw() -> void:
	var s: GameStateData = GameState.s
	if s.contacts.is_empty():
		return
	var pts := PackedVector2Array()
	var cols := PackedColorArray()
	var idx := PackedInt32Array()
	var bars := PackedVector2Array()
	var bar_cols := PackedColorArray()

	var boss: Contact = null
	for c in s.contacts:
		if c.is_boss:
			boss = c
			continue
		var col: Color = UITheme.tier_colour(c.tier)
		var hurt: float = c.hp / maxf(c.max_hp, 0.001)
		# Brightness falls as it takes damage, so you can read the field
		# without reading any numbers. Kept near 1.0 so the tier colour
		# survives the bloom instead of clipping to a white core.
		var shade: Color = col * (0.62 + hurt * 0.48)
		if c.flash > 0.0:
			shade = shade.lerp(Color(1.0, 0.98, 0.9), c.flash * 0.75) * (1.0 + c.flash * 0.9)
		_add_square(pts, cols, idx, c.pos, c.radius, shade)
		if hurt < 0.999:
			var w: float = c.radius * 1.6
			var y: float = c.pos.y - c.radius - 5.0
			bars.append(Vector2(c.pos.x - w, y))
			bars.append(Vector2(c.pos.x - w + 2.0 * w * hurt, y))
			bar_cols.append(Color(1.0, 0.85, 0.6) * 1.5)

	if not idx.is_empty():
		RenderingServer.canvas_item_add_triangle_array(get_canvas_item(), idx, pts, cols)
	if not bars.is_empty():
		draw_multiline_colors(bars, bar_cols, 2.0)
	if boss != null:
		_draw_boss(boss)

## The boss must be unmistakable at a glance: bigger, rotating, ringed.
func _draw_boss(c: Contact) -> void:
	var hurt: float = c.hp / maxf(c.max_hp, 0.001)
	var col: Color = UITheme.tier_colour(c.tier) * (0.70 + hurt * 0.55)
	if c.flash > 0.0:
		col = col.lerp(Color(1.0, 0.98, 0.9), c.flash * 0.6) * (1.0 + c.flash * 0.7)
	var r: float = c.radius
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
	# Its own health ring, so progress is readable without the top bar.
	draw_arc(c.pos, ring, -PI * 0.5, -PI * 0.5 + TAU * hurt, 40,
		Color(1.0, 0.55, 0.35) * 1.25, 3.0, true)

func _add_square(pts: PackedVector2Array, cols: PackedColorArray,
		idx: PackedInt32Array, centre: Vector2, r: float, col: Color) -> void:
	var base: int = pts.size()
	pts.append(centre + Vector2(-r, -r))
	pts.append(centre + Vector2(r, -r))
	pts.append(centre + Vector2(r, r))
	pts.append(centre + Vector2(-r, r))
	for _i in range(4):
		cols.append(col)
	idx.append(base); idx.append(base + 1); idx.append(base + 2)
	idx.append(base); idx.append(base + 2); idx.append(base + 3)
