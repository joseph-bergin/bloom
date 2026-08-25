extends Node2D

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	var s: GameStateData = GameState.s
	if s.projectiles.is_empty():
		return
	var pts := PackedVector2Array()
	var cols := PackedColorArray()
	for p in s.projectiles:
		var col: Color = Color(1.0, 0.95, 0.7) * (3.4 if p.crit else 2.2)
		pts.append(p.pos)
		pts.append(p.pos - p.vel.normalized() * (11.0 if p.crit else 7.0))
		cols.append(col)
	draw_multiline_colors(pts, cols, 2.0)
