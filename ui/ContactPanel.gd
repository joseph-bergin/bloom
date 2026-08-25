extends Control
## Sortable list with tier, staleness, awareness, actions.
## Every number here is the believed one. Nothing reads truth.

signal lance_requested(id: int)
signal tether_requested(id: int)
signal focus_requested(id: int)

enum Sort { TIER, STALENESS, AWARENESS, RANGE }

var sort_mode: Sort = Sort.TIER
var selected_id: int = -1

var _rows: VBoxContainer
var _detail: VBoxContainer
var _refresh: float = 0.0

func _ready() -> void:
	var panel := UITheme.make_panel()
	panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	panel.position = Vector2(-232, 108)
	panel.custom_minimum_size = Vector2(218, 300)
	panel.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 3)
	panel.add_child(col)

	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 4)
	col.add_child(head)
	head.add_child(UITheme.label("CONTACTS", UITheme.TEXT_DIM, 11))
	for pair in [["T", Sort.TIER], ["age", Sort.STALENESS], ["awr", Sort.AWARENESS]]:
		var b := UITheme.button(str(pair[0]), UITheme.TEXT_DIM)
		b.custom_minimum_size = Vector2(34, 18)
		var m: Sort = pair[1]
		b.pressed.connect(func():
			sort_mode = m
			_render())
		head.add_child(b)

	_rows = VBoxContainer.new()
	_rows.add_theme_constant_override("separation", 1)
	col.add_child(_rows)

	col.add_child(HSeparator.new())
	_detail = VBoxContainer.new()
	_detail.add_theme_constant_override("separation", 2)
	col.add_child(_detail)

func _process(delta: float) -> void:
	_refresh -= delta
	if _refresh <= 0.0:
		_refresh = 0.4
		_render()

func select(id: int) -> void:
	selected_id = id
	_render()

func _visible_contacts() -> Array[Contact]:
	var d: GameStateData = GameState.data
	var out: Array[Contact] = []
	for c in d.contacts:
		if Sensing.is_displayable(c, d.t):
			out.append(c)
	var t: float = d.t
	match sort_mode:
		Sort.TIER:
			out.sort_custom(func(a: Contact, b: Contact) -> bool: return a.known_tier > b.known_tier)
		Sort.STALENESS:
			out.sort_custom(func(a: Contact, b: Contact) -> bool:
				return Sensing.staleness(a, t) < Sensing.staleness(b, t))
		Sort.AWARENESS:
			out.sort_custom(func(a: Contact, b: Contact) -> bool:
				return a.known_awareness > b.known_awareness)
		Sort.RANGE:
			out.sort_custom(func(a: Contact, b: Contact) -> bool:
				return Sensing.believed_position(a, t).length() < Sensing.believed_position(b, t).length())
	return out

func _render() -> void:
	for c in _rows.get_children():
		c.queue_free()
	var d: GameStateData = GameState.data
	var list: Array[Contact] = _visible_contacts()
	for i in range(mini(list.size(), 9)):
		_rows.add_child(_row(d, list[i]))
	if list.is_empty():
		_rows.add_child(UITheme.label("nothing tracked", UITheme.TEXT_DIM, 11))
	_render_detail(d)

func _row(d: GameStateData, c: Contact) -> Control:
	var b := UITheme.button("", UITheme.TEXT)
	b.custom_minimum_size = Vector2(0, 20)
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	var stale: float = Sensing.staleness(c, d.t)
	var mark: String = "*" if c.resolved else ("^" if c.is_hunter else "-")
	if c.state == Contact.State.TETHERED:
		mark = "="
	b.text = "%s T%d  %ss  awr %d%%" % [mark, c.known_tier,
		String.num(minf(stale, 99.0), 0), int(c.known_awareness * 100.0)]
	var col: Color = UITheme.BAD if c.is_hunter else (
		UITheme.WARN if c.known_tier >= 4 else UITheme.TEXT)
	if c.id == selected_id:
		col = UITheme.TEXT_BRIGHT
	b.add_theme_color_override("font_color", col)
	b.pressed.connect(func():
		selected_id = c.id
		focus_requested.emit(c.id)
		_render())
	return b

func _render_detail(d: GameStateData) -> void:
	for c in _detail.get_children():
		c.queue_free()
	var c: Contact = d.find_contact(selected_id)
	if c == null or not c.has_contact:
		_detail.add_child(UITheme.label("select a contact", UITheme.TEXT_DIM, 11))
		return

	var stale: float = Sensing.staleness(c, d.t)
	_detail.add_child(UITheme.label("Contact %d — tier %d%s" % [c.id, c.known_tier,
		"" if (c.resolved or Stats.tier_id_exact) else " ?"], UITheme.TEXT_BRIGHT, 13))
	_detail.add_child(UITheme.label("bearing %d deg" % int(rad_to_deg(fposmod(c.known_bearing, TAU))),
		UITheme.TEXT_DIM, 11))
	_detail.add_child(UITheme.label(
		("range %d u" % int(c.known_range)) if c.known_range_valid else "range unknown",
		UITheme.TEXT_DIM if c.known_range_valid else UITheme.WARN, 11))
	_detail.add_child(UITheme.label("last seen %.1fs ago" % stale, UITheme.TEXT_DIM, 11))

	# The gamble must be legible before the player commits.
	var hit: float = Lances.hit_chance_for(d, c)
	var wit: float = Backlight.witness_chance(d, c.known_tier)
	var hit_l := UITheme.label("hit %d%%" % int(hit * 100.0),
		UITheme.GOOD if hit > 0.6 else UITheme.WARN, 12)
	_detail.add_child(hit_l)
	_detail.add_child(UITheme.label("witnessed %d%%" % int(wit * 100.0),
		UITheme.BAD if wit > 0.25 else UITheme.TEXT_DIM, 12))

	var acts := HBoxContainer.new()
	acts.add_theme_constant_override("separation", 4)
	_detail.add_child(acts)

	var lance := UITheme.button("Lance", UITheme.MOTES)
	lance.custom_minimum_size = Vector2(78, 24)
	lance.disabled = not Stats.manual_targeting_allowed() or not Lances.can_launch(d, c)
	if not Stats.manual_targeting_allowed():
		lance.text = "Autarch"
	lance.pressed.connect(func(): lance_requested.emit(c.id))
	acts.add_child(lance)

	var teth := UITheme.button("Tether", UITheme.SIGNAL)
	teth.custom_minimum_size = Vector2(78, 24)
	teth.disabled = not Tethers.can_establish(d, c)
	teth.tooltip_text = "Costs %s signal" % UITheme.fmt(Tethers.establish_cost(c))
	teth.pressed.connect(func(): tether_requested.emit(c.id))
	acts.add_child(teth)
