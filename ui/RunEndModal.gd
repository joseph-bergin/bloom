extends Control
## Game over. The level you reached is the score, but a number on its own
## does not tell you what the run *was* — so this also says how long you
## lasted, what you killed, how bright you got, and where the motes went.
## That last one is the interesting part: it names the build you actually
## played, which is rarely the one you thought you were playing.

signal restart_pressed()

var _body: VBoxContainer

func _ready() -> void:
	visible = false
	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(UITheme.VOID.r, UITheme.VOID.g, UITheme.VOID.b, 0.94)
	add_child(dim)
	var pair: Array = UITheme.make_section("run over", UITheme.BAD)
	var panel: PanelContainer = pair[0]
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.position = Vector2(-240, -180)
	panel.custom_minimum_size = Vector2(480, 0)
	add_child(panel)
	_body = pair[1]
	_body.add_theme_constant_override("separation", 6)

func open_modal(reason: String) -> void:
	for c in _body.get_children():
		c.queue_free()
	visible = true
	var s: GameStateData = GameState.s

	var best: int = maxi(s.best_level, s.level)
	var record: bool = s.level >= best
	var reached := UITheme.label("LEVEL %d" % s.level, UITheme.TEXT_BRIGHT, UITheme.HUGE)
	reached.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_body.add_child(reached)
	var best_l := UITheme.label(
		"a new best" if record else "best  level %d" % best,
		UITheme.GOOD if record else UITheme.TEXT_DIM, UITheme.TINY)
	best_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_body.add_child(best_l)
	_body.add_child(UITheme.label(reason, UITheme.TEXT_DIM, UITheme.TINY))

	_body.add_child(UITheme.rule())
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 26)
	grid.add_theme_constant_override("v_separation", 2)
	_body.add_child(grid)
	_stat(grid, "LASTED", UITheme.fmt_time(s.t), UITheme.TEXT)
	_stat(grid, "KILLED", "%d" % s.run_kills, UITheme.TEXT)
	_stat(grid, "MOTES", UITheme.fmt(s.total_motes_this_run), UITheme.MOTES)
	_stat(grid, "PEAK LIGHT", UITheme.fmt(s.peak_luminance), UITheme.LUM)

	_body.add_child(UITheme.rule())
	_body.add_child(UITheme.label("WHERE IT WENT", UITheme.TEXT_DIM, UITheme.TINY))
	var spend: Dictionary = _spend_by_branch(s)
	var total: int = 0
	for b in spend:
		total += int(spend[b])
	if total == 0:
		_body.add_child(UITheme.label("nothing built", UITheme.TEXT_FAINT, UITheme.TINY))
	else:
		for b in TreeDB.branches:
			_branch_row(b, int(spend.get(b, 0)), total)

	_body.add_child(UITheme.rule())
	var go := UITheme.cta("START AGAIN", UITheme.GOOD)
	go.custom_minimum_size = Vector2(0, 40)
	go.pressed.connect(func():
		visible = false
		restart_pressed.emit())
	_body.add_child(go)
	_body.add_child(UITheme.wrapped(
		"The tree unbuilds and you start over on level 1.",
		UITheme.TEXT_FAINT, 11, 452))

## Ranks bought per branch — ranks, not nodes, so ten ranks of one node
## counts as the ten purchases it was.
func _spend_by_branch(s: GameStateData) -> Dictionary:
	var out: Dictionary = {}
	for id in s.purchased:
		var n: TreeNode = TreeDB.get_node_def(StringName(id))
		if n == null:
			continue
		out[n.branch] = int(out.get(n.branch, 0)) + int(s.purchased[id])
	return out

func _stat(grid: GridContainer, key: String, value: String, col: Color) -> void:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 0)
	box.add_child(UITheme.label(key, UITheme.TEXT_FAINT, UITheme.TINY))
	box.add_child(UITheme.label(value, col, UITheme.LARGE))
	grid.add_child(box)

func _branch_row(branch: StringName, ranks: int, total: int) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	_body.add_child(row)
	var name_l := UITheme.label(String(branch), UITheme.branch_colour(branch), UITheme.TINY)
	name_l.custom_minimum_size = Vector2(70, 0)
	row.add_child(name_l)
	var bar := UITheme.meter(UITheme.branch_colour(branch), 10)
	bar.value = float(ranks) / float(maxi(total, 1))
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.custom_minimum_size = Vector2(280, 10)
	row.add_child(bar)
	var n_l := UITheme.label("%d" % ranks,
		UITheme.TEXT if ranks > 0 else UITheme.TEXT_FAINT, UITheme.TINY)
	n_l.custom_minimum_size = Vector2(34, 0)
	n_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(n_l)
