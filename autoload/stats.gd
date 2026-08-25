extends Node
## Derived stat computation, memoized on purchase version.
## Systems read these fields; nothing else recomputes them.

var cached_version: int = -1

# --- Luminance -----------------------------------------------------------
var structural_from_tree: float = 0.0
var lum_mult: float = 1.0
var shroud: float = 0.0
var transient_tau: float = Constants.TRANSIENT_TAU_BASE

# --- Sensing -------------------------------------------------------------
var passive_range: float = Constants.PASSIVE_RANGE_BASE
var passive_interval: float = Constants.PASSIVE_INTERVAL_BASE
var bearing_precision: float = 1.0
var optics_grade: int = 0            # integer "Optics rank" for gates 4 and 6
var tier_id_exact: bool = false
var tracking: float = 1.0            # divides staleness penalty and uncertainty

# --- Sweep ---------------------------------------------------------------
var sweep_radius: float = Constants.SWEEP_RADIUS_BASE
var sweep_radius_mult: float = 1.0
var sweep_speed: float = Constants.SWEEP_RING_SPEED
var sweep_cooldown: float = Constants.SWEEP_COOLDOWN_BASE

# --- Lance ---------------------------------------------------------------
var lance_speed: float = Constants.LANCE_SPEED_BASE
var min_hit_chance: float = Constants.MIN_HIT_CHANCE_BASE
var salvo: int = 1
var chain_chance: float = 0.0
var backlight_mult: float = 1.0

# --- Economy -------------------------------------------------------------
var yield_mult: float = 1.0
var signal_mult: float = 1.0
var facet_mult: float = 1.0
var income_mult: float = 1.0
var cost_mult: float = 1.0

# --- Tether --------------------------------------------------------------
var tether_capacity: int = Constants.SENSOR_CAPACITY_BASE
var tether_stability: float = 0.0
var tribute_mult: float = 1.0
var reassert_cost_mult: float = 1.0

# --- Redundancy ----------------------------------------------------------
var max_redundancy: int = Constants.REDUNDANCY_BASE
var blight_resist: float = 0.0
var strike_mitigation: float = 0.0   # chance an incoming strike is absorbed

# --- Cognition -----------------------------------------------------------
var dormancy_efficiency: float = Constants.DORMANCY_EFFICIENCY_BASE
var auto_sweep: bool = false
var auto_lance: bool = false
var auto_tether: bool = false
var triage_slots: int = 0

var _rules: Dictionary = {}
var _acc: Dictionary = {}

func has_rule(r: StringName) -> bool:
	return _rules.has(r)

func rules() -> Array:
	return _rules.keys()

func recompute(data: GameStateData) -> void:
	cached_version = data.purchase_version
	_acc = {}
	_rules = {}

	var blighted: Dictionary = {}
	for b in data.blighted_nodes:
		blighted[StringName(b)] = true

	structural_from_tree = 0.0
	for key in data.purchased.keys():
		var id := StringName(str(key))
		var rank: int = int(data.purchased[key])
		if rank <= 0:
			continue
		var n: TreeNode = TreeDB.get_node_def(id)
		if n == null:
			continue
		# Blighted nodes still cost you their luminance; you built them.
		# Only their effects are suspended. Growth you cannot use still burns.
		structural_from_tree += n.lum_at(rank)
		if blighted.has(id):
			continue
		TreeEffects.apply(n.effects, rank, _acc, _rules)

	_resolve(data)
	EventBus.stats_recomputed.emit()

func _g(key: String, dflt: float) -> float:
	return float(_acc.get(key, dflt))

func _resolve(data: GameStateData) -> void:
	# --- luminance ---
	lum_mult = _g("lum_mult", 1.0)
	if has_rule(&"nullwake"):
		lum_mult *= 0.4
	structural_from_tree *= lum_mult
	shroud = clampf(_g("shroud", 0.0), 0.0, Constants.SHROUD_CAP)
	transient_tau = maxf(Constants.TRANSIENT_TAU_BASE - _g("transient_decay", 0.0),
		Constants.TRANSIENT_TAU_MIN)

	# --- sensing ---
	optics_grade = int(_g("optics_grade", 0.0))
	passive_range = (Constants.PASSIVE_RANGE_BASE + _g("passive_range", 0.0)) \
		* _g("passive_range_mult", 1.0)
	if has_rule(&"long_ear"):
		passive_range *= 3.0
		optics_grade = maxi(optics_grade, Constants.OPTICS_RANK_RANGE_DATA)
	passive_interval = maxf(
		Constants.PASSIVE_INTERVAL_BASE - _g("passive_speed", 0.0),
		Constants.PASSIVE_INTERVAL_MIN)
	bearing_precision = maxf(1.0 + _g("bearing_precision", 0.0), 0.05)
	tier_id_exact = has_rule(&"long_ear") or _g("tier_id", 0.0) >= 1.0
	tracking = maxf(1.0 + _g("tracking", 0.0), 0.05)

	# --- sweep ---
	sweep_radius_mult = _g("sweep_radius_mult", 1.0) * (1.0 + _g("sweep_radius", 0.0))
	sweep_radius = Constants.SWEEP_RADIUS_BASE * sweep_radius_mult
	sweep_speed = Constants.SWEEP_RING_SPEED * _g("sweep_speed_mult", 1.0)
	sweep_cooldown = maxf(Constants.SWEEP_COOLDOWN_BASE - _g("sweep_cooldown", 0.0), 1.0)
	if has_rule(&"lighthouse"):
		# No cooldown, whole field, and everything it touches notices.
		sweep_cooldown = 0.0
		sweep_radius = Constants.FIELD_RADIUS
		sweep_radius_mult = Constants.LIGHTHOUSE_TRANSIENT_MULT

	# --- lance ---
	lance_speed = Constants.LANCE_SPEED_BASE * _g("lance_speed_mult", 1.0)
	min_hit_chance = clampf(Constants.MIN_HIT_CHANCE_BASE + _g("min_hit_chance", 0.0), 0.0, 1.0)
	salvo = 1 + int(_g("salvo", 0.0))
	chain_chance = clampf(_g("chain_chance", 0.0), 0.0, 1.0)
	backlight_mult = _g("backlight_mult", 1.0)
	if has_rule(&"overburn"):
		backlight_mult *= 3.0

	# --- economy ---
	income_mult = _g("income_mult", 1.0)
	if has_rule(&"diaspora"):
		income_mult *= 0.6
	if data.cold_rank > 0:
		income_mult *= pow(1.0 - Constants.COLD_INCOME_PENALTY, float(data.cold_rank))
	yield_mult = _g("yield_mult", 1.0) * income_mult
	if has_rule(&"wildfire"):
		yield_mult *= 4.0
	signal_mult = _g("signal_mult", 1.0) * income_mult
	facet_mult = _g("facet_mult", 1.0)
	cost_mult = maxf(_g("cost_mult", 1.0), 0.1)

	# --- tether ---
	tether_capacity = Constants.SENSOR_CAPACITY_BASE + int(_g("tether_capacity", 0.0))
	tether_stability = _g("tether_stability", 0.0)
	tribute_mult = _g("tribute_mult", 1.0) * income_mult
	if has_rule(&"hostage_doctrine"):
		tribute_mult *= 2.0
	reassert_cost_mult = maxf(_g("reassert_cost_mult", 1.0), 0.1)

	# --- redundancy ---
	max_redundancy = Constants.REDUNDANCY_BASE + int(_g("max_redundancy", 0.0))
	if has_rule(&"diaspora"):
		max_redundancy += 3
	blight_resist = clampf(_g("blight_resist", 0.0), 0.0, 0.9)
	strike_mitigation = clampf(_g("strike_mitigation", 0.0), 0.0, 0.75)

	# --- cognition ---
	dormancy_efficiency = clampf(
		Constants.DORMANCY_EFFICIENCY_BASE + _g("dormancy_efficiency", 0.0),
		0.0, Constants.DORMANCY_EFFICIENCY_MAX)
	auto_sweep = has_rule(&"auto_sweep") or has_rule(&"autarch")
	auto_lance = has_rule(&"auto_lance") or has_rule(&"autarch")
	auto_tether = has_rule(&"auto_tether") or has_rule(&"autarch")
	triage_slots = int(_g("triage_slots", 0.0)) + (4 if has_rule(&"autarch") else 0)

	data.sensor_capacity = tether_capacity

func can_sweep() -> bool:
	return not has_rule(&"nullwake")

func manual_targeting_allowed() -> bool:
	return not has_rule(&"autarch")

func range_data_available() -> bool:
	return optics_grade >= Constants.OPTICS_RANK_RANGE_DATA

func strike_detection_available() -> bool:
	return optics_grade >= Constants.OPTICS_RANK_STRIKE_DETECT
