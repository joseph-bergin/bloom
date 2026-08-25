class_name Backlight
extends RefCounted
## Every detonation rolls to see whether something else saw the flash.

static func flash_for(tier: int) -> float:
	return Constants.TRANSIENT_DETONATION * pow(float(tier) + 1.0, Constants.TRANSIENT_DETONATION_EXP)

## Shown in the targeting UI BEFORE the player commits. The gamble must be legible.
static func witness_chance(data: GameStateData, tier: int) -> float:
	var flash: float = flash_for(tier)
	var l: float = data.luminance_effective()
	return clampf(
		(Constants.BACKLIGHT_FLOOR + flash * l * Constants.BACKLIGHT_SCALE) * Stats.backlight_mult,
		Constants.BACKLIGHT_FLOOR, Constants.BACKLIGHT_CAP)

static func roll(data: GameStateData, tier: int, at: Vector2) -> bool:
	# The probability is read off the board the player committed against, so
	# it must be computed before the flash inflates their own luminance.
	# Doing it the other way round makes the displayed odds a lie.
	var p: float = witness_chance(data, tier)
	Luminance.add_transient(data, flash_for(tier))
	var witnessed: bool = data.rng.randf() < p
	EventBus.witness_rolled.emit(p, witnessed)
	if witnessed:
		var h := spawn_hunter(data, tier, at)
		data.record_cause("snuff of T%d witnessed (p=%.2f) -> hunter %d" % [tier, p, h.id])
	return witnessed

static func spawn_hunter(data: GameStateData, target_tier: int, near: Vector2) -> Contact:
	var c := Contact.new()
	c.id = data.next_contact_id
	data.next_contact_id += 1
	c.is_hunter = true
	# It knows roughly where the flash came from.
	c.bearing = fposmod(near.angle() + data.rng.randf_range(-0.35, 0.35), TAU)
	c.range_u = Constants.FIELD_RADIUS * Constants.HUNTER_SPAWN_RANGE
	c.drift = data.rng.randf_range(-0.01, 0.01)
	c.closing = Constants.HUNTER_CLOSING
	c.tier = clampi(maxi(Constants.HUNTER_TIER_MIN, data.player_tier() - 1),
		0, Contacts.tier_ceiling(data))
	c.awareness = Constants.HUNTER_AWARENESS
	c.spawned_at = data.t
	data.contacts.append(c)
	EventBus.contact_spawned.emit(c)
	EventBus.hunter_spawned.emit(c)
	EventBus.log_msg("Backlight. Something saw the flash and is coming.", "bad")
	return c

static func tick(_data: GameStateData, _delta: float) -> void:
	pass  # Backlight is event-driven; the hook exists to keep tick order literal.
