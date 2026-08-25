class_name Contact
extends RefCounted
## A red square that moves inward. No AI, no evasion, no targeting logic.

var pos: Vector2 = Vector2.ZERO
var vel: Vector2 = Vector2.ZERO
var hp: float = 0.0
var max_hp: float = 0.0
var tier: int = 0
var radius: float = 6.0
var is_boss: bool = false
var flash: float = 0.0

static func make(tier_v: int, at: Vector2, speed: float) -> Contact:
	var c := Contact.new()
	c.tier = tier_v
	c.pos = at
	c.vel = -at.normalized() * speed
	c.max_hp = Constants.HP_BASE * pow(Constants.HP_TIER_MULT, float(tier_v))
	c.hp = c.max_hp
	c.radius = Constants.RADIUS_BASE + float(tier_v) * Constants.RADIUS_TIER_STEP
	return c

func motes() -> float:
	var base: float = Constants.MOTE_BASE * pow(Constants.MOTE_TIER_MULT, float(tier))
	return base * Stats.mote_mult * (Constants.BOSS_MOTE_MULT if is_boss else 1.0)

static func make_boss(tier_v: int, at: Vector2, speed: float) -> Contact:
	var c := make(tier_v, at, speed * Constants.BOSS_DRIFT_MULT)
	c.is_boss = true
	c.max_hp *= Constants.BOSS_HP_MULT
	c.hp = c.max_hp
	c.radius *= Constants.BOSS_RADIUS_MULT
	return c

func to_dict() -> Dictionary:
	return {"x": pos.x, "y": pos.y, "vx": vel.x, "vy": vel.y,
		"hp": hp, "max_hp": max_hp, "tier": tier, "radius": radius,
		"is_boss": is_boss}

static func from_dict(d: Dictionary) -> Contact:
	var c := Contact.new()
	c.pos = Vector2(float(d.get("x", 0.0)), float(d.get("y", 0.0)))
	c.vel = Vector2(float(d.get("vx", 0.0)), float(d.get("vy", 0.0)))
	c.hp = float(d.get("hp", 1.0))
	c.max_hp = float(d.get("max_hp", 1.0))
	c.tier = int(d.get("tier", 0))
	c.radius = float(d.get("radius", 6.0))
	c.is_boss = bool(d.get("is_boss", false))
	return c
