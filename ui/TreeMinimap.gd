extends Control
## Branch minimap with a viewport rect indicator.

var view_rect: Rect2 = Rect2()
var bounds: Rect2 = Rect2()

func _ready() -> void:
	custom_minimum_size = Vector2(180, 140)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	if bounds.size.x <= 0.0 or bounds.size.y <= 0.0:
		return
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.03, 0.035, 0.05, 0.9))
	draw_rect(Rect2(Vector2.ZERO, size), UITheme.PANEL_EDGE, false, 1.0)
	var s: GameStateData = GameState.s
	var pad := 6.0
	var inner: Vector2 = size - Vector2(pad, pad) * 2.0
	var sc: float = minf(inner.x / bounds.size.x, inner.y / bounds.size.y)
	var off: Vector2 = Vector2(pad, pad) + (inner - bounds.size * sc) * 0.5
	for key in TreeDB.nodes.keys():
		var n: TreeNode = TreeDB.nodes[key]
		if n.section != &"base" and not s.unlocked_sections.has(String(n.section)):
			continue
		var p: Vector2 = off + (n.pos - bounds.position) * sc
		var owned: bool = int(s.purchased.get(String(n.id), 0)) > 0
		draw_circle(p, 2.0 if owned else 1.1,
			UITheme.branch_colour(n.branch) * (2.0 if owned else 0.34))
	if view_rect.size != Vector2.ZERO:
		draw_rect(Rect2(off + (view_rect.position - bounds.position) * sc,
			view_rect.size * sc), Color(0.85, 0.95, 1.0, 0.75), false, 1.0)
