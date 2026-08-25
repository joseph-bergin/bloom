extends Control
## Constellation minimap with a viewport rect indicator.

var view_rect: Rect2 = Rect2()
var bounds: Rect2 = Rect2()

func _ready() -> void:
	custom_minimum_size = Vector2(196, 148)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	if bounds.size.x <= 0.0 or bounds.size.y <= 0.0:
		return
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.03, 0.035, 0.05, 0.9))
	draw_rect(Rect2(Vector2.ZERO, size), UITheme.PANEL_EDGE, false, 1.0)
	var d: GameStateData = GameState.data
	var pad: float = 6.0
	var inner: Vector2 = size - Vector2(pad, pad) * 2.0
	var s: float = minf(inner.x / bounds.size.x, inner.y / bounds.size.y)
	var off: Vector2 = Vector2(pad, pad) + (inner - bounds.size * s) * 0.5

	for key in TreeDB.nodes.keys():
		var n: TreeNode = TreeDB.nodes[key]
		if n.region != &"base" and not d.unlocked_regions.has(String(n.region)):
			continue
		var p: Vector2 = off + (n.pos - bounds.position) * s
		var owned: bool = int(d.purchased.get(String(n.id), 0)) > 0
		var col: Color = UITheme.constellation_colour(n.constellation)
		if Blight.is_blighted(d, n.id):
			draw_circle(p, 1.6, UITheme.NECROTIC * 1.4)
		else:
			draw_circle(p, 1.8 if owned else 1.0, col * (2.0 if owned else 0.34))

	if view_rect.size != Vector2.ZERO:
		var r := Rect2(off + (view_rect.position - bounds.position) * s, view_rect.size * s)
		draw_rect(r, Color(0.85, 0.95, 1.0, 0.75), false, 1.0)
