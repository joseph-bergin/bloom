class_name Contact
extends RefCounted

enum State { DRIFTING, AWARE, COMMITTED, TETHERED, FLEEING }

var id: int = 0
var bearing: float = 0.0        # radians, 0..TAU
var range_u: float = 0.0        # units from player, 0..FIELD_RADIUS
var drift: float = 0.0          # radians/sec, signed
var closing: float = 0.0        # units/sec, negative approaches
var tier: int = 0               # 0..7
var cascade: float = 0.0        # 0..1, progress toward next tier
var awareness: float = 0.0      # 0..1, how well it has resolved YOU
var state: State = State.DRIFTING
var is_hunter: bool = false
var is_blight_source: bool = false
var spawned_at: float = 0.0
var flee_started_at: float = -1.0

# Player knowledge — separate from truth. This is the whole design.
var has_contact: bool = false
var known_at: float = -1.0      # sim seconds of last update
var known_bearing: float = 0.0
var known_range: float = 0.0
var known_range_valid: bool = false   # false until Optics rank 4
var known_drift: float = 0.0
var known_closing: float = 0.0
var known_tier: int = 0         # may be wrong by +/-1
var known_awareness: float = 0.0
var resolved: bool = false      # exact truth known this instant

func true_position() -> Vector2:
	return Vector2(cos(bearing), sin(bearing)) * range_u

func to_dict() -> Dictionary:
	return {
		"id": id, "bearing": bearing, "range_u": range_u, "drift": drift,
		"closing": closing, "tier": tier, "cascade": cascade,
		"awareness": awareness, "state": int(state), "is_hunter": is_hunter,
		"is_blight_source": is_blight_source, "spawned_at": spawned_at,
		"flee_started_at": flee_started_at,
		"has_contact": has_contact, "known_at": known_at,
		"known_bearing": known_bearing, "known_range": known_range,
		"known_range_valid": known_range_valid, "known_drift": known_drift,
		"known_closing": known_closing, "known_tier": known_tier,
		"known_awareness": known_awareness, "resolved": resolved,
	}

static func from_dict(d: Dictionary) -> Contact:
	var c := Contact.new()
	c.id = int(d.get("id", 0))
	c.bearing = float(d.get("bearing", 0.0))
	c.range_u = float(d.get("range_u", 0.0))
	c.drift = float(d.get("drift", 0.0))
	c.closing = float(d.get("closing", 0.0))
	c.tier = int(d.get("tier", 0))
	c.cascade = float(d.get("cascade", 0.0))
	c.awareness = float(d.get("awareness", 0.0))
	c.state = int(d.get("state", 0)) as State
	c.is_hunter = bool(d.get("is_hunter", false))
	c.is_blight_source = bool(d.get("is_blight_source", false))
	c.spawned_at = float(d.get("spawned_at", 0.0))
	c.flee_started_at = float(d.get("flee_started_at", -1.0))
	c.has_contact = bool(d.get("has_contact", false))
	c.known_at = float(d.get("known_at", -1.0))
	c.known_bearing = float(d.get("known_bearing", 0.0))
	c.known_range = float(d.get("known_range", 0.0))
	c.known_range_valid = bool(d.get("known_range_valid", false))
	c.known_drift = float(d.get("known_drift", 0.0))
	c.known_closing = float(d.get("known_closing", 0.0))
	c.known_tier = int(d.get("known_tier", 0))
	c.known_awareness = float(d.get("known_awareness", 0.0))
	c.resolved = bool(d.get("resolved", false))
	return c
