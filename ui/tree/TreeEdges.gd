extends Node2D
## Connections drawn in _draw() on a single background node — never one node
## per edge. With ~290 nodes that is the difference between a screen that
## opens instantly and one that hitches.

var visible_rect: Rect2 = Rect2()
var zoom: float = 1.0

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	var d: GameStateData = GameState.data
	for key in TreeDB.nodes.keys():
		var n: TreeNode = TreeDB.nodes[key]
		if n.region != &"base" and not d.unlocked_regions.has(String(n.region)):
			continue
		for r in n.requires:
			var p: TreeNode = TreeDB.get_node_def(r)
			if p == null:
				continue
			if not _seg_visible(p.pos, n.pos):
				continue
			var owned_parent: bool = int(d.purchased.get(String(p.id), 0)) > 0
			var owned_child: bool = int(d.purchased.get(String(n.id), 0)) > 0
			var col: Color
			var w: float = 1.0
			# Edges are structure, not content — they stay well under 1.0 so
			# the glow rig never picks them up and the nodes stay the subject.
			if owned_child:
				col = UITheme.constellation_colour(n.constellation) * 0.55
				w = 1.6
			elif owned_parent:
				col = UITheme.constellation_colour(n.constellation) * 0.26
				w = 1.2
			else:
				col = Color(0.10, 0.12, 0.16)
			if Blight.is_blighted(d, n.id) or Blight.is_blighted(d, p.id):
				col = UITheme.NECROTIC
			draw_line(p.pos, n.pos, col, w, false)

func _seg_visible(a: Vector2, b: Vector2) -> bool:
	if visible_rect.size == Vector2.ZERO:
		return true
	return visible_rect.grow(80.0).intersects(Rect2(a.min(b), (b - a).abs()).grow(1.0))
