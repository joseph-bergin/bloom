class_name Field
extends RefCounted
## Contact movement and breaches. A contact reaching the centre destroys
## itself and one shield.

static func move_contacts(s: GameStateData, delta: float) -> void:
	for c in s.contacts:
		c.pos += c.vel * delta

static func check_breaches(s: GameStateData) -> void:
	if s.contacts.is_empty():
		return
	var breached: Array[Contact] = []
	for c in s.contacts:
		if c.pos.length_squared() <= Constants.BREACH_RADIUS * Constants.BREACH_RADIUS:
			breached.append(c)
	for c in breached:
		s.contacts.erase(c)
		s.shields -= 1
		EventBus.shield_breached.emit(maxi(s.shields, 0))
		if s.shields <= 0:
			end_run(s, ("The level %d boss got through." % s.level) if c.is_boss
				else "Something reached you at level %d." % s.level)
			return
		if c.is_boss:
			Levels.boss_breached(s)

static func end_run(s: GameStateData, reason: String) -> void:
	if s.run_over:
		return
	s.run_over = true
	s.run_end_reason = reason
	EventBus.run_ended.emit(reason)
