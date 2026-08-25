class_name Economy
extends RefCounted
## Currencies, purchase flow, respec.

static func tick(data: GameStateData, delta: float) -> void:
	var passive_signal: float = Constants.SIGNAL_PASSIVE_BASE * Stats.signal_mult * delta
	if passive_signal > 0.0:
		data.signal_c += passive_signal

static func rank_of(data: GameStateData, id: StringName) -> int:
	return int(data.purchased.get(String(id), 0))

static func requirements_met(data: GameStateData, n: TreeNode) -> bool:
	for r in n.requires:
		if rank_of(data, r) <= 0:
			return false
	return true

static func is_revealed(data: GameStateData, n: TreeNode) -> bool:
	## Fog with silhouettes: a node is fully revealed when its requirements
	## are met; otherwise it draws as a ghosted outline if a neighbour is owned.
	if requirements_met(data, n):
		return true
	for r in n.requires:
		if rank_of(data, r) > 0:
			return true
	return n.requires.is_empty()

static func next_cost(data: GameStateData, n: TreeNode) -> Dictionary:
	var c: Dictionary = n.cost_at(rank_of(data, n.id))
	return {
		"motes": float(c["motes"]) * Stats.cost_mult,
		"signal": float(c["signal"]) * Stats.cost_mult,
		"facets": float(c["facets"]) * Stats.cost_mult,
	}

static func can_afford(data: GameStateData, n: TreeNode) -> bool:
	var c: Dictionary = next_cost(data, n)
	return data.motes >= float(c["motes"]) \
		and data.signal_c >= float(c["signal"]) \
		and data.facets >= float(c["facets"])

static func can_purchase(data: GameStateData, n: TreeNode) -> bool:
	if n == null or data.run_over:
		return false
	if n.region != &"base" and not data.unlocked_regions.has(String(n.region)):
		return false
	if not n.is_infinite() and rank_of(data, n.id) >= n.max_rank:
		return false
	if not requirements_met(data, n):
		return false
	if Blight.is_locked(data, n.id):
		return false
	return can_afford(data, n)

static func purchase(data: GameStateData, id: StringName) -> bool:
	var n: TreeNode = TreeDB.get_node_def(id)
	if not can_purchase(data, n):
		return false
	var c: Dictionary = next_cost(data, n)
	data.motes -= float(c["motes"])
	data.signal_c -= float(c["signal"])
	data.facets -= float(c["facets"])
	var new_rank: int = rank_of(data, id) + 1
	data.purchased[String(id)] = new_rank
	data.purchase_version += 1
	# Buying an upgrade produces a visible flare on the field.
	# The player learns viscerally that shopping is loud.
	Luminance.add_transient(data, Constants.TRANSIENT_PURCHASE)
	EventBus.node_purchased.emit(id, new_rank)
	EventBus.currency_changed.emit()
	return true

## Free respec, always. Zero cost, no cooldown — except while blight is active.
static func can_respec(data: GameStateData) -> bool:
	return not Blight.active(data)

static func respec(data: GameStateData) -> bool:
	if not can_respec(data):
		return false
	for key in data.purchased.keys():
		var n: TreeNode = TreeDB.get_node_def(StringName(str(key)))
		if n == null:
			continue
		var rank: int = int(data.purchased[key])
		for r in range(rank):
			var c: Dictionary = n.cost_at(r)
			data.motes += float(c["motes"]) * Stats.cost_mult
			data.signal_c += float(c["signal"]) * Stats.cost_mult
			data.facets += float(c["facets"]) * Stats.cost_mult
	data.purchased.clear()
	data.purchase_version += 1
	data.flags["wildfire_lum"] = 0.0
	EventBus.respec_performed.emit()
	EventBus.currency_changed.emit()
	EventBus.log_msg("Respec. Everything unbuilt, everything refunded.", "info")
	return true
