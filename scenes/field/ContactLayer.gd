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

	for c in s.contacts:
		# The boss draws above the darkness, on its own layer. Everything
		# past the light simply is not drawn — an outline out there told
		# the player exactly what the dark was supposed to be hiding.
		if c.is_boss or not Sight.can_see(s, c):
			continue
		var col: Color = UITheme.tier_colour(c.tier)
		var hurt: float = c.hp / maxf(c.max_hp, 0.001)
		# Brightness falls as it takes damage, so you can read the field
		# without reading any numbers. Kept near 1.0 so the tier colour
		# survives the bloom instead of clipping to a white core.
		var shade: Color = col * (0.78 + hurt * 0.55)
		if c.flash > 0.0:
			shade = shade.lerp(Color(1.0, 0.98, 0.9), c.flash * 0.75) * (1.0 + c.flash * 0.9)
		# Outline first, body over it: a hot square on a warm ground needs
		# the separation or it dissolves into the light pool.
		_add_square(pts, cols, idx, c.pos, c.radius + 2.0, UITheme.OUTLINE)
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
