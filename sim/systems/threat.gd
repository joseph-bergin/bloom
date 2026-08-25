class_name Threat
extends RefCounted
## Incoming strikes, redundancy, run end.

static func launch_strike(data: GameStateData, c: Contact) -> IncomingStrike:
	var s := IncomingStrike.new()
	s.source_id = c.id
	s.launched_at = data.t
	s.arrives_at = data.t + data.rng.randf_range(Constants.STRIKE_PREP_MIN, Constants.STRIKE_PREP_MAX) \
		+ c.range_u / Constants.STRIKE_SPEED
	s.bearing = c.bearing
	s.tier = c.tier
	# Without Optics rank 6, strikes arrive with no warning at all.
	s.detected = Stats.strike_detection_available()
	data.incoming.append(s)
	EventBus.strike_incoming.emit(s)
	if s.detected:
		EventBus.log_msg("Incoming. Bearing %d degrees, %ds out." %
			[int(rad_to_deg(s.bearing)), int(s.arrives_at - data.t)], "bad")
	data.record_cause("T%d contact %d launched a strike" % [c.tier, c.id])
	return s

static func can_disperse(data: GameStateData, s: IncomingStrike) -> bool:
	return s.detected and data.signal_c >= Constants.DISPERSAL_COST_SIGNAL and not s.from_tether

static func disperse(data: GameStateData, s: IncomingStrike) -> bool:
	if not can_disperse(data, s):
		return false
	data.signal_c -= Constants.DISPERSAL_COST_SIGNAL
	data.incoming.erase(s)
	Luminance.add_transient(data, Constants.DISPERSAL_TRANSIENT)
	EventBus.strike_dispersed.emit(s)
	EventBus.log_msg("Evasive dispersal. The strike went wide.", "good")
	return true

static func tick(data: GameStateData, delta: float) -> void:
	if data.incoming.is_empty():
		return
	var keep: Array[IncomingStrike] = []
	for s in data.incoming:
		if data.t >= s.arrives_at:
			_land(data, s)
		else:
			keep.append(s)
	data.incoming = keep

static func _land(data: GameStateData, s: IncomingStrike) -> void:
	if Stats.strike_mitigation > 0.0 and data.rng.randf() < Stats.strike_mitigation:
		EventBus.log_msg("Strike absorbed by redundant structure.", "good")
		EventBus.strike_dispersed.emit(s)
		return
	data.redundancy -= 1
	EventBus.strike_landed.emit(s)
	EventBus.redundancy_lost.emit(data.redundancy)
	EventBus.log_msg("Strike landed. Redundancy %d." % maxi(data.redundancy, 0), "bad")
	data.record_cause("strike from %d landed; redundancy %d" % [s.source_id, data.redundancy])
	if data.redundancy <= 0:
		end_run(data, "A strike found you.")

static func end_run(data: GameStateData, reason: String) -> void:
	if data.run_over:
		return
	data.run_over = true
	data.run_end_reason = reason
	EventBus.run_ended.emit(reason)
	EventBus.log_msg(reason, "bad")
