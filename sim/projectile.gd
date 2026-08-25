class_name Projectile
extends RefCounted
## Travels and hits. No miss chance, no prediction.

var pos: Vector2 = Vector2.ZERO
var vel: Vector2 = Vector2.ZERO
var damage: float = 0.0
var life: float = Constants.PROJECTILE_LIFETIME
var pierce: int = 0          # extra contacts it may pass through
var chain: int = 0           # remaining jumps to a nearby contact
var crit: bool = false
var hit_ids: Array[int] = []

static func make(at: Vector2, dir: Vector2, dmg: float, is_crit: bool) -> Projectile:
	var p := Projectile.new()
	p.pos = at
	p.vel = dir.normalized() * Constants.PROJECTILE_SPEED
	p.damage = dmg
	p.crit = is_crit
	p.pierce = Stats.pierce
	p.chain = Stats.chain
	return p
