class_name UITheme
extends RefCounted

const BG := Color(0.035, 0.042, 0.058, 0.90)
const PANEL_EDGE := Color(0.20, 0.26, 0.34, 0.85)
const TEXT := Color(0.80, 0.86, 0.93)
const TEXT_DIM := Color(0.48, 0.55, 0.64)
const TEXT_BRIGHT := Color(0.96, 0.98, 1.0)

const MOTES := Color(0.98, 0.78, 0.42)
const EMBERS := Color(1.0, 0.52, 0.32)
const LUM := Color(1.0, 0.84, 0.52)
const GOOD := Color(0.5, 0.92, 0.62)
const WARN := Color(0.98, 0.78, 0.35)
const BAD := Color(1.0, 0.42, 0.36)

const BRANCH := {
	&"burn": Color(1.0, 0.36, 0.16),
	&"shroud": Color(0.46, 0.56, 0.82),
	&"reach": Color(0.42, 0.88, 0.78),
	&"root": Color(0.56, 0.92, 0.38),
}

static func branch_colour(b: StringName) -> Color:
	return BRANCH.get(b, Color(0.7, 0.75, 0.8))

static func panel_style(bg: Color = BG) -> StyleBoxFlat:
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

static func make_panel() -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", panel_style())
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
	b.add_theme_stylebox_override("normal", panel_style(Color(0.09, 0.11, 0.15, 0.95)))
	b.add_theme_stylebox_override("hover", panel_style(Color(0.14, 0.18, 0.24, 0.98)))
	b.add_theme_stylebox_override("pressed", panel_style(Color(0.20, 0.26, 0.32, 1.0)))
	b.add_theme_stylebox_override("disabled", panel_style(Color(0.06, 0.07, 0.09, 0.8)))
	return b

static func fmt(v: float, places: int = 1) -> String:
	var a: float = absf(v)
	if a < 1000.0:
		return String.num(v, 0 if a == floor(a) else 1)
	var units: Array[String] = ["K", "M", "B", "T", "Qa", "Qi", "Sx", "Sp"]
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
	return "%dm %02ds" % [s / 60, s % 60]
