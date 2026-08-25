extends Node
## Player pool, bus management, cue dispatch.
## In a game about detection, audio is a primary information channel:
## contacts are audible before they are visible.

const POOL_SIZE := 24
const VOICE_REFRESH := 0.25
const SFX_POOL := 16

const BUS_MASTER := &"Master"
const BUS_SFX := &"SFX"
const BUS_AMBIENT := &"Ambient"
const BUS_UI := &"UI"
const BUS_MUSIC := &"Music"

var rig: Node2D = null                      # set by FieldView; field-space parent
var reduced_motion: bool = false
var master_volume: float = 0.0              # dB

var _voices: Array[AudioStreamPlayer2D] = []      # contact thrums
var _voice_owner: Array[int] = []                 # contact id per voice
var _voice_contact: Array[Contact] = []
var _voice_timer: float = 0.0
var _sfx: Array[AudioStreamPlayer2D] = []
var _ui_player: AudioStreamPlayer = null
var _ambient: AudioStreamPlayer = null
var _drone: AudioStreamPlayer = null

var _streams: Dictionary = {}
var _voice_streams: Array[AudioStreamWAV] = []
var _duck_until: float = 0.0
var _slack_timer: float = 0.0

func _ready() -> void:
	_build_buses()
	_build_streams()
	_build_players()
	_wire()

# --- Bus layout: Master -> SFX, Ambient, UI, Music ------------------------

func _build_buses() -> void:
	var wanted: Array[StringName] = [BUS_SFX, BUS_AMBIENT, BUS_UI, BUS_MUSIC]
	for name in wanted:
		if AudioServer.get_bus_index(name) != -1:
			continue
		var idx: int = AudioServer.bus_count
		AudioServer.add_bus(idx)
		AudioServer.set_bus_name(idx, name)
		AudioServer.set_bus_send(idx, BUS_MASTER)
	# Compressor on Master, for the strike duck to bite against.
	var master: int = AudioServer.get_bus_index(BUS_MASTER)
	if AudioServer.get_bus_effect_count(master) == 0:
		var comp := AudioEffectCompressor.new()
		comp.threshold = -12.0
		comp.ratio = 4.0
		comp.attack_us = 20.0
		comp.release_ms = 250.0
		AudioServer.add_bus_effect(master, comp)
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index(BUS_AMBIENT), -14.0)
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index(BUS_UI), -8.0)

func _build_streams() -> void:
	_streams["lance"] = Synth.lance_launch()
	_streams["sweep"] = Synth.sweep()
	_streams["purchase"] = Synth.purchase()
	_streams["cascade"] = Synth.cascade()
	_streams["alarm"] = Synth.alarm()
	_streams["strike"] = Synth.strike_land()
	_streams["slack"] = Synth.slack_tick()
	_streams["click"] = Synth.ui_click()
	_streams["ambient"] = Synth.ambient()
	_streams["drone"] = Synth.hunter_drone()
	for t in range(Constants.TIER_MAX + 1):
		_streams["det_%d" % t] = Synth.detonation(t)
		_voice_streams.append(Synth.contact_voice(t))

func _build_players() -> void:
	for i in range(POOL_SIZE):
		var p := AudioStreamPlayer2D.new()
		p.bus = BUS_SFX
		p.max_distance = Constants.FIELD_RADIUS * 1.1
		p.attenuation = 1.6
		p.panning_strength = 1.5
		p.volume_db = -10.0
		add_child(p)
		_voices.append(p)
		_voice_owner.append(-1)
		_voice_contact.append(null)
	for i in range(SFX_POOL):
		var s := AudioStreamPlayer2D.new()
		s.bus = BUS_SFX
		s.max_distance = Constants.FIELD_RADIUS * 1.4
		s.attenuation = 1.2
		s.panning_strength = 1.4
		add_child(s)
		_sfx.append(s)
	_ui_player = AudioStreamPlayer.new()
	_ui_player.bus = BUS_UI
	add_child(_ui_player)
	_ambient = AudioStreamPlayer.new()
	_ambient.bus = BUS_AMBIENT
	_ambient.stream = _streams["ambient"]
	_ambient.volume_db = -6.0
	add_child(_ambient)
	_ambient.play()
	_drone = AudioStreamPlayer.new()
	_drone.bus = BUS_AMBIENT
	_drone.stream = _streams["drone"]
	_drone.volume_db = -4.0
	add_child(_drone)

func _wire() -> void:
	EventBus.lance_launched.connect(_on_lance)
	EventBus.lance_hit.connect(_on_hit)
	EventBus.sweep_fired.connect(func(_r: float): play_ui("sweep", -4.0))
	EventBus.node_purchased.connect(func(_id: StringName, _r: int): play_ui("purchase", -3.0))
	EventBus.contact_cascaded.connect(_on_cascade)
	EventBus.strike_incoming.connect(func(s: IncomingStrike):
		if s.detected:
			play_at("alarm", Vector2(cos(s.bearing), sin(s.bearing)) * 300.0, -2.0))
	EventBus.strike_landed.connect(_on_strike)
	EventBus.hunter_spawned.connect(func(_c: Contact):
		if not _drone.playing:
			_drone.play())
	EventBus.hunter_cleared.connect(func():
		# Removing the drone when the last hunter dies is the beat.
		_drone.stop())

# --- Cues ----------------------------------------------------------------

func play_ui(key: String, db: float = -6.0) -> void:
	if not _streams.has(key):
		return
	_ui_player.stream = _streams[key]
	_ui_player.volume_db = db
	_ui_player.play()

func play_at(key: String, pos: Vector2, db: float = -6.0) -> void:
	if not _streams.has(key):
		return
	var p: AudioStreamPlayer2D = _free_sfx()
	if p == null:
		return
	p.stream = _streams[key]
	p.global_position = pos
	p.volume_db = db
	p.play()

func _free_sfx() -> AudioStreamPlayer2D:
	for p in _sfx:
		if not p.playing:
			return p
	return _sfx[0] if not _sfx.is_empty() else null

func _on_lance(l: Lance) -> void:
	play_at("lance", l.aim.normalized() * 120.0, -8.0)

func _on_hit(c: Contact, _m: float, _f: float, at: Vector2) -> void:
	play_at("det_%d" % clampi(c.tier, 0, Constants.TIER_MAX), at, -3.0)

func _on_cascade(c: Contact) -> void:
	# Loud even when the player wasn't watching.
	var pos: Vector2 = Sensing.believed_position(c, GameState.data.t) if c.has_contact \
		else Vector2(cos(c.bearing), sin(c.bearing)) * Constants.FIELD_RADIUS * 0.8
	play_at("cascade", pos, -4.0)

func _on_strike(_s: IncomingStrike) -> void:
	play_ui("strike", 0.0)
	duck(Constants.STRIKE_DUCK_TIME)

## Silence as an event. On a strike landing, everything goes to true silence.
func duck(seconds: float) -> void:
	_duck_until = maxf(_duck_until, Time.get_ticks_msec() / 1000.0 + seconds)
	for bus in [BUS_SFX, BUS_AMBIENT, BUS_MUSIC]:
		AudioServer.set_bus_mute(AudioServer.get_bus_index(bus), true)

# --- Contact voices ------------------------------------------------------

func _process(delta: float) -> void:
	if _duck_until > 0.0 and Time.get_ticks_msec() / 1000.0 >= _duck_until:
		_duck_until = 0.0
		for bus in [BUS_SFX, BUS_AMBIENT, BUS_MUSIC]:
			AudioServer.set_bus_mute(AudioServer.get_bus_index(bus), false)
	_voice_timer -= delta
	if _voice_timer <= 0.0:
		_voice_timer = VOICE_REFRESH
		_repick_voices()
	_track_voices()
	_update_slack(delta)

## LRU pool: the nearest N tracked contacts get voices, the rest are silent.
## Choosing which contacts hold voices is O(n log n) and does not need to
## happen every frame; following the ones that do is cheap and does.
func _repick_voices() -> void:
	var data: GameStateData = GameState.data
	var t: float = data.t
	var keyed: Array = []
	for c in data.contacts:
		if Sensing.is_displayable(c, t):
			keyed.append([Sensing.believed_position(c, t).length_squared(), c])
	keyed.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])

	var want: Dictionary = {}
	for i in range(mini(keyed.size(), POOL_SIZE)):
		var c: Contact = keyed[i][1]
		want[c.id] = c

	for i in range(_voices.size()):
		var owner_id: int = _voice_owner[i]
		if owner_id != -1 and not want.has(owner_id):
			_voices[i].stop()
			_voice_owner[i] = -1
			_voice_contact[i] = null

	for id in want.keys():
		if _voice_owner.has(id):
			continue
		var idx: int = _voice_owner.find(-1)
		if idx == -1:
			break
		var c: Contact = want[id]
		_voice_owner[idx] = id
		_voice_contact[idx] = c
		_voices[idx].stream = _voice_streams[clampi(c.known_tier, 0, _voice_streams.size() - 1)]
		_voices[idx].play(randf() * 0.4)

## Keep live voices glued to their contact's believed position.
func _track_voices() -> void:
	var t: float = GameState.data.t
	for i in range(_voices.size()):
		var c: Contact = _voice_contact[i]
		if c == null:
			continue
		_voices[i].global_position = Sensing.believed_position(c, t)
		# Hunters sit louder in the mix. You should feel the room change.
		_voices[i].volume_db = (-6.0 if c.is_hunter else -13.0) \
			- (6.0 if not c.resolved else 0.0)

func _update_slack(delta: float) -> void:
	var worst: float = 0.0
	for tt in GameState.data.tethers:
		worst = maxf(worst, tt.slack)
	if worst < Constants.TETHER_WARN_1:
		_slack_timer = 0.0
		return
	# Accelerating tick as any tether nears 1.0.
	var interval: float = lerpf(1.2, 0.16, inverse_lerp(Constants.TETHER_WARN_1, 1.0, worst))
	_slack_timer -= delta
	if _slack_timer <= 0.0:
		_slack_timer = interval
		play_ui("slack", -12.0)

func set_master_volume(db: float) -> void:
	master_volume = db
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index(BUS_MASTER), db)
