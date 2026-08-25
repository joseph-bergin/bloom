extends Node2D
## The dark, the boundary, and the turret's reach. Static apart from range,
## so it only redraws when range actually changes.

var _last_range: float = -1.0

func _process(_delta: float) -> void:
	if absf(Stats.turret_range - _last_range) < 0.5:
		return
	_last_range = Stats.turret_range
	queue_redraw()

func _draw() -> void:
	draw_arc(Vector2.ZERO, Constants.FIELD_RADIUS, 0.0, TAU, 72,
		Color(0.13, 0.15, 0.20), 1.5, false)
	# Turret range is a promise the player should be able to see.
	draw_arc(Vector2.ZERO, Stats.turret_range, 0.0, TAU, 64,
		Color(0.20, 0.34, 0.30), 1.0, false)
