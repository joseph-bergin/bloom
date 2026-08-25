extends Node2D
## Lances in flight, and the markers left where one found nothing.

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	var data: GameStateData = GameState.data
	var t: float = data.t
	for l in data.lances:
		var p: Vector2 = l.position(t)
		var tail: Vector2 = l.origin.lerp(l.aim, maxf(l.progress(t) - 0.09, 0.0))
		draw_line(tail, p, Color(1.0, 0.86, 0.55) * 2.4, 2.0, true)
		draw_circle(p, 3.0, Color(1.0, 0.95, 0.8) * 3.2)

	for m in data.miss_markers:
		var pos: Vector2 = m.get("pos", Vector2.ZERO)
		var left: float = float(m.get("until", 0.0)) - t
		var a: float = clampf(left / Constants.LANCE_MISS_MARKER_TIME, 0.0, 1.0)
		var s: float = 9.0
		var col := Color(0.9, 0.35, 0.3) * (1.4 * a)
		draw_line(pos + Vector2(-s, -s), pos + Vector2(s, s), col, 1.6, true)
		draw_line(pos + Vector2(s, -s), pos + Vector2(-s, s), col, 1.6, true)
