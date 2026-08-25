extends Node2D
## The game's signature moment. The ring must be beautiful.

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	for s in GameState.data.sweeps:
		var alpha: float = 1.0 - (s.radius / maxf(s.max_radius, 1.0))
		draw_arc(Vector2.ZERO, s.radius, 0.0, TAU, 128,
			Color(0.35, 0.95, 0.7) * (2.2 * alpha), 2.0, true)
		# A trailing echo so the ring reads as a wavefront, not an outline.
		var trail: float = maxf(s.radius - 26.0, 0.0)
		if trail > 0.0:
			draw_arc(Vector2.ZERO, trail, 0.0, TAU, 96,
				Color(0.25, 0.7, 0.6) * (0.9 * alpha), 1.0, true)
