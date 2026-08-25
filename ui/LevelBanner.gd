extends Control
## The level's punctuation: a boss bar while it lives, a clear banner after.
## Without these the run has no visible chapters at all.

var _boss_box: PanelContainer
var _boss_name: Label
var _boss_bar: ProgressBar
var _banner: VBoxContainer
var _banner_title: Label
var _banner_sub: Label
var _banner_time: float = 0.0

func _ready() -> void:
	# --- boss bar, top centre ---
	_boss_box = UITheme.make_panel(UITheme.BAD)
	_boss_box.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_boss_box.position = Vector2(-250, 14)
	_boss_box.custom_minimum_size = Vector2(500, 0)
	_boss_box.visible = false
	add_child(_boss_box)
	var bc := VBoxContainer.new()
	bc.add_theme_constant_override("separation", 3)
	_boss_box.add_child(bc)
	_boss_name = UITheme.label("", UITheme.BAD, 15)
	_boss_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bc.add_child(_boss_name)
	_boss_bar = UITheme.meter(UITheme.BAD, 12)
	bc.add_child(_boss_bar)

	# --- clear banner, centre screen ---
	_banner = VBoxContainer.new()
	_banner.set_anchors_preset(Control.PRESET_CENTER)
	_banner.position = Vector2(-220, -110)
	_banner.custom_minimum_size = Vector2(440, 0)
	_banner.add_theme_constant_override("separation", 4)
	_banner.visible = false
	add_child(_banner)
	_banner_title = UITheme.label("", UITheme.GOOD, 34)
	_banner_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner.add_child(_banner_title)
	_banner_sub = UITheme.label("", UITheme.MOTES, 16)
	_banner_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner.add_child(_banner_sub)

	EventBus.boss_spawned.connect(func(_c: Contact, level: int):
		_boss_name.text = "LEVEL %d BOSS — kill it to finish the level" % level
		_boss_box.visible = true)
	EventBus.level_cleared.connect(func(level: int, bonus: float):
		_boss_box.visible = false
		_show("LEVEL %d CLEARED" % level,
			"+%s motes    next: level %d" % [UITheme.fmt(bonus), level + 1], UITheme.GOOD))
	EventBus.boss_breached.connect(func(_level: int):
		_boss_box.visible = false
		_show("THE BOSS GOT THROUGH", "-1 shield", UITheme.BAD))
	EventBus.run_started.connect(func(): _boss_box.visible = false)

func _show(title: String, sub: String, col: Color) -> void:
	_banner_title.text = title
	_banner_title.add_theme_color_override("font_color", col)
	_banner_sub.text = sub
	_banner.visible = true
	_banner.modulate.a = 0.0
	_banner_time = Constants.LEVEL_CLEAR_PAUSE
	create_tween().tween_property(_banner, "modulate:a", 1.0, 0.25)

func _process(delta: float) -> void:
	if _banner_time > 0.0:
		_banner_time -= delta
		if _banner_time <= 0.0:
			var tw := create_tween()
			tw.tween_property(_banner, "modulate:a", 0.0, 0.4)
			tw.tween_callback(func(): _banner.visible = false)

	var b: Contact = GameState.s.boss()
	if b == null:
		if GameState.s.phase != GameStateData.Phase.BOSS:
			_boss_box.visible = false
		return
	_boss_box.visible = true
	_boss_bar.value = b.hp / maxf(b.max_hp, 0.001)
