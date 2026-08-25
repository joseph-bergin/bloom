class_name Ember
extends RefCounted
## Everything ends. But an ember drifted out before the end.

const REGIONS: Array[StringName] = [&"choir", &"lattice", &"the_cold"]

static func embers_gained(data: GameStateData) -> float:
	return floor(pow(data.total_motes_earned / Constants.EMBER_MOTE_DIVISOR, Constants.EMBER_EXP)) \
		+ data.facets * Constants.EMBER_FACET_VALUE

## Voluntary ember at a good moment must always beat being forced into one.
static func voluntary_bonus(data: GameStateData) -> float:
	if data.run_over:
		return 0.0
	return maxf(embers_gained(data) * 0.25, 1.0)

static func total_payout(data: GameStateData) -> float:
	return embers_gained(data) + voluntary_bonus(data)

static func next_region(data: GameStateData) -> StringName:
	for r in REGIONS:
		if not data.unlocked_regions.has(String(r)):
			return r
	return &""

static func commit(data: GameStateData) -> Dictionary:
	var gained: float = total_payout(data)
	var region: StringName = next_region(data)
	var report: Dictionary = {
		"embers": gained,
		"cycle": data.ember_count + 1,
		"region": String(region),
		"total_motes": data.total_motes_earned,
		"reason": data.run_end_reason if data.run_over else "Voluntary.",
		"causal": data.causal_log.duplicate(),
	}

	# --- carried across the ember ---
	var embers: float = data.embers + gained
	var ember_count: int = data.ember_count + 1
	var regions: PackedStringArray = data.unlocked_regions.duplicate()
	if region != &"" and not regions.has(String(region)):
		regions.append(String(region))
	var cold: int = data.cold_rank
	var flags: Dictionary = {}
	for k in data.flags.keys():
		if str(k).begins_with("meta_"):
			flags[k] = data.flags[k]

	# --- everything else ends ---
	data.t = 0.0
	data.motes = 0.0
	data.signal_c = 0.0
	data.facets = 0.0
	data.total_motes_earned = 0.0
	data.contacts = []
	data.lances = []
	data.incoming = []
	data.tethers = []
	data.sweeps = []
	data.blighted_nodes = PackedStringArray()
	data.blight_sources = PackedInt32Array()
	data.purchased = {}
	data.purchase_version += 1
	data.field_pressure = 0.0
	data.spawn_timer = 0.0
	data.passive_timer = 0.0
	data.sweep_cooldown = 0.0
	data.miss_markers = []
	data.causal_log = []
	data.next_contact_id = 1
	data.run_over = false
	data.run_end_reason = ""

	data.embers = embers
	data.ember_count = ember_count
	data.unlocked_regions = regions
	data.cold_rank = cold
	data.flags = flags
	data.redundancy = Stats.max_redundancy

	EventBus.ember_spent.emit(gained, ember_count)
	if region != &"":
		EventBus.region_unlocked.emit(region)
		EventBus.log_msg("A new region catches, deeper in the dark: %s." % String(region), "good")
	return report

static func cold_unlocked(data: GameStateData) -> bool:
	return data.ember_count >= Constants.COLD_UNLOCK_EMBERS

static func cold_cost(rank: int) -> float:
	return 4.0 * pow(1.8, float(rank))

static func raise_cold(data: GameStateData) -> bool:
	if not cold_unlocked(data):
		return false
	var cost: float = cold_cost(data.cold_rank)
	if data.embers < cost:
		return false
	data.embers -= cost
	data.cold_rank += 1
	data.purchase_version += 1
	EventBus.cold_rank_changed.emit(data.cold_rank)
	EventBus.log_msg("The Cold deepens. Nothing here will burn as brightly.", "info")
	return true

## The only stable configuration is an empty one.
static func is_ending(data: GameStateData) -> bool:
	return data.cold_rank >= Constants.TIER_MAX and data.contacts.is_empty()
