extends Node2D
## Flashes, shake driver, and the strike whiteout. Nothing here is state.

var flash: float = 0.0
var _cam: Camera2D = null
var shake: float = 0.0
var _noise_t: float = 0.0
var reduced_motion: bool = false

func _ready() -> void:
	EventBus.strike_landed.connect(func(_s: IncomingStrike):
		flash = 1.0
		add_shake(9.0))
	EventBus.lance_hit.connect(func(c: Contact, _m: float, _f: float, _at: Vector2):
		add_shake(Constants.SHAKE_PER_TIER * float(c.tier + 1)))
	EventBus.tether_fired.connect(func(_t: Tether):
		flash = 0.7
		add_shake(7.0))

func bind_camera(cam: Camera2D) -> void:
	_cam = cam

func add_shake(amount: float) -> void:
	if reduced_motion:
		return
	shake = minf(shake + amount, 34.0)

func _process(delta: float) -> void:
	if flash > 0.0:
		flash = maxf(flash - delta / Constants.STRIKE_FLASH_TIME, 0.0)
	if shake > 0.0:
		shake = maxf(shake - Constants.SHAKE_DECAY * delta * (1.0 + shake * 0.1), 0.0)
		_noise_t += delta
	if _cam != null:
		_cam.offset = Vector2(
			sin(_noise_t * 47.0) * shake,
			cos(_noise_t * 39.0) * shake) if shake > 0.01 else Vector2.ZERO
	queue_redraw()

func _draw() -> void:
	if flash <= 0.0:
		return
	var r: float = Constants.FIELD_RADIUS * 2.4
	draw_rect(Rect2(-r, -r, r * 2.0, r * 2.0), Color(1, 1, 1, 1) * (flash * 1.6))
