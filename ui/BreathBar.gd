extends Control
## The hide gauge. A smooth ProgressBar in a panel looked like a loading bar
## bolted to the bottom of the screen; breath is a countable resource, so it
## is drawn as cells that empty one at a time.

const CELLS := 14
const CELL_W := 12.0
const CELL_H := 16.0
const GAP := 2.0
const PAD := 5.0

var _t: float = 0.0

func _ready() -> void:
	# Fixed, not stretched: the cells are drawn from these numbers, so a
	# container that widened the Control left a gap inside the frame.
	var w: float = PAD * 2.0 + CELLS * CELL_W + (CELLS - 1) * GAP
	custom_minimum_size = Vector2(w, PAD * 2.0 + CELL_H)
	size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _process(delta: float) -> void:
	_t += delta
	queue_redraw()

func _draw() -> void:
	var s: GameStateData = GameState.s
	var active: bool = s.is_dousing()
	var spent: bool = s.douse_spent
	var frame: Color = UITheme.BAD if spent else (
		UITheme.TEXT_BRIGHT if active else UITheme.COOL)

	# Frame first, then the ground, so the cells sit inside a hard border.
	var r := Rect2(Vector2.ZERO, size)
	_frame(r, frame * (0.9 if not active else 1.4), 2.0)
	draw_rect(r.grow(-2.0), Color(0.075, 0.051, 0.055))

	var lit: float = s.douse_meter * float(CELLS)
	for i in range(CELLS):
		var at := Vector2(PAD + float(i) * (CELL_W + GAP), PAD)
		var cell := Rect2(at, Vector2(CELL_W, CELL_H))
		if float(i) >= lit:
			# Empty cells still have to be countable — at near-black they
			# vanished and a draining bar read as an empty box.
			draw_rect(cell, Color(0.239, 0.176, 0.192))
			continue
		var col: Color = UITheme.BAD if spent else UITheme.COOL * 1.3
		if active:
			col = UITheme.TEXT_BRIGHT
		# The last cell drains rather than blinking out.
		var part: float = clampf(lit - float(i), 0.0, 1.0)
		if part < 1.0:
			cell.size.y *= part
			cell.position.y += CELL_H - cell.size.y
		# A run-out warning you can catch out of the corner of your eye.
		if lit < 3.0 and not spent:
			col = col.lerp(UITheme.WARN, 0.5 + 0.5 * sin(_t * 9.0))
		draw_rect(cell, col)
		draw_rect(Rect2(cell.position, Vector2(cell.size.x, 2.0)),
			col.lerp(Color(1, 1, 1), 0.35))

func _frame(r: Rect2, col: Color, w: float) -> void:
	draw_rect(Rect2(r.position, Vector2(r.size.x, w)), col)
	draw_rect(Rect2(r.position + Vector2(0, r.size.y - w), Vector2(r.size.x, w)), col)
	draw_rect(Rect2(r.position, Vector2(w, r.size.y)), col)
	draw_rect(Rect2(r.position + Vector2(r.size.x - w, 0), Vector2(w, r.size.y)), col)
