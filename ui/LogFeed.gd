extends Control
## Persistent event feed. The log must reconstruct the causal chain — if a
## player cannot trace a run-ending strike back to a decision, the game
## reads as unfair.

const MAX_LINES := 120
const VISIBLE := 9

var _rows: VBoxContainer
var _lines: Array[Dictionary] = []
var _dirty: bool = true

func _ready() -> void:
	var panel := UITheme.make_panel()
	panel.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	panel.position = Vector2(-444, -216)
	panel.custom_minimum_size = Vector2(430, 200)
	panel.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(panel)
	_rows = VBoxContainer.new()
	_rows.add_theme_constant_override("separation", 1)
	_rows.alignment = BoxContainer.ALIGNMENT_END
	panel.add_child(_rows)
	EventBus.log_line.connect(_on_line)
	_on_line("The dark is not empty. Neither are you.", "info")

func _process(_delta: float) -> void:
	if _dirty:
		_dirty = false
		_render()

func _on_line(text: String, kind: String) -> void:
	_lines.append({"t": GameState.data.t, "text": text, "kind": kind})
	if _lines.size() > MAX_LINES:
		_lines.pop_front()
	_dirty = true

func _render() -> void:
	for c in _rows.get_children():
		c.queue_free()
	var start: int = maxi(_lines.size() - VISIBLE, 0)
	for i in range(start, _lines.size()):
		var e: Dictionary = _lines[i]
		var age: int = _lines.size() - 1 - i
		var col: Color = UITheme.log_colour(str(e["kind"]))
		col.a = clampf(1.0 - float(age) * 0.075, 0.35, 1.0)
		var l := UITheme.label("%s  %s" % [UITheme.fmt_time(float(e["t"])), str(e["text"])], col, 12)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size = Vector2(408, 0)
		_rows.add_child(l)

func history() -> Array[Dictionary]:
	return _lines
