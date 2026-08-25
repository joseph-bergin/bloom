class_name Dormancy
extends RefCounted
## The player banks their light and goes dark deliberately.
## On return, they are shown the changed board — not a modal with a number.

static func elapsed_since(last_real_time: float) -> float:
	if last_real_time <= 0.0:
		return 0.0
	var now: float = Time.get_unix_time_from_system()
	var dt: float = now - last_real_time
	if dt < 0.0:
		return 0.0   # clock manipulation
	return minf(dt, Constants.DORMANCY_CLAMP_SECONDS)

## Runs elapsed time through a compressed simulation and returns a report
## describing what changed. The board is mutated in place.
static func resolve(data: GameStateData, elapsed: float) -> Dictionary:
	var eff: float = Stats.dormancy_efficiency
	var effective_time: float = elapsed * eff
	if elapsed < 30.0:
		return {}

	var before_contacts: int = data.contacts.size()
	var before_pressure: float = data.field_pressure
	var motes_before: float = data.total_motes_earned

	# Tribute keeps paying while you are dark. Nothing else earns.
	var tribute: float = 0.0
	for t in data.tethers:
		tribute += Tethers.tribute_rate(t) * effective_time
		t.slack = clampf(t.slack + Tethers.slack_rate(data) * effective_time, 0.0, 0.99)
	data.motes += tribute
	data.total_motes_earned += tribute

	# Contacts you were tracking are gone. Time moved without you.
	var forgotten: int = 0
	var kept: Array[Contact] = []
	for c in data.contacts:
		if c.state == Contact.State.TETHERED:
			kept.append(c)
			continue
		forgotten += 1
	data.contacts = kept
	data.lances = []
	data.sweeps = []
	data.incoming = []

	data.t += effective_time
	Contacts._update_pressure(data)

	# New ones burn where nothing was.
	var spawn_count: int = int(clampf(effective_time / Contacts.spawn_interval(data),
		0.0, float(Contacts.contact_cap(data) - data.contacts.size())))
	var biggest: int = -1
	for _i in range(maxi(spawn_count, 0)):
		var c := Contacts.spawn_one(data)
		c.has_contact = false
		biggest = maxi(biggest, c.tier)

	# One of them is enormous.
	if not data.contacts.is_empty() and spawn_count > 0:
		var idx: int = data.rng.randi_range(0, data.contacts.size() - 1)
		var big: Contact = data.contacts[idx]
		big.tier = clampi(big.tier + 2, 0, Contacts.tier_ceiling(data))
		big.has_contact = false
		biggest = maxi(biggest, big.tier)

	var report: Dictionary = {
		"elapsed": elapsed,
		"efficiency": eff,
		"effective_time": effective_time,
		"tribute": tribute,
		"forgotten": forgotten,
		"spawned": maxi(spawn_count, 0),
		"biggest_tier": biggest,
		"pressure_before": before_pressure,
		"pressure_after": data.field_pressure,
		"contacts_before": before_contacts,
		"contacts_after": data.contacts.size(),
		"motes_gained": data.total_motes_earned - motes_before,
	}
	EventBus.dormancy_resolved.emit(report)
	return report
