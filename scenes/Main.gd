extends Node
## Wiring only.

@onready var field: Node2D = $FieldView
@onready var hud: Control = $UILayer/HUD
@onready var tree_view: Control = $UILayer/TreeView
@onready var run_end: Control = $UILayer/Modals/RunEndModal
@onready var settings: Control = $UILayer/Modals/SettingsPanel

func _ready() -> void:
	hud.tree_pressed.connect(_toggle_tree)
	hud.settings_pressed.connect(func(): settings.toggle())
	hud.next_level_pressed.connect(func(): GameState.begin_next_level())

	run_end.restart_pressed.connect(func(): GameState.restart_run())

	EventBus.run_ended.connect(func(reason: String):
		tree_view.close_view()
		run_end.open_modal(reason))

	# Clearing a level opens the tree, so the chance to spend what the level
	# paid is unmissable rather than something the player has to know about.
	EventBus.level_cleared.connect(_on_level_cleared)

	EventBus.contact_killed.connect(func(tier: int, _at: Vector2, _m: float):
		GameState.hitstop(tier))

## Let the LEVEL N CLEARED banner land, then put the tree in front of the
## player so the chance to spend is impossible to miss.
var _open_tree_in: float = -1.0

## Upgrades happen between levels, never during one.
func _toggle_tree() -> void:
	if tree_view.visible:
		tree_view.close_view()
	elif GameState.upgrading():
		tree_view.open_view()

func _on_level_cleared(_level: int, _bonus: float) -> void:
	_open_tree_in = Constants.LEVEL_CLEAR_PAUSE

func _process(delta: float) -> void:
	if _open_tree_in > 0.0:
		_open_tree_in -= delta
		if _open_tree_in <= 0.0:
			_open_tree_in = -1.0
			if GameState.upgrading() and not GameState.s.run_over:
				tree_view.open_view()

	# The settings panel is the pause menu, so it has to actually pause.
	# Nothing was setting this outside the title screen, so the sim kept
	# running behind the menu *and* aiming fell back to auto below — the
	# turret became a perfect auto-targeting gun for as long as it was open.
	GameState.paused = settings.visible

	# Aiming only applies while the player is looking at the field. Every
	# case here also stops the tick (upgrading, run over, paused), so the
	# auto fallback can never fire on the player's behalf.
	field.set_aiming(not tree_view.visible and not run_end.visible
		and not settings.visible and not GameState.s.run_over)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_tree"):
		_toggle_tree()
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
