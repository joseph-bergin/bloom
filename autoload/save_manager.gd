extends Node
## Serialize, load, migrate, autosave. Corruption in an incremental is
## catastrophic, so every write leaves a rolling backup behind.

var _timer: float = 0.0
var last_error: String = ""

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

# --- Serialization -------------------------------------------------------

func serialize(d: GameStateData) -> Dictionary:
	var contacts: Array = []
	for c in d.contacts:
		contacts.append(c.to_dict())
	var lances: Array = []
	for l in d.lances:
		lances.append(l.to_dict())
	var incoming: Array = []
	for s in d.incoming:
		incoming.append(s.to_dict())
	var tethers: Array = []
	for t in d.tethers:
		tethers.append(t.to_dict())
	return {
		"version": Constants.SAVE_VERSION,
		"last_real_time": Time.get_unix_time_from_system(),
		"t": d.t,
		"motes": d.motes,
		"signal_c": d.signal_c,
		"facets": d.facets,
		"embers": d.embers,
		"ember_count": d.ember_count,
		"luminance_structural": d.luminance_structural,
		"luminance_transient": d.luminance_transient,
		"redundancy": d.redundancy,
		"sensor_capacity": d.sensor_capacity,
		"contacts": contacts,
		"lances": lances,
		"incoming": incoming,
		"tethers": tethers,
		"blighted_nodes": Array(d.blighted_nodes),
		"blight_sources": Array(d.blight_sources),
		"purchased": d.purchased.duplicate(),
		"field_pressure": d.field_pressure,
		"total_motes_earned": d.total_motes_earned,
		"flags": d.flags.duplicate(),
		"next_contact_id": d.next_contact_id,
		"cold_rank": d.cold_rank,
		"unlocked_regions": Array(d.unlocked_regions),
		"triage_rules": d.triage_rules.duplicate(),
		"run_over": d.run_over,
		"run_end_reason": d.run_end_reason,
	}

func deserialize(raw: Dictionary, d: GameStateData) -> void:
	d.t = float(raw.get("t", 0.0))
	d.motes = float(raw.get("motes", 0.0))
	d.signal_c = float(raw.get("signal_c", 0.0))
	d.facets = float(raw.get("facets", 0.0))
	d.embers = float(raw.get("embers", 0.0))
	d.ember_count = int(raw.get("ember_count", 0))
	d.luminance_structural = float(raw.get("luminance_structural", 0.0))
	d.luminance_transient = float(raw.get("luminance_transient", 0.0))
	d.redundancy = int(raw.get("redundancy", 1))
	d.sensor_capacity = int(raw.get("sensor_capacity", Constants.SENSOR_CAPACITY_BASE))

	d.contacts = [] as Array[Contact]
	for e in (raw.get("contacts", []) as Array):
		d.contacts.append(Contact.from_dict(e))
	d.lances = [] as Array[Lance]
	for e in (raw.get("lances", []) as Array):
		d.lances.append(Lance.from_dict(e))
	d.incoming = [] as Array[IncomingStrike]
	for e in (raw.get("incoming", []) as Array):
		d.incoming.append(IncomingStrike.from_dict(e))
	d.tethers = [] as Array[Tether]
	for e in (raw.get("tethers", []) as Array):
		d.tethers.append(Tether.from_dict(e))
	d.sweeps = [] as Array[SweepRing]

	d.blighted_nodes = PackedStringArray(raw.get("blighted_nodes", []))
	d.blight_sources = PackedInt32Array(raw.get("blight_sources", []))
	d.purchased = (raw.get("purchased", {}) as Dictionary).duplicate()
	d.field_pressure = float(raw.get("field_pressure", 0.0))
	d.total_motes_earned = float(raw.get("total_motes_earned", 0.0))
	d.flags = (raw.get("flags", {}) as Dictionary).duplicate()
	d.next_contact_id = int(raw.get("next_contact_id", 1))
	d.cold_rank = int(raw.get("cold_rank", 0))
	d.unlocked_regions = PackedStringArray(raw.get("unlocked_regions", []))
	d.triage_rules = (raw.get("triage_rules", []) as Array).duplicate()
	d.run_over = bool(raw.get("run_over", false))
	d.run_end_reason = str(raw.get("run_end_reason", ""))
	d.last_real_time = float(raw.get("last_real_time", 0.0))
	d.purchase_version += 1

# --- Migration -----------------------------------------------------------

## Written from version 1, before shipping version 1. Every schema change
## adds a step. Never break an existing save.
func migrate(raw: Dictionary) -> Dictionary:
	var v: int = int(raw.get("version", 1))
	var out: Dictionary = raw.duplicate(true)
	while v < Constants.SAVE_VERSION:
		match v:
			1:
				# v1 -> v2: regions and Cold introduced.
				out["unlocked_regions"] = out.get("unlocked_regions", [])
				out["cold_rank"] = out.get("cold_rank", 0)
			2:
				# v2 -> v3: triage rules and the causal log introduced.
				out["triage_rules"] = out.get("triage_rules", [])
				out["run_over"] = out.get("run_over", false)
				out["run_end_reason"] = out.get("run_end_reason", "")
			_:
				pass
		v += 1
		out["version"] = v
	return out

# --- IO ------------------------------------------------------------------

func save_game() -> bool:
	var payload: Dictionary = serialize(GameState.data)
	var text: String = JSON.stringify(payload)
	# Roll the previous save to backup before overwriting.
	if FileAccess.file_exists(Constants.SAVE_PATH):
		var prev := FileAccess.get_file_as_string(Constants.SAVE_PATH)
		if not prev.is_empty():
			var bf := FileAccess.open(Constants.SAVE_BACKUP_PATH, FileAccess.WRITE)
			if bf != null:
				bf.store_string(prev)
				bf.close()
	var f := FileAccess.open(Constants.SAVE_PATH, FileAccess.WRITE)
	if f == null:
		last_error = "cannot open save for writing"
		return false
	f.store_string(text)
	f.close()
	SteamBridge.cloud_write("save.json", text, float(payload.get("total_motes_earned", 0.0)))
	return true

func load_game() -> bool:
	var raw: Dictionary = _read(Constants.SAVE_PATH)
	if raw.is_empty():
		raw = _read(Constants.SAVE_BACKUP_PATH)
		if not raw.is_empty():
			EventBus.log_msg("Primary save was unreadable; the backup loaded instead.", "warn")
	var cloud: Dictionary = SteamBridge.cloud_read("save.json")
	if not cloud.is_empty():
		var local_score: float = float(raw.get("total_motes_earned", -1.0))
		var cloud_score: float = float(cloud.get("total_motes_earned", -1.0))
		if cloud_score > local_score:
			raw = cloud
			EventBus.log_msg("A further-along save was found in the cloud and used instead.", "info")
	if raw.is_empty():
		return false
	raw = migrate(raw)
	deserialize(raw, GameState.data)
	Stats.recompute(GameState.data)
	var elapsed: float = Dormancy.elapsed_since(GameState.data.last_real_time)
	if elapsed >= 30.0 and not GameState.data.run_over:
		GameState.set_pending_dormancy(Dormancy.resolve(GameState.data, elapsed))
	EventBus.game_loaded.emit()
	return true

func _read(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var txt := FileAccess.get_file_as_string(path)
	if txt.is_empty():
		return {}
	var parsed: Variant = JSON.parse_string(txt)
	if typeof(parsed) != TYPE_DICTIONARY:
		last_error = "corrupt save at %s" % path
		return {}
	return parsed

func has_save() -> bool:
	return FileAccess.file_exists(Constants.SAVE_PATH)

func wipe() -> void:
	for p in [Constants.SAVE_PATH, Constants.SAVE_BACKUP_PATH]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(p))

# --- Export / import -----------------------------------------------------
# Players want it, and it makes bug reports vastly easier.

func export_string() -> String:
	return Marshalls.raw_to_base64(JSON.stringify(serialize(GameState.data)).to_utf8_buffer())

func import_string(b64: String) -> bool:
	var bytes := Marshalls.base64_to_raw(b64.strip_edges())
	if bytes.is_empty():
		return false
	var parsed: Variant = JSON.parse_string(bytes.get_string_from_utf8())
	if typeof(parsed) != TYPE_DICTIONARY:
		return false
	deserialize(migrate(parsed), GameState.data)
	Stats.recompute(GameState.data)
	EventBus.game_loaded.emit()
	return true
