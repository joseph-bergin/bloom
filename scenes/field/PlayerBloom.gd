extends Node2D
## The bloom is the luminance. Buying a node makes this visibly bigger
## within one frame, which teaches the whole design without tutorial text.

var _flare: float = 0.0
var _t: float = 0.0

func _ready() -> void:
	EventBus.node_purchased.connect(func(_id: StringName, _r: int): _flare = 1.0)

func _process(delta: float) -> void:
	_t += delta
	_flare = maxf(_flare - delta * 2.4, 0.0)
	queue_redraw()

func _draw() -> void:
	var s: GameStateData = GameState.s
	var l: float = s.effective_luminance()
	# The spec's curve was written for a 640-unit field. Scaled to the
	# current radius so the bloom occupies the same fraction of it and does
	# not swallow the contacts closing on you.
	var k: float = Constants.FIELD_RADIUS / 640.0
	var r: float = (14.0 + sqrt(l) * 3.2) * k
	var i: float = 1.2 + sqrt(l) * 0.22
	r *= 1.0 + 0.03 * sin(_t * 1.8)

	if _flare > 0.0:
		draw_circle(Vector2.ZERO, r * (1.0 + _flare * 1.5),
			Color(1.0, 0.82, 0.45) * (i * _flare * 0.85))

	draw_circle(Vector2.ZERO, r, Color(0.95, 0.72, 0.35) * i)
	draw_circle(Vector2.ZERO, r * 0.45, Color(1.0, 0.95, 0.8) * i * 1.5)

	# Shields read as shells. Losing one is visible without looking away.
	for shell in range(maxi(s.shields, 0)):
		draw_arc(Vector2.ZERO, r + 9.0 + float(shell) * 6.0, 0.0, TAU, 36,
			UITheme.COOL * 1.5, 1.6, true)

	if s.is_dousing():
		draw_arc(Vector2.ZERO, r + 4.0, 0.0, TAU, 40, UITheme.COOL * 1.6, 2.0, true)
