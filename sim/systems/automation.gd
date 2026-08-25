class_name Automation
extends RefCounted
## Runs last so its triage rules act on fully resolved state.
## Automation must change what the player does, not remove it: by late game
## they are tuning a policy, not clicking contacts.

const ACT_LANCE := "lance"
const ACT_TETHER := "tether"
const ACT_IGNORE := "ignore"
const ACT_SWEEP := "sweep"

static func default_rule() -> Dictionary:
	return {"enabled": true, "min_tier": 0, "max_tier": Constants.TIER_MAX,
		"awareness_gt": 0.0, "action": ACT_LANCE}

static func tick(data: GameStateData, delta: float) -> void:
	if data.run_over:
		return
	if Stats.auto_sweep:
		_auto_sweep(data)
	if Stats.auto_lance or Stats.auto_tether or Stats.triage_slots > 0:
		_triage(data, delta)

static func _auto_sweep(data: GameStateData) -> void:
	if not Sensing.can_sweep(data):
		return
	# Do not sweep into a transient spike we are still paying off.
	if data.luminance_transient > Constants.TRANSIENT_SWEEP * Constants.AUTO_SWEEP_MARGIN * 10.0:
		return
	Sensing.fire_sweep(data)

static func _triage(data: GameStateData, delta: float) -> void:
	data.auto_flags["timer"] = float(data.auto_flags.get("timer", 0.0)) - delta
	if float(data.auto_flags["timer"]) > 0.0:
		return
	data.auto_flags["timer"] = Constants.AUTO_LANCE_INTERVAL

	var rules: Array = data.triage_rules
	if rules.is_empty() and Stats.auto_lance:
		rules = [default_rule()]

	for c in data.contacts:
		if not c.has_contact or c.state == Contact.State.TETHERED:
			continue
		var act: String = _decide(c, rules)
		match act:
			ACT_LANCE:
				if Stats.auto_lance and _no_lance_inbound(data, c.id):
					Lances.launch(data, c)
					return   # one commitment per interval; salvos stay deliberate
			ACT_TETHER:
				if Stats.auto_tether and Tethers.can_establish(data, c):
					Tethers.establish(data, c)
					return
			_:
				pass

static func _decide(c: Contact, rules: Array) -> String:
	for r in rules:
		if typeof(r) != TYPE_DICTIONARY:
			continue
		var rule: Dictionary = r
		if not bool(rule.get("enabled", true)):
			continue
		if c.known_tier < int(rule.get("min_tier", 0)):
			continue
		if c.known_tier > int(rule.get("max_tier", Constants.TIER_MAX)):
			continue
		if c.known_awareness <= float(rule.get("awareness_gt", -1.0)) and float(rule.get("awareness_gt", -1.0)) > 0.0:
			continue
		return str(rule.get("action", ACT_IGNORE))
	return ACT_IGNORE

static func _no_lance_inbound(data: GameStateData, id: int) -> bool:
	for l in data.lances:
		if l.target_id == id:
			return false
	return true
