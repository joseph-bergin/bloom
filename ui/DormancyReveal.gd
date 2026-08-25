extends Control
## Not a popup. A scene.
## The mechanical outcome is identical to a modal reading "you earned 4.2M
## motes". The felt experience is not.

signal finished()

const BEAT := 1.15

var _lines: VBoxContainer
var _title: Label
var _dismiss: Button
var _queue: Array[String] = []
var _timer: float = 0.0
var _running: bool = false

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var vb := VBoxContainer.new()
	vb.set_anchors_preset(Control.PRESET_CENTER)
	vb.position = Vector2(-230, -120)
	vb.custom_minimum_size = Vector2(460, 0)
	vb.add_theme_constant_override("separation", 6)
	add_child(vb)
	_title = UITheme.label("YOU WERE DARK", UITheme.LUM, 22)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(_title)
	_lines = VBoxContainer.new()
	_lines.add_theme_constant_override("separation", 4)
	vb.add_child(_lines)
	_dismiss = UITheme.button("Look at it", UITheme.TEXT)
	_dismiss.custom_minimum_size = Vector2(0, 30)
	_dismiss.visible = false
	_dismiss.pressed.connect(_close)
	vb.add_child(_dismiss)

func play(report: Dictionary) -> void:
	if report.is_empty():
		return
	for c in _lines.get_children():
		c.queue_free()
	_queue = _narrate(report)
	visible = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	_running = true
	_timer = 0.35
	# The reveal is a sweep ring expanding across the field, not a dialog.
	GameState.data.sweeps.append(SweepRing.new(Constants.FIELD_RADIUS, GameState.data.t))
	AudioDirector.play_ui("sweep", -6.0)

func _narrate(r: Dictionary) -> Array[String]:
	var out: Array[String] = []
	out.append("You were dark for %s." % UITheme.fmt_time(float(r.get("elapsed", 0.0))))
	var forgotten: int = int(r.get("forgotten", 0))
	if forgotten > 0:
		out.append("%d contacts you were tracking are gone." % forgotten)
	var spawned: int = int(r.get("spawned", 0))
	if spawned > 0:
		out.append("%d new ones burn where nothing was." % spawned)
	var biggest: int = int(r.get("biggest_tier", -1))
	if biggest >= 4:
		out.append("One of them is enormous. Tier %d." % biggest)
	var tribute: float = float(r.get("tribute", 0.0))
	if tribute > 0.0:
		out.append("Tribute kept arriving: %s motes." % UITheme.fmt(tribute))
	out.append("Field pressure rose from %.2f to %.2f." %
		[float(r.get("pressure_before", 0.0)), float(r.get("pressure_after", 0.0))])
	out.append("It did not wait for you.")
	return out

func _process(delta: float) -> void:
	if not _running:
		return
	_timer -= delta
	if _timer > 0.0:
		return
	if _queue.is_empty():
		_running = false
		_dismiss.visible = true
		return
	_timer = BEAT
	var text: String = _queue.pop_front()
	var l := UITheme.label(text, UITheme.TEXT, 14)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.modulate.a = 0.0
	_lines.add_child(l)
	create_tween().tween_property(l, "modulate:a", 1.0, 0.5)
	AudioDirector.play_ui("click", -20.0)

func _close() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dismiss.visible = false
	finished.emit()
