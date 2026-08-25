extends Node2D

@onready var camera: Camera2D = $Camera2D
@onready var overlay: Node2D = $OverlayLayer
@onready var reticle: Node2D = $ReticleLayer

## The input layer owns aiming; the sim only reads the resulting vector.
var aiming_enabled: bool = true

func _ready() -> void:
	RenderingServer.set_default_clear_color(UITheme.VOID)
	overlay.bind_camera(camera)
	_fit()
	get_viewport().size_changed.connect(_fit)

func _fit() -> void:
	var vp: Vector2 = get_viewport_rect().size
	camera.zoom = Vector2.ONE * (minf(vp.x, vp.y) / (Constants.FIELD_RADIUS * 2.05))

func _process(_delta: float) -> void:
	if not aiming_enabled:
		return
	var m: Vector2 = get_global_mouse_position()
	reticle.aim_world = m
	if m.length_squared() > 1.0:
		GameState.s.aim = m.normalized()
		GameState.s.aim_auto = false

## While a modal or the tree is open the turret keeps working on its own
## rather than firing at wherever the cursor happens to rest.
func set_aiming(on: bool) -> void:
	aiming_enabled = on
	GameState.s.aim_auto = not on
