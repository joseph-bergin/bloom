extends Node2D
## Dev helper: every tree icon at tile size, labelled. Not shipped.
##   godot res://tools/dev/IconSheet.tscn -- --out=/tmp/icons.png

var out_path: String = "user://icons.png"
var _n: int = 0

func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		var kv: PackedStringArray = a.lstrip("-").split("=")
		if kv.size() == 2 and kv[0] == "out":
			out_path = kv[1]

func _process(_d: float) -> void:
	_n += 1
	queue_redraw()
	if _n < 6:
		return
	var img: Image = get_viewport().get_texture().get_image()
	img.save_png(out_path)
	print("saved ", out_path)
	get_tree().quit()

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, Vector2(1280, 800)), UITheme.VOID)
	var f: Font = UITheme.font()
	var i: int = 0
	for kind in TreeIcons.Kind.values():
		var name: String = TreeIcons.Kind.keys()[i]
		var col: int = i % 4
		var row: int = i / 4
		var at := Vector2(60 + col * 300, 60 + row * 150)
		draw_rect(Rect2(at - Vector2(8, 8), Vector2(106, 106)),
			Color(0.086, 0.055, 0.063))
		TreeIcons.draw_icon(self, kind, at, 90.0, UITheme.LIGHT)
		draw_string(f, at + Vector2(112, 58), name, HORIZONTAL_ALIGNMENT_LEFT,
			-1, 24, UITheme.TEXT)
		i += 1
