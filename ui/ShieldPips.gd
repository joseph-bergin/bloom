extends Control
## Shields as pips, not "shields 3 / 3". Three shapes you can count without
## reading are worth more here than six words.

const PIP := 14.0
const GAP := 6.0

var _t: float = 0.0

func _ready() -> void:
	custom_minimum_size = Vector2(0, PIP + 4.0)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _process(delta: float) -> void:
	_t += delta
	queue_redraw()

func _draw() -> void:
	var have: int = maxi(GameState.s.shields, 0)
	var total: int = maxi(Stats.max_shields, have)
	for i in range(total):
		var c := Vector2(PIP * 0.5 + float(i) * (PIP + GAP), PIP * 0.5 + 2.0)
		var lit: bool = i < have
		var col: Color = UITheme.LIGHT if lit else Color(0.208, 0.129, 0.137)
		if lit and have <= 1:
			# The last one breathes, so losing it is not a quiet event.
			col = UITheme.BAD * (1.1 + 0.35 * sin(_t * 5.0))
		var pts := PackedVector2Array()
		for k in range(4):
			var a: float = float(k) * PI * 0.5
			pts.append(c + Vector2(cos(a), sin(a)) * PIP * 0.5)
		if lit:
			draw_colored_polygon(pts, col)
		pts.append(pts[0])
		draw_polyline(pts, col * (1.6 if lit else 1.0), 1.5, true)
