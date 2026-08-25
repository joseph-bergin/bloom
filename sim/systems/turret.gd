class_name Turret
extends RefCounted
## Auto-targets the nearest contact within range. Fires on a timer.

static func tick(s: GameStateData, delta: float) -> void:
	s.fire_timer -= delta
	var interval: float = 1.0 / maxf(Stats.fire_rate, 0.01)
	while s.fire_timer <= 0.0:
		s.fire_timer += interval
		if not _fire(s):
			# Nothing in range — do not bank shots against an empty field.
			s.fire_timer = maxf(s.fire_timer, 0.0)
			return

static func nearest(s: GameStateData) -> Contact:
	var best: Contact = null
	var best_d: float = Stats.turret_range * Stats.turret_range
	for c in s.contacts:
		var d: float = c.pos.length_squared()
		if d <= best_d:
			best_d = d
			best = c
	return best

static func _fire(s: GameStateData) -> bool:
	var target: Contact = nearest(s)
	if target == null:
		return false
	var base_dir: Vector2 = target.pos.normalized()
	var count: int = Stats.projectile_count
	# Extra projectiles fan out around the aim line rather than stacking.
	var spread: float = 0.10
	for i in range(count):
		var offset: float = 0.0 if count == 1 else (float(i) - float(count - 1) * 0.5) * spread
		var dir: Vector2 = base_dir.rotated(offset)
		var is_crit: bool = s.rng.randf() < Stats.crit_chance
		var dmg: float = Stats.damage * (Stats.crit_mult if is_crit else 1.0)
		s.projectiles.append(Projectile.make(Vector2.ZERO, dir, dmg, is_crit))
	return true

static func move_projectiles(s: GameStateData, delta: float) -> void:
	if s.projectiles.is_empty():
		return
	var keep: Array[Projectile] = []
	for p in s.projectiles:
		p.pos += p.vel * delta
		p.life -= delta
		if p.life <= 0.0 or p.pos.length() > Constants.FIELD_RADIUS * 1.15:
			continue
		if _collide(s, p):
			continue
		keep.append(p)
	s.projectiles = keep

## Returns true if the projectile is spent.
static func _collide(s: GameStateData, p: Projectile) -> bool:
	for c in s.contacts:
		var id: int = c.get_instance_id()
		if p.hit_ids.has(id):
			continue
		if p.pos.distance_squared_to(c.pos) > c.radius * c.radius:
			continue
		p.hit_ids.append(id)
		_damage(s, c, p.damage)
		if p.chain > 0:
			p.chain -= 1
			var next: Contact = _nearest_other(s, c.pos, p.hit_ids)
			if next != null:
				p.vel = (next.pos - p.pos).normalized() * Constants.PROJECTILE_SPEED
				return false
		if p.pierce > 0:
			p.pierce -= 1
			return false
		return true
	return false

static func _nearest_other(s: GameStateData, from: Vector2, exclude: Array[int]) -> Contact:
	var best: Contact = null
	var best_d: float = 240.0 * 240.0
	for c in s.contacts:
		if exclude.has(c.get_instance_id()):
			continue
		var d: float = from.distance_squared_to(c.pos)
		if d < best_d:
			best_d = d
			best = c
	return best

static func _damage(s: GameStateData, c: Contact, amount: float) -> void:
	c.hp -= amount
	if c.hp > 0.0:
		return
	var gained: float = c.motes()
	s.motes += gained
	s.total_motes_this_run += gained
	s.contacts.erase(c)
	EventBus.contact_killed.emit(c.tier, c.pos, gained)
