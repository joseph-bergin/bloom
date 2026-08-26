class_name TreeNodeButton
extends Control
## One node: a square tile with a pixel sprite in it and a border that
## carries its state. Hexagons with rank arcs and a name under every one
## made a hundred-node screen read as noise; the tile says everything in
## its frame and the panel says the rest.

signal clicked(id: StringName)
signal hovered(id: StringName)
signal unhovered(id: StringName)

const TILE := 38.0
const HIT := 44.0
const BORDER := 2.0

var node_def: TreeNode = null
var rank: int = 0
var state: int = 0        # 0 hidden, 2 available, 3 owned
var affordable: bool = false
var compact: bool = false
var _hover: bool = false
var _kind: TreeIcons.Kind = TreeIcons.Kind.GENERIC
var _t: float = 0.0

func _ready() -> void:
	custom_minimum_size = Vector2(HIT, HIT)
	size = Vector2(HIT, HIT)
	mouse_filter = Control.MOUSE_FILTER_STOP

func _process(delta: float) -> void:
	if _hover:
		_t += delta
		queue_redraw()

func bind(n: TreeNode, p_rank: int, p_state: int, p_afford: bool) -> void:
	node_def = n
	rank = p_rank
	state = p_state
	affordable = p_afford
	_kind = TreeIcons.kind_for(n)
	position = (n.pos - Vector2(HIT, HIT) * 0.5).round()
	visible = true
	queue_redraw()

func _gui_input(event: InputEvent) -> void:
	if node_def == null or state < 2:
		return
	if event is InputEventMouseButton and event.pressed \
			and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		clicked.emit(node_def.id)
		accept_event()

func _notification(what: int) -> void:
	if what == NOTIFICATION_MOUSE_ENTER:
		_hover = true
		if node_def != null:
			hovered.emit(node_def.id)
		queue_redraw()
	elif what == NOTIFICATION_MOUSE_EXIT:
		_hover = false
		if node_def != null:
			unhovered.emit(node_def.id)
		queue_redraw()

## Border colour is the whole state readout: dim when you cannot afford it,
## branch colour when you can, bright and filled when owned, amber at max.
func border_colour() -> Color:
	var base: Color = UITheme.branch_colour(node_def.branch)
	var maxed: bool = not node_def.is_infinite() and rank >= node_def.max_rank
	if state == 3:
		return UITheme.LIGHT * 1.5 if maxed else base * 1.6
	return base * (1.35 if affordable else 0.85)

func _draw() -> void:
	if node_def == null:
		return
	var box := Rect2(((Vector2(HIT, HIT) - Vector2(TILE, TILE)) * 0.5).round(),
		Vector2(TILE, TILE))
	var base: Color = UITheme.branch_colour(node_def.branch)
	var owned: bool = state == 3

	if compact:
		# Zoomed out: lit points, no chrome to read.
		var dot: float = 8.0 if owned else 5.0
		draw_rect(Rect2(box.get_center() - Vector2(dot, dot) * 0.5, Vector2(dot, dot)),
			base * (1.6 if owned else 0.5))
		return

	# Ground, then a 2px frame in the state colour. Whole pixels only.
	var fill: Color = base * 0.16 if owned else Color(0.086, 0.055, 0.063)
	draw_rect(box, fill)
	_frame(box, border_colour(), BORDER)

	# Kept near 1.0. Pushing an owned icon toward white clipped every sprite
	# to the same pale blob and the shapes stopped being distinguishable.
	var icon: Color = base
	if owned:
		icon = base * 1.15
	elif not affordable:
		icon = base * 0.55
	TreeIcons.draw_icon(self, _kind, box.position + Vector2(4, 4), TILE - 8.0, icon)

	# Rank as a bar across the bottom of the tile — countable without
	# reading, and it never collides with a neighbour the way a label did.
	if not node_def.is_infinite() and node_def.max_rank > 1 and rank > 0:
		var frac: float = float(rank) / float(node_def.max_rank)
		var y: float = box.position.y + box.size.y - BORDER - 3.0
		draw_rect(Rect2(box.position.x + BORDER, y,
			(box.size.x - BORDER * 2.0) * frac, 3.0), UITheme.LIGHT * 1.4)

	if _hover:
		_frame(box.grow(3.0), Color(1, 1, 1) * (1.2 + 0.3 * sin(_t * 7.0)), 1.0)

func _frame(r: Rect2, col: Color, w: float) -> void:
	draw_rect(Rect2(r.position, Vector2(r.size.x, w)), col)
	draw_rect(Rect2(r.position + Vector2(0, r.size.y - w), Vector2(r.size.x, w)), col)
	draw_rect(Rect2(r.position, Vector2(w, r.size.y)), col)
	draw_rect(Rect2(r.position + Vector2(r.size.x - w, 0), Vector2(w, r.size.y)), col)
