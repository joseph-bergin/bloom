class_name Tethers
extends RefCounted
## Deterrence as income. Your own growth erodes your credibility.

static func can_establish(data: GameStateData, c: Contact) -> bool:
	if c == null or data.run_over:
		return false
	if c.state == Contact.State.TETHERED or c.state == Contact.State.FLEEING:
		return false
	if c.awareness >= Constants.TETHER_MAX_AWARENESS:
		return false
	if c.tier > data.player_tier() + Constants.TETHER_TIER_MARGIN:
		return false
	if data.tethers.size() >= Stats.tether_capacity:
		return false
	return data.signal_c >= establish_cost(c)

static func establish_cost(c: Contact) -> float:
	return Constants.TETHER_ESTABLISH_COST * pow(1.35, float(c.tier))

static func reassert_cost(t: Tether) -> float:
	return Constants.TETHER_REASSERT_COST * pow(1.25, float(t.tier)) * Stats.reassert_cost_mult

static func establish(data: GameStateData, c: Contact) -> bool:
	if not can_establish(data, c):
		return false
	data.signal_c -= establish_cost(c)
	c.state = Contact.State.TETHERED
	var t := Tether.new()
	t.contact_id = c.id
	t.established_at = data.t
	t.last_facet_at = data.t
	t.tier = c.tier
	data.tethers.append(t)
	EventBus.tether_established.emit(t)
	EventBus.log_msg("Tether established on contact %d." % c.id, "good")
	return true

static func reassert(data: GameStateData, t: Tether) -> bool:
	var cost: float = reassert_cost(t)
	if data.signal_c < cost or data.run_over:
		return false
	data.signal_c -= cost
	t.slack = 0.0
	t.warn_level = 0
	Luminance.add_transient(data, Constants.TRANSIENT_REASSERT)
	EventBus.tether_reasserted.emit(t)
	data.record_cause("tether %d reasserted" % t.contact_id)
	return true

static func slack_rate(data: GameStateData) -> float:
	return Constants.SLACK_BASE * (1.0 + data.luminance_effective() / Constants.SLACK_LUM_SCALE) \
		/ (1.0 + Stats.tether_stability)

static func tribute_rate(t: Tether) -> float:
	return Constants.TETHER_YIELD * pow(float(t.tier) + 1.0, 2.0) * Stats.tribute_mult

static func tick(data: GameStateData, delta: float) -> void:
	if data.tethers.is_empty():
		return
	var rate: float = slack_rate(data)
	var fired: Array[Tether] = []
	for t in data.tethers:
		var c: Contact = data.find_contact(t.contact_id)
		if c == null:
			continue
		var pay: float = tribute_rate(t) * delta
		data.motes += pay
		data.total_motes_earned += pay
		if data.t - t.last_facet_at >= Constants.TETHER_FACET_INTERVAL:
			t.last_facet_at = data.t
			data.facets += 1.0 * Stats.facet_mult
		t.slack += rate * delta
		if t.warn_level < 1 and t.slack >= Constants.TETHER_WARN_1:
			t.warn_level = 1
			EventBus.tether_warned.emit(t, 1)
			EventBus.log_msg("Tether %d is going slack." % t.contact_id, "warn")
		elif t.warn_level < 2 and t.slack >= Constants.TETHER_WARN_2:
			t.warn_level = 2
			EventBus.tether_warned.emit(t, 2)
			EventBus.log_msg("Tether %d is about to break." % t.contact_id, "bad")
		if t.slack >= 1.0:
			fired.append(t)

	for t in fired:
		_fire(data, t)
		if Stats.has_rule(&"hostage_doctrine"):
			# If any tether fires, all tethers fire.
			for other in data.tethers.duplicate():
				if other != t:
					_fire(data, other)
			break

static func _fire(data: GameStateData, t: Tether) -> void:
	if not data.tethers.has(t):
		return
	data.tethers.erase(t)
	var c: Contact = data.find_contact(t.contact_id)
	EventBus.tether_fired.emit(t)
	EventBus.log_msg("Tether %d went slack. It fired first." % t.contact_id, "bad")
	data.record_cause("tether %d fired (slack)" % t.contact_id)
	# Immediate, undetectable, no counterplay.
	var s := IncomingStrike.new()
	s.source_id = t.contact_id
	s.launched_at = data.t
	s.arrives_at = data.t
	s.bearing = c.bearing if c != null else data.rng.randf() * TAU
	s.detected = false
	s.tier = t.tier
	s.from_tether = true
	data.incoming.append(s)
	if c != null:
		c.state = Contact.State.COMMITTED

static func release(data: GameStateData, t: Tether) -> void:
	var c: Contact = data.find_contact(t.contact_id)
	if c != null and c.state == Contact.State.TETHERED:
		c.state = Contact.State.DRIFTING
	data.tethers.erase(t)
	EventBus.tether_released.emit(t)
