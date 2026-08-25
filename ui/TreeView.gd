extends Control
## Pan, zoom, fog, purchase, free respec. Culled to the camera rect.

const POOL := 200
const ZOOM_MIN := 0.35
const ZOOM_MAX := 2.0
const LABEL_ZOOM := 0.6

var _vp: SubViewport
var _canvas: Node2D
var _cam: Camera2D
var _edges: Node2D
var _pool: Array[TreeNodeButton] = []
var _minimap: Control
var _detail: VBoxContainer
var _respec: Button
var _filters: HBoxContainer

var _zoom: float = 0.85
var _pan: bool = false
var _hovered: StringName = &""
var _selected: StringName = &""
var _bounds: Rect2 = Rect2()
var _dirty: bool = true
var _last_cam: Vector2 = Vector2(NAN, NAN)
var _last_zoom: float = -1.0
var _refresh: float = 0.0
var _next_box: PanelContainer
var _next_label: Label
var _next_btn: Button

func _ready() -> void:
	visible = false
	_build()
	_compute_bounds()
	EventBus.node_purchased.connect(func(_i: StringName, _r: int): _dirty = true)
	EventBus.respec_performed.connect(func(): _dirty = true)
	EventBus.level_cleared.connect(func(_l: int, _b: float): _dirty = true)

func _build() -> void:
	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.02, 0.025, 0.035, 1.0)
	add_child(bg)

	var vpc := SubViewportContainer.new()
	vpc.set_anchors_preset(Control.PRESET_FULL_RECT)
	vpc.stretch = true
	vpc.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(vpc)
	_vp = SubViewport.new()
	_vp.transparent_bg = true
	_vp.handle_input_locally = true
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vpc.add_child(_vp)

	_canvas = Node2D.new()
	_vp.add_child(_canvas)
	_cam = Camera2D.new()
	_cam.zoom = Vector2.ONE * _zoom
	_canvas.add_child(_cam)
	_edges = preload("res://ui/TreeEdges.gd").new()
	_canvas.add_child(_edges)
	var host := Node2D.new()
	_canvas.add_child(host)
	for _i in range(POOL):
		var b := TreeNodeButton.new()
		b.visible = false
		b.clicked.connect(_on_click)
		b.hovered.connect(func(id: StringName):
			_hovered = id
			_render_detail())
		host.add_child(b)
		_pool.append(b)

	var header := ColorRect.new()
	header.set_anchors_preset(Control.PRESET_TOP_WIDE)
	header.custom_minimum_size = Vector2(0, 82)
	header.color = Color(UITheme.VOID.r, UITheme.VOID.g, UITheme.VOID.b, 0.96)
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(header)

	var top := HBoxContainer.new()
	top.position = Vector2(16, 12)
	top.add_theme_constant_override("separation", 10)
	add_child(top)
	top.add_child(UITheme.label("THE TREE", UITheme.TEXT_BRIGHT, 18))
	var close := UITheme.button("Close  [T]", UITheme.TEXT)
	close.custom_minimum_size = Vector2(100, 26)
	close.pressed.connect(close_view)
	top.add_child(close)
	_respec = UITheme.button("Respec (free)", UITheme.GOOD)
	_respec.custom_minimum_size = Vector2(130, 26)
	_respec.pressed.connect(func():
		GameState.respec()
		_dirty = true)
	top.add_child(_respec)

	_filters = HBoxContainer.new()
	_filters.position = Vector2(16, 46)
	_filters.add_theme_constant_override("separation", 5)
	add_child(_filters)

	var pair: Array = UITheme.make_section("node", UITheme.ACCENT)
	var side: PanelContainer = pair[0]
	side.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	side.position = Vector2(-312, 88)
	side.custom_minimum_size = Vector2(296, 210)
	add_child(side)
	_detail = pair[1]
	_detail.add_theme_constant_override("separation", 4)

	var mm := UITheme.make_panel()
	mm.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	mm.position = Vector2(-216, -172)
	add_child(mm)
	_minimap = preload("res://ui/TreeMinimap.gd").new()
	mm.add_child(_minimap)

	var help := UITheme.label("drag to pan · wheel to zoom · click to buy",
		UITheme.TEXT_DIM, 11)
	help.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	help.position = Vector2(16, -26)
	add_child(help)

	_next_box = UITheme.make_panel()
	_next_box.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_next_box.position = Vector2(-190, -92)
	_next_box.custom_minimum_size = Vector2(380, 0)
	_next_box.visible = false
	add_child(_next_box)
	var nb := VBoxContainer.new()
	nb.add_theme_constant_override("separation", 3)
	_next_box.add_child(nb)
	_next_label = UITheme.label("", UITheme.GOOD, 13)
	_next_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	nb.add_child(_next_label)
	_next_btn = UITheme.button("", UITheme.TEXT_BRIGHT)
	_next_btn.custom_minimum_size = Vector2(0, 38)
	_next_btn.pressed.connect(func():
		if GameState.begin_next_level():
			close_view())
	nb.add_child(_next_btn)

func _build_filters() -> void:
	for c in _filters.get_children():
		c.queue_free()
	var all := UITheme.button("all", UITheme.TEXT)
	all.custom_minimum_size = Vector2(44, 22)
	all.pressed.connect(func(): _focus(Vector2.ZERO))
	_filters.add_child(all)
	for b in TreeDB.branches:
		var btn := UITheme.button(String(b), UITheme.branch_colour(b))
		btn.custom_minimum_size = Vector2(0, 22)
		var bb: StringName = b
		btn.pressed.connect(func():
			var centre := Vector2.ZERO
			var n_count: int = 0
			for n in TreeDB.branch_nodes(bb):
				centre += n.pos
				n_count += 1
			_focus(centre / maxf(float(n_count), 1.0)))
		_filters.add_child(btn)

func _focus(at: Vector2) -> void:
	_cam.position = at
	_dirty = true

func _compute_bounds() -> void:
	var first: bool = true
	for key in TreeDB.nodes.keys():
		var n: TreeNode = TreeDB.nodes[key]
		if first:
			_bounds = Rect2(n.pos, Vector2.ZERO)
			first = false
		else:
			_bounds = _bounds.expand(n.pos)
	_bounds = _bounds.grow(110.0)
	_minimap.bounds = _bounds

func open_view() -> void:
	visible = true
	_build_filters()
	_render_detail()
	_dirty = true

func close_view() -> void:
	visible = false

func toggle() -> void:
	if visible:
		close_view()
	else:
		open_view()

func _gui_input(event: InputEvent) -> void:
	_handle(event)

func _handle(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		match mb.button_index:
			MOUSE_BUTTON_WHEEL_UP:
				_set_zoom(_zoom * 1.12)
			MOUSE_BUTTON_WHEEL_DOWN:
				_set_zoom(_zoom / 1.12)
			MOUSE_BUTTON_LEFT, MOUSE_BUTTON_MIDDLE, MOUSE_BUTTON_RIGHT:
				_pan = mb.pressed
	elif event is InputEventMouseMotion and _pan:
		_cam.position -= (event as InputEventMouseMotion).relative / _zoom

func _set_zoom(z: float) -> void:
	_zoom = clampf(z, ZOOM_MIN, ZOOM_MAX)
	_cam.zoom = Vector2.ONE * _zoom
	_dirty = true

func _process(delta: float) -> void:
	if not visible:
		return
	var upgrading: bool = GameState.upgrading()
	_next_box.visible = upgrading
	if upgrading:
		_next_label.text = "Level %d cleared — spend what it paid" % GameState.s.level
		_next_btn.text = "Begin level %d" % (GameState.s.level + 1)
	var view := Rect2(_cam.position - _vp.size * 0.5 / _zoom, _vp.size / _zoom)
	_edges.visible_rect = view
	_minimap.view_rect = view
	# Affordability shading goes stale as motes come in.
	_refresh -= delta
	if _refresh <= 0.0:
		_refresh = 0.4
		_dirty = true
	if _dirty or not _cam.position.is_equal_approx(_last_cam) or _zoom != _last_zoom:
		_last_cam = _cam.position
		_last_zoom = _zoom
		_dirty = false
		_rebind(view)

func _rebind(view: Rect2) -> void:
	var s: GameStateData = GameState.s
	var cull := view.grow(90.0)
	var dots: bool = _zoom < LABEL_ZOOM
	var i: int = 0
	for key in TreeDB.nodes.keys():
		var n: TreeNode = TreeDB.nodes[key]
		if not cull.has_point(n.pos) or i >= _pool.size():
			continue
		var rank: int = int(s.purchased.get(String(n.id), 0))
		var state: int = 0
		if rank > 0:
			state = 3
		elif GameState.requirements_met(n):
			state = 2
		elif GameState.is_revealed(n):
			state = 1
		if state == 0:
			continue
		var b: TreeNodeButton = _pool[i]
		b.show_label = not dots
		b.mouse_filter = Control.MOUSE_FILTER_IGNORE if dots else Control.MOUSE_FILTER_STOP
		b.bind(n, rank, state, s.motes >= GameState.next_cost(n))
		i += 1
	for k in range(i, _pool.size()):
		_pool[k].visible = false

func _on_click(id: StringName) -> void:
	_selected = id
	if not GameState.purchase(id):
		Audio.play("click", -16.0)
	_dirty = true
	_render_detail()

func _render_detail() -> void:
	for c in _detail.get_children():
		c.queue_free()
	var id: StringName = _hovered if _hovered != &"" else _selected
	var n: TreeNode = TreeDB.get_node_def(id)
	var s: GameStateData = GameState.s
	if n == null:
		_detail.add_child(UITheme.label("hover a node to read it", UITheme.TEXT_DIM, 12))
		_detail.add_child(UITheme.wrapped(
			"Everything you build adds luminance, and luminance is what makes "
			+ "the field spawn faster and stronger. Shroud is the only branch "
			+ "that costs none.", UITheme.TEXT_FAINT, 11, 268))
		return
	var rank: int = int(s.purchased.get(String(n.id), 0))
	_detail.add_child(UITheme.label(n.display_name, UITheme.branch_colour(n.branch), 16))
	_detail.add_child(UITheme.label("%s%s   rank %d/%s" % [String(n.branch),
		"   KEYSTONE" if n.keystone else "", rank,
		"inf" if n.is_infinite() else str(n.max_rank)], UITheme.TEXT_DIM, 11))
	var d := UITheme.label(n.desc, UITheme.TEXT, 12)
	d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	d.custom_minimum_size = Vector2(266, 0)
	_detail.add_child(d)

	if n.lum > 0.0:
		_detail.add_child(UITheme.label("+%.1f luminance per rank" % n.lum, UITheme.LUM, 12))
	else:
		_detail.add_child(UITheme.label("no luminance", UITheme.GOOD, 12))

	var maxed: bool = not n.is_infinite() and rank >= n.max_rank
	if maxed:
		_detail.add_child(UITheme.label("fully built", UITheme.GOOD, 13))
	else:
		var cost: float = GameState.next_cost(n)
		_detail.add_child(UITheme.label("%s motes" % UITheme.fmt(cost),
			UITheme.MOTES if s.motes >= cost else UITheme.TEXT_DIM, 14))

	if not n.requires.is_empty():
		var req: PackedStringArray = []
		for r in n.requires:
			var rn: TreeNode = TreeDB.get_node_def(r)
			req.append(rn.display_name if rn != null else String(r))
		_detail.add_child(UITheme.label("needs: " + ", ".join(req), UITheme.TEXT_DIM, 11))

	var buy := UITheme.button("Build", UITheme.TEXT_BRIGHT)
	buy.custom_minimum_size = Vector2(0, 28)
	buy.disabled = not GameState.can_purchase(n)
	buy.pressed.connect(func(): _on_click(n.id))
	_detail.add_child(buy)
