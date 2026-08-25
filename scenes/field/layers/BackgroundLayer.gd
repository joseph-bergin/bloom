extends Node2D
## Field boundary, range rings, and the faint grain of an immense dark.

const RING_COUNT := 4
var _star_lines: PackedVector2Array = []
var _star_cols: PackedColorArray = []

func _ready() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1312
	for _i in range(220):
		var a: float = rng.randf() * TAU
		var r: float = sqrt(rng.randf()) * Constants.FIELD_RADIUS * 1.25
		var p := Vector2(cos(a), sin(a)) * r
		_star_lines.append(p)
		_star_lines.append(p + Vector2(1.4, 0.0))
		var b: float = rng.randf_range(0.05, 0.32)
		_star_cols.append(Color(0.35, 0.42, 0.55) * b)

## The background is static apart from a slow pressure tint. Re-emitting 220
## star circles every frame is pure waste, so it only redraws when the thing
## it actually depends on has moved.
var _last_pressure: float = -1.0
var _last_passive: float = -1.0

func _process(_delta: float) -> void:
	var p: float = GameState.data.field_pressure
	var r: float = Stats.passive_range
	if absf(p - _last_pressure) < 0.005 and absf(r - _last_passive) < 1.0:
		return
	_last_pressure = p
	_last_passive = r
	queue_redraw()

func _draw() -> void:
	# One batched command rather than 220 circle polygons.
	draw_multiline_colors(_star_lines, _star_cols, 1.0)

	var pressure: float = GameState.data.field_pressure
	for i in range(1, RING_COUNT + 1):
		var r: float = Constants.FIELD_RADIUS * float(i) / float(RING_COUNT)
		var c := Color(0.16, 0.22, 0.30) * (0.55 - 0.06 * float(i))
		draw_arc(Vector2.ZERO, r, 0.0, TAU, 48, c, 1.0, false)

	# The boundary reddens as the field escalates.
	var edge := Color(0.22 + pressure * 0.35, 0.26, 0.34).clamp()
	draw_arc(Vector2.ZERO, Constants.FIELD_RADIUS, 0.0, TAU, 72, edge, 1.6, false)

	# Passive sensing envelope — what you hear without doing anything.
	draw_arc(Vector2.ZERO, Stats.passive_range, 0.0, TAU, 48,
		Color(0.22, 0.44, 0.40) * 0.7, 1.0, false)
