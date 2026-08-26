extends Node2D
## Sparks on a hit, a burst on a death, and the ripple when you go dark.
## All of it is short-lived primitives — no particle nodes, no allocation
## churn beyond a couple of small arrays.

class Spark extends RefCounted:
	var pos: Vector2
	var vel: Vector2
	var life: float
	var max_life: float
	var col: Color
	var length: float

class Burst extends RefCounted:
	var pos: Vector2
	var life: float
	var max_life: float
	var col: Color
	var radius: float

var _sparks: Array[Spark] = []
var _bursts: Array[Burst] = []
var _ripple: float = -1.0
var _rng := RandomNumberGenerator.new()

func _ready() -> void:
	_rng.randomize()
	EventBus.contact_hit.connect(_on_hit)
	EventBus.contact_killed.connect(_on_kill)
	EventBus.douse_started.connect(func(): _ripple = 0.0)

## A struck contact throws a few sparks back along the shot.
func _on_hit(at: Vector2, dir: Vector2, crit: bool, lethal: bool) -> void:
	if lethal:
		return
	var n: int = 5 if crit else 3
	var col: Color = Color(1.0, 0.92, 0.62) * (3.0 if crit else 2.0)
	for _i in range(n):
		var s := Spark.new()
		s.pos = at
		var a: float = dir.angle() + PI + _rng.randf_range(-0.9, 0.9)
		s.vel = Vector2(cos(a), sin(a)) * _rng.randf_range(90.0, 230.0)
		s.max_life = _rng.randf_range(0.12, 0.26)
		s.life = s.max_life
		s.col = col
		s.length = _rng.randf_range(4.0, 9.0)
		_sparks.append(s)

## A death throws shards outward and leaves an expanding ring.
func _on_kill(tier: int, at: Vector2, _motes: float) -> void:
	var col: Color = UITheme.tier_colour(tier)
	var b := Burst.new()
	b.pos = at
	b.max_life = 0.34 + float(tier) * 0.03
	b.life = b.max_life
	b.col = col
	b.radius = 16.0 + float(tier) * 7.0
	_bursts.append(b)
	for _i in range(6 + tier * 2):
		var s := Spark.new()
		s.pos = at
		var a: float = _rng.randf() * TAU
		s.vel = Vector2(cos(a), sin(a)) * _rng.randf_range(110.0, 300.0)
		s.max_life = _rng.randf_range(0.20, 0.44)
		s.life = s.max_life
		s.col = col * 2.2
		s.length = _rng.randf_range(5.0, 12.0)
		_sparks.append(s)

func _process(delta: float) -> void:
	if not _sparks.is_empty():
		var keep: Array[Spark] = []
		for s in _sparks:
			s.life -= delta
			if s.life <= 0.0:
				continue
			s.pos += s.vel * delta
			s.vel *= 1.0 - minf(delta * 5.0, 0.9)
			keep.append(s)
		_sparks = keep
	if not _bursts.is_empty():
		var kb: Array[Burst] = []
		for b in _bursts:
			b.life -= delta
			if b.life > 0.0:
				kb.append(b)
		_bursts = kb
	if _ripple >= 0.0:
		_ripple += delta
		if _ripple > 0.55:
			_ripple = -1.0
	queue_redraw()

func _draw() -> void:
	for b in _bursts:
		var t: float = 1.0 - b.life / b.max_life
		var r: float = b.radius * (0.35 + t * 1.5)
		draw_arc(b.pos, r, 0.0, TAU, 24, b.col * (2.6 * (1.0 - t)), 2.4 * (1.0 - t) + 0.6, true)

	if not _sparks.is_empty():
		var pts := PackedVector2Array()
		var cols := PackedColorArray()
		for s in _sparks:
			var t: float = s.life / s.max_life
			pts.append(s.pos)
			pts.append(s.pos - s.vel.normalized() * s.length * t)
			cols.append(s.col * t)
		draw_multiline_colors(pts, cols, 1.8)

	# Going dark throws a ring outward: the light you just pulled in.
	if _ripple >= 0.0:
		var t: float = _ripple / 0.55
		draw_arc(Vector2.ZERO, 30.0 + t * Constants.FIELD_RADIUS * 0.9, 0.0, TAU, 72,
			UITheme.COOL * (2.4 * (1.0 - t)), 3.0 * (1.0 - t) + 0.8, true)
