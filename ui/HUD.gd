extends Control
## Everything the player needs at a glance, in one voice: chamfered panels,
## tick-led headers, and colour that always means the same thing.
##
## The two lines that matter most sit together at the top left — the level
## you are on, and the luminance that decides how hard it is.

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
var _shields: Label
var _dps: Label
var _aim: Label
var _clock: Label
var _best: Label
var _next: Button
var _tree_btn: Button
var _douse_label: Label
var _douse_sub: Label
var _douse_bar: ProgressBar
var _hint: Label
var _hint_until: float = 0.0
var _refresh: float = 0.0

func _ready() -> void:
	_build_status()
	_build_run()
	_build_douse()
	_build_bar()

# --- top left: where you are, and how bright ----------------------------

func _build_status() -> void:
	var pair: Array = UITheme.make_section("level", UITheme.GOOD)
	var panel: PanelContainer = pair[0]
	var col: VBoxContainer = pair[1]
	panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	panel.position = Vector2(16, 14)
	panel.custom_minimum_size = Vector2(302, 0)
	add_child(panel)

	_level = UITheme.label("LEVEL 1", UITheme.TEXT_BRIGHT, 26)
	col.add_child(_level)
	_level_bar = UITheme.meter(UITheme.GOOD, 7)
	col.add_child(_level_bar)
	_level_sub = UITheme.label("", UITheme.TEXT_DIM, 11)
	col.add_child(_level_sub)

	col.add_child(UITheme.rule())
	col.add_child(UITheme.header("luminance", UITheme.LUM))
	_lum = UITheme.label("0", UITheme.LUM, 26)
	col.add_child(_lum)
	# The line that makes the whole design legible: what your light is doing
	# to the field, updated live.
	_cause = UITheme.label("", UITheme.TEXT_DIM, 12)
	col.add_child(_cause)

	col.add_child(UITheme.rule())
	_motes = UITheme.label("0 motes", UITheme.MOTES, 17)
	col.add_child(_motes)
	_shields = UITheme.label("shields 3 / 3", UITheme.GOOD, 14)
	col.add_child(_shields)
	_dps = UITheme.label("", UITheme.TEXT_FAINT, 11)
	col.add_child(_dps)
	_aim = UITheme.label("", UITheme.TEXT_DIM, 12)
	col.add_child(_aim)

# --- top right: the run ---------------------------------------------------

func _build_run() -> void:
	var pair: Array = UITheme.make_section("run", UITheme.COOL)
	var panel: PanelContainer = pair[0]
	var col: VBoxContainer = pair[1]
	panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	panel.position = Vector2(-238, 14)
	panel.custom_minimum_size = Vector2(222, 0)
	add_child(panel)

	_clock = UITheme.label("0s", UITheme.TEXT, 14)
	col.add_child(_clock)
	_best = UITheme.label("best  level 1", UITheme.TEXT_DIM, 13)
	col.add_child(_best)
	_next = UITheme.cta("Begin level 2", UITheme.GOOD)
	_next.custom_minimum_size = Vector2(0, 38)
	_next.visible = false
	_next.pressed.connect(func(): next_level_pressed.emit())
	col.add_child(_next)

# --- bottom centre: the one held key -------------------------------------

func _build_douse() -> void:
	var pair: Array = UITheme.make_section("", UITheme.COOL)
	var panel: PanelContainer = pair[0]
	var col: VBoxContainer = pair[1]
	panel.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	panel.position = Vector2(-160, -104)
	panel.custom_minimum_size = Vector2(320, 0)
	add_child(panel)

	_douse_label = UITheme.label("HOLD SPACE TO HIDE", UITheme.TEXT_DIM, 14)
	_douse_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(_douse_label)
	_douse_sub = UITheme.label("", UITheme.TEXT_FAINT, 10)
	_douse_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(_douse_sub)
	_douse_bar = UITheme.meter(UITheme.COOL, 8)
	col.add_child(_douse_bar)
	_hint = UITheme.label("", UITheme.WARN, 13)
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(_hint)
	# The spec introduces Douse the first time a shield goes, not before.
	EventBus.shield_breached.connect(func(_r: int): _hint_until = 8.0)

func _build_bar() -> void:
	var bar := HBoxContainer.new()
	bar.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	bar.position = Vector2(16, -52)
	bar.add_theme_constant_override("separation", 8)
	add_child(bar)
	_tree_btn = UITheme.button("Tree  [T]", UITheme.ACCENT)
	_tree_btn.custom_minimum_size = Vector2(206, 34)
	_tree_btn.tooltip_text = "Upgrades happen between levels."
	_tree_btn.pressed.connect(func(): tree_pressed.emit())
	bar.add_child(_tree_btn)
	var set_btn := UITheme.button("Settings  [Esc]", UITheme.TEXT_DIM)
	set_btn.custom_minimum_size = Vector2(150, 34)
	set_btn.pressed.connect(func(): settings_pressed.emit())
	bar.add_child(set_btn)

# --- live ----------------------------------------------------------------

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
			_tint(_level_sub, "boss — kill it to finish the level", UITheme.BAD)
		GameStateData.Phase.UPGRADING:
			_level_bar.value = 1.0
			_tint(_level_sub, "cleared — spend, then begin level %d" % (s.level + 1), UITheme.GOOD)
		_:
			_level_bar.value = Levels.progress(s)
			var left: float = Levels.time_left(s)
			_tint(_level_sub, "%d / %d kills to the boss     boss in %ds" % [
				s.level_kills, Levels.quota(s), int(left)],
				UITheme.WARN if left < 10.0 else UITheme.TEXT_DIM)

	_lum.text = UITheme.fmt(l)
	_lum.add_theme_color_override("font_color", UITheme.COOL if s.is_dousing() else UITheme.LUM)
	var pressure: float = Spawning.spawn_pressure(l)
	if pressure <= 0.0:
		_tint(_cause, "nothing is spawning", UITheme.GOOD)
	else:
		_tint(_cause, "spawn x%.1f     max tier %d     speed %d" % [
			pressure, Spawning.max_tier(l), int(Spawning.drift_speed(l))],
			UITheme.BAD if pressure > 4.0 else UITheme.TEXT_DIM)

	_motes.text = "%s motes" % UITheme.fmt(s.motes)
	_tint(_shields, "shields %d / %d" % [maxi(s.shields, 0), Stats.max_shields],
		UITheme.BAD if s.shields <= 1 else UITheme.GOOD)
	_dps.text = "%s dps     %d range     %d contacts" % [
		UITheme.fmt(Stats.dps()), int(Stats.turret_range), s.contacts.size()]

	if s.locked_id != 0:
		_tint(_aim, "ON TARGET", UITheme.GOOD)
	elif Turret.anything_in_range(s):
		_tint(_aim, "aim at something in range", UITheme.WARN)
	else:
		_tint(_aim, "nothing in range", UITheme.TEXT_FAINT)

	_clock.text = UITheme.fmt_time(s.t)
	_best.text = "best  level %d" % maxi(s.best_level, s.level)
	var shopping: bool = GameState.upgrading()
	_next.visible = shopping
	_next.text = "Begin level %d" % (s.level + 1)
	_tree_btn.disabled = not shopping
	_tree_btn.text = "Tree  [T]" if shopping else "Tree — between levels"

	_douse_bar.value = s.douse_meter
	if s.is_dousing():
		_tint(_douse_label, "HIDDEN", UITheme.COOL)
		_douse_sub.text = "spawning almost stopped · earning nothing"
	elif s.douse_meter < 0.25:
		_tint(_douse_label, "OUT OF BREATH", UITheme.WARN)
		_douse_sub.text = "wait for the meter to refill"
	else:
		_tint(_douse_label, "HOLD SPACE TO HIDE", UITheme.TEXT_DIM)
		_douse_sub.text = "light drops to 10% · spawning slows · you earn nothing"

	_hint_until = maxf(_hint_until - REFRESH, 0.0)
	_hint.text = "Losing shields? Hold Space." if _hint_until > 0.0 else ""

func _tint(l: Label, text: String, col: Color) -> void:
	l.text = text
	l.add_theme_color_override("font_color", col)
