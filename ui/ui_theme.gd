class_name UITheme
extends RefCounted
## One palette and one set of builders. Every panel, header and button in
## the game comes from here so the interface reads as a single system.

## The font is a 5x7 bitmap, so sizes are integer multiples of the cell.
## Anything else resamples and the pixels stop being pixels.
const CELL := 8
## 1:1 is too small to read on a 1280x800 screen, so the smallest the UI
## goes is 2x. Every size is still an integer multiple of the cell.
const TINY := CELL * 2     # 16 — captions
const BODY := CELL * 2     # 16 — everything normal
const LARGE := CELL * 3    # 24 — emphasis
const HUGE := CELL * 5     # 40 — headline
const TITLE := CELL * 9    # 72 — the wordmark, and nothing else

# --- ground --------------------------------------------------------------
# Warm and dark. Everything used to sit on a blue-grey neutral, which read
# as cold and generic; these are biased toward the fire the game is about.
const VOID := Color(0.039, 0.024, 0.027)
const PANEL := Color(0.098, 0.063, 0.071, 0.96)
const PANEL_SOLID := Color(0.098, 0.063, 0.071)
const BEVEL := Color(0.220, 0.141, 0.149)
const EDGE := Color(0.353, 0.204, 0.212)

# --- text ----------------------------------------------------------------
const TEXT := Color(0.910, 0.835, 0.800)
const TEXT_DIM := Color(0.627, 0.510, 0.470)
const TEXT_FAINT := Color(0.420, 0.325, 0.302)
const TEXT_BRIGHT := Color(1.0, 0.965, 0.937)

# --- meaning -------------------------------------------------------------
# Muted rather than neon. Saturated accents on near-black is the look the
# whole interface was trying to get away from.
const MOTES := Color(0.949, 0.667, 0.282)
const LIGHT := Color(0.980, 0.729, 0.353)
const LUM := LIGHT
const GOOD := Color(0.612, 0.757, 0.373)
const WARN := Color(0.910, 0.639, 0.267)
const BAD := Color(0.878, 0.286, 0.220)
const ACCENT := Color(0.878, 0.325, 0.243)
## Hiding. Cold against all that warmth, but a dusty violet rather than the
## bright blue that used to be everywhere.
const COOL := Color(0.545, 0.451, 0.639)

const BRANCH := {
	&"burn": Color(0.949, 0.361, 0.204),
	&"shroud": Color(0.588, 0.475, 0.686),
	&"reach": Color(0.427, 0.706, 0.612),
	&"root": Color(0.678, 0.749, 0.361),
}

## Contact colour by tier. Shared by the field, the impact sparks and
## anything else that has to agree on what a tier-4 looks like.
## Hot and saturated on purpose. The ground is warm now, so a contact in
## the same register as the light pool simply vanishes into it.
const TIER: Array[Color] = [
	Color(1.00, 0.322, 0.243), Color(1.00, 0.443, 0.196),
	Color(1.00, 0.624, 0.180), Color(1.00, 0.298, 0.396),
	Color(1.00, 0.216, 0.545), Color(0.925, 0.243, 0.729),
	Color(0.769, 0.322, 0.925), Color(0.588, 0.475, 1.00)]
## Drawn a pixel out behind every contact so it separates from whatever it
## is sitting on.
const OUTLINE := Color(0.086, 0.043, 0.051)

static func tier_colour(t: int) -> Color:
	return TIER[clampi(t, 0, 7)]

static func branch_colour(b: StringName) -> Color:
	return BRANCH.get(b, Color(0.7, 0.75, 0.8))

# --- panels --------------------------------------------------------------

static func box(accent: Color = ACCENT, tab: bool = false) -> PixelPanel:
	return PixelPanel.new(PANEL, EDGE, accent, tab)

static func make_panel(accent: Color = ACCENT, tab: bool = false) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", box(accent, tab))
	return p

## A panel with a titled header. Returns the content box to fill.
static func make_section(title: String, accent: Color = ACCENT) -> Array:
	var panel := make_panel(accent, title != "")
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 4)
	panel.add_child(col)
	if title != "":
		col.add_child(header(title, accent))
	return [panel, col]

## Plain small caps in the accent. The leading tick marks and letter-spaced
## micro-type they replaced were chrome, not information.
static func header(text: String, accent: Color = ACCENT) -> Control:
	var l := Label.new()
	l.text = text.to_upper()
	l.add_theme_font_override("font", font())
	l.add_theme_color_override("font_color", accent)
	l.add_theme_font_size_override("font_size", TINY)
	return l

static func rule(col: Color = EDGE) -> Control:
	var r := ColorRect.new()
	r.color = col
	r.custom_minimum_size = Vector2(0, 2)
	return r

# --- atoms ---------------------------------------------------------------

static func label(text: String, col: Color = TEXT, size: int = BODY) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", font())
	l.add_theme_color_override("font_color", col)
	l.add_theme_font_size_override("font_size", size)
	return l

static func wrapped(text: String, col: Color, size: int, width: float) -> Label:
	var l := label(text, col, size)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(width, 0)
	return l

static func button(text: String, col: Color = TEXT) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_override("font", font())
	b.add_theme_color_override("font_color", col)
	b.add_theme_color_override("font_hover_color", TEXT_BRIGHT)
	b.add_theme_color_override("font_pressed_color", TEXT_BRIGHT)
	b.add_theme_color_override("font_disabled_color", TEXT_FAINT)
	b.add_theme_font_size_override("font_size", BODY)
	b.add_theme_stylebox_override("normal",
		PixelPanel.new(Color(0.129, 0.082, 0.090), EDGE, col))
	b.add_theme_stylebox_override("hover",
		PixelPanel.new(Color(0.192, 0.118, 0.125), col * 0.8, col))
	b.add_theme_stylebox_override("pressed",
		PixelPanel.new(col * 0.28, col, col))
	b.add_theme_stylebox_override("disabled",
		PixelPanel.new(Color(0.075, 0.051, 0.055),
			Color(0.157, 0.106, 0.114), Color(0.20, 0.15, 0.15)))
	return b

## A primary action: brighter fill, same frame. No extra chrome.
static func cta(text: String, col: Color = ACCENT) -> Button:
	var b := button(text, TEXT_BRIGHT)
	b.add_theme_font_size_override("font_size", BODY)
	b.add_theme_stylebox_override("normal", PixelPanel.new(col * 0.24, col, col))
	b.add_theme_stylebox_override("hover", PixelPanel.new(col * 0.42, col, col))
	b.add_theme_stylebox_override("pressed", PixelPanel.new(col * 0.62, col, col))
	return b

## A labelled bar. Flat blocks with a hard frame, on the pixel grid.
static func meter(col: Color, height: int = 8) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.custom_minimum_size = Vector2(0, height)
	bar.show_percentage = false
	bar.max_value = 1.0
	var fill := StyleBoxFlat.new()
	fill.bg_color = col
	bar.add_theme_stylebox_override("fill", fill)
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.157, 0.098, 0.106)
	bg.border_color = EDGE
	bg.set_border_width_all(1)
	bar.add_theme_stylebox_override("background", bg)
	return bar

## For _draw() callers: ThemeDB.fallback_font is Godot's default, not ours.
static func font() -> Font:
	return PixelFont.font if PixelFont.font != null else ThemeDB.fallback_font

# --- numbers -------------------------------------------------------------

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
