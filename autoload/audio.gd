extends Node
## Audio does more work than art here.

const POOL := 12
const STREAK_WINDOW := 1.2

var master_db: float = 0.0
var reduced_motion: bool = false

var _pool: Array[AudioStreamPlayer] = []
var _next: int = 0
var _streams: Dictionary = {}
var _kill_streams: Array[AudioStreamWAV] = []
var _ambient: AudioStreamPlayer
var _douse: AudioStreamPlayer
var _duck_until: float = 0.0
var _streak: int = 0
var _last_kill: float = -99.0

func _ready() -> void:
	_buses()
	_streams["purchase"] = Synth.purchase()
	_streams["breach"] = Synth.breach()
	_streams["click"] = Synth.click()
	for t in range(Constants.MAX_TIER + 1):
		_kill_streams.append(Synth.kill(t))

	for i in range(POOL):
		var p := AudioStreamPlayer.new()
		p.bus = &"SFX"
		add_child(p)
		_pool.append(p)
	_ambient = AudioStreamPlayer.new()
	_ambient.bus = &"Ambient"
	_ambient.stream = Synth.ambient()
	_ambient.volume_db = -8.0
	add_child(_ambient)
	_ambient.play()
	_douse = AudioStreamPlayer.new()
	_douse.bus = &"Ambient"
	_douse.stream = Synth.douse()
	_douse.volume_db = -10.0
	add_child(_douse)

	EventBus.contact_killed.connect(_on_kill)
	EventBus.node_purchased.connect(func(_id: StringName, _r: int): play("purchase", -3.0))
	EventBus.shield_breached.connect(func(_r: int):
		play("breach", 0.0)
		duck(Constants.BREACH_DUCK))

func _buses() -> void:
	for name in [&"SFX", &"Ambient", &"UI"]:
		if AudioServer.get_bus_index(name) != -1:
			continue
		var idx: int = AudioServer.bus_count
		AudioServer.add_bus(idx)
		AudioServer.set_bus_name(idx, name)
		AudioServer.set_bus_send(idx, &"Master")
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index(&"Ambient"), -12.0)

func play(key: String, db: float = -6.0, pitch: float = 1.0) -> void:
	if not _streams.has(key):
		return
	_emit(_streams[key], db, pitch)

func _emit(stream: AudioStream, db: float, pitch: float) -> void:
	var p: AudioStreamPlayer = _pool[_next]
	_next = (_next + 1) % _pool.size()
	p.stream = stream
	p.volume_db = db
	p.pitch_scale = pitch
	p.play()

## Rising pitch on kill streaks.
func _on_kill(tier: int, _at: Vector2, _motes: float) -> void:
	var now: float = float(Time.get_ticks_msec()) / 1000.0
	_streak = _streak + 1 if now - _last_kill < STREAK_WINDOW else 0
	_last_kill = now
	var pitch: float = clampf(1.0 + float(_streak) * 0.035, 1.0, 1.8)
	_emit(_kill_streams[clampi(tier, 0, _kill_streams.size() - 1)], -9.0, pitch)

## Silence lands harder than noise.
func duck(seconds: float) -> void:
	_duck_until = float(Time.get_ticks_msec()) / 1000.0 + seconds
	for b in [&"SFX", &"Ambient"]:
		AudioServer.set_bus_mute(AudioServer.get_bus_index(b), true)

func _process(_delta: float) -> void:
	if _duck_until > 0.0 and float(Time.get_ticks_msec()) / 1000.0 >= _duck_until:
		_duck_until = 0.0
		for b in [&"SFX", &"Ambient"]:
			AudioServer.set_bus_mute(AudioServer.get_bus_index(b), false)
	var want: bool = GameState.s.is_dousing()
	if want and not _douse.playing:
		_douse.play()
	elif not want and _douse.playing:
		_douse.stop()

func set_master_volume(db: float) -> void:
	master_db = db
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index(&"Master"), db)
