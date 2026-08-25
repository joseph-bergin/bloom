extends Control
## The rule editor. By late game the player is not clicking contacts — they
## are tuning a policy and watching it run against forty simultaneous tracks.
## The verb escalates from aiming to governing.

var _rows: VBoxContainer
var _root: PanelContainer
var _add: Button

func _ready() -> void:
	_root = UITheme.make_panel(Vector2(300, 0))
	_root.set_anchors_preset(Control.PRESET_CENTER_LEFT)
	_root.position = Vector2(14, -60)
	_root.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(_root)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 4)
	_root.add_child(col)
	col.add_child(UITheme.label("TRIAGE POLICY", UITheme.CONSTELLATION[&"cognition"], 12))
	col.add_child(UITheme.label("evaluated top to bottom; first match wins",
		UITheme.TEXT_DIM, 10))
	_rows = VBoxContainer.new()
	_rows.add_theme_constant_override("separation", 3)
	col.add_child(_rows)
	_add = UITheme.button("+ rule", UITheme.TEXT)
	_add.custom_minimum_size = Vector2(0, 22)
	_add.pressed.connect(func():
		GameState.data.triage_rules.append(Automation.default_rule())
		_render())
	col.add_child(_add)
	visible = false

func _process(_delta: float) -> void:
	var want: bool = Stats.triage_slots > 0
	if want != visible:
		visible = want
		if want:
			_render()

func _render() -> void:
	for c in _rows.get_children():
		c.queue_free()
	var rules: Array = GameState.data.triage_rules
	for i in range(rules.size()):
		_rows.add_child(_row(i, rules[i]))
	_add.disabled = rules.size() >= Stats.triage_slots
	_add.text = "+ rule  (%d/%d)" % [rules.size(), Stats.triage_slots]

func _row(idx: int, rule: Dictionary) -> Control:
	var box := HBoxContainer.new()
	box.add_theme_constant_override("separation", 3)

	var on := UITheme.button("on" if bool(rule.get("enabled", true)) else "off",
		UITheme.GOOD if bool(rule.get("enabled", true)) else UITheme.TEXT_DIM)
	on.custom_minimum_size = Vector2(32, 20)
	on.pressed.connect(func():
		rule["enabled"] = not bool(rule.get("enabled", true))
		_render())
	box.add_child(on)

	box.add_child(UITheme.label("T", UITheme.TEXT_DIM, 11))
	box.add_child(_spin(rule, "min_tier", 0, Constants.TIER_MAX))
	box.add_child(UITheme.label("-", UITheme.TEXT_DIM, 11))
	box.add_child(_spin(rule, "max_tier", 0, Constants.TIER_MAX))

	box.add_child(UITheme.label("awr>", UITheme.TEXT_DIM, 11))
	var awr := SpinBox.new()
	awr.min_value = 0.0
	awr.max_value = 1.0
	awr.step = 0.05
	awr.value = float(rule.get("awareness_gt", 0.0))
	awr.custom_minimum_size = Vector2(58, 20)
	awr.value_changed.connect(func(v: float): rule["awareness_gt"] = v)
	box.add_child(awr)

	var act := OptionButton.new()
	act.custom_minimum_size = Vector2(70, 20)
	var actions: Array[String] = [Automation.ACT_LANCE, Automation.ACT_TETHER, Automation.ACT_IGNORE]
	for i in range(actions.size()):
		act.add_item(actions[i], i)
	act.selected = maxi(actions.find(str(rule.get("action", Automation.ACT_LANCE))), 0)
	act.item_selected.connect(func(i: int): rule["action"] = actions[i])
	box.add_child(act)

	var del := UITheme.button("x", UITheme.BAD)
	del.custom_minimum_size = Vector2(22, 20)
	del.pressed.connect(func():
		GameState.data.triage_rules.remove_at(idx)
		_render())
	box.add_child(del)
	return box

func _spin(rule: Dictionary, key: String, lo: int, hi: int) -> SpinBox:
	var sb := SpinBox.new()
	sb.min_value = lo
	sb.max_value = hi
	sb.step = 1
	sb.value = int(rule.get(key, lo))
	sb.custom_minimum_size = Vector2(46, 20)
	sb.value_changed.connect(func(v: float): rule[key] = int(v))
	return sb
