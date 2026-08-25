class_name Levels
extends RefCounted
## Levels give the run visible chapters. Kill the quota, kill the boss, the
## level is over and it says so. Without this the run just continues until
## you happen to die, which reads as nothing happening.

## Set once when the level begins, from how fast the field is spawning right
## then. Being brighter means more to kill, not a shorter level.
static func compute_quota(s: GameStateData) -> int:
	var iv: float = Spawning.spawn_interval(s.effective_luminance())
	if is_inf(iv) or iv <= 0.0:
		return int(Constants.LEVEL_QUOTA_MIN)
	var n: float = Constants.LEVEL_SECONDS / iv
	n *= 1.0 + float(s.level - 1) * Constants.LEVEL_QUOTA_STEP
	return int(clampf(n, Constants.LEVEL_QUOTA_MIN, Constants.LEVEL_QUOTA_MAX))

static func quota(s: GameStateData) -> int:
	return maxi(s.level_quota, 1)

## How long a level may run before the boss arrives anyway.
static func time_limit() -> float:
	return Constants.LEVEL_SECONDS * Constants.LEVEL_TIME_LIMIT

static func time_left(s: GameStateData) -> float:
	return maxf(time_limit() - s.level_time, 0.0)

static func progress(s: GameStateData) -> float:
	return clampf(float(s.level_kills) / float(quota(s)), 0.0, 1.0)

## Levels add pressure of their own, so the run escalates even if the player
## buys nothing. Luminance is still the bigger term — it has to stay the
## thing the player feels responsible for.
static func spawn_scalar(level: int) -> float:
	return 1.0 + float(level - 1) * Constants.LEVEL_SPAWN_SCALE

static func boss_tier(s: GameStateData) -> int:
	var from_light: int = Spawning.max_tier(s.effective_luminance())
	var from_level: int = int(floor(float(s.level - 1) * Constants.BOSS_TIER_STEP))
	return clampi(maxi(from_light, from_level) + 1, 1, Constants.MAX_TIER)

## Worth roughly what the level's boss is worth, so the reward tracks the
## difficulty rather than the level counter.
static func clear_bonus(s: GameStateData) -> float:
	var tier: float = float(boss_tier(s))
	return Constants.MOTE_BASE * pow(Constants.MOTE_TIER_MULT, tier) \
		* Constants.LEVEL_CLEAR_MULT * Stats.mote_mult

static func tick(s: GameStateData, delta: float) -> void:
	match s.phase:
		GameStateData.Phase.FIGHTING:
			s.level_time += delta
			if s.level_kills >= quota(s) or s.level_time >= time_limit():
				_summon_boss(s)
		GameStateData.Phase.BOSS:
			if s.boss() == null:
				_clear_level(s)
		GameStateData.Phase.CLEARED:
			s.clear_timer -= delta
			if s.clear_timer <= 0.0:
				_begin_level(s)

static func on_kill(s: GameStateData, c: Contact) -> void:
	if c.is_boss:
		return
	if s.phase == GameStateData.Phase.FIGHTING:
		s.level_kills += 1

static func _summon_boss(s: GameStateData) -> void:
	s.phase = GameStateData.Phase.BOSS
	var a: float = s.rng.randf() * TAU
	var at := Vector2(cos(a), sin(a)) * Constants.FIELD_RADIUS
	var b := Contact.make_boss(boss_tier(s), at,
		Spawning.drift_speed(s.effective_luminance()))
	# Past the tier cap the boss keeps growing on level alone, so there is
	# always a wall ahead however strong the player gets.
	var over: int = maxi(s.level - 1, 0)
	b.max_hp *= pow(Constants.BOSS_LEVEL_HP_GROWTH, float(over))
	b.hp = b.max_hp
	s.contacts.append(b)
	s.boss_id = b.get_instance_id()
	EventBus.contact_spawned.emit(b)
	EventBus.boss_spawned.emit(b, s.level)

static func _clear_level(s: GameStateData) -> void:
	s.boss_id = 0
	s.phase = GameStateData.Phase.CLEARED
	s.clear_timer = Constants.LEVEL_CLEAR_PAUSE
	var bonus: float = clear_bonus(s)
	s.motes += bonus
	s.total_motes_this_run += bonus
	# The field empties for the breather, so the win is legible.
	s.contacts.clear()
	s.projectiles.clear()
	EventBus.level_cleared.emit(s.level, bonus)

static func _begin_level(s: GameStateData) -> void:
	s.level += 1
	s.best_level = maxi(s.best_level, s.level)
	s.level_kills = 0
	s.level_quota = compute_quota(s)
	s.level_time = 0.0
	s.phase = GameStateData.Phase.FIGHTING
	s.spawn_timer = 0.0
	EventBus.level_started.emit(s.level)

## The boss reaching you costs a shield and comes straight back. The level
## does NOT advance — if it did, a build with no damage at all could walk
## through every level by paying shields, and damage would buy nothing.
## This is the gate that makes the offence branches worth anything.
static func boss_breached(s: GameStateData) -> void:
	s.boss_id = 0
	EventBus.boss_breached.emit(s.level)
	if s.shields > 0:
		_summon_boss(s)

static func reset(s: GameStateData) -> void:
	# Record how far this run got before wiping it — that is the score the
	# player is actually chasing.
	s.best_level = maxi(s.best_level, s.level)
	s.level = 1
	s.level_kills = 0
	s.phase = GameStateData.Phase.FIGHTING
	s.clear_timer = 0.0
	s.boss_id = 0
	s.level_time = 0.0
	s.level_quota = compute_quota(s)
