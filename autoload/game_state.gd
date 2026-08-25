extends Node
## Holds the GameStateData and owns the tick order.

var data: GameStateData = GameStateData.new()
var paused: bool = false
var _hitstop_frames: int = 0
var _pending_dormancy: Dictionary = {}

func _ready() -> void:
	data.rng.randomize()
	reset_run(true)

func reset_run(fresh: bool) -> void:
	if fresh:
		data.purchase_version += 1
	Stats.recompute(data)
	data.redundancy = Stats.max_redundancy
	data.sensor_capacity = Stats.tether_capacity
	data.spawn_timer = 0.0
	data.passive_timer = 0.0

## Called by SimRoot from _physics_process. Order matters — do not rearrange.
func tick(delta: float) -> void:
	if paused or data.run_over:
		return
	if data.purchase_version != Stats.cached_version:
		Stats.recompute(data)
	data.t += delta

	Luminance.tick(data, delta)
	Contacts.tick(data, delta)
	Sensing.tick(data, delta)
	Awareness.tick(data, delta)
	Lances.tick(data, delta)
	Backlight.tick(data, delta)
	Tethers.tick(data, delta)
	Blight.tick(data, delta)
	Threat.tick(data, delta)
	Economy.tick(data, delta)
	Automation.tick(data, delta)

# --- Player intents ------------------------------------------------------

func try_sweep() -> bool:
	return Sensing.fire_sweep(data)

func try_lance(contact_id: int) -> bool:
	if not Stats.manual_targeting_allowed():
		return false
	var c: Contact = data.find_contact(contact_id)
	if c == null:
		return false
	var launched: int = 0
	for _i in range(Stats.salvo):
		if Lances.launch(data, c) != null:
			launched += 1
	return launched > 0

func try_tether(contact_id: int) -> bool:
	if not Stats.manual_targeting_allowed():
		return false
	var c: Contact = data.find_contact(contact_id)
	return Tethers.establish(data, c) if c != null else false

func try_reassert(contact_id: int) -> bool:
	var t: Tether = data.find_tether(contact_id)
	return Tethers.reassert(data, t) if t != null else false

func try_purchase(id: StringName) -> bool:
	return Economy.purchase(data, id)

func try_respec() -> bool:
	return Economy.respec(data)

func try_disperse(s: IncomingStrike) -> bool:
	return Threat.disperse(data, s)

func commit_ember() -> Dictionary:
	var report: Dictionary = Ember.commit(data)
	Stats.recompute(data)
	data.redundancy = Stats.max_redundancy
	SaveManager.save_game()
	return report

# --- Nearest-contact picking (screen -> sim) -----------------------------

## Uses believed positions only. Rendering and targeting never see truth.
func pick_contact(at: Vector2, radius: float = 42.0) -> Contact:
	var best: Contact = null
	var best_d: float = radius
	for c in data.contacts:
		if not Sensing.is_displayable(c, data.t):
			continue
		var d: float = Sensing.believed_position(c, data.t).distance_to(at)
		if d < best_d:
			best_d = d
			best = c
	return best

# --- Feel ----------------------------------------------------------------

func hitstop() -> void:
	if _hitstop_frames > 0:
		return
	_hitstop_frames = Constants.HITSTOP_FRAMES
	Engine.time_scale = 0.0
	for _i in range(Constants.HITSTOP_FRAMES):
		await get_tree().physics_frame
	Engine.time_scale = 1.0
	_hitstop_frames = 0

# --- Dormancy handoff ----------------------------------------------------

func set_pending_dormancy(report: Dictionary) -> void:
	_pending_dormancy = report

func take_pending_dormancy() -> Dictionary:
	var r: Dictionary = _pending_dormancy
	_pending_dormancy = {}
	return r
