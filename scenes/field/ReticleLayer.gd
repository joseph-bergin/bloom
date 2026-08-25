extends Node2D
## Where you are pointing, and what that has locked onto. This layer is the
## whole reason the player feels in control, so it draws above everything.

var aim_world: Vector2 = Vector2.ZERO
var _t: float = 0.0

func _process(delta: float) -> void:
	_t += delta
	queue_redraw()

func _draw() -> void:
	var s: GameStateData = GameState.s
	if s.run_over:
		return
	var in_range: bool = Turret.anything_in_range(s)
	var locked: Contact = null
	for c in s.contacts:
		if c.get_instance_id() == s.locked_id:
			locked = c
			break

	var dir: Vector2 = s.aim
	var reach: float = Stats.turret_range

	# The firing line: solid to the edge of range when it will hit something,
	# faint when the turret is pointed at empty dark.
	var live: bool = locked != null and in_range
	var line_col: Color = Color(1.0, 0.86, 0.55) * (1.6 if live else 0.35)
	draw_line(dir * 26.0, dir * reach, line_col, 1.4 if live else 1.0, true)

	# Reticle at the cursor.
	var r: float = 13.0
	var col: Color = Color(1.0, 0.9, 0.6) * 1.8 if live else Color(0.55, 0.62, 0.72) * 0.9
	for i in range(4):
		var a: float = float(i) * PI * 0.5 + PI * 0.25
		var v := Vector2(cos(a), sin(a))
		draw_line(aim_world + v * r, aim_world + v * (r + 7.0), col, 1.6, true)

	if locked != null:
		# Lock bracket, so the player can see exactly what the trigger is on.
		var pulse: float = 1.0 + 0.10 * sin(_t * 9.0)
		var lr: float = (locked.radius + 7.0) * pulse
		var lc := Color(1.0, 0.92, 0.62) * 2.0
		for i in range(4):
			var a0: float = float(i) * PI * 0.5 + 0.30
			var a1: float = float(i) * PI * 0.5 + PI * 0.5 - 0.30
			draw_arc(locked.pos, lr, a0, a1, 8, lc, 2.0, true)
	elif in_range:
		# Something is out there and you are not pointed at it.
		draw_arc(aim_world, r + 12.0, 0.0, TAU, 24,
			Color(0.9, 0.4, 0.35) * (0.7 + 0.3 * sin(_t * 6.0)), 1.2, true)
