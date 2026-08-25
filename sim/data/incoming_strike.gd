class_name IncomingStrike
extends RefCounted

var source_id: int = 0
var launched_at: float = 0.0
var arrives_at: float = 0.0
var bearing: float = 0.0
var detected: bool = false     # false unless Optics rank >= 6
var tier: int = 0
var from_tether: bool = false

func progress(t: float) -> float:
	var span: float = maxf(arrives_at - launched_at, 0.0001)
	return clampf((t - launched_at) / span, 0.0, 1.0)

func to_dict() -> Dictionary:
	return {"source_id": source_id, "launched_at": launched_at,
		"arrives_at": arrives_at, "bearing": bearing, "detected": detected,
		"tier": tier, "from_tether": from_tether}

static func from_dict(d: Dictionary) -> IncomingStrike:
	var s := IncomingStrike.new()
	s.source_id = int(d.get("source_id", 0))
	s.launched_at = float(d.get("launched_at", 0.0))
	s.arrives_at = float(d.get("arrives_at", 0.0))
	s.bearing = float(d.get("bearing", 0.0))
	s.detected = bool(d.get("detected", false))
	s.tier = int(d.get("tier", 0))
	s.from_tether = bool(d.get("from_tether", false))
	return s
