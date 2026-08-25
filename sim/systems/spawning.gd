class_name Spawning
extends RefCounted
## Everything here keys off luminance. That is the whole design.

static func spawn_interval(l: float) -> float:
	var base: float = Constants.SPAWN_INTERVAL_BASE / (1.0 + l / Constants.SPAWN_LUM_SCALE)
	if Stats.has_rule(&"cinder"):
		# Below the threshold nothing spawns at all; above it, twice as fast.
		if l < Constants.CINDER_THRESHOLD:
			return INF
		base /= Constants.CINDER_SPAWN_MULT
	return base / maxf(Stats.spawn_rate_mult
		* Levels.spawn_scalar(GameState.s.level), 0.01)

static func max_tier(l: float) -> int:
	return clampi(int(floor(l / Constants.TIER_LUM_STEP)), 0, Constants.MAX_TIER)

static func drift_speed(l: float) -> float:
	return Constants.DRIFT_BASE + l * Constants.DRIFT_LUM_SCALE

## How much harder the field is than at zero luminance. Shown in the HUD so
## the causation is impossible to miss.
static func spawn_pressure(l: float) -> float:
	var iv: float = spawn_interval(l)
	if is_inf(iv):
		return 0.0
	return Constants.SPAWN_INTERVAL_BASE / iv

static func tick(s: GameStateData, delta: float) -> void:
	# The boss fight and the breather after it are the level's punctuation;
	# nothing new wanders in during either.
	if s.phase != GameStateData.Phase.FIGHTING:
		return
	var l: float = Luminance.effective(s)
	var iv: float = spawn_interval(l)
	if is_inf(iv):
		return
	s.spawn_timer -= delta
	if s.spawn_timer > 0.0:
		return
	s.spawn_timer += iv
	if s.contacts.size() >= Constants.MAX_CONTACTS:
		return
	spawn_one(s, l)

static func spawn_one(s: GameStateData, l: float) -> Contact:
	var a: float = s.rng.randf() * TAU
	var at := Vector2(cos(a), sin(a)) * Constants.FIELD_RADIUS
	var c := Contact.make(roll_tier(s, l), at, drift_speed(l))
	s.contacts.append(c)
	EventBus.contact_spawned.emit(c)
	return c

## Uniform over 0..max_tier, biased toward the top third.
static func roll_tier(s: GameStateData, l: float) -> int:
	var top: int = max_tier(l)
	if top <= 0:
		return 0
	if s.rng.randf() < Constants.TIER_TOP_THIRD_BIAS:
		return s.rng.randi_range(int(ceil(float(top) * 2.0 / 3.0)), top)
	return s.rng.randi_range(0, top)
