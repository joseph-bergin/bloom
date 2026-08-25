class_name Blight
extends RefCounted
## The tree turns against you. Clearing requires going loud, which means
## backlight. That vise is the entire point.

static func seed(data: GameStateData, source: Contact) -> void:
	var candidates: Array[StringName] = _candidates(data)
	if candidates.is_empty():
		# Nothing safe to rot — it strikes instead.
		Threat.launch_strike(data, source)
		return
	var count: int = data.rng.randi_range(Constants.BLIGHT_NODES_MIN, Constants.BLIGHT_NODES_MAX)
	count = int(round(float(count) * (1.0 - Stats.blight_resist)))
	count = clampi(count, 1, candidates.size())

	var weights: Array[float] = _weights(data, candidates)
	var chosen: PackedStringArray = []
	for _i in range(count):
		if candidates.is_empty():
			break
		var idx: int = Constants.weighted_roll(weights, data.rng)
		idx = clampi(idx, 0, candidates.size() - 1)
		chosen.append(String(candidates[idx]))
		candidates.remove_at(idx)
		weights.remove_at(idx)

	for id in chosen:
		if not data.blighted_nodes.has(id):
			data.blighted_nodes.append(id)
	if not data.blight_sources.has(source.id):
		data.blight_sources.append(source.id)
	source.is_blight_source = true
	source.state = Contact.State.COMMITTED
	data.purchase_version += 1   # effects change; Stats must recompute
	EventBus.blight_seeded.emit(chosen, source.id)
	EventBus.log_msg("Blight. %d nodes have gone necrotic." % chosen.size(), "bad")
	data.record_cause("T%d contact %d seeded blight on %d nodes" % [source.tier, source.id, chosen.size()])

## Only purchased, non-gateway, not-already-blighted nodes are eligible.
## Never blight a node that would soft-lock progression.
static func _candidates(data: GameStateData) -> Array[StringName]:
	var out: Array[StringName] = []
	for key in data.purchased.keys():
		var id := StringName(str(key))
		if int(data.purchased[key]) <= 0:
			continue
		if data.blighted_nodes.has(String(id)):
			continue
		var n: TreeNode = TreeDB.get_node_def(id)
		if n == null or n.blight_safe:
			continue
		out.append(id)
	return out

## Weighted toward the constellation the player has invested in most.
static func _weights(data: GameStateData, candidates: Array[StringName]) -> Array[float]:
	var invest: Dictionary = {}
	for key in data.purchased.keys():
		var n: TreeNode = TreeDB.get_node_def(StringName(str(key)))
		if n == null:
			continue
		invest[n.constellation] = float(invest.get(n.constellation, 0.0)) + float(data.purchased[key])
	var top: StringName = &""
	var top_v: float = -1.0
	for k in invest.keys():
		if float(invest[k]) > top_v:
			top_v = float(invest[k])
			top = k
	var w: Array[float] = []
	for id in candidates:
		var n: TreeNode = TreeDB.get_node_def(id)
		w.append(Constants.BLIGHT_CONSTELLATION_WEIGHT if (n != null and n.constellation == top) else 1.0)
	return w

static func is_blighted(data: GameStateData, id: StringName) -> bool:
	return data.blighted_nodes.has(String(id))

## A node is locked if it is blighted, or any ancestor is blighted.
static func is_locked(data: GameStateData, id: StringName) -> bool:
	if data.blighted_nodes.is_empty():
		return false
	var seen: Dictionary = {}
	var stack: Array[StringName] = [id]
	while not stack.is_empty():
		var cur: StringName = stack.pop_back()
		if seen.has(cur):
			continue
		seen[cur] = true
		if data.blighted_nodes.has(String(cur)):
			return true
		var n: TreeNode = TreeDB.get_node_def(cur)
		if n != null:
			for r in n.requires:
				stack.append(r)
	return false

static func active(data: GameStateData) -> bool:
	return not data.blighted_nodes.is_empty()

static func clear_source(data: GameStateData, source_id: int) -> void:
	if not data.blight_sources.has(source_id):
		return
	var idx: int = data.blight_sources.find(source_id)
	if idx >= 0:
		data.blight_sources.remove_at(idx)
	# Snuffing a source lifts the rot it seeded. With several sources live,
	# each snuff lifts a proportional share.
	if data.blight_sources.is_empty():
		data.blighted_nodes = PackedStringArray()
	else:
		var share: int = int(ceil(float(data.blighted_nodes.size()) / float(data.blight_sources.size() + 1)))
		for _i in range(share):
			if data.blighted_nodes.is_empty():
				break
			data.blighted_nodes.remove_at(0)
	data.purchase_version += 1
	EventBus.blight_cleared.emit(source_id)
	EventBus.log_msg("Blight source snuffed. The tree is coming back.", "good")

static func tick(data: GameStateData, _delta: float) -> void:
	# Drop sources that no longer exist (fled, despawned) so the rot can lift.
	if data.blight_sources.is_empty():
		return
	var alive: PackedInt32Array = []
	for id in data.blight_sources:
		if data.find_contact(id) != null:
			alive.append(id)
	if alive.size() != data.blight_sources.size():
		data.blight_sources = alive
		if alive.is_empty() and not data.blighted_nodes.is_empty():
			data.blighted_nodes = PackedStringArray()
			data.purchase_version += 1
			EventBus.blight_cleared.emit(-1)
