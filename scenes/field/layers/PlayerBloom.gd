extends Node2D
## Luminance IS the render. Buying an upgrade makes you visibly bigger and
## brighter, immediately, every time. This is the single most important
## visual decision in the game.

var _flare: float = 0.0
var _t: float = 0.0

func _ready() -> void:
	EventBus.node_purchased.connect(func(_id: StringName, _r: int): _flare = 1.0)

func _process(delta: float) -> void:
	_t += delta
	_flare = maxf(_flare - delta * 2.2, 0.0)
	queue_redraw()

func _draw() -> void:
	var l: float = GameState.data.luminance_effective()
	var radius: float = 14.0 + sqrt(l) * 3.2
	var intensity: float = 1.2 + sqrt(l) * 0.22
	var breathe: float = 1.0 + 0.03 * sin(_t * 1.7)
	radius *= breathe

	if _flare > 0.0:
		draw_circle(Vector2.ZERO, radius * (1.0 + _flare * 1.4),
			Color(1.0, 0.8, 0.45) * (intensity * _flare * 0.8))

	draw_circle(Vector2.ZERO, radius, Color(0.95, 0.72, 0.35) * intensity)
	draw_circle(Vector2.ZERO, radius * 0.45, Color(1.0, 0.95, 0.8) * (intensity * 1.5))

	# Redundancy reads as concentric shells. Losing one is visible.
	for i in range(maxi(GameState.data.redundancy, 0)):
		draw_arc(Vector2.ZERO, radius + 9.0 + float(i) * 5.0, 0.0, TAU, 40,
			Color(0.6, 0.85, 0.95) * 0.9, 1.0, true)
