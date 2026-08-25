class_name Sensing
extends RefCounted
## Passive (free, silent, degraded) and active sweep (loud, exact).
## Everything that targets or renders goes through believed_position().

static func believed_position(c: Contact, t: float) -> Vector2:
	var dt: float = t - c.known_at
	var b: float = c.known_bearing + c.known_drift * dt
	var r: float = c.known_range + c.known_closing * dt
	return Vector2(cos(b), sin(b)) * r

static func staleness(c: Contact, t: float) -> float:
	if c.known_at < 0.0:
		return INF
	return maxf(t - c.known_at, 0.0)

static func uncertainty_radius(c: Contact, t: float) -> float:
	return staleness(c, t) * Constants.UNCERT_GROWTH / maxf(Stats.tracking, 0.01)

static func is_displayable(c: Contact, t: float) -> bool:
	if not c.has_contact:
		return false
	return uncertainty_radius(c, t) <= Constants.DROP_THRESHOLD

static func tick(data: GameStateData, delta: float) -> void:
	_passive(data, delta)
	_sweeps(data, delta)
	data.sweep_cooldown = maxf(data.sweep_cooldown - delta, 0.0)

static func _passive(data: GameStateData, delta: float) -> void:
	data.passive_timer -= delta
	if data.passive_timer > 0.0:
		return
	data.passive_timer += Stats.passive_interval
	var rng := data.rng
	var earned: float = 0.0
	for c in data.contacts:
		if c.range_u > Stats.passive_range:
			continue
		var first: bool = not c.has_contact
		c.has_contact = true
		c.known_at = data.t
		c.known_bearing = c.bearing + rng.randf_range(-1.0, 1.0) \
			* Constants.PASSIVE_BEARING_NOISE / Stats.bearing_precision
		c.known_drift = c.drift
		if Stats.range_data_available():
			c.known_range = c.range_u * (1.0 + rng.randf_range(-1.0, 1.0) * Constants.PASSIVE_RANGE_NOISE)
			c.known_closing = c.closing
			c.known_range_valid = true
		else:
			# Bearing only. You know something is out there, not how far.
			c.known_range = Constants.FIELD_RADIUS * 0.75
			c.known_closing = 0.0
			c.known_range_valid = false
		c.known_tier = c.tier if Stats.tier_id_exact else clampi(
			c.tier + (rng.randi_range(-1, 1)), 0, Constants.TIER_MAX)
		c.known_awareness = c.awareness
		c.resolved = false
		earned += Constants.SIGNAL_PER_READ * Stats.signal_mult
		if first:
			EventBus.log_msg("Passive contact — bearing %d degrees." % int(rad_to_deg(c.known_bearing)), "sense")
	if earned > 0.0:
		data.signal_c += earned

static func can_sweep(data: GameStateData) -> bool:
	return Stats.can_sweep() and data.sweep_cooldown <= 0.0 and not data.run_over

static func fire_sweep(data: GameStateData) -> bool:
	if not can_sweep(data):
		return false
	data.sweep_cooldown = Stats.sweep_cooldown
	var ring := SweepRing.new(Stats.sweep_radius, data.t)
	data.sweeps.append(ring)
	Luminance.add_transient(data, Constants.SWEEP_TRANSIENT * Stats.sweep_radius_mult)
	EventBus.sweep_fired.emit(ring.max_radius)
	data.record_cause("active sweep at L=%.1f" % data.luminance_effective())
	return true

static func _sweeps(data: GameStateData, delta: float) -> void:
	if data.sweeps.is_empty():
		return
	var keep: Array[SweepRing] = []
	for s in data.sweeps:
		var prev: float = s.radius
		s.radius += Stats.sweep_speed * delta
		# Long Ear trades the sweep's reveal for permanent passive coverage.
		if not Stats.has_rule(&"long_ear"):
			for c in data.contacts:
				if c.range_u > prev and c.range_u <= s.radius:
					resolve_exact(data, c)
		if s.radius < s.max_radius:
			keep.append(s)
	data.sweeps = keep

## Set a contact's knowledge to exact truth.
static func resolve_exact(data: GameStateData, c: Contact) -> void:
	var first: bool = not c.has_contact
	c.has_contact = true
	c.known_at = data.t
	c.known_bearing = c.bearing
	c.known_range = c.range_u
	c.known_range_valid = true
	c.known_drift = c.drift
	c.known_closing = c.closing
	c.known_tier = c.tier
	c.known_awareness = c.awareness
	c.resolved = true
	if Stats.has_rule(&"lighthouse"):
		c.awareness = clampf(c.awareness + Constants.LIGHTHOUSE_AWARENESS, 0.0, 1.0)
	data.signal_c += Constants.SIGNAL_PER_READ * 2.0 * Stats.signal_mult
	EventBus.contact_resolved.emit(c)
	if first and c.tier >= 4:
		EventBus.log_msg("Sweep resolved a tier %d contact at %d units." % [c.tier, int(c.range_u)], "warn")
