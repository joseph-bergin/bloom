extends Control
## Luminance is on screen at all times. It is the only thing anything
## out there can see, so it never leaves the frame.

signal sweep_pressed()
signal tree_pressed()
signal ember_pressed()
signal settings_pressed()

var _lum: Label
var _lum_bar: ProgressBar
var _lum_detail: Label
var _motes: Label
var _signal: Label
var _facets: Label
var _embers: Label
var _redundancy: Label
var _pressure: Label
var _clock: Label
var _sweep_btn: Button
var _tree_btn: Button
var _ember_btn: Button
var _contacts: Label
var _hunter: Label

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build()

func _build() -> void:
	# --- top-left: luminance, the permanent readout ---
	var top := UITheme.make_panel()
	top.position = Vector2(14, 12)
	top.custom_minimum_size = Vector2(288, 0)
	top.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(top)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 2)
	top.add_child(col)

	_lum = UITheme.label("LUMINANCE 0.0", UITheme.LUM, 19)
	col.add_child(_lum)
	_lum_bar = ProgressBar.new()
	_lum_bar.custom_minimum_size = Vector2(0, 5)
	_lum_bar.show_percentage = false
	_lum_bar.max_value = 1.0
	var fill := StyleBoxFlat.new()
	fill.bg_color = UITheme.LUM
	_lum_bar.add_theme_stylebox_override("fill", fill)
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.12, 0.11, 0.09)
	_lum_bar.add_theme_stylebox_override("background", bg)
	col.add_child(_lum_bar)
	_lum_detail = UITheme.label("", UITheme.TEXT_DIM, 11)
	col.add_child(_lum_detail)

	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 16)
	col.add_child(grid)
	_motes = UITheme.label("0 motes", UITheme.MOTES, 13)
	_signal = UITheme.label("0 signal", UITheme.SIGNAL, 13)
	_facets = UITheme.label("0 facets", UITheme.FACETS, 13)
	_embers = UITheme.label("0 embers", UITheme.EMBERS, 13)
	for l in [_motes, _signal, _facets, _embers]:
		grid.add_child(l)

	_redundancy = UITheme.label("Redundancy 1", UITheme.TEXT, 13)
	col.add_child(_redundancy)

	# --- top-right: field state ---
	var right := UITheme.make_panel()
	right.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	right.position = Vector2(-232, 12)
	right.custom_minimum_size = Vector2(218, 0)
	right.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(right)
	var rc := VBoxContainer.new()
	rc.add_theme_constant_override("separation", 2)
	right.add_child(rc)
	_clock = UITheme.label("0s", UITheme.TEXT_DIM, 12)
	_pressure = UITheme.label("Field pressure 0.00", UITheme.TEXT, 13)
	_contacts = UITheme.label("0 contacts", UITheme.TEXT_DIM, 12)
	_hunter = UITheme.label("", UITheme.BAD, 12)
	for l in [_clock, _pressure, _contacts, _hunter]:
		rc.add_child(l)

	# --- bottom-left: actions ---
	var bar := HBoxContainer.new()
	bar.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	bar.position = Vector2(14, -46)
	bar.add_theme_constant_override("separation", 8)
	add_child(bar)
	_sweep_btn = UITheme.button("Sweep  [Space]", UITheme.SIGNAL)
	_sweep_btn.custom_minimum_size = Vector2(150, 32)
	_sweep_btn.pressed.connect(func(): sweep_pressed.emit())
	bar.add_child(_sweep_btn)
	_tree_btn = UITheme.button("Tree  [T]", UITheme.TEXT)
	_tree_btn.custom_minimum_size = Vector2(110, 32)
	_tree_btn.pressed.connect(func(): tree_pressed.emit())
	bar.add_child(_tree_btn)
	_ember_btn = UITheme.button("Ember out", UITheme.EMBERS)
	_ember_btn.custom_minimum_size = Vector2(120, 32)
	_ember_btn.pressed.connect(func(): ember_pressed.emit())
	bar.add_child(_ember_btn)
	var settings_btn := UITheme.button("Settings  [Esc]", UITheme.TEXT_DIM)
	settings_btn.custom_minimum_size = Vector2(130, 32)
	settings_btn.pressed.connect(func(): settings_pressed.emit())
	bar.add_child(settings_btn)

const REFRESH := 1.0 / 15.0
var _refresh: float = 0.0

func _process(delta: float) -> void:
	_refresh -= delta
	if _refresh > 0.0:
		return
	_refresh = REFRESH
	var d: GameStateData = GameState.data
	var l: float = d.luminance_effective()
	_lum.text = "LUMINANCE %s" % UITheme.fmt(l, 1)
	_lum_bar.value = clampf(l / 400.0, 0.0, 1.0)
	var shroud_pct: int = int(round(Stats.shroud * 100.0))
	_lum_detail.text = "structural %s   transient %s   shroud %d%%" % [
		UITheme.fmt(d.luminance_structural, 1),
		UITheme.fmt(d.luminance_transient, 1), shroud_pct]

	_motes.text = "%s motes" % UITheme.fmt(d.motes)
	_signal.text = "%s signal" % UITheme.fmt(d.signal_c)
	_facets.text = "%s facets" % UITheme.fmt(d.facets)
	_embers.text = "%s embers" % UITheme.fmt(d.embers)
	_redundancy.text = "Redundancy %d / %d" % [maxi(d.redundancy, 0), Stats.max_redundancy]
	_redundancy.add_theme_color_override("font_color",
		UITheme.BAD if d.redundancy <= 1 else UITheme.TEXT)

	_clock.text = UITheme.fmt_time(d.t) + ("   cycle %d" % d.ember_count if d.ember_count > 0 else "")
	_pressure.text = "Field pressure %.2f" % d.field_pressure
	_contacts.text = "%d contacts   %d tracked" % [d.contacts.size(), _tracked(d)]
	_hunter.text = "HUNTER IN THE FIELD" if d.has_hunter() else ""

	if Stats.can_sweep():
		var cd: float = d.sweep_cooldown
		_sweep_btn.disabled = cd > 0.0
		_sweep_btn.text = "Sweep  [Space]" if cd <= 0.0 else "Sweep  %.1fs" % cd
	else:
		_sweep_btn.disabled = true
		_sweep_btn.text = "Sweep — Nullwake"

	_ember_btn.text = "Ember out  +%s" % UITheme.fmt(Ember.total_payout(d), 1)

func _tracked(d: GameStateData) -> int:
	var n: int = 0
	for c in d.contacts:
		if Sensing.is_displayable(c, d.t):
			n += 1
	return n
