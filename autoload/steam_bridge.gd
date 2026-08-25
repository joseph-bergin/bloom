extends Node
## GodotSteam wrapper. No-ops cleanly when Steam is absent — the game must
## run from the editor and from a non-Steam build.

const APP_ID := 480   # replace with the real appid at ship time

var available: bool = false
var _steam: Object = null
var _unlocked: Dictionary = {}

const ACHIEVEMENTS := {
	"FIRST_KILL": "The first thing out of the dark",
	"FIRST_NODE": "Brighter already",
	"FIRST_EMBER": "Banked",
	"TIER_SEVEN": "Something very large",
	"WILDFIRE": "It never stops growing",
	"CINDER": "Almost nothing",
}

func _ready() -> void:
	if Engine.has_singleton("Steam"):
		_steam = Engine.get_singleton("Steam")
		available = _init_steam()
	if not available:
		print("SteamBridge: Steam unavailable — running standalone.")
	_wire()

func _init_steam() -> bool:
	if _steam == null or not _steam.has_method("steamInitEx"):
		return false
	var res: Variant = _steam.call("steamInitEx", true, APP_ID)
	return typeof(res) == TYPE_DICTIONARY and int((res as Dictionary).get("status", -1)) == 0

func _process(_delta: float) -> void:
	if available and _steam != null and _steam.has_method("run_callbacks"):
		_steam.call("run_callbacks")

func _wire() -> void:
	EventBus.contact_killed.connect(func(tier: int, _at: Vector2, _m: float):
		unlock("FIRST_KILL")
		if tier >= Constants.MAX_TIER:
			unlock("TIER_SEVEN"))
	EventBus.node_purchased.connect(func(id: StringName, _r: int):
		unlock("FIRST_NODE")
		if id == &"burn_wildfire":
			unlock("WILDFIRE")
		elif id == &"shroud_cinder":
			unlock("CINDER"))
	EventBus.ember_banked.connect(func(_g: float, _c: int): unlock("FIRST_EMBER"))

func unlock(id: String) -> void:
	if _unlocked.has(id):
		return
	_unlocked[id] = true
	if available and _steam != null and _steam.has_method("setAchievement"):
		_steam.call("setAchievement", id)
		if _steam.has_method("storeStats"):
			_steam.call("storeStats")

func cloud_write(filename: String, text: String) -> bool:
	if not available or _steam == null or not _steam.has_method("fileWrite"):
		return false
	var buf := text.to_utf8_buffer()
	return bool(_steam.call("fileWrite", filename, buf, buf.size()))

func is_steam_deck() -> bool:
	if not available or _steam == null or not _steam.has_method("isSteamRunningOnSteamDeck"):
		return false
	return bool(_steam.call("isSteamRunningOnSteamDeck"))
