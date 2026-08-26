class_name PixelIcon
extends Control
## A tree sprite as a Control, so a number can carry the same symbol the
## tree uses for it. Motes are a gem everywhere or they are nowhere.

var kind: TreeIcons.Kind = TreeIcons.Kind.GENERIC
var colour: Color = UITheme.TEXT
var px: float = 18.0

static func make(p_kind: TreeIcons.Kind, p_colour: Color,
		p_px: float = 18.0) -> PixelIcon:
	var i := PixelIcon.new()
	i.kind = p_kind
	i.colour = p_colour
	i.px = p_px
	return i

func _ready() -> void:
	custom_minimum_size = Vector2(px, px)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _draw() -> void:
	TreeIcons.draw_icon(self, kind, Vector2.ZERO, px, colour)
