class_name Lances
extends RefCounted
## Player strikes. No health bars: a lance erases a contact or misses entirely.

static func hit_chance_for(data: GameStateData, c: Contact) -> float:
	if Stats.has_rule(&"overburn"):
		return 1.0
	var stale: float = Sensing.staleness(c, data.t)
	if is_inf(stale):
		return Stats.min_hit_chance
	return clampf(1.0 - (stale * Constants.STALE_PENALTY) / Stats.tracking,
		Stats.min_hit_chance, 1.0)

static func can_launch(data: GameStateData, c: Contact) -> bool:
	if data.run_over or c == null or not c.has_contact:
		return false
	return c.state != Contact.State.TETHERED

static func launch(data: GameStateData, c: Contact) -> Lance:
	if not can_launch(data, c):
		return null
	var believed: Vector2 = Sensing.believed_position(c, data.t)
	var dist: float = believed.length()
	var flight: float = dist / maxf(Stats.lance_speed, 1.0)
	# Lead the target using what we believe about its motion.
	var aim: Vector2 = believed + Vector2(
		cos(c.known_bearing) * c.known_closing,
		sin(c.known_bearing) * c.known_closing) * flight

	var hit_chance: float = hit_chance_for(data, c)

	Luminance.add_transient(data, Constants.TRANSIENT_LANCE_LAUNCH)
	var l := Lance.new(c.id, aim, hit_chance, data.t, flight, c.tier)
	data.lances.append(l)
	EventBus.lance_launched.emit(l)
	return l

static func tick(data: GameStateData, delta: float) -> void:
	if not data.lances.is_empty():
		var keep: Array[Lance] = []
		for l in data.lances:
			if data.t >= l.arrives_at:
				_resolve(data, l)
			else:
				keep.append(l)
		data.lances = keep
	if not data.miss_markers.is_empty():
		var mk: Array = []
		for m in data.miss_markers:
			if float(m.get("until", 0.0)) > data.t:
				mk.append(m)
		data.miss_markers = mk

static func _resolve(data: GameStateData, l: Lance) -> void:
	var c: Contact = data.find_contact(l.target_id)
	if c == null:
		return  # already gone; the lance finds nothing
	if data.rng.randf() <= l.hit_chance:
		_hit(data, l, c)
	else:
		_miss(data, l, c)

static func _hit(data: GameStateData, l: Lance, c: Contact) -> void:
	var motes: float = Constants.MOTES_BASE * pow(float(c.tier) + 1.0, Constants.MOTES_TIER_EXP) \
		* Stats.yield_mult
	var facets: float = (1.0 * Stats.facet_mult) if c.tier >= Constants.FACET_TIER_MIN else 0.0
	data.motes += motes
	data.total_motes_earned += motes
	data.facets += facets
	var at: Vector2 = c.true_position()
	if c.is_blight_source:
		Blight.clear_source(data, c.id)
	Contacts.remove(data, c)
	EventBus.lance_hit.emit(c, motes, facets, at)
	Backlight.roll(data, c.tier, at)
	if Stats.chain_chance > 0.0 and data.rng.randf() < Stats.chain_chance:
		_chain(data, at, c.tier)

static func _chain(data: GameStateData, at: Vector2, tier: int) -> void:
	# Chain detonation catches the nearest tracked neighbour.
	var best: Contact = null
	var best_d: float = 260.0
	for other in data.contacts:
		if not other.has_contact:
			continue
		var d: float = Sensing.believed_position(other, data.t).distance_to(at)
		if d < best_d:
			best_d = d
			best = other
	if best != null:
		var lc := Lance.new(best.id, Sensing.believed_position(best, data.t), 1.0, data.t, 0.15, best.tier)
		data.lances.append(lc)
		EventBus.log_msg("Chain detonation.", "good")

static func _miss(data: GameStateData, l: Lance, c: Contact) -> void:
	c.awareness = clampf(c.awareness + Constants.LANCE_MISS_AWARENESS, 0.0, 1.0)
	data.miss_markers.append({"pos": l.aim, "until": data.t + Constants.LANCE_MISS_MARKER_TIME})
	EventBus.lance_missed.emit(l, l.aim)
	EventBus.log_msg("Lance missed. Something went past it.", "warn")
	data.record_cause("lance missed contact %d (p=%.2f)" % [l.target_id, l.hit_chance])
