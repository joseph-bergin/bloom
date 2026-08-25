extends Node2D
## Red squares that move inward. One layer, one batched draw — no node per
## contact, which is what lets a few hundred of them stay cheap.

const TIER_COLOUR: Array[Color] = [
	Color(0.85, 0.32, 0.30), Color(0.90, 0.42, 0.28), Color(0.94, 0.55, 0.26),
	Color(0.96, 0.36, 0.42), Color(0.92, 0.28, 0.55), Color(0.80, 0.30, 0.75),
	Color(0.62, 0.36, 0.92), Color(0.45, 0.50, 1.00)]

func _process(_delta: float) -> void:
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
		var col: Color = TIER_COLOUR[clampi(c.tier, 0, 7)]
		var hurt: float = c.hp / maxf(c.max_hp, 0.001)
		# Brightness falls as it takes damage, so you can read the field
		# without reading any numbers.
		_add_square(pts, cols, idx, c.pos, c.radius, col * (0.9 + hurt * 0.9))
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
