extends Node
## Audio does more work than art here.

const POOL := 12
const STREAK_WINDOW := 1.2
const HIT_GAP := 0.055

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
## Music is baked off-thread: the four layers take about two seconds to
## generate, which as a startup block is a visible hang.
var _music: Dictionary = {}      # layer -> AudioStreamPlayer
var _gain: Dictionary = {}       # layer -> current linear gain
var _baked: Dictionary = {}      # written by the thread, read after join
var _bake: Thread = null
var _last_kill: float = -99.0
var _last_hit: float = -99.0
var _last_hover: float = -99.0

func _ready() -> void:
	_buses()
	_streams["purchase"] = Synth.purchase()
	_streams["hit"] = Synth.hit()
	_streams["crit"] = Synth.crit()
	_streams["douse_in"] = Synth.douse_in()
	_streams["douse_out"] = Synth.douse_out()
	_streams["breach"] = Synth.breach()
	_streams["boss"] = Synth.boss()
	_streams["cleared"] = Synth.cleared()
	_streams["click"] = Synth.click()
	_streams["hover"] = Synth.hover()
	_streams["press"] = Synth.press()
	_streams["denied"] = Synth.denied()
	_streams["open"] = Synth.whoosh(true)
	_streams["close"] = Synth.whoosh(false)
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

	EventBus.contact_hit.connect(_on_hit)
	EventBus.contact_killed.connect(_on_kill)
	EventBus.douse_started.connect(func():
		play("douse_in", -4.0)
		# Everything else ducks while you are hiding, so the world going
		# quiet is the feedback that it worked.
		_set_hidden(true))
	EventBus.douse_ended.connect(func():
		play("douse_out", -8.0)
		_set_hidden(false))
	EventBus.node_purchased.connect(func(_id: StringName, _r: int): play("purchase", -3.0))
	EventBus.boss_spawned.connect(func(_c: Contact, _l: int): play("boss", -1.0))
	EventBus.level_cleared.connect(func(_l: int, _b: float): play("cleared", -4.0))
	EventBus.shield_breached.connect(func(_r: int):
		play("breach", 0.0)
		duck(Constants.BREACH_DUCK))

	# Headless is the test suite and the balance runner. Neither listens,
	# and baking there costs two seconds on every CI run.
	if DisplayServer.get_name() != "headless":
		_bake = Thread.new()
		_bake.start(_bake_music)

func _buses() -> void:
	for name in [&"SFX", &"Ambient", &"UI", &"Music"]:
		if AudioServer.get_bus_index(name) != -1:
			continue
		var idx: int = AudioServer.bus_count
		AudioServer.add_bus(idx)
		AudioServer.set_bus_name(idx, name)
		AudioServer.set_bus_send(idx, &"Master")
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index(&"Ambient"), -12.0)
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index(&"Music"), -9.0)

func play(key: String, db: float = -6.0, pitch: float = 1.0) -> void:
	if not _streams.has(key):
		return
	_emit(_streams[key], db, pitch)

## Hover fires as fast as the cursor moves. Without a gate, sweeping across
## the tree machine-guns the pool and drowns out everything else.
func hover() -> void:
	var now: float = float(Time.get_ticks_msec()) / 1000.0
	if now - _last_hover < 0.045:
		return
	_last_hover = now
	play("hover", -26.0, randf_range(0.94, 1.06))

func _emit(stream: AudioStream, db: float, pitch: float) -> void:
	var p: AudioStreamPlayer = _pool[_next]
	_next = (_next + 1) % _pool.size()
	p.stream = stream
	p.volume_db = db
	p.pitch_scale = pitch
	p.play()

## Landed shots tick. Throttled, because a fast turret would otherwise
## produce a continuous drill rather than a rhythm.
func _on_hit(_at: Vector2, _dir: Vector2, crit: bool, lethal: bool) -> void:
	if lethal:
		return
	var now: float = float(Time.get_ticks_msec()) / 1000.0
	if now - _last_hit < HIT_GAP and not crit:
		return
	_last_hit = now
	play("crit" if crit else "hit", -16.0 if crit else -22.0,
		randf_range(0.94, 1.06))

## While hidden the mix pulls back, so going dark is audible as well as
## visible. Not silence — that is reserved for a shield breaking.
func _set_hidden(on: bool) -> void:
	var sfx: int = AudioServer.get_bus_index(&"SFX")
	var amb: int = AudioServer.get_bus_index(&"Ambient")
	var mus: int = AudioServer.get_bus_index(&"Music")
	AudioServer.set_bus_volume_db(sfx, -13.0 if on else 0.0)
	AudioServer.set_bus_volume_db(amb, -22.0 if on else -12.0)
	# The music goes with it. Holding your breath should sound like holding
	# your breath, and half a mix carrying on regardless undoes that.
	AudioServer.set_bus_volume_db(mus, -20.0 if on else -9.0)

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
	for b in [&"SFX", &"Ambient", &"Music"]:
		AudioServer.set_bus_mute(AudioServer.get_bus_index(b), true)

func _process(_delta: float) -> void:
	if _duck_until > 0.0 and float(Time.get_ticks_msec()) / 1000.0 >= _duck_until:
		_duck_until = 0.0
		for b in [&"SFX", &"Ambient", &"Music"]:
			AudioServer.set_bus_mute(AudioServer.get_bus_index(b), false)
	var want: bool = GameState.s.is_dousing()
	if want and not _douse.playing:
		_douse.play()
	elif not want and _douse.playing:
		_douse.stop()

	if _bake != null and not _bake.is_alive():
		_bake.wait_to_finish()
		_bake = null
		_start_music()
	_mix_music(_delta)

func set_master_volume(db: float) -> void:
	master_db = db
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index(&"Master"), db)

# --- music ---------------------------------------------------------------

## Runs on the bake thread. Touches nothing but its own output; the join in
## _process is what makes handing _baked over safe.
func _bake_music() -> void:
	_baked = {"bed": Music.bed(), "pulse": Music.pulse(),
		"tension": Music.tension(), "dread": Music.dread()}

## All four start in the same frame and never stop, so they stay in phase
## for the life of the process and can be crossfaded without re-syncing.
func _start_music() -> void:
	for layer in _baked:
		var p := AudioStreamPlayer.new()
		p.bus = &"Music"
		p.stream = _baked[layer]
		p.volume_db = -80.0
		add_child(p)
		p.play()
		_music[layer] = p
		_gain[layer] = 0.0

## What each layer should be doing right now. Tension is the interesting
## one: it tracks the light you are giving off, so burning brighter is
## audible as the music closing in before it is visible as anything else.
func _music_mix() -> Dictionary:
	var s: GameStateData = GameState.s
	var live: bool = not GameState.paused and not s.run_over
	var fighting: bool = live and s.phase != GameStateData.Phase.UPGRADING
	var boss: bool = live and s.phase == GameStateData.Phase.BOSS
	var lit: float = clampf(s.effective_luminance() / 140.0, 0.0, 1.0)
	return {
		"bed": 0.85,
		"pulse": 0.75 if fighting else 0.0,
		"tension": lit * 0.8 if fighting else 0.0,
		"dread": 0.9 if boss else 0.0,
	}

func _mix_music(delta: float) -> void:
	if _music.is_empty():
		return
	var want: Dictionary = _music_mix()
	for layer in _music:
		var target: float = want[layer]
		# Toward silence faster than toward sound: a layer arriving should
		# feel like something turning up, and a layer leaving should not
		# hang around after the reason for it has gone.
		var rate: float = 1.4 if target > _gain[layer] else 2.6
		_gain[layer] = move_toward(_gain[layer], target, delta * rate)
		var p: AudioStreamPlayer = _music[layer]
		p.volume_db = -80.0 if _gain[layer] < 0.001 else linear_to_db(_gain[layer])
