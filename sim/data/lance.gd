class_name Lance
extends RefCounted

var target_id: int = 0
var origin: Vector2 = Vector2.ZERO
var aim: Vector2 = Vector2.ZERO
var hit_chance: float = 1.0
var launched_at: float = 0.0
var arrives_at: float = 0.0
var target_tier: int = 0
var resolved: bool = false

func _init(p_target: int = 0, p_aim: Vector2 = Vector2.ZERO, p_chance: float = 1.0,
		p_t: float = 0.0, p_flight: float = 0.0, p_tier: int = 0) -> void:
	target_id = p_target
	aim = p_aim
	hit_chance = p_chance
	launched_at = p_t
	arrives_at = p_t + p_flight
	target_tier = p_tier

func progress(t: float) -> float:
	var span: float = maxf(arrives_at - launched_at, 0.0001)
	return clampf((t - launched_at) / span, 0.0, 1.0)

func position(t: float) -> Vector2:
	return origin.lerp(aim, progress(t))

func to_dict() -> Dictionary:
	return {"target_id": target_id, "aim_x": aim.x, "aim_y": aim.y,
		"hit_chance": hit_chance, "launched_at": launched_at,
		"arrives_at": arrives_at, "target_tier": target_tier}

static func from_dict(d: Dictionary) -> Lance:
	var l := Lance.new()
	l.target_id = int(d.get("target_id", 0))
	l.aim = Vector2(float(d.get("aim_x", 0.0)), float(d.get("aim_y", 0.0)))
	l.hit_chance = float(d.get("hit_chance", 1.0))
	l.launched_at = float(d.get("launched_at", 0.0))
	l.arrives_at = float(d.get("arrives_at", 0.0))
	l.target_tier = int(d.get("target_tier", 0))
	return l
