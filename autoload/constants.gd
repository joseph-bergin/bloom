extends Node
## Every tuning number, no exceptions.
##
## These are `var`, not `const`, so tools/sim_runner.gd can sweep them with
## --set=KEY=VALUE. Nothing else may write to them.

var FIELD_RADIUS: float = 440.0

var SPAWN_INTERVAL_BASE: float = 3.0
var SPAWN_LUM_SCALE: float = 50.0
var TIER_LUM_STEP: float = 40.0
var MAX_TIER: int = 7
## Hard ceiling on live contacts. Protects the frame rate, and stops a
## runaway field from becoming an unreadable wall of squares.
var MAX_CONTACTS: int = 400
## Tier rolls uniformly 0..max_tier but weighted toward the top third, so the
## field feels like it is escalating rather than averaging out.
var TIER_TOP_THIRD_BIAS: float = 0.45

var DRIFT_BASE: float = 17.5
var DRIFT_LUM_SCALE: float = 0.24

var HP_BASE: float = 10.0
var HP_TIER_MULT: float = 2.2
var MOTE_BASE: float = 3.0
var MOTE_TIER_MULT: float = 2.6
var RADIUS_BASE: float = 11.0
var RADIUS_TIER_STEP: float = 3.5

var SHROUD_CAP: float = 0.80
var DOUSE_FACTOR: float = 0.10
var DOUSE_DRAIN: float = 0.20        # meter per second held
var DOUSE_REFILL: float = 0.06


# --- levels ---------------------------------------------------------------
## A level is a kill quota, then a boss. Clearing the boss ends the level.
## Levels are what make progress legible: the run has visible chapters
## instead of running until you happen to die.
## A level's kill quota is set from how fast the field is currently spawning,
## so a level is always about this many seconds of fighting. A linear quota
## collapsed to a few seconds once kill rate started growing exponentially,
## which made deep runs read as "instant, instant, instant, dead".
var LEVEL_SECONDS: float = 42.0
var LEVEL_QUOTA_MIN: float = 10.0
var LEVEL_QUOTA_MAX: float = 400.0
var LEVEL_QUOTA_STEP: float = 0.04
## The boss shows up on schedule whether or not the quota is met. Without
## this a dark, slow build simply takes as long as it likes over every
## level, and out-earns everyone by never being pressured.
var LEVEL_TIME_LIMIT: float = 1.7
var LEVEL_SPAWN_SCALE: float = 0.06
var LEVEL_CLEAR_PAUSE: float = 2.6
## Tied to what the level actually contained rather than to the level
## number. An exponential in the level number runs away the moment the
## player can clear levels quickly.
var LEVEL_CLEAR_MULT: float = 26.0

## Contact tier caps at MAX_TIER, so past that the boss has to keep growing
## some other way or it stops being a wall and the run never ends.
var BOSS_LEVEL_HP_GROWTH: float = 1.14

## The boss is a wall, not a coin flip: heavy, slow, and worth a lot. If it
## reaches you it costs a shield and spends itself, so a level can always
## be got past — the price is just steep.
var BOSS_HP_MULT: float = 1.6
## The boss used to amble in from the edge and the end of every level was
## spent waiting for it to reach range. It now starts closer and moves at a
## real pace.
var BOSS_DRIFT_MULT: float = 0.62
var BOSS_SPAWN_RANGE: float = 0.80
var BOSS_MOTE_MULT: float = 9.0
var BOSS_RADIUS_MULT: float = 2.6
var BOSS_TIER_STEP: float = 0.55

var START_SHIELDS: int = 3

## How wide a cone the turret will steer a shot into. Aiming is target
## selection, not a twitch test — the assist makes pointing near a contact
## enough, and Reach widens it.
var AIM_ASSIST_CONE: float = 0.16
var BREACH_RADIUS: float = 15.0

var TURRET_RANGE_BASE: float = 240.0
var TURRET_DAMAGE_BASE: float = 4.0
var TURRET_RATE_BASE: float = 2.0    # shots per second
var PROJECTILE_SPEED: float = 357.5
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
var SAVE_VERSION: int = 3
const SAVE_PATH := "user://save.json"
const SAVE_BACKUP_PATH := "user://save.backup.json"
var AUTOSAVE_INTERVAL: float = 20.0


## Apply a sweep override. Used only by the headless runner.
func set_tuning(key: String, value: float) -> bool:
	if not has_method("get") or get(key) == null:
		return false
	set(key, int(value) if typeof(get(key)) == TYPE_INT else value)
	return true
