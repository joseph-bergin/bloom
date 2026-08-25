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

# --- ground --------------------------------------------------------------
const VOID := Color(0.020, 0.027, 0.040)
const PANEL := Color(0.043, 0.055, 0.075, 0.93)
const PANEL_SOLID := Color(0.043, 0.055, 0.075, 0.99)
const EDGE := Color(0.24, 0.36, 0.44, 0.85)

# --- text ----------------------------------------------------------------
const TEXT := Color(0.78, 0.85, 0.92)
const TEXT_DIM := Color(0.44, 0.53, 0.62)
const TEXT_FAINT := Color(0.30, 0.37, 0.45)
const TEXT_BRIGHT := Color(0.95, 0.98, 1.0)

# --- meaning -------------------------------------------------------------
const MOTES := Color(0.99, 0.76, 0.36)
const LUM := Color(1.0, 0.82, 0.48)
const GOOD := Color(0.40, 0.92, 0.66)
const WARN := Color(0.99, 0.76, 0.32)
const BAD := Color(1.0, 0.38, 0.34)
const COOL := Color(0.42, 0.72, 1.0)
const ACCENT := Color(0.40, 0.88, 0.78)

const BRANCH := {
	&"burn": Color(1.0, 0.36, 0.16),
	&"shroud": Color(0.46, 0.56, 0.82),
	&"reach": Color(0.42, 0.88, 0.78),
	&"root": Color(0.56, 0.92, 0.38),
}

## Contact colour by tier. Shared by the field, the impact sparks and
## anything else that has to agree on what a tier-4 looks like.
const TIER: Array[Color] = [
	Color(0.85, 0.32, 0.30), Color(0.90, 0.42, 0.28), Color(0.94, 0.55, 0.26),
	Color(0.96, 0.36, 0.42), Color(0.92, 0.28, 0.55), Color(0.80, 0.30, 0.75),
	Color(0.62, 0.36, 0.92), Color(0.45, 0.50, 1.00)]

static func tier_colour(t: int) -> Color:
	return TIER[clampi(t, 0, 7)]

static func branch_colour(b: StringName) -> Color:
	return BRANCH.get(b, Color(0.7, 0.75, 0.8))

# --- panels --------------------------------------------------------------

static func box(accent: Color = ACCENT, solid: bool = false) -> ChamferBox:
	return ChamferBox.new(PANEL_SOLID if solid else PANEL, EDGE, accent)

static func make_panel(accent: Color = ACCENT, solid: bool = false) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", box(accent, solid))
	return p

## A panel with a titled header rule. Returns the content box to fill.
static func make_section(title: String, accent: Color = ACCENT) -> Array:
	var panel := make_panel(accent)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 4)
	panel.add_child(col)
	if title != "":
		col.add_child(header(title, accent))
	return [panel, col]

## Small caps with tracking and a leading tick — the game's label voice.
static func header(text: String, accent: Color = ACCENT) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	var tick := ColorRect.new()
	tick.color = accent
	tick.custom_minimum_size = Vector2(3, 10)
	tick.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(tick)
	var l := Label.new()
	l.text = text.to_upper()
	l.add_theme_font_override("font", font())
	l.add_theme_color_override("font_color", accent * 0.92)
	l.add_theme_font_size_override("font_size", TINY)
	l.add_theme_constant_override("outline_size", 0)
	row.add_child(l)
	return row

static func rule(col: Color = EDGE) -> Control:
	var r := ColorRect.new()
	r.color = Color(col.r, col.g, col.b, 0.30)
	r.custom_minimum_size = Vector2(0, 1)
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
	b.add_theme_font_size_override("font_size", 14)
	var normal := ChamferBox.new(Color(0.07, 0.09, 0.12, 0.95), EDGE * 0.9, col * 0.75)
	normal.set_pad(8.0)
	normal.ticks = false
	b.add_theme_stylebox_override("normal", normal)
	var hover := ChamferBox.new(Color(0.11, 0.15, 0.20, 0.98), col * 0.8, col)
	hover.set_pad(8.0)
	hover.ticks = false
	b.add_theme_stylebox_override("hover", hover)
	var pressed := ChamferBox.new(col * 0.22, col, col)
	pressed.set_pad(8.0)
	pressed.ticks = false
	b.add_theme_stylebox_override("pressed", pressed)
	var disabled := ChamferBox.new(Color(0.05, 0.06, 0.08, 0.85),
		Color(0.16, 0.20, 0.24, 0.6), Color(0.20, 0.24, 0.28))
	disabled.set_pad(8.0)
	disabled.ticks = false
	b.add_theme_stylebox_override("disabled", disabled)
	return b

## A primary action: bigger, brighter, unmistakable.
static func cta(text: String, col: Color = ACCENT) -> Button:
	var b := button(text, TEXT_BRIGHT)
	b.add_theme_font_size_override("font_size", 14)
	var normal := ChamferBox.new(col * 0.16, col * 0.9, col)
	normal.set_pad(10.0)
	normal.accent_width = 3.0
	b.add_theme_stylebox_override("normal", normal)
	var hover := ChamferBox.new(col * 0.30, col, col)
	hover.set_pad(10.0)
	hover.accent_width = 3.0
	b.add_theme_stylebox_override("hover", hover)
	return b

## A labelled bar. Returns [row, bar] so callers can drive the value.
static func meter(col: Color, height: int = 6) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.custom_minimum_size = Vector2(0, height)
	bar.show_percentage = false
	bar.max_value = 1.0
	var fill := StyleBoxFlat.new()
	fill.bg_color = col
	fill.set_corner_radius_all(0)
	bar.add_theme_stylebox_override("fill", fill)
	var bg := StyleBoxFlat.new()
	# Dark, but visibly a track — an invisible one makes a part-full meter
	# read as a stray nub rather than progress.
	bg.bg_color = Color(col.r, col.g, col.b, 0.20).darkened(0.55)
	bg.set_corner_radius_all(0)
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
