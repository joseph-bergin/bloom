class_name Awareness
extends RefCounted
## How they find you. Your light is the only input.

## AWARENESS_TIER_MULT ^ tier, for tier 0..TIER_MAX. Tier is a small integer
## and this is evaluated for every contact on every tick, so it is a table.
const TIER_POW: Array[float] = [1.0, 1.9, 3.61, 6.859, 13.0321, 24.76099,
	47.045881, 89.3871739]

static func threshold(c: Contact) -> float:
	return Constants.AWARENESS_THRESHOLD_BASE * TIER_POW[clampi(c.tier, 0, 7)] \
		* (c.range_u / Constants.FIELD_RADIUS)

static func tick(data: GameStateData, delta: float) -> void:
	var l: float = Luminance.detectable(data)
	var cinder_penalty: bool = Stats.has_rule(&"cinder") and l >= 20.0
	for c in data.contacts:
		if c.state == Contact.State.COMMITTED or c.state == Contact.State.FLEEING:
			continue
		if c.state == Contact.State.TETHERED:
			continue
		var thr: float = maxf(threshold(c), 0.001)
		if l > thr:
			var rate: float = Constants.AWARENESS_RATE * (l / thr - 1.0)
			if cinder_penalty:
				rate *= 3.0
			c.awareness += rate * delta
		else:
			c.awareness = maxf(c.awareness - Constants.AWARENESS_DECAY * delta, 0.0)

		if c.awareness >= 1.0:
			_commit(data, c)

static func _commit(data: GameStateData, c: Contact) -> void:
	c.awareness = 1.0
	c.state = Contact.State.COMMITTED
	EventBus.contact_committed.emit(c)
	if c.tier <= 1:
		# Free — but it is out there now, and it knows.
		c.state = Contact.State.FLEEING
		c.flee_started_at = data.t
		EventBus.log_msg("A tier %d contact resolved you and ran." % c.tier, "warn")
		data.record_cause("T%d contact fled with your position" % c.tier)
		return
	if c.tier >= Constants.BLIGHT_TIER_MIN and data.rng.randf() < Constants.BLIGHT_CHANCE:
		Blight.seed(data, c)
		return
	Threat.launch_strike(data, c)
