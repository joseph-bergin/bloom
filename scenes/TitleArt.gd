extends Node2D
## The title screen's field: one bloom, breathing, in the dark.
##
## It is the whole game stated without a word — this is what you are, and
## that circle of light is all of it you can see by.

const STARS := 260

var _stars := PackedVector2Array()
var _star_cols := PackedColorArray()
var _t: float = 0.0
var _rng := RandomNumberGenerator.new()

## The lit radius, breathing. TitleScreen reads this to drive the darkness.
const SIGHT_MID := 170.0
const SIGHT_SWING := 28.0
var sight: float = SIGHT_MID

## The widest the pool ever gets, so the layout can sit clear of it.
func sight_max() -> float:
	return SIGHT_MID + SIGHT_SWING

func _ready() -> void:
	_rng.seed = 424242
	for _i in range(STARS):
		var a: float = _rng.randf() * TAU
		var r: float = sqrt(_rng.randf()) * 900.0
		var p := Vector2(cos(a), sin(a)) * r
		_stars.append(p)
		_stars.append(p + Vector2(1.4, 0))
		var b: float = _rng.randf_range(0.25, 1.15)
		_star_cols.append(Color(0.78, 0.66, 0.62) * b)

func _process(delta: float) -> void:
	_t += delta
	# A slow tide in and out, so the light is visibly a thing that changes.
	sight = SIGHT_MID + sin(_t * 0.30) * SIGHT_SWING
	queue_redraw()

func _draw() -> void:
	var xf := Transform2D(_t * 0.012, Vector2.ZERO)
	var pts := PackedVector2Array()
	for p in _stars:
		pts.append(xf * p)
	draw_multiline_colors(pts, _star_cols, 1.0)

	# The bloom, breathing.
	var pulse: float = 1.0 + 0.045 * sin(_t * 1.15)
	var br: float = 36.0 * pulse
	draw_circle(Vector2.ZERO, br, Color(0.95, 0.72, 0.35) * 2.0)
	draw_circle(Vector2.ZERO, br * 0.45, Color(1.0, 0.95, 0.8) * 3.0)
	draw_arc(Vector2.ZERO, sight, 0.0, TAU, 96, UITheme.LIGHT * 0.6, 2.0, true)
