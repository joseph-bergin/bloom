class_name GameStateData
extends RefCounted

var t: float = 0.0
var motes: float = 0.0
var shields: int = Constants.START_SHIELDS
var luminance: float = 0.0
var dousing: bool = false
var douse_meter: float = 1.0
var contacts: Array[Contact] = []
var projectiles: Array[Projectile] = []
var purchased: Dictionary = {}          # node_id -> rank
var total_motes_this_run: float = 0.0

# --- bookkeeping ---
var purchase_version: int = 0
var spawn_timer: float = 0.0
var fire_timer: float = 0.0
var wildfire_lum: float = 0.0
## Unit vector the player is pointing the turret along. Set by the input
## layer each frame; the sim only ever reads it. When aim_auto is on (the
## headless runner, or before the first mouse move) the turret falls back
## to the nearest contact.
var aim: Vector2 = Vector2.RIGHT
var aim_auto: bool = true
var locked_id: int = 0

## Level state. FIGHTING until the kill quota is met, BOSS while the boss
## is alive, CLEARED for a beat afterwards so the player can read it.
## FIGHTING until the kill quota is met, BOSS while the boss is alive, then
## UPGRADING — which waits for the player rather than a timer, so there is
## always a moment to spend what the level paid before the next one starts.
enum Phase { FIGHTING, BOSS, UPGRADING }

var level: int = 1
var level_kills: int = 0
var level_quota: int = 12
var level_time: float = 0.0
var phase: Phase = Phase.FIGHTING
var last_clear_bonus: float = 0.0
var boss_id: int = 0
var best_level: int = 1

var run_over: bool = false
var run_end_reason: String = ""
var rng: RandomNumberGenerator = RandomNumberGenerator.new()

func boss() -> Contact:
	if boss_id == 0:
		return null
	for c in contacts:
		if c.get_instance_id() == boss_id:
			return c
	return null

func is_dousing() -> bool:
	return dousing and douse_meter > 0.0

func effective_luminance() -> float:
	return Luminance.effective(self)
