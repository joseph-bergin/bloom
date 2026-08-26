extends Control
## Pan, zoom, fog, purchase, free respec. Culled to the camera rect.

const POOL := 200
const ZOOM_MIN := 0.30
const ZOOM_MAX := 2.0
const LABEL_ZOOM := 0.6

var _vp: SubViewport
var _canvas: Node2D
var _cam: Camera2D
var _edges: Node2D
var _pool: Array[TreeNodeButton] = []
var _minimap: Control
var _tip: Control
var _respec: Button

var _zoom: float = 1.15
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
var _motes: Label

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
			var hn: TreeNode = TreeDB.get_node_def(id)
			if hn != null:
				_tip.show_node(hn))
		b.unhovered.connect(func(id: StringName):
			if _hovered == id:
				_hovered = &""
				_tip.hide_node())
		host.add_child(b)
		_pool.append(b)

	var header := ColorRect.new()
	header.set_anchors_preset(Control.PRESET_TOP_WIDE)
	header.custom_minimum_size = Vector2(0, 50)
	header.color = Color(UITheme.VOID.r, UITheme.VOID.g, UITheme.VOID.b, 0.96)
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(header)

	var top := HBoxContainer.new()
	top.position = Vector2(16, 12)
	top.add_theme_constant_override("separation", 10)
	add_child(top)
	# No "UPGRADES" plate — the screen is plainly the tree, and the only
	# things worth space up here are what you can spend and the two verbs.
	var purse := UITheme.make_panel(UITheme.MOTES)
	var pr := HBoxContainer.new()
	pr.add_theme_constant_override("separation", 8)
	purse.add_child(pr)
	pr.add_child(PixelIcon.make(TreeIcons.Kind.MOTES, UITheme.MOTES, 18.0))
	_motes = UITheme.label("0", UITheme.MOTES, UITheme.BODY)
	pr.add_child(_motes)
	top.add_child(purse)
	var close := UITheme.button("CLOSE", UITheme.TEXT)
	close.custom_minimum_size = Vector2(100, 26)
	close.pressed.connect(close_view)
	top.add_child(close)
	_respec = UITheme.button("RESPEC", UITheme.LIGHT)
	_respec.custom_minimum_size = Vector2(130, 26)
	_respec.pressed.connect(func():
		GameState.respec()
		_dirty = true)
	top.add_child(_respec)

	_tip = preload("res://ui/TreeTooltip.gd").new()
	_tip.set_anchors_preset(Control.PRESET_FULL_RECT)
	# Above everything else this view draws — the next-level box is created
	# after it and would otherwise sit on top of the readout.
	_tip.z_index = 20
	add_child(_tip)

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
	_next_label = UITheme.label("", UITheme.LIGHT, UITheme.BODY)
	_next_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	nb.add_child(_next_label)
	_next_btn = UITheme.button("", UITheme.TEXT_BRIGHT)
	_next_btn.custom_minimum_size = Vector2(0, 38)
	_next_btn.pressed.connect(func():
		if GameState.begin_next_level():
			close_view())
	nb.add_child(_next_btn)

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
		_next_label.text = "Level %d Cleared" % GameState.s.level
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
	_motes.text = str(int(s.motes))
	var cull := view.grow(90.0)
	var dots: bool = _zoom < LABEL_ZOOM
	var i: int = 0
	for key in TreeDB.nodes.keys():
		var n: TreeNode = TreeDB.nodes[key]
		if not cull.has_point(n.pos) or i >= _pool.size():
			continue
		if not GameState.is_revealed(n):
			continue
		var rank: int = int(s.purchased.get(String(n.id), 0))
		var state: int = 3 if rank > 0 else 2
		var b: TreeNodeButton = _pool[i]
		b.compact = dots
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
	var n: TreeNode = TreeDB.get_node_def(id)
	if n != null:
		_tip.show_node(n)
