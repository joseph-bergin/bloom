extends Node
## Signal hub. Declarations only — no logic lives here.
## The sim emits; UI and audio subscribe. The sim never holds UI references.

# --- Contacts ---
signal contact_spawned(c: Contact)
signal contact_cascaded(c: Contact)
signal contact_resolved(c: Contact)
signal contact_committed(c: Contact)
signal contact_removed(id: int)

# --- Player action ---
signal sweep_fired(radius_max: float)
signal lance_launched(l: Lance)
signal lance_hit(c: Contact, motes: float, facets: float, at: Vector2)
signal lance_missed(l: Lance, at: Vector2)

# --- Threat ---
signal witness_rolled(p: float, witnessed: bool)
signal hunter_spawned(c: Contact)
signal hunter_cleared()
signal strike_incoming(s: IncomingStrike)
signal strike_landed(s: IncomingStrike)
signal strike_dispersed(s: IncomingStrike)
signal redundancy_lost(remaining: int)
signal run_ended(reason: String)

# --- Tethers ---
signal tether_established(t: Tether)
signal tether_warned(t: Tether, level: int)
signal tether_reasserted(t: Tether)
signal tether_fired(t: Tether)
signal tether_released(t: Tether)

# --- Blight ---
signal blight_seeded(node_ids: PackedStringArray, source_id: int)
signal blight_cleared(source_id: int)

# --- Economy / tree ---
signal node_purchased(node_id: StringName, rank: int)
signal node_refunded(node_id: StringName)
signal respec_performed()
signal currency_changed()
signal stats_recomputed()

# --- Meta ---
signal ember_spent(gained: float, cycle: int)
signal region_unlocked(region: StringName)
signal dormancy_resolved(report: Dictionary)
signal cold_rank_changed(rank: int)
signal game_loaded()
signal log_line(text: String, kind: String)

## Convenience so systems don't hand-roll log formatting.
func log_msg(text: String, kind: String = "info") -> void:
	log_line.emit(text, kind)
