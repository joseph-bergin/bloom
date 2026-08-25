extends Node2D
## Hitstop is in the sim; the flash, shake and mote arcs live here.

var flash: float = 0.0
var shake: float = 0.0
var reduced_motion: bool = false
## How far into hiding the field is, 0..1. Eased so going dark reads as a
## thing that happens rather than a boolean flip.
var _veil: float = 0.0

var _cam: Camera2D = null
var _noise_t: float = 0.0
var _motes: Array[Dictionary] = []

func _ready() -> void:
	EventBus.shield_breached.connect(func(_r: int):
		flash = 1.0
		add_shake(10.0))
	EventBus.contact_killed.connect(func(tier: int, at: Vector2, motes: float):
		add_shake(Constants.SHAKE_PER_TIER * float(tier + 1))
		_motes.append({"from": at, "t": 0.0, "amount": motes}))

func bind_camera(cam: Camera2D) -> void:
	_cam = cam

func add_shake(amount: float) -> void:
	if reduced_motion:
		return
	shake = minf(shake + amount, 30.0)

func _process(delta: float) -> void:
	var want: float = 1.0 if GameState.s.is_dousing() else 0.0
	_veil = move_toward(_veil, want, delta * (5.0 if want > 0.0 else 2.5))
	if flash > 0.0:
		flash = maxf(flash - delta / Constants.BREACH_FLASH, 0.0)
	if shake > 0.0:
		shake = maxf(shake - Constants.SHAKE_DECAY * delta * (1.0 + shake * 0.1), 0.0)
		_noise_t += delta
	if _cam != null:
		_cam.offset = Vector2(sin(_noise_t * 46.0), cos(_noise_t * 37.0)) * shake \
			if shake > 0.01 else Vector2.ZERO
	if not _motes.is_empty():
		var keep: Array[Dictionary] = []
		for m in _motes:
			m["t"] = float(m["t"]) + delta
			if float(m["t"]) < 0.7:
				keep.append(m)
		_motes = keep
	queue_redraw()

func _draw() -> void:
	_draw_vignette()
	_draw_veil()

	# Motes arc outward from the kill point toward the counter.
	for m in _motes:
		var k: float = float(m["t"]) / 0.7
		var from: Vector2 = m["from"]
		var to := Vector2(-Constants.FIELD_RADIUS * 0.9, -Constants.FIELD_RADIUS * 0.72)
		var arc := from.lerp(to, ease(k, 0.4)) + Vector2(0, -60.0 * sin(k * PI))
		draw_circle(arc, 3.0 * (1.0 - k * 0.5), Color(0.98, 0.78, 0.42) * (2.4 * (1.0 - k)))

	if flash > 0.0:
		var r: float = Constants.FIELD_RADIUS * 2.5
		draw_rect(Rect2(-r, -r, r * 2.0, r * 2.0), Color(1, 1, 1, 1) * (flash * 1.5))

## While hiding, a cold veil closes over the field. Douse used to be a
## number changing in a panel; this is what makes it feel like an action.
func _draw_veil() -> void:
	if _veil <= 0.001:
		return
	var R: float = Constants.FIELD_RADIUS
	var r: float = R * 2.2
	draw_rect(Rect2(-r, -r, r * 2.0, r * 2.0),
		Color(0.05, 0.10, 0.20, 0.55 * _veil))
	# And the boundary pulls inward, so the world feels smaller.
	var steps: int = 8
	for i in range(steps):
		var t: float = float(i) / float(steps)
		draw_arc(Vector2.ZERO, lerpf(R * 1.05, R * 0.55, t * _veil), 0.0, TAU, 64,
			Color(0.30, 0.55, 0.95, 0.10 * _veil * (1.0 - t)),
			(R * 0.5) / float(steps) + 2.0, false)

## Darkens the corners so the eye is pulled to the middle, where the game is.
func _draw_vignette() -> void:
	var R: float = Constants.FIELD_RADIUS
	var steps: int = 14
	for i in range(steps):
		var t: float = float(i) / float(steps)
		var r: float = lerpf(R * 1.08, R * 2.1, t)
		var a: float = lerpf(0.0, 0.22, pow(t, 1.6))
		draw_arc(Vector2.ZERO, r, 0.0, TAU, 72,
			Color(UITheme.VOID.r, UITheme.VOID.g, UITheme.VOID.b, a),
			(R * 1.02) / float(steps) + 2.0, false)
