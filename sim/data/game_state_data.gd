class_name GameStateData
extends RefCounted

var t: float = 0.0
var motes: float = 0.0
var signal_c: float = 0.0
var facets: float = 0.0
var embers: float = 0.0
var ember_count: int = 0

var luminance_structural: float = 0.0
var luminance_transient: float = 0.0

var redundancy: int = 1
var sensor_capacity: int = 3

var contacts: Array[Contact] = []
var lances: Array[Lance] = []
var incoming: Array[IncomingStrike] = []
var tethers: Array[Tether] = []
var sweeps: Array[SweepRing] = []
var blighted_nodes: PackedStringArray = []
var blight_sources: PackedInt32Array = []

var purchased: Dictionary = {}      # node_id: String -> rank: int
var purchase_version: int = 0       # bumped on any purchase; Stats memo key
var field_pressure: float = 0.0
var total_motes_earned: float = 0.0
var flags: Dictionary = {}

# --- Runtime bookkeeping (not player-facing) -----------------------------
var next_contact_id: int = 1
var spawn_timer: float = 0.0
var passive_timer: float = 0.0
var sweep_cooldown: float = 0.0
var cold_rank: int = 0
var run_over: bool = false
var run_end_reason: String = ""
var unlocked_regions: PackedStringArray = []
var triage_rules: Array = []        # Array[Dictionary]
var auto_flags: Dictionary = {}
var miss_markers: Array = []        # Array[Dictionary] {pos, until}
var last_real_time: float = 0.0
var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var causal_log: Array = []          # Array[Dictionary] for PostRunSummary

func luminance_effective() -> float:
	var shroud: float = clampf(Stats.shroud, 0.0, Constants.SHROUD_CAP)
	if Stats.has_rule(&"cinder") and (luminance_structural * (1.0 - shroud) + luminance_transient) < 20.0:
		pass  # Cinder does not change L, only detectability. See Awareness.
	return maxf(luminance_structural * (1.0 - shroud) + luminance_transient, 0.0)

func find_contact(id: int) -> Contact:
	for c in contacts:
		if c.id == id:
			return c
	return null

func find_tether(contact_id: int) -> Tether:
	for tt in tethers:
		if tt.contact_id == contact_id:
			return tt
	return null

func has_hunter() -> bool:
	for c in contacts:
		if c.is_hunter:
			return true
	return false

func tethered_count() -> int:
	return tethers.size()

func player_tier() -> int:
	## The player's own "tier" for gating — derived from luminance.
	var l: float = luminance_effective()
	if l <= 0.0:
		return 0
	return clampi(int(floor(log(maxf(l, 1.0)) / log(2.6))), 0, Constants.TIER_MAX)

func record_cause(text: String) -> void:
	causal_log.append({"t": t, "text": text})
	if causal_log.size() > 60:
		causal_log.pop_front()
