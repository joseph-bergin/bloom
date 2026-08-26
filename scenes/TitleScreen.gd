extends Control
## The title screen. The art behind it is the game's own field, so the
## thesis lands before anything is read: you are a light, the light is what
## you see by, and things drift at the edge of it.

@onready var art: Node2D = $Art
@onready var darkness: ColorRect = $Darkness
@onready var settings: Control = $Settings

const COVER := 1100.0   # half-extent the darkness rect spans, in art units

var _mat: ShaderMaterial
var _menu: VBoxContainer
var _continue: Button
var _best: Label
var _menu_col: VBoxContainer

func _ready() -> void:
	RenderingServer.set_default_clear_color(UITheme.VOID)
	# Nothing should be ticking behind the menu.
	GameState.paused = true
	_mat = darkness.material
	_build_menu()
	get_viewport().size_changed.connect(_place)
	call_deferred("_place")

var _placed_for: Vector2 = Vector2.ZERO

func _place() -> void:
	var vp: Vector2 = get_viewport_rect().size
	if vp.x <= 0.0 or vp.y <= 0.0:
		return
	_placed_for = vp
	# The bloom sits above centre so the wordmark and menu have the lower
	# half to themselves.
	art.position = Vector2(round(vp.x * 0.5), round(vp.y * 0.20))
	art.scale = Vector2.ONE * minf(vp.x / 1280.0, vp.y / 800.0)
	darkness.position = art.position - Vector2(COVER, COVER) * art.scale.x
	darkness.size = Vector2(COVER, COVER) * 2.0 * art.scale.x
	if _menu_col != null:
		# Directly under the bloom, with room for its glow.
		_menu_col.size = Vector2(COL_W, 0.0)
		# Clear of the pool at its widest, so the wordmark sits in the dark
		# below the light rather than inside it.
		_menu_col.position = Vector2(
			round(vp.x * 0.5 - COL_W * 0.5),
			round(art.position.y + (art.sight_max() + 24.0) * art.scale.x))

func _process(_delta: float) -> void:
	# Self-correcting: the viewport is not always sized when _ready runs,
	# and the menu ends up off-screen if the layout is only done once.
	if get_viewport_rect().size != _placed_for:
		_place()
	if _mat == null:
		return
	# The darkness follows the breathing light, so the mechanic is on show.
	_mat.set_shader_parameter("sight_uv", art.sight / (COVER * 2.0))
	_mat.set_shader_parameter("feather", 0.030)

## One column, one width. Every label centres inside it and every button
## fills it, so nothing can drift out of alignment as the wording changes.
const COL_W := 480.0
const BTN_H := 46.0

func _build_menu() -> void:
	var col := VBoxContainer.new()
	col.custom_minimum_size = Vector2(COL_W, 0.0)
	col.add_theme_constant_override("separation", 6)
	col.alignment = BoxContainer.ALIGNMENT_BEGIN
	# Positioned absolutely from _place(). Anchor presets kept resolving
	# against a parent that had no size yet and pinned this to the left.
	add_child(col)
	_menu_col = col

	col.add_child(_centred("BLOOM", UITheme.LUM, UITheme.TITLE))
	col.add_child(_spacer(10))
	col.add_child(_centred("as you get brighter more can find you",
		UITheme.TEXT_DIM, UITheme.TINY))
	col.add_child(_spacer(28))

	_menu = VBoxContainer.new()
	_menu.add_theme_constant_override("separation", 8)
	col.add_child(_menu)

	var s: GameStateData = GameState.s
	var resumable: bool = SaveManager.has_save() and not s.run_over and s.level > 1
	if resumable:
		_continue = _action("CONTINUE  LEVEL %d" % s.level, UITheme.LIGHT, true)
		_continue.pressed.connect(_resume)
		_menu.add_child(_continue)

	var start := _action("NEW RUN" if resumable else "BEGIN", UITheme.ACCENT, not resumable)
	start.pressed.connect(_begin)
	_menu.add_child(start)

	var opts := _action("OPTIONS", UITheme.TEXT_DIM, false)
	opts.pressed.connect(func(): settings.toggle())
	_menu.add_child(opts)

	var quit := _action("QUIT", UITheme.TEXT_FAINT, false)
	quit.pressed.connect(func(): get_tree().quit())
	_menu.add_child(quit)

	col.add_child(_spacer(16))
	_best = _centred("", UITheme.TEXT_FAINT, UITheme.TINY)
	col.add_child(_best)
	if s.best_level > 1:
		_best.text = "BEST  LEVEL %d" % s.best_level

## Every button is the same height and fills the column; only the primary
## one is emphasised, so the block reads as one stack.
func _action(text: String, col: Color, primary: bool) -> Button:
	var b: Button = UITheme.cta(text, col) if primary else UITheme.button(text, col)
	b.custom_minimum_size = Vector2(COL_W, BTN_H)
	b.size_flags_horizontal = Control.SIZE_FILL
	return b

func _centred(text: String, col: Color, size: int) -> Label:
	var l := UITheme.label(text, col, size)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.custom_minimum_size = Vector2(COL_W, 0.0)
	l.size_flags_horizontal = Control.SIZE_FILL
	return l

func _spacer(h: int) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, h)
	return c

func _begin() -> void:
	GameState.restart_run()
	_enter()

func _resume() -> void:
	_enter()

func _enter() -> void:
	GameState.paused = false
	get_tree().change_scene_to_file("res://scenes/Main.tscn")

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and (event as InputEventKey).pressed \
			and (event as InputEventKey).keycode == KEY_ESCAPE and settings.visible:
		settings.visible = false
		get_viewport().set_input_as_handled()
