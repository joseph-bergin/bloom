class_name PixelPanel
extends StyleBox
## A pixel-art panel: a hard two-pixel border, a one-pixel bevel inside it,
## and a flat fill. No chamfers, no corner ticks, no accent rail — those
## read as generic sci-fi HUD chrome, and this game is drawn in blocks.
##
## Everything is snapped to whole pixels and sized on the 8px font cell, so
## the frame sits on the same grid as the type.

@export var fill: Color = Color(0.098, 0.063, 0.071, 0.96)
@export var edge: Color = Color(0.353, 0.204, 0.212)
@export var bevel: Color = Color(0.220, 0.141, 0.149)
@export var accent: Color = Color(0.91, 0.294, 0.235)
## Draws a two-pixel bar along the top edge in the accent. Used sparingly —
## on the panel a section is titled by, not on every box.
@export var tab: bool = false
@export var border: float = 2.0
@export var pad: float = 8.0

func _init(p_fill: Color = fill, p_edge: Color = edge, p_accent: Color = accent,
		p_tab: bool = false) -> void:
	fill = p_fill
	edge = p_edge
	accent = p_accent
	tab = p_tab
	set_pad(pad)

func set_pad(v: float) -> void:
	pad = v
	content_margin_left = border + v
	content_margin_right = border + v
	content_margin_top = border + v * 0.75 + (2.0 if tab else 0.0)
	content_margin_bottom = border + v * 0.75

func _rect(ci: RID, r: Rect2, c: Color) -> void:
	RenderingServer.canvas_item_add_rect(ci, r, c)

func _draw(to_canvas_item: RID, rect: Rect2) -> void:
	# Whole pixels only. A half-pixel border is what makes a pixel UI look
	# blurry rather than crisp.
	var r := Rect2(rect.position.round(), rect.size.round())
	var b: float = border

	_rect(to_canvas_item, r, edge)
	_rect(to_canvas_item, Rect2(r.position + Vector2(b, b),
		r.size - Vector2(b, b) * 2.0), fill)
	# One-pixel bevel: lighter along the top and left, so the panel reads as
	# raised rather than as an outline.
	_rect(to_canvas_item, Rect2(r.position + Vector2(b, b),
		Vector2(r.size.x - b * 2.0, 1.0)), bevel)
	_rect(to_canvas_item, Rect2(r.position + Vector2(b, b),
		Vector2(1.0, r.size.y - b * 2.0)), bevel)

	if tab:
		_rect(to_canvas_item, Rect2(r.position + Vector2(b, b),
			Vector2(r.size.x - b * 2.0, 2.0)), accent)
