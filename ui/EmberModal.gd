extends Control
## Voluntary ember. Reward the player for reading the board and leaving on
## their own terms.

signal confirmed()

var _body: VBoxContainer

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	visible = false
	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.01, 0.012, 0.02, 0.9)
	add_child(dim)
	var panel := UITheme.make_panel(Vector2(520, 0))
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.position = Vector2(-260, -170)
	add_child(panel)
	_body = VBoxContainer.new()
	_body.add_theme_constant_override("separation", 6)
	panel.add_child(_body)

func open_modal() -> void:
	for c in _body.get_children():
		c.queue_free()
	var d: GameStateData = GameState.data
	visible = true
	_body.add_child(UITheme.label("GO OUT ON AN EMBER", UITheme.EMBERS, 20))
	var blurb := UITheme.label(
		"Everything here ends. An ember drifts out before it does, carrying a "
		+ "sliver of what you knew, and catches somewhere deeper in the dark.",
		UITheme.TEXT, 13)
	blurb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	blurb.custom_minimum_size = Vector2(496, 0)
	_body.add_child(blurb)
	_body.add_child(HSeparator.new())

	var base: float = Ember.embers_gained(d)
	var bonus: float = Ember.voluntary_bonus(d)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 40)
	_body.add_child(grid)
	grid.add_child(UITheme.label("From what you earned", UITheme.TEXT_DIM, 12))
	grid.add_child(UITheme.label(UITheme.fmt(base, 1), UITheme.EMBERS, 12))
	grid.add_child(UITheme.label("For leaving on your terms", UITheme.TEXT_DIM, 12))
	grid.add_child(UITheme.label("+" + UITheme.fmt(bonus, 1), UITheme.GOOD, 12))
	grid.add_child(UITheme.label("Total", UITheme.TEXT, 13))
	grid.add_child(UITheme.label(UITheme.fmt(base + bonus, 1), UITheme.EMBERS, 14))

	var region: StringName = Ember.next_region(d)
	if region != &"":
		_body.add_child(UITheme.label("A new region catches: %s" % String(region), UITheme.FACETS, 13))
	_body.add_child(UITheme.label(
		"Field pressure baseline rises. Contacts start higher. The tree grows.",
		UITheme.TEXT_DIM, 11))

	if Cold.unlocked(d):
		_body.add_child(HSeparator.new())
		_body.add_child(UITheme.label("THE COLD  —  rank %d / %d" %
			[d.cold_rank, Cold.max_rank()], UITheme.CONSTELLATION[&"the_cold"], 14))
		var cd := UITheme.label(
			"Lower the ambient energy of the whole region. Each rank caps what "
			+ "anything here can become, including you. Income falls. Threats fall faster.",
			UITheme.TEXT_DIM, 11)
		cd.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		cd.custom_minimum_size = Vector2(496, 0)
		_body.add_child(cd)
		var cost: float = Ember.cold_cost(d.cold_rank)
		var cb := UITheme.button("Deepen the Cold  —  %s embers" % UITheme.fmt(cost, 1),
			UITheme.CONSTELLATION[&"the_cold"])
		cb.custom_minimum_size = Vector2(0, 28)
		cb.disabled = d.embers < cost or Cold.at_maximum(d)
		if Cold.at_maximum(d):
			cb.text = "The Cold is at maximum"
		cb.pressed.connect(func():
			if Ember.raise_cold(d):
				open_modal())
		_body.add_child(cb)

	_body.add_child(HSeparator.new())
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	_body.add_child(row)
	var go := UITheme.button("Go out", UITheme.EMBERS)
	go.custom_minimum_size = Vector2(240, 32)
	go.pressed.connect(func():
		visible = false
		confirmed.emit())
	row.add_child(go)
	var stay := UITheme.button("Keep burning", UITheme.TEXT_DIM)
	stay.custom_minimum_size = Vector2(240, 32)
	stay.pressed.connect(func(): visible = false)
	row.add_child(stay)
