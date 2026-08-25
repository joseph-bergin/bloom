extends Control
## Audio and reduced-motion only. Everything past those two is explicitly
## cuttable (spec section 16), so the panel stays small on purpose.

const PATH := "user://settings.cfg"

var _root: PanelContainer
var _export_box: LineEdit

func _ready() -> void:
	_root = UITheme.make_panel(Vector2(320, 0))
	_root.set_anchors_preset(Control.PRESET_CENTER)
	_root.position = Vector2(-160, -170)
	add_child(_root)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	_root.add_child(col)
	col.add_child(UITheme.label("SETTINGS", UITheme.TEXT_BRIGHT, 16))

	col.add_child(UITheme.label("Master volume", UITheme.TEXT_DIM, 11))
	var vol := HSlider.new()
	vol.min_value = -40.0
	vol.max_value = 6.0
	vol.step = 1.0
	vol.value = AudioDirector.master_volume
	vol.custom_minimum_size = Vector2(0, 18)
	vol.value_changed.connect(func(v: float):
		AudioDirector.set_master_volume(v)
		save_settings())
	col.add_child(vol)

	var rm := CheckBox.new()
	rm.text = "Reduced motion"
	rm.tooltip_text = "Disables screenshake and hitstop."
	rm.button_pressed = AudioDirector.reduced_motion
	rm.toggled.connect(func(on: bool):
		set_reduced_motion(on)
		save_settings())
	col.add_child(rm)

	col.add_child(HSeparator.new())
	col.add_child(UITheme.label("Save export — paste to restore", UITheme.TEXT_DIM, 11))
	_export_box = LineEdit.new()
	_export_box.placeholder_text = "base64 save string"
	col.add_child(_export_box)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	col.add_child(row)
	var ex := UITheme.button("Export", UITheme.TEXT)
	ex.custom_minimum_size = Vector2(96, 24)
	ex.pressed.connect(func():
		_export_box.text = SaveManager.export_string()
		DisplayServer.clipboard_set(_export_box.text)
		EventBus.log_msg("Save exported to clipboard.", "info"))
	row.add_child(ex)
	var im := UITheme.button("Import", UITheme.TEXT)
	im.custom_minimum_size = Vector2(96, 24)
	im.pressed.connect(func():
		if SaveManager.import_string(_export_box.text):
			EventBus.log_msg("Save imported.", "good")
		else:
			EventBus.log_msg("That is not a readable save string.", "bad"))
	row.add_child(im)

	var close := UITheme.button("Close  [Esc]", UITheme.TEXT)
	close.custom_minimum_size = Vector2(0, 26)
	close.pressed.connect(func(): visible = false)
	col.add_child(close)

	visible = false
	load_settings()

func toggle() -> void:
	visible = not visible

func set_reduced_motion(on: bool) -> void:
	AudioDirector.reduced_motion = on
	var overlay: Node = get_tree().root.find_child("OverlayLayer", true, false)
	if overlay != null:
		overlay.set("reduced_motion", on)
		if on:
			overlay.set("shake", 0.0)

func save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("audio", "master_db", AudioDirector.master_volume)
	cfg.set_value("accessibility", "reduced_motion", AudioDirector.reduced_motion)
	cfg.save(PATH)

func load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(PATH) != OK:
		return
	AudioDirector.set_master_volume(float(cfg.get_value("audio", "master_db", 0.0)))
	set_reduced_motion(bool(cfg.get_value("accessibility", "reduced_motion", false)))
