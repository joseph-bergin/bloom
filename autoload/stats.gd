extends Node
## Derived stats, memoized on purchase count. Systems read these fields.

var cached_version: int = -1

# --- luminance ---
var lum_from_tree: float = 0.0
var shroud: float = 0.0

# --- burn ---
var damage: float = Constants.TURRET_DAMAGE_BASE
var fire_rate: float = Constants.TURRET_RATE_BASE
var crit_chance: float = 0.0
var crit_mult: float = Constants.CRIT_MULT_BASE
var projectile_count: int = 1

# --- reach ---
var turret_range: float = Constants.TURRET_RANGE_BASE
var pierce: int = 0
var chain: int = 0
var aim_assist: float = Constants.AIM_ASSIST_CONE

# --- root ---
var max_shields: int = Constants.START_SHIELDS
var mote_mult: float = 1.0
var ember_mult: float = 1.0

# --- shroud ---
var douse_drain: float = Constants.DOUSE_DRAIN
var douse_refill: float = Constants.DOUSE_REFILL

var spawn_rate_mult: float = 1.0

var _acc: Dictionary = {}
var _rules: Dictionary = {}

func has_rule(r: StringName) -> bool:
	return _rules.has(r)

func recompute(s: GameStateData) -> void:
	cached_version = s.purchase_version
	_acc = {}
	_rules = {}
	lum_from_tree = 0.0

	for key in s.purchased.keys():
		var rank: int = int(s.purchased[key])
		if rank <= 0:
			continue
		var n: TreeNode = TreeDB.get_node_def(StringName(str(key)))
		if n == null:
			continue
		lum_from_tree += n.lum_at(rank)
		_apply(n.effects, rank)

	_resolve()
	EventBus.stats_recomputed.emit()

func _apply(effects: Array, rank: int) -> void:
	for e in effects:
		if typeof(e) != TYPE_DICTIONARY:
			continue
		var eff: Dictionary = e
		var op: String = str(eff.get("op", "add"))
		if op == "rule":
			_rules[StringName(str(eff.get("rule", "")))] = true
			continue
		var stat: String = str(eff.get("stat", ""))
		if stat == "":
			continue
		var v: float = float(eff.get("value", 0.0))
		if op == "mul":
			_acc[stat] = float(_acc.get(stat, 1.0)) * pow(1.0 + v, float(rank))
		else:
			_acc[stat] = float(_acc.get(stat, 0.0)) + v * float(rank)

func _g(key: String, dflt: float) -> float:
	return float(_acc.get(key, dflt))

func _resolve() -> void:
	shroud = clampf(_g("shroud", 0.0), 0.0, Constants.SHROUD_CAP)

	damage = Constants.TURRET_DAMAGE_BASE * (1.0 + _g("damage_mult", 0.0)) * _g("damage_scale", 1.0)
	fire_rate = Constants.TURRET_RATE_BASE * (1.0 + _g("fire_rate_mult", 0.0))
	crit_chance = clampf(_g("crit_chance", 0.0), 0.0, 1.0)
	crit_mult = Constants.CRIT_MULT_BASE + _g("crit_mult", 0.0)
	projectile_count = 1 + int(_g("projectiles", 0.0))

	turret_range = Constants.TURRET_RANGE_BASE * (1.0 + _g("range_mult", 0.0))
	pierce = int(_g("pierce", 0.0))
	chain = int(_g("chain", 0.0))
	aim_assist = Constants.AIM_ASSIST_CONE * (1.0 + _g("aim_assist", 0.0))

	max_shields = Constants.START_SHIELDS + int(_g("shields", 0.0))
	mote_mult = _g("mote_mult", 1.0)
	ember_mult = _g("ember_mult", 1.0)

	douse_drain = maxf(Constants.DOUSE_DRAIN * (1.0 - _g("douse_efficiency", 0.0)), 0.02)
	douse_refill = Constants.DOUSE_REFILL * (1.0 + _g("douse_refill", 0.0))
	spawn_rate_mult = 1.0

	# --- keystones: rule changes with real drawbacks ---
	if has_rule(&"wildfire"):
		damage *= Constants.WILDFIRE_DAMAGE_MULT
	if has_rule(&"longshot"):
		turret_range *= Constants.LONGSHOT_RANGE_MULT
		fire_rate *= Constants.LONGSHOT_RATE_MULT
		pierce = maxi(pierce, 3)
	if has_rule(&"diaspora"):
		max_shields += Constants.DIASPORA_SHIELDS
		mote_mult *= Constants.DIASPORA_INCOME_MULT

func dps() -> float:
	return damage * fire_rate * float(projectile_count) \
		* (1.0 + crit_chance * (crit_mult - 1.0))
