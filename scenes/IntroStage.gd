extends Node2D
## The intro's field. Everything the cutscene says in words, this draws:
## a spark waking, the pool of sight opening, and the Unlit steering in by
## the only light left burning.
##
## The director sets the targets; this eases toward them, so a cut between
## beats is a movement rather than a jump.

const STARS := 300

## Targets, written by Intro.gd each frame.
var want_core: float = 0.0      # radius of the bloom itself
var want_sight: float = 0.0     # radius of the lit pool
var want_unlit: int = 0
var scatter: bool = false       # the Unlit have lost the light and drift off

var core: float = 0.0
var sight: float = 0.0

var _stars := PackedVector2Array()
var _star_cols := PackedColorArray()
var _unlit: Array[Dictionary] = []
var _t: float = 0.0
var _rng := RandomNumberGenerator.new()

func _ready() -> void:
	_rng.seed = 90210
	for _i in range(STARS):
		var a: float = _rng.randf() * TAU
		var r: float = sqrt(_rng.randf()) * 980.0
		var p := Vector2(cos(a), sin(a)) * r
		_stars.append(p)
		_stars.append(p + Vector2(1.4, 0))
		_star_cols.append(Color(0.78, 0.66, 0.62) * _rng.randf_range(0.2, 1.0))

func _process(delta: float) -> void:
	_t += delta
	# Eased, not snapped: the light growing is the story.
	core = lerpf(core, want_core, 1.0 - pow(0.06, delta))
	sight = lerpf(sight, want_sight, 1.0 - pow(0.22, delta))

	while _unlit.size() < want_unlit:
		_spawn_unlit()
	while _unlit.size() > want_unlit:
		_unlit.pop_back()

	for u in _unlit:
		# Steering by the light is the whole reason they exist. With it out
		# they lose the bearing and drift back off into the dark.
		var goal: float = 1500.0 if scatter else u["hold"]
		var speed: float = u["speed"] * (1.7 if scatter else 1.0)
		u["r"] = move_toward(u["r"], goal, speed * delta)
		u["a"] += u["drift"] * delta
	queue_redraw()

func _spawn_unlit() -> void:
	var hold: float = _rng.randf_range(70.0, 300.0)
	_unlit.append({
		"a": _rng.randf() * TAU,
		# Each holds at its own distance instead of marching to the middle.
		# Converging on a point stacked the whole crowd behind the bloom.
		"hold": hold,
		# Started relative to that, not from a fixed far ring: from way out
		# the slowest took sixteen seconds to arrive and every beat played
		# over an empty pool.
		"r": hold + _rng.randf_range(120.0, 420.0),
		"speed": _rng.randf_range(120.0, 240.0),
		"drift": _rng.randf_range(-0.22, 0.22),
		"size": _rng.randf_range(11.0, 19.0),
		"tier": _rng.randi_range(0, 2),
	})

func _draw() -> void:
	var xf := Transform2D(_t * 0.010, Vector2.ZERO)
	var pts := PackedVector2Array()
	for p in _stars:
		pts.append(xf * p)
	draw_multiline_colors(pts, _star_cols, 1.0)

	for u in _unlit:
		var p: Vector2 = Vector2(cos(u["a"]), sin(u["a"])) * u["r"]
		var s: float = u["size"]
		# Lit ones are the game's own contact colours. The rest are the
		# shapes you half-see at the rim — enough to know they are there.
		var seen: bool = p.length() < sight
		var col: Color = UITheme.tier_colour(u["tier"])
		var box := Rect2(p - Vector2(s, s) * 0.5, Vector2(s, s))
		draw_rect(box.grow(1.0), UITheme.OUTLINE)
		draw_rect(box, col if seen else col * 0.42)

	if sight > 2.0:
		draw_arc(Vector2.ZERO, sight, 0.0, TAU, 96, UITheme.LIGHT * 0.55, 2.0, true)

	if core > 0.5:
		var pulse: float = 1.0 + 0.05 * sin(_t * 1.3)
		var br: float = core * pulse
		draw_circle(Vector2.ZERO, br, Color(0.95, 0.72, 0.35) * 2.0)
		draw_circle(Vector2.ZERO, br * 0.45, Color(1.0, 0.95, 0.8) * 3.0)
