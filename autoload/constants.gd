extends Node
## Every tuning number, no exceptions.
##
## These are `var`, not `const`, so tools/sim_runner.gd can sweep them with
## --set=KEY=VALUE. Nothing else may write to them.

var FIELD_RADIUS: float = 640.0

var SPAWN_INTERVAL_BASE: float = 3.0
var SPAWN_LUM_SCALE: float = 50.0
var TIER_LUM_STEP: float = 40.0
var MAX_TIER: int = 7
## Tier rolls uniformly 0..max_tier but weighted toward the top third, so the
## field feels like it is escalating rather than averaging out.
var TIER_TOP_THIRD_BIAS: float = 0.45

var DRIFT_BASE: float = 18.0
var DRIFT_LUM_SCALE: float = 0.25

var HP_BASE: float = 10.0
var HP_TIER_MULT: float = 2.2
var MOTE_BASE: float = 3.0
var MOTE_TIER_MULT: float = 1.9
var RADIUS_BASE: float = 6.0
var RADIUS_TIER_STEP: float = 2.0

var SHROUD_CAP: float = 0.80
var DOUSE_FACTOR: float = 0.10
var DOUSE_DRAIN: float = 0.20        # meter per second held
var DOUSE_REFILL: float = 0.06

## Each prestige starts you in a darker, denser field. Without this the
## field never escalates across runs, mote income stays flat, and ember
## income with it — the whole campaign plateaus on the first cycle.
var PRESTIGE_DENSITY: float = 0.04

var START_SHIELDS: int = 3
var EMBER_DIVISOR: float = 80.0
## Retiring early must always beat dying.
var RETIRE_BONUS: float = 0.25

var TURRET_RANGE_BASE: float = 260.0
var TURRET_DAMAGE_BASE: float = 4.0
var TURRET_RATE_BASE: float = 2.0    # shots per second
var PROJECTILE_SPEED: float = 520.0
var PROJECTILE_LIFETIME: float = 3.0
var CRIT_MULT_BASE: float = 2.0

var WILDFIRE_LUM_RATE: float = 0.3
var CINDER_THRESHOLD: float = 20.0
var CINDER_SPAWN_MULT: float = 2.0
var LONGSHOT_RANGE_MULT: float = 2.5
var LONGSHOT_RATE_MULT: float = 0.5
var WILDFIRE_DAMAGE_MULT: float = 3.0
var DIASPORA_SHIELDS: int = 3
var DIASPORA_INCOME_MULT: float = 0.6

# --- feel ----------------------------------------------------------------
var HITSTOP_SECONDS: float = 0.05
var SHAKE_PER_TIER: float = 2.2
var SHAKE_DECAY: float = 7.0
var BREACH_FLASH: float = 0.3
var BREACH_DUCK: float = 1.0

# --- save ----------------------------------------------------------------
var SAVE_VERSION: int = 2
const SAVE_PATH := "user://save.json"
const SAVE_BACKUP_PATH := "user://save.backup.json"
var AUTOSAVE_INTERVAL: float = 20.0


## Apply a sweep override. Used only by the headless runner.
func set_tuning(key: String, value: float) -> bool:
	if not has_method("get") or get(key) == null:
		return false
	set(key, int(value) if typeof(get(key)) == TYPE_INT else value)
	return true
