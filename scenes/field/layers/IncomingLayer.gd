extends Node2D
## Countdown arcs closing on the player — but only if Optics can see them
## coming. Without that investment, strikes arrive with no warning at all.

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	var data: GameStateData = GameState.data
	if not FieldView.layer_on(data, &"incoming"):
		return
	for s in data.incoming:
		if not s.detected:
			continue
		var prog: float = s.progress(data.t)
		var r: float = lerpf(Constants.FIELD_RADIUS * 0.95, 40.0, prog)
		var urgency: float = pow(prog, 2.0)
		var col := Color(1.0, 0.3, 0.25) * (1.1 + urgency * 2.4)
		var span: float = lerpf(0.9, 0.35, prog)
		draw_arc(Vector2.ZERO, r, s.bearing - span, s.bearing + span, 48, col, 2.2, true)
		var dir := Vector2(cos(s.bearing), sin(s.bearing))
		draw_line(dir * r, dir * (r - 34.0), col, 1.6, true)
