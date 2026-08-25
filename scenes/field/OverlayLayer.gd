extends Node2D
## Hitstop is in the sim; the flash, shake and mote arcs live here.

var flash: float = 0.0
var shake: float = 0.0
var reduced_motion: bool = false

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
