class_name UITheme
extends RefCounted
## One palette for the whole interface. Currency colours are load-bearing:
## node costs are colour-coded so the tree reads as complex at a glance
## while staying instantly legible.

const BG := Color(0.035, 0.042, 0.058, 0.88)
const BG_SOLID := Color(0.045, 0.052, 0.070, 0.98)
const PANEL_EDGE := Color(0.20, 0.26, 0.34, 0.85)
const TEXT := Color(0.80, 0.86, 0.93)
const TEXT_DIM := Color(0.48, 0.55, 0.64)
const TEXT_BRIGHT := Color(0.96, 0.98, 1.0)

const MOTES := Color(0.98, 0.78, 0.42)
const SIGNAL := Color(0.42, 0.88, 0.78)
const FACETS := Color(0.72, 0.62, 0.98)
const EMBERS := Color(1.0, 0.52, 0.32)
const LUM := Color(1.0, 0.84, 0.52)

const GOOD := Color(0.5, 0.92, 0.62)
const WARN := Color(0.98, 0.78, 0.35)
const BAD := Color(1.0, 0.42, 0.36)
const CASCADE := Color(1.0, 0.62, 0.30)
const NECROTIC := Color(0.36, 0.30, 0.36)

const CONSTELLATION := {
	&"expansion": Color(0.98, 0.72, 0.38),
	&"shroud": Color(0.46, 0.52, 0.72),
	&"optics": Color(0.44, 0.86, 0.82),
	&"sweep": Color(0.40, 0.94, 0.66),
	&"lance": Color(1.0, 0.56, 0.42),
	&"tether": Color(0.92, 0.80, 0.44),
	&"redundancy": Color(0.58, 0.78, 0.96),
	&"cognition": Color(0.78, 0.62, 0.98),
	&"choir": Color(0.96, 0.48, 0.72),
	&"lattice": Color(0.52, 0.94, 0.90),
	&"the_cold": Color(0.72, 0.86, 1.0),
}

static func constellation_colour(c: StringName) -> Color:
	return CONSTELLATION.get(c, Color(0.7, 0.75, 0.8))

static func log_colour(kind: String) -> Color:
	match kind:
		"good": return GOOD
		"warn": return WARN
		"bad": return BAD
		"cascade": return CASCADE
		"sense": return SIGNAL
		_: return TEXT_DIM

static func panel(bg: Color = BG) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = PANEL_EDGE
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(3)
	sb.content_margin_left = 10
	sb.content_margin_right = 10
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	return sb

static func make_panel(size: Vector2 = Vector2.ZERO) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", panel())
	if size != Vector2.ZERO:
		p.custom_minimum_size = size
	return p

static func label(text: String, col: Color = TEXT, size: int = 13) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_color_override("font_color", col)
	l.add_theme_font_size_override("font_size", size)
	return l

static func button(text: String, col: Color = TEXT) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_color_override("font_color", col)
	b.add_theme_color_override("font_hover_color", TEXT_BRIGHT)
	b.add_theme_color_override("font_disabled_color", TEXT_DIM * 0.7)
	b.add_theme_font_size_override("font_size", 13)
	var normal := panel(Color(0.09, 0.11, 0.15, 0.95))
	b.add_theme_stylebox_override("normal", normal)
	var hover := panel(Color(0.14, 0.18, 0.24, 0.98))
	b.add_theme_stylebox_override("hover", hover)
	var pressed := panel(Color(0.20, 0.26, 0.32, 1.0))
	b.add_theme_stylebox_override("pressed", pressed)
	var disabled := panel(Color(0.06, 0.07, 0.09, 0.8))
	b.add_theme_stylebox_override("disabled", disabled)
	return b

## Numbers in an incremental have to stay readable across 12 orders of magnitude.
static func fmt(v: float, places: int = 1) -> String:
	var a: float = absf(v)
	if a < 1000.0:
		return String.num(v, 1 if a < 100.0 and a != floor(a) else 0)
	var units: Array[String] = ["K", "M", "B", "T", "Qa", "Qi", "Sx", "Sp", "Oc", "No", "Dc"]
	var idx: int = -1
	var x: float = v
	while absf(x) >= 1000.0 and idx < units.size() - 1:
		x /= 1000.0
		idx += 1
	return String.num(x, places) + units[idx]

static func fmt_time(seconds: float) -> String:
	var s: int = int(maxf(seconds, 0.0))
	if s < 60:
		return "%ds" % s
	if s < 3600:
		return "%dm %02ds" % [s / 60, s % 60]
	return "%dh %02dm" % [s / 3600, (s % 3600) / 60]
