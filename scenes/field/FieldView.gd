class_name FieldView
extends Node2D
## Owns the camera, input picking, and progression gating of information
## layers. Five overlapping data layers on a dark field at once is mud, so
## each is introduced a full act apart.

signal contact_hovered(c: Contact)
signal contact_clicked(c: Contact)

@onready var camera: Camera2D = $Camera2D
@onready var contact_layer: Node2D = $ContactLayer
@onready var overlay: Node2D = $OverlayLayer
@onready var glow_rig: WorldEnvironment = $GlowRig

var zoom_level: float = 1.0
var _drag: bool = false

func _ready() -> void:
	AudioDirector.rig = $AudioRig
	overlay.bind_camera(camera)
	_fit()
	get_viewport().size_changed.connect(_fit)
	EventBus.contact_committed.connect(func(_c: Contact):
		GameState.data.flags["act_awareness"] = true)
	EventBus.node_purchased.connect(func(id: StringName, _r: int):
		var n: TreeNode = TreeDB.get_node_def(id)
		if n != null and n.constellation == &"optics":
			GameState.data.flags["act_ghosts"] = true)
	EventBus.run_ended.connect(func(_r: String): set_process_unhandled_input(false))

## Gate for each information layer. Ghosts, uncertainty circles, bearing
## lines, awareness indicators and incoming arcs are learned in isolation.
static func layer_on(data: GameStateData, key: StringName) -> bool:
	match key:
		&"uncertainty":
			return bool(data.flags.get("act_ghosts", false)) or data.t > 180.0
		&"awareness":
			return bool(data.flags.get("act_awareness", false))
		&"incoming":
			return Stats.strike_detection_available()
		_:
			return true

func _fit() -> void:
	var vp: Vector2 = get_viewport_rect().size
	var fit: float = minf(vp.x, vp.y) / (Constants.FIELD_RADIUS * 2.15)
	camera.zoom = Vector2.ONE * (fit * zoom_level)

func _process(_delta: float) -> void:
	var m: Vector2 = get_global_mouse_position()
	var c: Contact = GameState.pick_contact(m)
	var new_id: int = c.id if c != null else -1
	if new_id != contact_layer.hovered_id:
		contact_layer.hovered_id = new_id
		contact_hovered.emit(c)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		var mb := event as InputEventMouseButton
		match mb.button_index:
			MOUSE_BUTTON_LEFT:
				var c: Contact = GameState.pick_contact(get_global_mouse_position())
				contact_layer.selected_id = c.id if c != null else -1
				contact_clicked.emit(c)
				AudioDirector.play_ui("click", -16.0)
				get_viewport().set_input_as_handled()
			MOUSE_BUTTON_WHEEL_UP:
				set_zoom(zoom_level * 1.1)
			MOUSE_BUTTON_WHEEL_DOWN:
				set_zoom(zoom_level / 1.1)

func set_zoom(z: float) -> void:
	zoom_level = clampf(z, 0.5, 2.5)
	_fit()

func select(id: int) -> void:
	contact_layer.selected_id = id

func selected() -> Contact:
	return GameState.data.find_contact(contact_layer.selected_id)

## The Cold ending. No fanfare.
func fade_to_cold() -> void:
	glow_rig.fade_out(30.0)
