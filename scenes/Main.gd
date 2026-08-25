extends Node
## Wiring only. The sim never holds references to anything here.

@onready var field: FieldView = $FieldView
@onready var hud: Control = $UILayer/HUD
@onready var contacts_panel: Control = $UILayer/ContactPanel
@onready var tether_panel: Control = $UILayer/TetherPanel
@onready var incoming_panel: Control = $UILayer/IncomingPanel
@onready var triage_panel: Control = $UILayer/TriagePanel
@onready var log_feed: Control = $UILayer/LogFeed
@onready var tree_view: Control = $UILayer/TreeView
@onready var dormancy: Control = $UILayer/Modals/DormancyReveal
@onready var ember_modal: Control = $UILayer/Modals/EmberModal
@onready var post_run: Control = $UILayer/Modals/PostRunSummary
@onready var settings: Control = $UILayer/Modals/SettingsPanel

var _cold_fading: bool = false

func _ready() -> void:
	_wire_ui()
	_wire_events()
	# A save may have resolved dormancy during SaveManager's deferred load.
	call_deferred("_check_dormancy")

func _wire_ui() -> void:
	hud.sweep_pressed.connect(func(): GameState.try_sweep())
	hud.tree_pressed.connect(func(): tree_view.toggle())
	hud.ember_pressed.connect(func(): ember_modal.open_modal())
	hud.settings_pressed.connect(func(): settings.toggle())

	field.contact_clicked.connect(func(c: Contact):
		contacts_panel.select(c.id if c != null else -1))
	contacts_panel.lance_requested.connect(func(id: int): GameState.try_lance(id))
	contacts_panel.tether_requested.connect(func(id: int): GameState.try_tether(id))
	contacts_panel.focus_requested.connect(func(id: int): field.select(id))
	tether_panel.reassert_requested.connect(func(id: int): GameState.try_reassert(id))
	tether_panel.release_requested.connect(func(id: int):
		var t: Tether = GameState.data.find_tether(id)
		if t != null:
			Tethers.release(GameState.data, t))

	ember_modal.confirmed.connect(_do_ember)
	post_run.ember_chosen.connect(_do_ember)
	dormancy.finished.connect(func(): GameState.paused = false)

func _wire_events() -> void:
	EventBus.lance_hit.connect(func(_c: Contact, _m: float, _f: float, _at: Vector2):
		if not AudioDirector.reduced_motion:
			GameState.hitstop())
	EventBus.run_ended.connect(func(reason: String):
		post_run.show_run(reason))
	EventBus.game_loaded.connect(func():
		call_deferred("_check_dormancy"))
	EventBus.cold_rank_changed.connect(func(_r: int): _check_cold_ending())
	EventBus.contact_removed.connect(func(_id: int): _check_cold_ending())

func _check_dormancy() -> void:
	var report: Dictionary = GameState.take_pending_dormancy()
	if report.is_empty():
		return
	GameState.paused = true
	dormancy.play(report)

func _do_ember() -> void:
	var report: Dictionary = GameState.commit_ember()
	EventBus.log_msg("Cycle %d. It catches." % int(report.get("cycle", 0)), "good")
	tree_view.close_view()

## The correct ending is not victory. It is the player realising the only
## stable configuration is an empty one, and choosing it anyway.
func _check_cold_ending() -> void:
	if _cold_fading or not Cold.ending_reached(GameState.data):
		return
	_cold_fading = true
	field.fade_to_cold()
	for panel in [hud, contacts_panel, tether_panel, incoming_panel, triage_panel, log_feed]:
		var tw := create_tween()
		tw.tween_property(panel, "modulate:a", 0.0, 12.0)
	await get_tree().create_timer(26.0).timeout
	var end := UITheme.label("Nothing here burns.", UITheme.TEXT_DIM, 18)
	end.set_anchors_preset(Control.PRESET_CENTER)
	end.position = Vector2(-100, 0)
	end.modulate.a = 0.0
	$UILayer.add_child(end)
	create_tween().tween_property(end, "modulate:a", 1.0, 6.0)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_tree"):
		tree_view.toggle()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("sweep") and not tree_view.visible:
		GameState.try_sweep()
		get_viewport().set_input_as_handled()
	elif event is InputEventKey and (event as InputEventKey).pressed:
		var k := event as InputEventKey
		if k.keycode == KEY_ESCAPE:
			if tree_view.visible:
				tree_view.close_view()
			elif settings.visible:
				settings.visible = false
			else:
				settings.toggle()
			get_viewport().set_input_as_handled()
		elif k.keycode == KEY_F and not tree_view.visible:
			# Fire at the current selection — the whole verb on one key.
			var c: Contact = field.selected()
			if c != null:
				GameState.try_lance(c.id)
