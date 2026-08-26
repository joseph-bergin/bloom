extends Control
## Audio and reduced-motion only. Everything past those is cuttable.

const PATH := "user://settings.cfg"

func _ready() -> void:
	visible = false
	var pair: Array = UITheme.make_section("settings", UITheme.ACCENT)
	var panel: PanelContainer = pair[0]
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.position = Vector2(-160, -120)
	panel.custom_minimum_size = Vector2(320, 0)
	add_child(panel)
	var col: VBoxContainer = pair[1]
	col.add_theme_constant_override("separation", 6)

	col.add_child(UITheme.label("Master volume", UITheme.TEXT_DIM, UITheme.TINY))
	var vol := HSlider.new()
	vol.min_value = -40.0
	vol.max_value = 6.0
	vol.step = 1.0
	vol.value = Audio.master_db
	vol.custom_minimum_size = Vector2(0, 18)
	vol.value_changed.connect(func(v: float):
		Audio.set_master_volume(v)
		save_settings())
	col.add_child(vol)

	var rm := CheckBox.new()
	rm.text = "Reduced motion"
	rm.tooltip_text = "Disables screenshake."
	rm.button_pressed = Audio.reduced_motion
	rm.toggled.connect(func(on: bool):
		set_reduced_motion(on)
		save_settings())
	col.add_child(rm)

	col.add_child(UITheme.rule())
	var wipe := UITheme.button("Erase save", UITheme.BAD)
	wipe.custom_minimum_size = Vector2(0, 26)
	wipe.pressed.connect(func():
		SaveManager.wipe()
		get_tree().reload_current_scene())
	col.add_child(wipe)

	var close := UITheme.button("Close  [Esc]", UITheme.TEXT)
	close.custom_minimum_size = Vector2(0, 26)
	close.pressed.connect(func(): visible = false)
	col.add_child(close)

	load_settings()

func toggle() -> void:
	visible = not visible

func set_reduced_motion(on: bool) -> void:
	Audio.reduced_motion = on
	var overlay: Node = get_tree().root.find_child("OverlayLayer", true, false)
	if overlay != null:
		overlay.set("reduced_motion", on)
		if on:
			overlay.set("shake", 0.0)

func save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("audio", "master_db", Audio.master_db)
	cfg.set_value("a11y", "reduced_motion", Audio.reduced_motion)
	cfg.save(PATH)

func load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(PATH) != OK:
		return
	Audio.set_master_volume(float(cfg.get_value("audio", "master_db", 0.0)))
	set_reduced_motion(bool(cfg.get_value("a11y", "reduced_motion", false)))
