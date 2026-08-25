extends Node
## Dev helper: boot the game, run it, capture the viewport. Not shipped.
##   godot res://tools/dev/Shot.tscn -- --frames=240 --out=/tmp/shot.png

var frames: int = 240
var out_path: String = "user://shot.png"
var contacts: int = 0
var lum: float = 0.0
var open_tree: bool = false
var force_boss: bool = false
var force_cleared: bool = false
var start_level: int = 1
var _n: int = 0
var _seeded: bool = false
var _fps: Array[float] = []
var _aim_target: Vector2 = Vector2.ZERO

func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		var kv: PackedStringArray = a.lstrip("-").split("=")
		if kv.size() != 2:
			continue
		match kv[0]:
			"frames": frames = int(kv[1])
			"out": out_path = kv[1]
			"contacts": contacts = int(kv[1])
			"lum": lum = float(kv[1])
			"tree": open_tree = int(kv[1]) != 0
			"boss": force_boss = int(kv[1]) != 0
			"cleared": force_cleared = int(kv[1]) != 0
			"level": start_level = int(kv[1])
	# Measure real headroom, not the refresh rate.
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	add_child(load("res://scenes/Main.tscn").instantiate())

func _process(_delta: float) -> void:
	_n += 1
	if not _seeded and _n == 4:
		_seeded = true
		_seed()
	if _aim_target != Vector2.ZERO and _n % 20 == 0:
		var fv: Node2D = get_node("Main/FieldView")
		var xf: Transform2D = fv.get_viewport().get_canvas_transform()
		get_viewport().warp_mouse(xf * _aim_target)
	if _n > 50:
		_fps.append(Engine.get_frames_per_second())
	if _n >= frames:
		var img: Image = get_viewport().get_texture().get_image()
		img.save_png(out_path)
		var lo: float = 9999.0
		var sum: float = 0.0
		for f in _fps:
			lo = minf(lo, f)
			sum += f
		print("saved %s  fps avg=%d min=%d  contacts=%d  lum=%.1f" %
			[out_path, int(sum / maxf(float(_fps.size()), 1.0)), int(lo),
			GameState.s.contacts.size(), GameState.s.effective_luminance()])
		get_tree().quit()

func _seed() -> void:
	var s: GameStateData = GameState.s
	s.motes = 400.0
	if lum > 0.0:
		# Luminance is derived from the tree, so buy into it to fake a level.
		s.motes = 1.0e9
		for _p in range(60):
			var best: TreeNode = null
			var cost: float = -1.0
			for id in TreeDB.all_ids():
				var n: TreeNode = TreeDB.get_node_def(id)
				if n.branch != &"burn" or not GameState.can_purchase(n):
					continue
				var c: float = GameState.next_cost(n)
				if c > cost:
					cost = c
					best = n
			if best == null or Stats.lum_from_tree >= lum:
				break
			GameState.purchase(best.id)
		s.motes = 800.0
	if start_level > 1:
		s.level = start_level
		s.best_level = start_level
		s.level_quota = Levels.compute_quota(s)
	if force_boss:
		# Jump straight to the boss so the bar and bracket are on screen.
		s.level_kills = Levels.quota(s)
		Levels.tick(s, 0.016)
		var b: Contact = s.boss()
		if b != null:
			b.pos = b.pos.normalized() * (Constants.FIELD_RADIUS * 0.42)
			b.hp = b.max_hp * 0.62
			_aim_target = b.pos
	if force_cleared:
		s.motes = 2400.0
		s.phase = GameStateData.Phase.BOSS
		s.boss_id = 0
		Levels.tick(s, 0.016)
	for _i in range(contacts):
		Spawning.spawn_one(s, s.effective_luminance())
		s.contacts[-1].pos *= randf_range(0.30, 1.0)
	# Point the turret at something so the reticle and lock bracket show.
	if not s.contacts.is_empty():
		var best: Contact = s.contacts[0]
		for c in s.contacts:
			if c.pos.length() < best.pos.length():
				best = c
		_aim_target = best.pos
	if open_tree:
		s.motes = 9.0e3
		for _p in range(10):
			for id in TreeDB.all_ids():
				if GameState.can_purchase(TreeDB.get_node_def(id)):
					GameState.purchase(id)
		get_node("Main").tree_view.open_view()
