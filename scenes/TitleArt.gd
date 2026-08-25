extends Node2D
## The title screen's field: a bloom breathing in the dark with things
## drifting at the edge of the light, never quite arriving.
##
## It is the whole game stated without a word — this is what you are, that
## is what the light is for, and those are what it attracts.

const STARS := 260
const DRIFTERS := 26

var _stars := PackedVector2Array()
var _star_cols := PackedColorArray()
var _drift_pos: Array[Vector2] = []
var _drift_vel: Array[Vector2] = []
var _drift_tier: Array[int] = []
var _t: float = 0.0
var _rng := RandomNumberGenerator.new()

## The lit radius, breathing. TitleScreen reads this to drive the darkness.
const SIGHT_MID := 200.0
const SIGHT_SWING := 34.0
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
		_star_cols.append(Color(0.62, 0.76, 0.98) * b)
	for _i in range(DRIFTERS):
		_spawn(_rng.randf_range(250.0, 700.0))

func _spawn(dist: float) -> void:
	var a: float = _rng.randf() * TAU
	var p := Vector2(cos(a), sin(a)) * dist
	_drift_pos.append(p)
	_drift_vel.append(-p.normalized() * _rng.randf_range(7.0, 17.0))
	_drift_tier.append(_rng.randi_range(0, 5))

func _process(delta: float) -> void:
	_t += delta
	# A slow tide in and out, so the light is visibly a thing that changes.
	sight = SIGHT_MID + sin(_t * 0.30) * SIGHT_SWING
	for i in range(_drift_pos.size()):
		_drift_pos[i] += _drift_vel[i] * delta
		# Nothing ever reaches you here. They turn at the edge of the light.
		if _drift_pos[i].length() < sight * 0.50:
			_drift_vel[i] = -_drift_vel[i]
		elif _drift_pos[i].length() > 900.0:
			_drift_vel[i] = -_drift_vel[i]
	queue_redraw()

func _draw() -> void:
	var xf := Transform2D(_t * 0.012, Vector2.ZERO)
	var pts := PackedVector2Array()
	for p in _stars:
		pts.append(xf * p)
	draw_multiline_colors(pts, _star_cols, 1.0)

	for i in range(_drift_pos.size()):
		var p: Vector2 = _drift_pos[i]
		if p.length() > sight:
			continue   # past the light there is nothing to see
		var r: float = 7.0 + float(_drift_tier[i]) * 2.4
		draw_rect(Rect2(p - Vector2(r, r), Vector2(r, r) * 2.0),
			UITheme.tier_colour(_drift_tier[i]) * 1.05)

	# The bloom, breathing.
	var pulse: float = 1.0 + 0.045 * sin(_t * 1.15)
	var br: float = 42.0 * pulse
	draw_circle(Vector2.ZERO, br, Color(0.95, 0.72, 0.35) * 2.0)
	draw_circle(Vector2.ZERO, br * 0.45, Color(1.0, 0.95, 0.8) * 3.0)
	draw_arc(Vector2.ZERO, sight, 0.0, TAU, 96, Color(1.0, 0.74, 0.34) * 0.55, 1.6, true)
