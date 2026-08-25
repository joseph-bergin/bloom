extends Node2D
## Uncertainty. Everything here is what the player believes, not what is true.
## Introduced a full act apart from the other layers — see FieldView.layer_on().

## Dash count is deliberately low: with dozens of ghosts on screen this runs
## hundreds of times a frame, and a ring reads fine at 12 dashes.
const DASHES := 12
const DASH_ARC := TAU / float(DASHES) * 0.55

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	var data: GameStateData = GameState.data
	if not FieldView.layer_on(data, &"uncertainty"):
		return
	var t: float = data.t
	# Every dash from every ghost goes into one batched multiline. Issuing a
	# draw command per ghost is what makes this layer expensive at high
	# contact counts, not the geometry itself.
	var pts := PackedVector2Array()
	var cols := PackedColorArray()

	for c in data.contacts:
		if not Sensing.is_displayable(c, t) or c.resolved:
			continue
		var p: Vector2 = Sensing.believed_position(c, t)
		var u: float = Sensing.uncertainty_radius(c, t)
		if u < 6.0:
			continue
		var fade: float = clampf(1.0 - u / Constants.DROP_THRESHOLD, 0.0, 1.0)
		var col := Color(0.5, 0.62, 0.8) * (0.9 * fade)
		for i in range(DASHES):
			var a0: float = TAU * float(i) / float(DASHES)
			var a1: float = a0 + DASH_ARC
			pts.append(p + Vector2(cos(a0), sin(a0)) * u)
			pts.append(p + Vector2(cos(a1), sin(a1)) * u)
			cols.append(col)

	# A contact without a range fix is a bearing, not a point. Draw the line.
	for c in data.contacts:
		if not c.has_contact or c.known_range_valid or c.resolved:
			continue
		if not Sensing.is_displayable(c, t):
			continue
		var dir := Vector2(cos(c.known_bearing), sin(c.known_bearing))
		pts.append(dir * 60.0)
		pts.append(dir * Constants.FIELD_RADIUS)
		cols.append(Color(0.34, 0.44, 0.6) * 0.5)

	if not pts.is_empty():
		draw_multiline_colors(pts, cols, 1.0)
