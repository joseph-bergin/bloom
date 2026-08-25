class_name Contacts
extends RefCounted
## Spawning, drift, cascade, field pressure.

static func tick(data: GameStateData, delta: float) -> void:
	_update_pressure(data)
	_spawn(data, delta)
	_step(data, delta)
	_reap(data)

static func _update_pressure(data: GameStateData) -> void:
	data.field_pressure = Constants.PRESSURE_PER_EMBER * float(data.ember_count) \
		+ Constants.PRESSURE_TIME_SCALE * pow(data.t / 60.0, Constants.PRESSURE_TIME_EXP) \
		+ Constants.PRESSURE_LUM_SCALE * (data.luminance_effective() / 100.0)

static func contact_cap(data: GameStateData) -> int:
	return Constants.CONTACT_CAP_BASE + data.ember_count * Constants.CONTACT_CAP_PER_EMBER

static func spawn_interval(data: GameStateData) -> float:
	return Constants.SPAWN_INTERVAL_BASE / (1.0 + data.field_pressure * Constants.SPAWN_PRESSURE_SCALE)

static func _spawn(data: GameStateData, delta: float) -> void:
	data.spawn_timer -= delta
	if data.spawn_timer > 0.0:
		return
	data.spawn_timer += spawn_interval(data)
	if data.contacts.size() >= contact_cap(data):
		return
	spawn_one(data)

static func spawn_one(data: GameStateData) -> Contact:
	var rng := data.rng
	var c := Contact.new()
	c.id = data.next_contact_id
	data.next_contact_id += 1
	c.bearing = rng.randf() * TAU
	c.range_u = Constants.FIELD_RADIUS * rng.randf_range(
		Constants.SPAWN_RANGE_MIN, Constants.SPAWN_RANGE_MAX)
	c.drift = rng.randf_range(-Constants.SPAWN_DRIFT_MAX, Constants.SPAWN_DRIFT_MAX)
	c.closing = rng.randf_range(Constants.SPAWN_CLOSING_MIN, Constants.SPAWN_CLOSING_MAX)
	c.tier = roll_tier(data)
	c.spawned_at = data.t
	data.contacts.append(c)
	EventBus.contact_spawned.emit(c)
	return c

static func roll_tier(data: GameStateData) -> int:
	var tier_floor: int = int(floor(data.field_pressure * Constants.TIER_PRESSURE_FLOOR))
	var tier: int = tier_floor + Constants.weighted_roll(Constants.TIER_WEIGHTS, data.rng)
	return clampi(tier, 0, tier_ceiling(data))

## The Cold lowers the ceiling on what anything in the field can become.
static func tier_ceiling(data: GameStateData) -> int:
	return clampi(Constants.TIER_MAX - data.cold_rank * Constants.COLD_TIER_PER_RANK, 0, Constants.TIER_MAX)

## Movement and cascade share one pass. This is the hottest loop in the sim;
## it is written flat on purpose — a per-contact helper call costs more here
## than the loop merge saves.
static func _step(data: GameStateData, delta: float) -> void:
	var ceiling: int = tier_ceiling(data)
	var cascade_rate: float = Constants.CASCADE_BASE * (1.0 + data.field_pressure) * delta
	var edge: float = Constants.FIELD_RADIUS
	var inner: float = Constants.CONTACT_MIN_RANGE
	var flee_speed: float = Constants.FLEE_SPEED
	for c in data.contacts:
		var st: int = c.state
		c.bearing = fposmod(c.bearing + c.drift * delta, TAU)
		if st == Contact.State.TETHERED:
			continue

		c.range_u += (flee_speed if st == Contact.State.FLEEING else c.closing) * delta
		# Bounce at the edges. A contact that leaves and re-enters resets
		# nothing and feels arbitrary, so it never leaves.
		if c.range_u > edge:
			c.range_u = edge
			if st != Contact.State.FLEEING:
				c.closing = -absf(c.closing)
		elif c.range_u < inner:
			c.range_u = inner
			c.closing = absf(c.closing)

		if st == Contact.State.FLEEING or c.tier >= ceiling:
			continue
		c.cascade += cascade_rate * (1.0 + float(c.tier) * Constants.CASCADE_TIER_SCALE)
		if c.cascade >= 1.0:
			c.tier += 1
			c.cascade = 0.0
			# The player may not have been watching. Make it loud.
			EventBus.contact_cascaded.emit(c)
			EventBus.log_msg("Cascade — contact %d escalated to tier %d." % [c.id, c.tier], "cascade")
			data.record_cause("contact %d cascaded to T%d" % [c.id, c.tier])

static func _reap(data: GameStateData) -> void:
	# Scan before allocating: this runs 60x a second and almost never
	# has anything to do.
	var any: bool = false
	for c in data.contacts:
		if c.state == Contact.State.FLEEING and c.flee_started_at >= 0.0 \
				and data.t - c.flee_started_at >= Constants.FLEE_DESPAWN:
			any = true
			break
	if not any:
		return
	var keep: Array[Contact] = []
	for c in data.contacts:
		if c.state == Contact.State.FLEEING and c.flee_started_at >= 0.0 \
				and data.t - c.flee_started_at >= Constants.FLEE_DESPAWN:
			EventBus.contact_removed.emit(c.id)
			continue
		keep.append(c)
	data.contacts = keep

static func remove(data: GameStateData, c: Contact) -> void:
	var was_hunter: bool = c.is_hunter
	data.contacts.erase(c)
	var tt := data.find_tether(c.id)
	if tt != null:
		data.tethers.erase(tt)
	EventBus.contact_removed.emit(c.id)
	if was_hunter and not data.has_hunter():
		EventBus.hunter_cleared.emit()
