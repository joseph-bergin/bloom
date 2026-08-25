extends Control
## Pan/zoom, fog, culling, purchase flow, free respec.

const POOL := 320
const ZOOM_MIN := 0.35
const ZOOM_MAX := 2.0
const LABEL_ZOOM := 0.6

var _vpc: SubViewportContainer
var _vp: SubViewport
var _canvas: Node2D
var _cam: Camera2D
var _edges: Node2D
var _host: Node2D
var _pool: Array[TreeNodeButton] = []
var _minimap: Control
var _detail: VBoxContainer
var _header: Label
var _respec: Button
var _filter: HBoxContainer

var _pan: bool = false
var _zoom: float = 0.8
var _hovered: StringName = &""
var _selected: StringName = &""
var _bounds: Rect2 = Rect2()
var _dirty: bool = true
var _last_cam: Vector2 = Vector2(NAN, NAN)
var _last_zoom: float = -1.0
var _con_filter: StringName = &""

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	visible = false
	_build()
	_compute_bounds()
	EventBus.node_purchased.connect(func(_i: StringName, _r: int): _dirty = true)
	EventBus.currency_changed.connect(func(): _dirty = true)
	EventBus.respec_performed.connect(func(): _dirty = true)
	EventBus.blight_seeded.connect(func(_i, _s): _dirty = true)
	EventBus.blight_cleared.connect(func(_s): _dirty = true)
	EventBus.region_unlocked.connect(func(_r: StringName):
		_compute_bounds()
		_dirty = true)

func _build() -> void:
	var bgp := ColorRect.new()
	bgp.set_anchors_preset(Control.PRESET_FULL_RECT)
	bgp.color = Color(0.02, 0.025, 0.035, 1.0)
	add_child(bgp)

	_vpc = SubViewportContainer.new()
	_vpc.set_anchors_preset(Control.PRESET_FULL_RECT)
	_vpc.stretch = true
	_vpc.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(_vpc)
	_vp = SubViewport.new()
	_vp.transparent_bg = true
	_vp.handle_input_locally = true
	_vp.gui_embed_subwindows = false
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_vpc.add_child(_vp)

	_canvas = Node2D.new()
	_vp.add_child(_canvas)
	_cam = Camera2D.new()
	_cam.zoom = Vector2.ONE * _zoom
	_canvas.add_child(_cam)
	_edges = preload("res://ui/tree/TreeEdges.gd").new()
	_canvas.add_child(_edges)
	_host = Node2D.new()
	_canvas.add_child(_host)

	for _i in range(POOL):
		var b := TreeNodeButton.new()
		b.visible = false
		b.clicked.connect(_on_node_clicked)
		b.hovered.connect(func(id: StringName):
			_hovered = id
			_render_detail())
		_host.add_child(b)
		_pool.append(b)

	# --- chrome ---
	var header_bg := ColorRect.new()
	header_bg.set_anchors_preset(Control.PRESET_TOP_WIDE)
	header_bg.custom_minimum_size = Vector2(0, 78)
	header_bg.size = Vector2(0, 78)
	header_bg.color = Color(0.02, 0.025, 0.035, 0.92)
	header_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(header_bg)

	var top := HBoxContainer.new()
	top.position = Vector2(16, 14)
	top.add_theme_constant_override("separation", 10)
	add_child(top)
	_header = UITheme.label("THE TREE", UITheme.TEXT_BRIGHT, 18)
	top.add_child(_header)
	var close := UITheme.button("Close  [T]", UITheme.TEXT)
	close.custom_minimum_size = Vector2(100, 26)
	close.pressed.connect(close_view)
	top.add_child(close)
	_respec = UITheme.button("Respec (free)", UITheme.SIGNAL)
	_respec.custom_minimum_size = Vector2(130, 26)
	_respec.pressed.connect(func():
		if GameState.try_respec():
			_dirty = true)
	top.add_child(_respec)

	_filter = HBoxContainer.new()
	_filter.position = Vector2(16, 48)
	_filter.add_theme_constant_override("separation", 4)
	add_child(_filter)

	var side := UITheme.make_panel(Vector2(300, 0))
	side.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	side.position = Vector2(-316, 14)
	add_child(side)
	_detail = VBoxContainer.new()
	_detail.add_theme_constant_override("separation", 4)
	side.add_child(_detail)

	var mm := UITheme.make_panel()
	mm.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	mm.position = Vector2(-232, -178)
	add_child(mm)
	_minimap = preload("res://ui/tree/TreeMinimap.gd").new()
	mm.add_child(_minimap)

	var help := UITheme.label(
		"drag to pan   wheel to zoom   click to buy   right-drag pans too",
		UITheme.TEXT_DIM, 11)
	help.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	help.position = Vector2(16, -28)
	add_child(help)

func _build_filters() -> void:
	for c in _filter.get_children():
		c.queue_free()
	var all := UITheme.button("all", UITheme.TEXT)
	all.custom_minimum_size = Vector2(46, 22)
	all.pressed.connect(func():
		_con_filter = &""
		_dirty = true)
	_filter.add_child(all)
	for con in TreeDB.constellations:
		var count: int = 0
		for n in TreeDB.constellation_nodes(con):
			if n.region == &"base" or GameState.data.unlocked_regions.has(String(n.region)):
				count += 1
		if count == 0:
			continue
		var b := UITheme.button(String(con), UITheme.constellation_colour(con))
		b.custom_minimum_size = Vector2(0, 22)
		var c2: StringName = con
		b.pressed.connect(func():
			_con_filter = c2
			_focus_constellation(c2)
			_dirty = true)
		_filter.add_child(b)

func _compute_bounds() -> void:
	var first: bool = true
	for key in TreeDB.nodes.keys():
		var n: TreeNode = TreeDB.nodes[key]
		if n.region != &"base" and not GameState.data.unlocked_regions.has(String(n.region)):
			continue
		if first:
			_bounds = Rect2(n.pos, Vector2.ZERO)
			first = false
		else:
			_bounds = _bounds.expand(n.pos)
	_bounds = _bounds.grow(120.0)
	_minimap.bounds = _bounds

func open_view() -> void:
	visible = true
	_build_filters()
	_dirty = true
	set_process(true)

func close_view() -> void:
	visible = false

func toggle() -> void:
	if visible:
		close_view()
	else:
		open_view()

func _focus_constellation(con: StringName) -> void:
	var centre := Vector2.ZERO
	var n_count: int = 0
	for n in TreeDB.constellation_nodes(con):
		centre += n.pos
		n_count += 1
	if n_count > 0:
		_cam.position = centre / float(n_count)

# --- input ---------------------------------------------------------------

func _gui_input(event: InputEvent) -> void:
	_handle(event)

func _unhandled_input(event: InputEvent) -> void:
	if visible:
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
			MOUSE_BUTTON_MIDDLE, MOUSE_BUTTON_RIGHT:
				_pan = mb.pressed
	elif event is InputEventMouseMotion and _pan:
		_cam.position -= (event as InputEventMouseMotion).relative / _zoom

func _set_zoom(z: float) -> void:
	_zoom = clampf(z, ZOOM_MIN, ZOOM_MAX)
	_cam.zoom = Vector2.ONE * _zoom
	_dirty = true

# --- culling and binding -------------------------------------------------

var _afford_timer: float = 0.0

func _process(delta: float) -> void:
	if not visible:
		return
	_afford_timer -= delta
	if _afford_timer <= 0.0:
		_afford_timer = 0.5
		_dirty = true
	var vp_size: Vector2 = _vp.size
	var view := Rect2(_cam.position - vp_size * 0.5 / _zoom, vp_size / _zoom)
	_edges.visible_rect = view
	_edges.zoom = _zoom
	_minimap.view_rect = view
	_respec.disabled = not Economy.can_respec(GameState.data)
	_respec.text = "Respec (free)" if Economy.can_respec(GameState.data) else "Respec locked — blight"

	# Binding builds a tooltip string per node. Only redo it when the view
	# actually moved or the tree actually changed.
	if _dirty or not _cam.position.is_equal_approx(_last_cam) or _zoom != _last_zoom:
		_last_cam = _cam.position
		_last_zoom = _zoom
		_rebind(view)

func _rebind(view: Rect2) -> void:
	var d: GameStateData = GameState.data
	var cull := view.grow(80.0)
	var dot_mode: bool = _zoom < LABEL_ZOOM
	var idx: int = 0
	for key in TreeDB.nodes.keys():
		var n: TreeNode = TreeDB.nodes[key]
		if n.region != &"base" and not d.unlocked_regions.has(String(n.region)):
			continue
		if not cull.has_point(n.pos):
			continue
		if _con_filter != &"" and n.constellation != _con_filter and not dot_mode:
			continue
		if idx >= _pool.size():
			break
		var state: int = _state_of(d, n)
		if state == 0:
			continue
		var b: TreeNodeButton = _pool[idx]
		b.show_label = not dot_mode
		b.dot_mode = dot_mode
		b.mouse_filter = Control.MOUSE_FILTER_IGNORE if dot_mode else Control.MOUSE_FILTER_STOP
		b.bind(n, int(d.purchased.get(String(n.id), 0)), state, Economy.can_afford(d, n))
		idx += 1
	for i in range(idx, _pool.size()):
		_pool[i].visible = false
	_dirty = false

func _state_of(d: GameStateData, n: TreeNode) -> int:
	var rank: int = int(d.purchased.get(String(n.id), 0))
	if Blight.is_blighted(d, n.id):
		return 4
	if rank > 0:
		return 3
	if Blight.is_locked(d, n.id):
		return 5
	if Economy.requirements_met(d, n):
		return 2
	if Economy.is_revealed(d, n):
		return 1
	return 0

# --- purchase and detail -------------------------------------------------

func _on_node_clicked(id: StringName) -> void:
	_selected = id
	if GameState.try_purchase(id):
		_dirty = true
	else:
		AudioDirector.play_ui("click", -14.0)
	_render_detail()

func _render_detail() -> void:
	for c in _detail.get_children():
		c.queue_free()
	var id: StringName = _hovered if _hovered != &"" else _selected
	var n: TreeNode = TreeDB.get_node_def(id)
	var d: GameStateData = GameState.data
	if n == null:
		_detail.add_child(UITheme.label("hover a node", UITheme.TEXT_DIM, 12))
		_detail.add_child(UITheme.label(
			"%d / %d nodes built" % [_owned_count(d), TreeDB.nodes.size()], UITheme.TEXT_DIM, 11))
		return

	var rank: int = int(d.purchased.get(String(n.id), 0))
	_detail.add_child(UITheme.label(n.display_name, UITheme.constellation_colour(n.constellation), 16))
	var kind_txt: String = ["rank", "KEYSTONE", "bridge", "sink"][int(n.kind)]
	_detail.add_child(UITheme.label("%s   %s   rank %d/%s" % [String(n.constellation), kind_txt,
		rank, "inf" if n.is_infinite() else str(n.max_rank)], UITheme.TEXT_DIM, 11))
	var desc := UITheme.label(n.desc, UITheme.TEXT, 12)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.custom_minimum_size = Vector2(276, 0)
	_detail.add_child(desc)

	if Blight.is_blighted(d, n.id):
		_detail.add_child(UITheme.label("BLIGHTED — effects suspended.", UITheme.BAD, 12))
	elif Blight.is_locked(d, n.id):
		_detail.add_child(UITheme.label("Locked behind blighted ancestry.", UITheme.BAD, 12))

	if n.lum > 0.0:
		_detail.add_child(UITheme.label("+%.1f luminance per rank" % n.lum, UITheme.LUM, 12))
	elif n.constellation == &"shroud":
		_detail.add_child(UITheme.label("no luminance", UITheme.TEXT_DIM, 11))

	var cost: Dictionary = Economy.next_cost(d, n)
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 10)
	_detail.add_child(line)
	if float(cost["motes"]) > 0.0:
		line.add_child(UITheme.label("%s motes" % UITheme.fmt(float(cost["motes"])),
			UITheme.MOTES if d.motes >= float(cost["motes"]) else UITheme.TEXT_DIM, 13))
	if float(cost["signal"]) > 0.0:
		line.add_child(UITheme.label("%s signal" % UITheme.fmt(float(cost["signal"])),
			UITheme.SIGNAL if d.signal_c >= float(cost["signal"]) else UITheme.TEXT_DIM, 13))
	if float(cost["facets"]) > 0.0:
		line.add_child(UITheme.label("%s facets" % UITheme.fmt(float(cost["facets"])),
			UITheme.FACETS if d.facets >= float(cost["facets"]) else UITheme.TEXT_DIM, 13))

	if not n.requires.is_empty():
		var req: PackedStringArray = []
		for r in n.requires:
			var rn: TreeNode = TreeDB.get_node_def(r)
			req.append(rn.display_name if rn != null else String(r))
		_detail.add_child(UITheme.label("needs: " + ", ".join(req), UITheme.TEXT_DIM, 11))

	var buy := UITheme.button("Build", UITheme.TEXT_BRIGHT)
	buy.custom_minimum_size = Vector2(0, 28)
	buy.disabled = not Economy.can_purchase(d, n)
	buy.pressed.connect(func(): _on_node_clicked(n.id))
	_detail.add_child(buy)
	_detail.add_child(UITheme.label("Building anything is loud: +%d transient."
		% int(Constants.TRANSIENT_PURCHASE), UITheme.TEXT_DIM, 10))

func _owned_count(d: GameStateData) -> int:
	var n: int = 0
	for k in d.purchased.keys():
		if int(d.purchased[k]) > 0:
			n += 1
	return n
