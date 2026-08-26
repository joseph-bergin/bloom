extends Node2D
## All connections in one _draw() on one node — never one node per edge.

var visible_rect: Rect2 = Rect2()

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	var s: GameStateData = GameState.s
	var pts := PackedVector2Array()
	var cols := PackedColorArray()
	for key in TreeDB.nodes.keys():
		var n: TreeNode = TreeDB.nodes[key]
		for r in n.requires:
			var p: TreeNode = TreeDB.get_node_def(r)
			if p == null or not _visible(p.pos, n.pos):
				continue
			var owned_child: bool = int(s.purchased.get(String(n.id), 0)) > 0
			var owned_parent: bool = int(s.purchased.get(String(p.id), 0)) > 0
			# A route you have not opened is not drawn at all. Pre-drawing
			# the whole graph gave the map away and made the tree read as a
			# diagram rather than as something you are cutting into.
			if not owned_parent:
				continue
			pts.append(p.pos.round())
			pts.append(n.pos.round())
			cols.append(UITheme.LIGHT * (0.85 if owned_child else 0.30))
	if not pts.is_empty():
		draw_multiline_colors(pts, cols, 2.0)

func _visible(a: Vector2, b: Vector2) -> bool:
	if visible_rect.size == Vector2.ZERO:
		return true
	return visible_rect.grow(80.0).intersects(Rect2(a.min(b), (b - a).abs()).grow(1.0))
