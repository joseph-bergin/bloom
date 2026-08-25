extends Node
## GodotSteam wrapper. Must no-op cleanly when Steam is absent — the game
## has to run from the editor and from a non-Steam build without touching
## a missing API.

const APP_ID := 480   # replace with the real appid at ship time

var available: bool = false
var _steam: Object = null
var _unlocked: Dictionary = {}

const ACHIEVEMENTS := {
	"FIRST_SNUFF": "The first thing you put out",
	"FIRST_WITNESS": "Something saw you do it",
	"FIRST_BLIGHT": "The tree turned",
	"TETHER_FIVE": "Five debts outstanding",
	"FIRST_EMBER": "Carried out on an ember",
	"COLD_MAX": "An empty configuration",
	"NULLWAKE": "Blind and unseen",
	"AUTARCH": "You handed over the trigger",
}

func _ready() -> void:
	if Engine.has_singleton("Steam"):
		_steam = Engine.get_singleton("Steam")
		available = _init_steam()
	if not available:
		print("SteamBridge: Steam unavailable — running standalone.")
	_wire_achievements()

func _init_steam() -> bool:
	if _steam == null:
		return false
	if not _steam.has_method("steamInitEx"):
		return false
	var res: Variant = _steam.call("steamInitEx", true, APP_ID)
	var status: int = int((res as Dictionary).get("status", -1)) if typeof(res) == TYPE_DICTIONARY else -1
	return status == 0

func _process(_delta: float) -> void:
	if available and _steam != null and _steam.has_method("run_callbacks"):
		_steam.call("run_callbacks")

# --- Achievements --------------------------------------------------------

func unlock(id: String) -> void:
	if _unlocked.has(id):
		return
	_unlocked[id] = true
	if not available or _steam == null:
		return
	if _steam.has_method("setAchievement"):
		_steam.call("setAchievement", id)
		if _steam.has_method("storeStats"):
			_steam.call("storeStats")

func _wire_achievements() -> void:
	EventBus.lance_hit.connect(func(_c, _m, _f, _at): unlock("FIRST_SNUFF"))
	EventBus.hunter_spawned.connect(func(_c): unlock("FIRST_WITNESS"))
	EventBus.blight_seeded.connect(func(_ids, _src): unlock("FIRST_BLIGHT"))
	EventBus.ember_spent.connect(func(_g, _c): unlock("FIRST_EMBER"))
	EventBus.tether_established.connect(func(_t):
		if GameState.data.tethers.size() >= 5:
			unlock("TETHER_FIVE"))
	EventBus.cold_rank_changed.connect(func(r: int):
		if r >= Constants.TIER_MAX:
			unlock("COLD_MAX"))
	EventBus.node_purchased.connect(func(id: StringName, _r: int):
		if id == &"shroud_nullwake":
			unlock("NULLWAKE")
		elif id == &"cognition_autarch":
			unlock("AUTARCH"))

# --- Cloud saves ---------------------------------------------------------

func cloud_write(filename: String, text: String, _score: float) -> bool:
	if not available or _steam == null or not _steam.has_method("fileWrite"):
		return false
	var buf := text.to_utf8_buffer()
	return bool(_steam.call("fileWrite", filename, buf, buf.size()))

func cloud_read(filename: String) -> Dictionary:
	if not available or _steam == null or not _steam.has_method("fileRead"):
		return {}
	if _steam.has_method("fileExists") and not bool(_steam.call("fileExists", filename)):
		return {}
	var res: Variant = _steam.call("fileRead", filename, 1024 * 1024)
	if typeof(res) != TYPE_DICTIONARY:
		return {}
	var buf: PackedByteArray = (res as Dictionary).get("buf", PackedByteArray())
	if buf.is_empty():
		return {}
	var parsed: Variant = JSON.parse_string(buf.get_string_from_utf8())
	return parsed if typeof(parsed) == TYPE_DICTIONARY else {}

# --- Deck / input --------------------------------------------------------

func is_steam_deck() -> bool:
	if not available or _steam == null or not _steam.has_method("isSteamRunningOnSteamDeck"):
		return false
	return bool(_steam.call("isSteamRunningOnSteamDeck"))
