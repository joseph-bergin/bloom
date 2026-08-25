extends Node2D
## The dark, given depth: a drifting starfield at three parallax depths, a
## polar grid that echoes the radial shape of the game, the field boundary,
## and the turret's reach. Everything here is dim on purpose — the bloom is
## the subject and this is the room it sits in.

const SPOKES := 16
const RINGS := 5
const STAR_LAYERS := 3
const STARS_PER_LAYER := 130

var _stars: Array[PackedVector2Array] = []
var _star_cols: Array[PackedColorArray] = []
var _drift: Array[float] = [0.006, 0.013, 0.024]
var _t: float = 0.0

func _ready() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 90210
	var reach: float = Constants.FIELD_RADIUS * 1.5
	for layer in range(STAR_LAYERS):
		var pts := PackedVector2Array()
		var cols := PackedColorArray()
		var depth: float = float(layer) / float(STAR_LAYERS - 1)
		for _i in range(STARS_PER_LAYER):
			var a: float = rng.randf() * TAU
			var r: float = sqrt(rng.randf()) * reach
			var p := Vector2(cos(a), sin(a)) * r
			var len: float = lerpf(0.9, 2.2, depth)
			pts.append(p)
			pts.append(p + Vector2(len, 0))
			# Nearer stars are brighter and cooler; far ones sink into the dark.
			# A handful sit above 1.0 so the glow rig catches them and the
			# field reads as deep space rather than a black rectangle.
			var b: float = lerpf(0.45, 1.35, depth) * rng.randf_range(0.5, 1.0)
			var tint := Color(0.62, 0.76, 0.98)
			if rng.randf() < 0.07:
				tint = Color(1.0, 0.86, 0.72)
				b *= 1.5
			cols.append(tint * b)
		_stars.append(pts)
		_star_cols.append(cols)

func _process(delta: float) -> void:
	_t += delta
	queue_redraw()

func _draw() -> void:
	var R: float = Constants.FIELD_RADIUS

	# --- starfield, each layer rotating at its own rate ---
	for layer in range(_stars.size()):
		var xf := Transform2D(_t * _drift[layer], Vector2.ZERO)
		var pts := PackedVector2Array()
		for p in _stars[layer]:
			pts.append(xf * p)
		draw_multiline_colors(pts, _star_cols[layer], 1.0)

	# --- polar grid: spokes and rings, echoing the shape of the field ---
	var grid := Color(0.16, 0.26, 0.33)
	var spokes := PackedVector2Array()
	var spoke_cols := PackedColorArray()
	for i in range(SPOKES):
		var a: float = TAU * float(i) / float(SPOKES) + _t * 0.008
		var d := Vector2(cos(a), sin(a))
		spokes.append(d * (R * 0.13))
		spokes.append(d * R)
		# Every fourth spoke is a little stronger, so the wheel has cardinals.
		spoke_cols.append(grid * (1.7 if i % 4 == 0 else 0.75))
	draw_multiline_colors(spokes, spoke_cols, 1.0)

	for i in range(1, RINGS + 1):
		var rr: float = R * float(i) / float(RINGS)
		draw_arc(Vector2.ZERO, rr, 0.0, TAU, 72, grid * 0.55, 1.0, false)

	# --- the boundary things come out of ---
	draw_arc(Vector2.ZERO, R, 0.0, TAU, 96, Color(0.30, 0.46, 0.56), 1.8, true)
	# A faint inner glow just inside the rim, so the edge reads as an edge.
	draw_arc(Vector2.ZERO, R - 5.0, 0.0, TAU, 96, Color(0.09, 0.15, 0.19), 3.0, false)

	# --- turret reach: the promise the player aims inside of ---
	var reach: float = Stats.turret_range
	var pulse: float = 0.85 + 0.15 * sin(_t * 1.1)
	draw_arc(Vector2.ZERO, reach, 0.0, TAU, 96,
		Color(0.20, 0.44, 0.40) * pulse, 1.4, true)
	# Ticks on the reach ring give it a machined feel rather than a plain circle.
	var ticks := PackedVector2Array()
	var tick_cols := PackedColorArray()
	for i in range(SPOKES):
		var a: float = TAU * float(i) / float(SPOKES)
		var d := Vector2(cos(a), sin(a))
		ticks.append(d * (reach - 5.0))
		ticks.append(d * (reach + 5.0))
		tick_cols.append(Color(0.24, 0.50, 0.46) * pulse)
	draw_multiline_colors(ticks, tick_cols, 1.0)
