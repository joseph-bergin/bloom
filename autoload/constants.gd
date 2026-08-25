extends Node
## Every tunable number in the game. Pure data, no logic.
## A literal number in a system file is a bug (see spec 2.4).

# --- Field ---------------------------------------------------------------
const FIELD_RADIUS := 1000.0

# --- Contacts ------------------------------------------------------------
const CASCADE_BASE := 0.0035
const SPAWN_INTERVAL_BASE := 12.0
const CONTACT_CAP_BASE := 40
const CONTACT_CAP_PER_EMBER := 12
const SPAWN_PRESSURE_SCALE := 0.4
const SPAWN_RANGE_MIN := 0.55
const SPAWN_RANGE_MAX := 1.0
const SPAWN_DRIFT_MAX := 0.06          # rad/s
const SPAWN_CLOSING_MIN := -14.0       # u/s, negative approaches
const SPAWN_CLOSING_MAX := 6.0
const TIER_MAX := 7
const TIER_WEIGHTS: Array[float] = [0.45, 0.28, 0.15, 0.08, 0.04]
const TIER_PRESSURE_FLOOR := 0.8
const CASCADE_TIER_SCALE := 0.15
const FLEE_DESPAWN := 20.0
const FLEE_SPEED := 90.0
const CONTACT_MIN_RANGE := 30.0

# --- Field pressure ------------------------------------------------------
const PRESSURE_PER_EMBER := 0.18
const PRESSURE_TIME_SCALE := 0.0006
const PRESSURE_TIME_EXP := 1.25
const PRESSURE_LUM_SCALE := 0.0015

# --- Luminance -----------------------------------------------------------
# You are a colony of something that burns. There is no configuration in
# which you emit nothing — Shroud reduces this baseline like any other
# structural light, but never removes it. Without a floor, a player who
# builds nothing is permanently undetectable and waiting becomes a winning
# strategy, which spec section 15 lists as a failure mode to design against.
const LUMINANCE_BASELINE := 2.5

const TRANSIENT_TAU_BASE := 12.0
const TRANSIENT_TAU_MIN := 4.0
const SHROUD_CAP := 0.88
const TRANSIENT_SWEEP := 25.0
const TRANSIENT_LANCE_LAUNCH := 8.0
const TRANSIENT_DETONATION := 6.0
const TRANSIENT_DETONATION_EXP := 1.4
const TRANSIENT_REASSERT := 40.0
const TRANSIENT_PURCHASE := 3.0

# --- Sensing -------------------------------------------------------------
const PASSIVE_INTERVAL_BASE := 6.0
const PASSIVE_INTERVAL_MIN := 1.5
const PASSIVE_RANGE_BASE := 420.0
const PASSIVE_BEARING_NOISE := 0.25    # radians at precision 1.0
const PASSIVE_RANGE_NOISE := 0.30      # +/- 30%
const OPTICS_RANK_RANGE_DATA := 4      # rank at which range becomes known
const OPTICS_RANK_STRIKE_DETECT := 6
const SIGNAL_PER_READ := 0.35

const SWEEP_RING_SPEED := 600.0
const SWEEP_RADIUS_BASE := 350.0
const SWEEP_COOLDOWN_BASE := 8.0
const SWEEP_TRANSIENT := 25.0
const LIGHTHOUSE_TRANSIENT_MULT := 4.0
const LIGHTHOUSE_AWARENESS := 0.15

const UNCERT_GROWTH := 14.0
const DROP_THRESHOLD := 400.0

# --- Lances --------------------------------------------------------------
const LANCE_SPEED_BASE := 260.0
const STALE_PENALTY := 0.10
const MIN_HIT_CHANCE_BASE := 0.05
const LANCE_MISS_AWARENESS := 0.3
const LANCE_MISS_MARKER_TIME := 2.0
const LANCE_COST_SIGNAL := 0.0
const MOTES_BASE := 8.0
const MOTES_TIER_EXP := 1.8
const FACET_TIER_MIN := 4

# --- Backlight -----------------------------------------------------------
const BACKLIGHT_FLOOR := 0.015
const BACKLIGHT_SCALE := 0.00004
const BACKLIGHT_CAP := 0.90
const HUNTER_AWARENESS := 0.75
const HUNTER_TIER_MIN := 2
const HUNTER_SPAWN_RANGE := 0.92       # fraction of FIELD_RADIUS
const HUNTER_CLOSING := -22.0

# --- Awareness -----------------------------------------------------------
const AWARENESS_RATE := 0.012
const AWARENESS_THRESHOLD_BASE := 30.0
const AWARENESS_TIER_MULT := 1.9
const AWARENESS_DECAY := 0.004         # when below threshold
const BLIGHT_TIER_MIN := 4
const BLIGHT_CHANCE := 0.4

# --- Strikes -------------------------------------------------------------
const STRIKE_SPEED := 180.0
const STRIKE_PREP_MIN := 5.0
const STRIKE_PREP_MAX := 20.0
const DISPERSAL_COST_SIGNAL := 40.0
const DISPERSAL_TRANSIENT := 10.0

# --- Tethers -------------------------------------------------------------
const TETHER_YIELD := 0.6
const SLACK_BASE := 0.004
const SLACK_LUM_SCALE := 200.0
const TETHER_ESTABLISH_COST := 25.0    # signal
const TETHER_REASSERT_COST := 18.0     # signal
const TETHER_MAX_AWARENESS := 0.5
const TETHER_TIER_MARGIN := 1
const TETHER_FACET_INTERVAL := 90.0
const TETHER_WARN_1 := 0.75
const TETHER_WARN_2 := 0.9
const SENSOR_CAPACITY_BASE := 3

# --- Blight --------------------------------------------------------------
const BLIGHT_NODES_MIN := 3
const BLIGHT_NODES_MAX := 6
const BLIGHT_CONSTELLATION_WEIGHT := 3.0

# --- Redundancy ----------------------------------------------------------
const REDUNDANCY_BASE := 1
const STRIKE_FLASH_TIME := 0.4
const STRIKE_DUCK_TIME := 1.0

# --- Economy -------------------------------------------------------------
const SIGNAL_PASSIVE_BASE := 0.0
const COST_GROWTH_RANK := 1.15
const COST_GROWTH_STRONG := 1.35

# --- Prestige ------------------------------------------------------------
const DORMANCY_EFFICIENCY_BASE := 0.35
const DORMANCY_EFFICIENCY_MAX := 0.8
const DORMANCY_CLAMP_SECONDS := 43200.0   # 12h
const EMBER_MOTE_DIVISOR := 1.0e6
const EMBER_EXP := 0.42
const EMBER_FACET_VALUE := 0.5
const COLD_UNLOCK_EMBERS := 8
const COLD_TIER_PER_RANK := 1
const COLD_INCOME_PENALTY := 0.18

# --- Automation ----------------------------------------------------------
const AUTO_SWEEP_MARGIN := 0.1
const AUTO_LANCE_INTERVAL := 0.75

# --- Feel ----------------------------------------------------------------
const HITSTOP_FRAMES := 3
const SHAKE_PER_TIER := 2.4
const SHAKE_DECAY := 6.0

# --- Save ----------------------------------------------------------------
const SAVE_VERSION := 3
const AUTOSAVE_INTERVAL := 30.0
const SAVE_PATH := "user://save.json"
const SAVE_BACKUP_PATH := "user://save.backup.json"

# --- Rendering -----------------------------------------------------------
const HDR_CONTACT_BASE := 1.4
const HDR_PLAYER_BASE := 1.2

## Deterministic-friendly weighted roll. Returns index into `weights`.
static func weighted_roll(weights: Array, rng: RandomNumberGenerator = null) -> int:
	var total: float = 0.0
	for w in weights:
		total += float(w)
	if total <= 0.0:
		return 0
	var r: float = (rng.randf() if rng != null else randf()) * total
	var acc: float = 0.0
	for i in range(weights.size()):
		acc += float(weights[i])
		if r <= acc:
			return i
	return weights.size() - 1
