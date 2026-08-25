extends Control
## Luminance is on screen at all times, and the line that says what it is
## doing to the field sits directly under it. Everything depends on the
## player connecting those two by minute four.

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
var _best: Label
var _shields: Label
var _dps: Label
var _aim: Label
var _clock: Label
var _douse_bar: ProgressBar
var _douse_label: Label
var _douse_sub: Label
var _hint: Label
var _hint_until: float = 0.0
var _next: Button
var _refresh: float = 0.0

func _ready() -> void:
	# Anchor the panels, never this wrapper — its preset comes from Main.tscn.
	var top := UITheme.make_panel()
	top.set_anchors_preset(Control.PRESET_TOP_LEFT)
	top.position = Vector2(14, 12)
	top.custom_minimum_size = Vector2(300, 0)
	add_child(top)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 3)
	top.add_child(col)

	_level = UITheme.label("LEVEL 1", UITheme.TEXT_BRIGHT, 24)
	col.add_child(_level)
	_level_bar = ProgressBar.new()
	_level_bar.custom_minimum_size = Vector2(0, 7)
	_level_bar.show_percentage = false
	_level_bar.max_value = 1.0
	var lfill := StyleBoxFlat.new()
	lfill.bg_color = Color(0.55, 0.92, 0.68)
	_level_bar.add_theme_stylebox_override("fill", lfill)
	var lbg := StyleBoxFlat.new()
	lbg.bg_color = Color(0.10, 0.14, 0.12)
	_level_bar.add_theme_stylebox_override("background", lbg)
	col.add_child(_level_bar)
	_level_sub = UITheme.label("", UITheme.TEXT_DIM, 11)
	col.add_child(_level_sub)
	col.add_child(HSeparator.new())

	_lum = UITheme.label("LUMINANCE 0", UITheme.LUM, 22)
	col.add_child(_lum)
	# The causation line. This is the most important text in the game.
	_cause = UITheme.label("spawn x1.0   tier 0   speed 18", UITheme.TEXT_DIM, 12)
	col.add_child(_cause)
	col.add_child(HSeparator.new())
	_motes = UITheme.label("0 motes", UITheme.MOTES, 16)
	col.add_child(_motes)
	_shields = UITheme.label("Shields 3", UITheme.GOOD, 14)
	col.add_child(_shields)
	_dps = UITheme.label("", UITheme.TEXT_DIM, 11)
	col.add_child(_dps)
	_aim = UITheme.label("", UITheme.TEXT_DIM, 12)
	col.add_child(_aim)

	var right := UITheme.make_panel()
	right.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	right.position = Vector2(-262, 12)
	right.custom_minimum_size = Vector2(248, 0)
	add_child(right)
	var rc := VBoxContainer.new()
	rc.add_theme_constant_override("separation", 3)
	right.add_child(rc)
	_clock = UITheme.label("0s", UITheme.TEXT_DIM, 12)
	rc.add_child(_clock)
	_best = UITheme.label("best: level 1", UITheme.TEXT_DIM, 13)
	rc.add_child(_best)
	# Only appears between levels, which is the moment to spend.
	_next = UITheme.button("Begin level 2", UITheme.GOOD)
	_next.custom_minimum_size = Vector2(0, 34)
	_next.visible = false
	_next.pressed.connect(func(): next_level_pressed.emit())
	rc.add_child(_next)

	# Douse meter, bottom centre, where a panic button belongs.
	var douse := UITheme.make_panel()
	douse.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	douse.position = Vector2(-130, -78)
	douse.custom_minimum_size = Vector2(260, 0)
	add_child(douse)
	var dc := VBoxContainer.new()
	dc.add_theme_constant_override("separation", 2)
	douse.add_child(dc)
	_douse_label = UITheme.label("HOLD SPACE TO HIDE", UITheme.TEXT_DIM, 13)
	_douse_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	dc.add_child(_douse_label)
	_douse_sub = UITheme.label("light drops to 10% · spawning slows · you earn nothing",
		UITheme.TEXT_DIM * 0.85, 10)
	_douse_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	dc.add_child(_douse_sub)
	_douse_bar = ProgressBar.new()
	_douse_bar.custom_minimum_size = Vector2(0, 8)
	_douse_bar.show_percentage = false
	_douse_bar.max_value = 1.0
	_douse_bar.value = 1.0
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color(0.45, 0.65, 1.0)
	_douse_bar.add_theme_stylebox_override("fill", fill)
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.10, 0.11, 0.14)
	_douse_bar.add_theme_stylebox_override("background", bg)
	dc.add_child(_douse_bar)
	_hint = UITheme.label("", UITheme.WARN, 13)
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	dc.add_child(_hint)
	# The spec introduces Douse the first time a shield goes, not before.
	EventBus.shield_breached.connect(func(_r: int):
		_hint_until = 8.0)

	var bar := HBoxContainer.new()
	bar.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	bar.position = Vector2(14, -46)
	bar.add_theme_constant_override("separation", 8)
	add_child(bar)
	var tree_btn := UITheme.button("Tree  [T]", UITheme.TEXT_BRIGHT)
	tree_btn.custom_minimum_size = Vector2(130, 32)
	tree_btn.pressed.connect(func(): tree_pressed.emit())
	bar.add_child(tree_btn)
	var set_btn := UITheme.button("Settings  [Esc]", UITheme.TEXT_DIM)
	set_btn.custom_minimum_size = Vector2(140, 32)
	set_btn.pressed.connect(func(): settings_pressed.emit())
	bar.add_child(set_btn)

func _process(delta: float) -> void:
	_refresh -= delta
	if _refresh > 0.0:
		return
	_refresh = REFRESH
	var s: GameStateData = GameState.s
	var l: float = s.effective_luminance()

	_level.text = "LEVEL %d" % s.level
	match s.phase:
		GameStateData.Phase.BOSS:
			_level_bar.value = 1.0
			_level_sub.text = "boss — kill it to finish the level"
			_level_sub.add_theme_color_override("font_color", UITheme.BAD)
		GameStateData.Phase.UPGRADING:
			_level_bar.value = 1.0
			_level_sub.text = "cleared — spend, then begin level %d" % (s.level + 1)
			_level_sub.add_theme_color_override("font_color", UITheme.GOOD)
		_:
			_level_bar.value = Levels.progress(s)
			var left: float = Levels.time_left(s)
			_level_sub.text = "%d / %d kills to the boss    boss in %ds" % [
				s.level_kills, Levels.quota(s), int(left)]
			_level_sub.add_theme_color_override("font_color",
				UITheme.WARN if left < 10.0 else UITheme.TEXT_DIM)

	_lum.text = "LUMINANCE %s" % UITheme.fmt(l)
	_lum.add_theme_color_override("font_color",
		Color(0.45, 0.65, 1.0) if s.is_dousing() else UITheme.LUM)

	var pressure: float = Spawning.spawn_pressure(l)
	var arrow: String = "v" if s.is_dousing() else "^"
	if pressure <= 0.0:
		_cause.text = "%s  nothing is spawning" % arrow
		_cause.add_theme_color_override("font_color", UITheme.GOOD)
	else:
		_cause.text = "%s spawn x%.1f   max tier %d   speed %d" % [
			arrow, pressure, Spawning.max_tier(l), int(Spawning.drift_speed(l))]
		_cause.add_theme_color_override("font_color",
			UITheme.BAD if pressure > 4.0 else UITheme.TEXT_DIM)

	_motes.text = "%s motes" % UITheme.fmt(s.motes)
	_shields.text = "Shields %d / %d" % [maxi(s.shields, 0), Stats.max_shields]
	_shields.add_theme_color_override("font_color",
		UITheme.BAD if s.shields <= 1 else UITheme.GOOD)
	_dps.text = "%s dps   %d range   %d contacts" % [
		UITheme.fmt(Stats.dps()), int(Stats.turret_range), s.contacts.size()]
	if s.locked_id != 0:
		_aim.text = "ON TARGET"
		_aim.add_theme_color_override("font_color", UITheme.GOOD)
	elif Turret.anything_in_range(s):
		_aim.text = "aim at something in range"
		_aim.add_theme_color_override("font_color", UITheme.WARN)
	else:
		_aim.text = "nothing in range"
		_aim.add_theme_color_override("font_color", UITheme.TEXT_DIM)

	_clock.text = UITheme.fmt_time(s.t)
	_best.text = "best: level %d" % maxi(s.best_level, s.level)
	_next.visible = GameState.upgrading()
	_next.text = "Begin level %d" % (s.level + 1)

	_douse_bar.value = s.douse_meter
	if s.is_dousing():
		_douse_label.text = "HIDDEN"
		_douse_label.add_theme_color_override("font_color", Color(0.55, 0.75, 1.0))
		_douse_sub.text = "spawning almost stopped · earning nothing"
	elif s.douse_meter < 0.25:
		_douse_label.text = "OUT OF BREATH"
		_douse_label.add_theme_color_override("font_color", UITheme.WARN)
		_douse_sub.text = "wait for the meter to refill"
	else:
		_douse_label.text = "HOLD SPACE TO HIDE"
		_douse_label.add_theme_color_override("font_color", UITheme.TEXT_DIM)
		_douse_sub.text = "light drops to 10% · spawning slows · you earn nothing"

	_hint_until = maxf(_hint_until - REFRESH, 0.0)
	_hint.text = "Losing shields? Hold Space." if _hint_until > 0.0 else ""
