extends Node2D

@onready var camera: Camera2D = $Camera2D
@onready var overlay: Node2D = $OverlayLayer

func _ready() -> void:
	overlay.bind_camera(camera)
	_fit()
	get_viewport().size_changed.connect(_fit)

func _fit() -> void:
	var vp: Vector2 = get_viewport_rect().size
	camera.zoom = Vector2.ONE * (minf(vp.x, vp.y) / (Constants.FIELD_RADIUS * 2.2))
