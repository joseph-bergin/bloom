extends Node
## Wiring only.

@onready var field: Node2D = $FieldView
@onready var hud: Control = $UILayer/HUD
@onready var tree_view: Control = $UILayer/TreeView
@onready var run_end: Control = $UILayer/Modals/RunEndModal
@onready var settings: Control = $UILayer/Modals/SettingsPanel

func _ready() -> void:
	hud.tree_pressed.connect(func(): tree_view.toggle())
	hud.settings_pressed.connect(func(): settings.toggle())
	hud.retire_pressed.connect(func():
		GameState.paused = true
		run_end.open_modal(false))

	# The modal opens for a death or a voluntary retire; run_over tells
	# them apart, and retiring must pay better.
	run_end.confirmed.connect(func():
		GameState.bank_embers(not GameState.s.run_over)
		GameState.paused = false)

	EventBus.run_ended.connect(func(reason: String):
		run_end.open_modal(true, reason))
	EventBus.contact_killed.connect(func(tier: int, _at: Vector2, _m: float):
		GameState.hitstop(tier))

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_tree"):
		tree_view.toggle()
		get_viewport().set_input_as_handled()
	elif event is InputEventKey and (event as InputEventKey).pressed \
			and (event as InputEventKey).keycode == KEY_ESCAPE:
		if tree_view.visible:
			tree_view.close_view()
		elif run_end.visible:
			pass
		else:
			settings.toggle()
		get_viewport().set_input_as_handled()
