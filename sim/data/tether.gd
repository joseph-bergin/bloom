class_name Tether
extends RefCounted

var contact_id: int = 0
var slack: float = 0.0
var established_at: float = 0.0
var last_facet_at: float = 0.0
var warn_level: int = 0        # 0 none, 1 at 0.75, 2 at 0.9
var tier: int = 0

func to_dict() -> Dictionary:
	return {"contact_id": contact_id, "slack": slack,
		"established_at": established_at, "last_facet_at": last_facet_at,
		"warn_level": warn_level, "tier": tier}

static func from_dict(d: Dictionary) -> Tether:
	var t := Tether.new()
	t.contact_id = int(d.get("contact_id", 0))
	t.slack = float(d.get("slack", 0.0))
	t.established_at = float(d.get("established_at", 0.0))
	t.last_facet_at = float(d.get("last_facet_at", 0.0))
	t.warn_level = int(d.get("warn_level", 0))
	t.tier = int(d.get("tier", 0))
	return t
