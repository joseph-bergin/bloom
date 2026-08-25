extends Node
## user://save.json, with a rolling backup and a version field.

var _timer: float = 0.0

func _ready() -> void:
	get_tree().set_auto_accept_quit(false)
	call_deferred("load_game")

func _process(delta: float) -> void:
	_timer += delta
	if _timer >= Constants.AUTOSAVE_INTERVAL:
		_timer = 0.0
		save_game()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		save_game()
		get_tree().quit()

func serialize(s: GameStateData) -> Dictionary:
	var contacts: Array = []
	for c in s.contacts:
		contacts.append(c.to_dict())
	return {
		"version": Constants.SAVE_VERSION,
		"t": s.t, "motes": s.motes, "embers": s.embers,
		"ember_count": s.ember_count, "shields": s.shields,
		"luminance": s.luminance, "douse_meter": s.douse_meter,
		"contacts": contacts, "purchased": s.purchased.duplicate(),
		"total_motes_this_run": s.total_motes_this_run,
		"wildfire_lum": s.wildfire_lum,
		"unlocked_sections": Array(s.unlocked_sections),
		"run_over": s.run_over, "run_end_reason": s.run_end_reason,
	}

func deserialize(raw: Dictionary, s: GameStateData) -> void:
	s.t = float(raw.get("t", 0.0))
	s.motes = float(raw.get("motes", 0.0))
	s.embers = float(raw.get("embers", 0.0))
	s.ember_count = int(raw.get("ember_count", 0))
	s.shields = int(raw.get("shields", Constants.START_SHIELDS))
	s.luminance = float(raw.get("luminance", 0.0))
	s.douse_meter = float(raw.get("douse_meter", 1.0))
	s.contacts = [] as Array[Contact]
	for e in (raw.get("contacts", []) as Array):
		s.contacts.append(Contact.from_dict(e))
	s.projectiles = [] as Array[Projectile]
	s.purchased = (raw.get("purchased", {}) as Dictionary).duplicate()
	s.total_motes_this_run = float(raw.get("total_motes_this_run", 0.0))
	s.wildfire_lum = float(raw.get("wildfire_lum", 0.0))
	s.unlocked_sections = PackedStringArray(raw.get("unlocked_sections", []))
	s.run_over = bool(raw.get("run_over", false))
	s.run_end_reason = str(raw.get("run_end_reason", ""))
	s.purchase_version += 1

## Written from version 1 before shipping version 1. Never break a save.
func migrate(raw: Dictionary) -> Dictionary:
	var v: int = int(raw.get("version", 1))
	var out: Dictionary = raw.duplicate(true)
	while v < Constants.SAVE_VERSION:
		match v:
			1:
				# v1 -> v2: ember sections and the Wildfire accumulator.
				out["unlocked_sections"] = out.get("unlocked_sections", [])
				out["wildfire_lum"] = out.get("wildfire_lum", 0.0)
			_:
				pass
		v += 1
		out["version"] = v
	return out

func save_game() -> bool:
	var text: String = JSON.stringify(serialize(GameState.s))
	if FileAccess.file_exists(Constants.SAVE_PATH):
		var prev := FileAccess.get_file_as_string(Constants.SAVE_PATH)
		if not prev.is_empty():
			var bf := FileAccess.open(Constants.SAVE_BACKUP_PATH, FileAccess.WRITE)
			if bf != null:
				bf.store_string(prev)
				bf.close()
	var f := FileAccess.open(Constants.SAVE_PATH, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(text)
	f.close()
	SteamBridge.cloud_write("save.json", text)
	return true

func load_game() -> bool:
	var raw: Dictionary = _read(Constants.SAVE_PATH)
	if raw.is_empty():
		raw = _read(Constants.SAVE_BACKUP_PATH)
	if raw.is_empty():
		return false
	deserialize(migrate(raw), GameState.s)
	Stats.recompute(GameState.s)
	EventBus.game_loaded.emit()
	return true

func _read(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if typeof(parsed) == TYPE_DICTIONARY else {}

func wipe() -> void:
	for p in [Constants.SAVE_PATH, Constants.SAVE_BACKUP_PATH]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(p))
