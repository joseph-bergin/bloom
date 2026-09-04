extends Control
## The first thing a new player sees. It teaches the whole game by showing
## it rather than listing it: light is the map, brightness is what draws the
## Unlit in, and going dark is how you survive them.
##
## Plays once. Skippable from the first frame — nobody should have to sit
## through it twice, and the Options panel can replay it on purpose.

const COVER := 1100.0   # half-extent the darkness rect spans, in stage units

## Each beat: how long it holds, what it says, and where it puts the stage.
## `core` is the bloom, `sight` the lit pool, `unlit` how many are out there.
const BEATS: Array[Dictionary] = [
	{"hold": 3.0, "core": 0.0, "sight": 0.0, "unlit": 0,
	 "text": "There were a billion lights once."},
	{"hold": 2.8, "core": 0.0, "sight": 0.0, "unlit": 0,
	 "text": "The night they all went out has a name."},
	{"hold": 2.8, "core": 5.0, "sight": 0.0, "unlit": 0, "cue": "breach",
	 "text": "The Snuffing."},
	{"hold": 3.2, "core": 30.0, "sight": 0.0, "unlit": 0, "cue": "purchase",
	 "text": "You are what it missed."},
	{"hold": 3.6, "core": 34.0, "sight": 175.0, "unlit": 0, "cue": "douse_out",
	 "text": "Your light is the only map you have.\nWhat it touches, you can reach."},
	{"hold": 3.2, "core": 34.0, "sight": 185.0, "unlit": 5,
	 "text": "But the dark out here is not empty."},
	{"hold": 3.8, "core": 36.0, "sight": 195.0, "unlit": 9,
	 "text": "The Unlit carry no glow of their own.\nThey steer by yours."},
	{"hold": 3.6, "core": 52.0, "sight": 285.0, "unlit": 14, "cue": "cleared",
	 "text": "Burn brighter. Strike harder. See farther. Hold longer."},
	{"hold": 3.6, "core": 62.0, "sight": 330.0, "unlit": 30, "cue": "boss",
	 "text": "Burn brighter. And more of them find you."},
	{"hold": 4.2, "core": 7.0, "sight": 46.0, "unlit": 30, "cue": "douse_in",
	 "scatter": true,
	 "text": "So when the dark gets crowded, stop burning.\nHold it in. Let them drift past."},
	{"hold": 4.5, "core": 40.0, "sight": 200.0, "unlit": 0, "cue": "purchase",
	 "title": true, "text": ""},
]

var _stage: Node2D
var _dark: ColorRect
var _line: Label
var _title: Label
var _tagline: Label
var _skip: Label
var _mat: ShaderMaterial

var _i: int = 0
var _t: float = 0.0
var _done: bool = false
var _placed_for: Vector2 = Vector2.ZERO

func _ready() -> void:
	RenderingServer.set_default_clear_color(UITheme.VOID)
	# Nothing may tick behind this.
	GameState.paused = true

	_stage = preload("res://scenes/IntroStage.gd").new()
	add_child(_stage)

	_dark = ColorRect.new()
	_dark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mat = ShaderMaterial.new()
	_mat.shader = preload("res://scenes/field/shaders/darkness.gdshader")
	_mat.set_shader_parameter("dark", Color(0, 0, 0, 1))
	_mat.set_shader_parameter("warm", Color(1, 0.74, 0.34, 1))
	_mat.set_shader_parameter("warm_amount", 0.13)
	_mat.set_shader_parameter("falloff", 1.6)
	_dark.material = _mat
	add_child(_dark)

	_line = _centred(UITheme.TEXT, UITheme.LARGE)
	_title = _centred(UITheme.LUM, UITheme.TITLE)
	_tagline = _centred(UITheme.TEXT_DIM, UITheme.TINY)
	_tagline.text = "as you get brighter more can find you"
	_title.modulate.a = 0.0
	_tagline.modulate.a = 0.0
	_skip = _centred(UITheme.TEXT_FAINT, UITheme.TINY)
	_skip.text = "press any key to skip"

	_apply(BEATS[0])
	get_viewport().size_changed.connect(_place)
	call_deferred("_place")

func _centred(col: Color, size: int) -> Label:
	var l := UITheme.label("", col, size)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.modulate.a = 0.0
	add_child(l)
	return l

func _place() -> void:
	var vp: Vector2 = get_viewport_rect().size
	if vp.x <= 0.0 or vp.y <= 0.0:
		return
	_placed_for = vp
	var scale: float = minf(vp.x / 1280.0, vp.y / 800.0)
	_stage.position = Vector2(round(vp.x * 0.5), round(vp.y * 0.40))
	_stage.scale = Vector2.ONE * scale
	_dark.position = _stage.position - Vector2(COVER, COVER) * scale
	_dark.size = Vector2(COVER, COVER) * 2.0 * scale

	for l in [_line, _title, _tagline, _skip]:
		l.size = Vector2(vp.x, 0.0)
		l.position.x = 0.0
	_line.position.y = round(vp.y * 0.74)
	_title.position.y = round(vp.y * 0.66)
	_tagline.position.y = round(vp.y * 0.80)
	_skip.position.y = round(vp.y - 40.0)

func _process(delta: float) -> void:
	if get_viewport_rect().size != _placed_for:
		_place()
	_mat.set_shader_parameter("sight_uv", _stage.sight / (COVER * 2.0))
	# Wide and soft while the pool is small, so the spark reads as a spark
	# rather than a hard-edged disc.
	_mat.set_shader_parameter("feather", 0.030 + 0.05 / maxf(_stage.sight, 12.0))

	if _done:
		return
	_t += delta
	var beat: Dictionary = BEATS[_i]
	var hold: float = beat["hold"]

	# In over the first half second, out over the last.
	var a: float = clampf(_t / 0.5, 0.0, 1.0) * clampf((hold - _t) / 0.5, 0.0, 1.0)
	if bool(beat.get("title", false)):
		_title.modulate.a = a
		_tagline.modulate.a = a
	else:
		_line.modulate.a = a
	# Gone by the payoff frame — it is the last thing that should share the
	# screen with the wordmark.
	if bool(beat.get("title", false)):
		_skip.modulate.a = maxf(_skip.modulate.a - delta * 2.0, 0.0)
	else:
		_skip.modulate.a = clampf(_t * 0.6, 0.0, 1.0) * 0.7 if _i == 0 else 0.7

	if _t >= hold:
		_i += 1
		_t = 0.0
		if _i >= BEATS.size():
			_finish()
			return
		_apply(BEATS[_i])

func _apply(beat: Dictionary) -> void:
	_stage.want_core = beat["core"]
	_stage.want_sight = beat["sight"]
	_stage.want_unlit = beat["unlit"]
	_stage.scatter = bool(beat.get("scatter", false))
	if bool(beat.get("title", false)):
		_title.text = "BLOOM"
	else:
		_line.text = beat["text"]
	if beat.has("cue"):
		Audio.play(beat["cue"], -8.0)

func _unhandled_input(event: InputEvent) -> void:
	var pressed: bool = (event is InputEventKey and (event as InputEventKey).pressed) \
		or (event is InputEventMouseButton and (event as InputEventMouseButton).pressed)
	if pressed and not _done:
		# Marked handled first: _finish() swaps the scene, and by the next
		# line get_viewport() is null. Skipping threw every time.
		get_viewport().set_input_as_handled()
		_finish()

func _finish() -> void:
	if _done:
		return
	_done = true
	SettingsPanel.mark_intro_seen()
	get_tree().change_scene_to_file("res://scenes/TitleScreen.tscn")
