extends Control
## Two numbers matter — the level you are on and the light that decides how
## hard it is. Everything else is a bar, a pip, or gone.

signal tree_pressed()
signal next_level_pressed()
signal settings_pressed()

const REFRESH := 1.0 / 15.0

var _level: Label
var _level_bar: ProgressBar
var _level_sub: Label
var _lum: Label
var _cause: Label
var _motes: Label
var _pips: Control
var _clock: Label
var _next: Button
var _tree_btn: Button
var _breath: ProgressBar
var _hint: Label
var _hint_until: float = 0.0
var _refresh: float = 0.0

func _ready() -> void:
	_build_status()
	_build_run()
	_build_breath()
	_build_bar()

func _build_status() -> void:
	var pair: Array = UITheme.make_section("level", UITheme.GOOD)
	var panel: PanelContainer = pair[0]
	var col: VBoxContainer = pair[1]
	panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	panel.position = Vector2(16, 14)
	panel.custom_minimum_size = Vector2(300, 0)
	add_child(panel)

	_level = UITheme.label("1", UITheme.TEXT_BRIGHT, UITheme.HUGE)
	col.add_child(_level)
	_level_bar = UITheme.meter(UITheme.GOOD, 7)
	col.add_child(_level_bar)
	_level_sub = UITheme.label("", UITheme.TEXT_DIM, UITheme.TINY)
	col.add_child(_level_sub)

	col.add_child(UITheme.rule())
	col.add_child(UITheme.header("light", UITheme.LUM))
	_lum = UITheme.label("0", UITheme.LUM, UITheme.HUGE)
	col.add_child(_lum)
	# The one line of prose that earns its place: what your light is doing
	# to the field, live.
	_cause = UITheme.label("", UITheme.TEXT_DIM, UITheme.TINY)
	col.add_child(_cause)

	col.add_child(UITheme.rule())
	_motes = UITheme.label("0", UITheme.MOTES, UITheme.LARGE)
	col.add_child(_motes)
	_pips = preload("res://ui/ShieldPips.gd").new()
	col.add_child(_pips)

func _build_run() -> void:
	var pair: Array = UITheme.make_section("run", UITheme.COOL)
	var panel: PanelContainer = pair[0]
	var col: VBoxContainer = pair[1]
	panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	panel.position = Vector2(-230, 14)
	panel.custom_minimum_size = Vector2(214, 0)
	add_child(panel)
	_clock = UITheme.label("", UITheme.TEXT_DIM, UITheme.TINY)
	col.add_child(_clock)
	_next = UITheme.cta("BEGIN LEVEL 2", UITheme.GOOD)
	_next.custom_minimum_size = Vector2(0, 40)
	_next.visible = false
	_next.pressed.connect(func(): next_level_pressed.emit())
	col.add_child(_next)

## Just the bar. Holding Space is discovered once and then it is muscle.
func _build_breath() -> void:
	var panel := UITheme.make_panel(UITheme.COOL)
	panel.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	panel.position = Vector2(-130, -78)
	panel.custom_minimum_size = Vector2(260, 0)
	add_child(panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 3)
	panel.add_child(col)
	_breath = UITheme.meter(UITheme.COOL, 10)
	col.add_child(_breath)
	_hint = UITheme.label("", UITheme.WARN, UITheme.BODY)
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(_hint)
	# Douse is introduced the first time a shield goes, and never again.
	EventBus.shield_breached.connect(func(_r: int): _hint_until = 7.0)

func _build_bar() -> void:
	var bar := HBoxContainer.new()
	bar.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	bar.position = Vector2(16, -50)
	bar.add_theme_constant_override("separation", 8)
	add_child(bar)
	_tree_btn = UITheme.button("TREE", UITheme.ACCENT)
	_tree_btn.custom_minimum_size = Vector2(150, 34)
	_tree_btn.tooltip_text = "Upgrades happen between levels."
	_tree_btn.pressed.connect(func(): tree_pressed.emit())
	bar.add_child(_tree_btn)
	var set_btn := UITheme.button("OPTIONS", UITheme.TEXT_DIM)
	set_btn.custom_minimum_size = Vector2(130, 34)
	set_btn.pressed.connect(func(): settings_pressed.emit())
	bar.add_child(set_btn)

func _process(delta: float) -> void:
	_refresh -= delta
	if _refresh > 0.0:
		return
	_refresh = REFRESH
	var s: GameStateData = GameState.s
	var l: float = s.effective_luminance()

	_level.text = str(s.level)
	match s.phase:
		GameStateData.Phase.BOSS:
			_level_bar.value = 1.0
			_tint(_level_sub, "BOSS", UITheme.BAD)
		GameStateData.Phase.UPGRADING:
			_level_bar.value = 1.0
			_tint(_level_sub, "CLEARED", UITheme.GOOD)
		_:
			_level_bar.value = Levels.progress(s)
			var left: float = Levels.time_left(s)
			_tint(_level_sub, "%d/%d  BOSS %ds" % [s.level_kills, Levels.quota(s), int(left)],
				UITheme.WARN if left < 10.0 else UITheme.TEXT_DIM)

	_lum.text = UITheme.fmt(l)
	_lum.add_theme_color_override("font_color", UITheme.COOL if s.is_dousing() else UITheme.LUM)
	var pressure: float = Spawning.spawn_pressure(l)
	if pressure <= 0.0:
		_tint(_cause, "NOTHING SPAWNING", UITheme.GOOD)
	else:
		_tint(_cause, "SPAWN x%.1f  TIER %d" % [pressure, Spawning.max_tier(l)],
			UITheme.BAD if pressure > 4.0 else UITheme.TEXT_DIM)

	_motes.text = UITheme.fmt(s.motes)

	_clock.text = "BEST %d" % maxi(s.best_level, s.level)
	var shopping: bool = GameState.upgrading()
	_next.visible = shopping
	_next.text = "BEGIN LEVEL %d" % (s.level + 1)
	_tree_btn.disabled = not shopping

	_breath.value = s.douse_meter
	_hint_until = maxf(_hint_until - REFRESH, 0.0)
	_hint.text = "HOLD SPACE TO HIDE" if _hint_until > 0.0 else ""

func _tint(l: Label, text: String, col: Color) -> void:
	l.text = text
	l.add_theme_color_override("font_color", col)
