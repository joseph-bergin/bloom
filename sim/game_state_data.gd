class_name GameStateData
extends RefCounted

var t: float = 0.0
var motes: float = 0.0
var embers: float = 0.0
var ember_count: int = 0
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

var run_over: bool = false
var run_end_reason: String = ""
var unlocked_sections: PackedStringArray = []
var rng: RandomNumberGenerator = RandomNumberGenerator.new()

func is_dousing() -> bool:
	return dousing and douse_meter > 0.0

func effective_luminance() -> float:
	return Luminance.effective(self)
