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
			# Edges are structure, not content: kept under 1.0 so the glow
			# rig never picks them up and the nodes stay the subject.
			var col: Color
			if owned_child:
				col = UITheme.branch_colour(n.branch) * 0.55
			elif owned_parent:
				col = UITheme.branch_colour(n.branch) * 0.26
			else:
				col = Color(0.10, 0.12, 0.16)
			pts.append(p.pos)
			pts.append(n.pos)
			cols.append(col)
	if not pts.is_empty():
		draw_multiline_colors(pts, cols, 1.4)

func _visible(a: Vector2, b: Vector2) -> bool:
	if visible_rect.size == Vector2.ZERO:
		return true
	return visible_rect.grow(80.0).intersects(Rect2(a.min(b), (b - a).abs()).grow(1.0))
