extends Node
## Development helper: boot the game, let it run, capture the viewport.
##   godot res://tools/dev/Shot.tscn -- --frames=240 --out=/tmp/shot.png
## Not shipped with the game.

var frames: int = 240
var out_path: String = "user://shot.png"
var _n: int = 0
var _seeded: bool = false

func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		var kv: PackedStringArray = a.lstrip("-").split("=")
		if kv.size() != 2:
			continue
		match kv[0]:
			"frames": frames = int(kv[1])
			"out": out_path = kv[1]
			"contacts": _target_contacts = int(kv[1])
			"lum": _force_lum = float(kv[1])
			"tree": _open_tree = int(kv[1]) != 0
			"off": _off = kv[1].split(",")
	add_child(load("res://scenes/Main.tscn").instantiate())

var _target_contacts: int = 0
var _force_lum: float = 0.0
var _open_tree: bool = false
var _off: PackedStringArray = []
var _fps_samples: Array[float] = []

func _process(_delta: float) -> void:
	_n += 1
	if not _seeded and _n == 4:
		_seeded = true
		_seed_board()
	if _n > 60:
		_fps_samples.append(Engine.get_frames_per_second())
	if _n >= frames:
		var img: Image = get_viewport().get_texture().get_image()
		img.save_png(out_path)
		var lo: float = 9999.0
		var sum: float = 0.0
		for f in _fps_samples:
			lo = minf(lo, f)
			sum += f
		print("saved %s  (%dx%d)  fps avg=%d min=%d  contacts=%d  luminance=%.1f" %
			[out_path, img.get_width(), img.get_height(),
			int(sum / float(maxi(_fps_samples.size(), 1))), int(lo), GameState.data.contacts.size(),
			GameState.data.luminance_effective()])
		get_tree().quit()

func _seed_board() -> void:
	var d: GameStateData = GameState.data
	if _force_lum > 0.0:
		# Structural luminance is derived from the tree; fake it via the
		# transient channel so the bloom renders at the requested brightness.
		d.luminance_transient = _force_lum
	for _i in range(_target_contacts):
		var c: Contact = Contacts.spawn_one(d)
		Sensing.resolve_exact(d, c)
	if _target_contacts > 0:
		d.sweeps.append(SweepRing.new(Constants.FIELD_RADIUS, d.t))
	for name in _off:
		if name == "audio":
			AudioDirector.set_process(false)
			for v in AudioDirector.get_children():
				if v is AudioStreamPlayer2D or v is AudioStreamPlayer:
					v.stop()
			continue
		for base in ["Main/UILayer/", "Main/FieldView/"]:
			var n: Node = get_node_or_null(base + name)
			if n != null:
				n.set_process(false)
				if n is CanvasItem:
					(n as CanvasItem).visible = false
	if _open_tree:
		d.motes = 5.0e6
		d.signal_c = 2.0e5
		d.facets = 60.0
		for _p in range(6):
			for id in TreeDB.all_ids():
				if Economy.can_purchase(d, TreeDB.get_node_def(id)):
					Economy.purchase(d, id)
			Stats.recompute(d)
		get_node("Main").tree_view.open_view()
