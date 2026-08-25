class_name Turret
extends RefCounted
## Fires along the direction the player is aiming, whenever anything is in
## range. Choosing what to point at is the game's active decision — the
## turret handles the trigger, the player handles the target.

static func tick(s: GameStateData, delta: float) -> void:
	s.locked_id = 0
	var target: Contact = acquire(s)
	if target != null:
		s.locked_id = target.get_instance_id()

	# Both of these walk the whole contact list, so they are answered once
	# per tick rather than once per shot. At a few hundred contacts and a
	# high fire rate the difference is the whole frame.
	var has_target: bool = target != null or anything_in_range(s)
	s.fire_timer -= delta
	if not has_target:
		s.fire_timer = maxf(s.fire_timer, 0.0)
		return
	var interval: float = 1.0 / maxf(Stats.fire_rate, 0.01)
	# A pathological fire rate must not spin here for thousands of shots.
	var budget: int = 24
	while s.fire_timer <= 0.0 and budget > 0:
		budget -= 1
		s.fire_timer += interval
		_fire(s, target)
	if budget <= 0:
		s.fire_timer = maxf(s.fire_timer, 0.0)

## The contact the turret will steer onto: nearest to the aim line, within
## the assist cone and within range. Pointing at empty dark hits nothing.
static func acquire(s: GameStateData) -> Contact:
	if s.aim_auto:
		return nearest(s)
	var range_sq: float = Stats.turret_range * Stats.turret_range
	var best: Contact = null
	var best_score: float = INF
	for c in s.contacts:
		var d_sq: float = c.pos.length_squared()
		if d_sq > range_sq:
			continue
		var dir: Vector2 = c.pos.normalized()
		var off: float = absf(dir.angle_to(s.aim))
		# A big contact is easier to point at than a small one.
		var forgiveness: float = Stats.aim_assist + atan(c.radius / maxf(c.pos.length(), 1.0))
		if off > forgiveness:
			continue
		# Prefer what the player is pointing most directly at, then what is
		# closest — so a near threat wins a near-tie.
		var score: float = off + sqrt(d_sq) / maxf(Stats.turret_range, 1.0) * 0.15
		if score < best_score:
			best_score = score
			best = c
	return best

## Any contact in range, ignoring aim. Used for the auto fallback and to
## decide whether the turret has anything to shoot at.
static func nearest(s: GameStateData) -> Contact:
	var best: Contact = null
	var best_d: float = Stats.turret_range * Stats.turret_range
	for c in s.contacts:
		var d: float = c.pos.length_squared()
		if d <= best_d:
			best_d = d
			best = c
	return best

static func anything_in_range(s: GameStateData) -> bool:
	var range_sq: float = Stats.turret_range * Stats.turret_range
	for c in s.contacts:
		if c.pos.length_squared() <= range_sq:
			return true
	return false

## Caller guarantees something is in range. Fires where the player points,
## hit or miss.
static func _fire(s: GameStateData, target: Contact) -> void:
	var base_dir: Vector2 = target.pos.normalized() if target != null else s.aim
	if base_dir == Vector2.ZERO:
		base_dir = Vector2.RIGHT
	var count: int = Stats.projectile_count
	var spread: float = 0.10
	for i in range(count):
		var offset: float = 0.0 if count == 1 else (float(i) - float(count - 1) * 0.5) * spread
		var dir: Vector2 = base_dir.rotated(offset)
		var is_crit: bool = s.rng.randf() < Stats.crit_chance
		var dmg: float = Stats.damage * (Stats.crit_mult if is_crit else 1.0)
		s.projectiles.append(Projectile.make(Vector2.ZERO, dir, dmg, is_crit))

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
	var best_d: float = 165.0 * 165.0
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
	Levels.on_kill(s, c)
	EventBus.contact_killed.emit(c.tier, c.pos, gained)
