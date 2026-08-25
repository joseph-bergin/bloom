extends Node
## Dev helper: boot the game, run it, capture the viewport. Not shipped.
##   godot res://tools/dev/Shot.tscn -- --frames=240 --out=/tmp/shot.png

var frames: int = 240
var out_path: String = "user://shot.png"
var contacts: int = 0
var lum: float = 0.0
var open_tree: bool = false
var _n: int = 0
var _seeded: bool = false
var _fps: Array[float] = []

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
	add_child(load("res://scenes/Main.tscn").instantiate())

func _process(_delta: float) -> void:
	_n += 1
	if not _seeded and _n == 4:
		_seeded = true
		_seed()
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
	for _i in range(contacts):
		Spawning.spawn_one(s, s.effective_luminance())
		s.contacts[-1].pos *= randf_range(0.35, 1.0)
	if open_tree:
		s.motes = 5.0e5
		for _p in range(10):
			for id in TreeDB.all_ids():
				if GameState.can_purchase(TreeDB.get_node_def(id)):
					GameState.purchase(id)
		get_node("Main").tree_view.open_view()
