extends Node2D
## Marker language:
##   resolved  - solid, filled, sharp, HDR-bright
##   ghost     - hollow outline, opacity falling with staleness
##   hunter    - angular, pulsing
##   tethered  - thin taut line to the player
##   blight source - faint permanent bearing line even when unresolved
##
## Every marker body is accumulated into a single batched triangle array
## rather than one draw_circle per contact. Profiling at 200 contacts showed
## this layer alone costing more than half the frame, and the cost was draw
## calls, not geometry.

## Looked up per contact per frame; a match statement here is needless work.
const TIER_COLOUR: Array[Color] = [
	Color(0.55, 0.72, 0.85), Color(0.62, 0.80, 0.70), Color(0.85, 0.82, 0.50),
	Color(0.90, 0.60, 0.35), Color(0.92, 0.40, 0.30), Color(0.95, 0.28, 0.35),
	Color(0.85, 0.25, 0.60), Color(0.75, 0.35, 0.95)]
## Punched out of hollow markers to fake a ring with two filled discs.
const BACKDROP := Color(0.02, 0.025, 0.035)
const DISC_SEGMENTS := 14
const AWARENESS_SEGMENTS := 10
const AWARENESS_MIN := 0.08

var _pulse: float = 0.0
var hovered_id: int = -1
var selected_id: int = -1

# Reused across frames so a busy field does not churn allocations.
var _pts := PackedVector2Array()
var _cols := PackedColorArray()
var _idx := PackedInt32Array()
var _lines := PackedVector2Array()
var _line_cols := PackedColorArray()

func _process(delta: float) -> void:
	_pulse += delta
	queue_redraw()

func _draw() -> void:
	var data: GameStateData = GameState.data
	var t: float = data.t
	_pts.clear()
	_cols.clear()
	_idx.clear()
	_lines.clear()
	_line_cols.clear()

	# Tether lines first so markers sit on top.
	for tt in data.tethers:
		var c: Contact = data.find_contact(tt.contact_id)
		if c == null or not c.has_contact:
			continue
		var p: Vector2 = Sensing.believed_position(c, t)
		var col := Color(0.9, 0.75, 0.35).lerp(Color(1.0, 0.25, 0.2), tt.slack) * (1.1 + tt.slack * 1.4)
		draw_line(Vector2.ZERO, p, col, lerpf(1.6, 0.6, tt.slack), true)
		if tt.slack > Constants.TETHER_WARN_1:
			var wob: float = sin(_pulse * lerpf(6.0, 22.0, tt.slack)) * 4.0 * tt.slack
			draw_line(p, p + Vector2(0, wob), col, 1.0, true)

	# Blight sources keep a permanent bearing line so they stay findable.
	for src_id in data.blight_sources:
		var c: Contact = data.find_contact(src_id)
		if c == null:
			continue
		var b: float = c.known_bearing if c.has_contact else c.bearing
		var dir := Vector2(cos(b), sin(b))
		draw_line(dir * 40.0, dir * Constants.FIELD_RADIUS,
			Color(0.55, 0.2, 0.45) * 1.1, 1.2, true)

	for c in data.contacts:
		if not Sensing.is_displayable(c, t):
			continue
		_build_contact(data, c, t)

	if not _idx.is_empty():
		RenderingServer.canvas_item_add_triangle_array(
			get_canvas_item(), _idx, _pts, _cols)
	if not _lines.is_empty():
		draw_multiline_colors(_lines, _line_cols, 1.6)

	# Selection and hover are at most two markers, so they stay stroked.
	for id in [hovered_id, selected_id]:
		if id < 0:
			continue
		var c: Contact = data.find_contact(id)
		if c == null or not Sensing.is_displayable(c, t):
			continue
		var p: Vector2 = Sensing.believed_position(c, t)
		var r: float = _size_of(c) + (10.0 if id == selected_id else 9.0)
		var col: Color = Color(0.6, 1.0, 0.85) * 1.6 if id == selected_id \
			else Color(0.5, 0.8, 0.75) * 1.1
		draw_arc(p, r, 0.0, TAU, 24, col, 1.2, true)

## Field units. The camera fits a 2000-unit field into ~800px, so these are
## roughly a third this size on screen — small enough already that the
## marker language (solid / hollow / angular) has to be drawn generously
## to read at all.
func _size_of(c: Contact) -> float:
	return 15.0 + float(c.known_tier) * 4.5

func _build_contact(data: GameStateData, c: Contact, t: float) -> void:
	var p: Vector2 = Sensing.believed_position(c, t)
	var stale: float = Sensing.staleness(c, t)
	var fade: float = clampf(1.0 - stale / 40.0, 0.25, 1.0)
	var size: float = _size_of(c)
	var hot: Color = TIER_COLOUR[clampi(c.known_tier, 0, 7)]

	if c.is_hunter:
		# Distinct angular shape, subtle pulse. The player should feel the
		# room change, so hunters keep their own silhouette.
		var pulse: float = 0.85 + 0.35 * sin(_pulse * 3.4)
		_add_ngon(p, (size + 3.0) * pulse, 3, hot * (1.7 * fade),
			-PI * 0.5 + _pulse * 0.4)
		_add_ring_lines(p, (size + 4.0) * pulse, 3,
			Color(1.0, 0.5, 0.4) * (2.2 * pulse), -PI * 0.5 + _pulse * 0.4)
	elif c.state == Contact.State.TETHERED:
		_add_disc(p, size + 2.5, Color(0.95, 0.8, 0.4) * 1.3)
		_add_disc(p, size, hot * (Constants.HDR_CONTACT_BASE * fade))
	elif c.resolved:
		# Solid, filled, sharp. The core stays near 1.0 so the tier colour
		# survives the bloom instead of clipping to white.
		_add_disc(p, size, hot * Constants.HDR_CONTACT_BASE)
		_add_disc(p, size * 0.34, hot.lerp(Color(1, 1, 1), 0.55) * 1.9)
	else:
		# Hollow outline. You know roughly where, not exactly what.
		_add_disc(p, size, hot * (0.85 * fade + 0.3))
		_add_disc(p, size - 3.6, BACKDROP)

	if c.state == Contact.State.FLEEING:
		_add_ring_lines(p, size + 6.0, 10, Color(0.4, 0.7, 0.9) * 0.8, 0.0)

	# Awareness ring — how much of you it has worked out.
	if c.known_awareness > AWARENESS_MIN and FieldView.layer_on(data, &"awareness"):
		var col := Color(1.0, 0.35, 0.25) * (1.2 + c.known_awareness)
		var span: float = TAU * c.known_awareness
		var r: float = size + 5.0
		for i in range(AWARENESS_SEGMENTS):
			var a0: float = -PI * 0.5 + span * float(i) / float(AWARENESS_SEGMENTS)
			var a1: float = -PI * 0.5 + span * float(i + 1) / float(AWARENESS_SEGMENTS)
			_lines.append(p + Vector2(cos(a0), sin(a0)) * r)
			_lines.append(p + Vector2(cos(a1), sin(a1)) * r)
			_line_cols.append(col)

# --- batched primitives --------------------------------------------------

func _add_disc(centre: Vector2, radius: float, col: Color) -> void:
	_add_ngon(centre, radius, DISC_SEGMENTS, col, 0.0)

func _add_ngon(centre: Vector2, radius: float, sides: int, col: Color, phase: float) -> void:
	var base: int = _pts.size()
	_pts.append(centre)
	_cols.append(col)
	for i in range(sides):
		var a: float = phase + TAU * float(i) / float(sides)
		_pts.append(centre + Vector2(cos(a), sin(a)) * radius)
		_cols.append(col)
	for i in range(sides):
		_idx.append(base)
		_idx.append(base + 1 + i)
		_idx.append(base + 1 + (i + 1) % sides)

func _add_ring_lines(centre: Vector2, radius: float, sides: int, col: Color, phase: float) -> void:
	for i in range(sides):
		var a0: float = phase + TAU * float(i) / float(sides)
		var a1: float = phase + TAU * float(i + 1) / float(sides)
		_lines.append(centre + Vector2(cos(a0), sin(a0)) * radius)
		_lines.append(centre + Vector2(cos(a1), sin(a1)) * radius)
		_line_cols.append(col)
