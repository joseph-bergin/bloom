class_name Luminance
extends RefCounted
## L = sum over purchased nodes (node.lum * rank) * (1 - shroud)
## While Douse is held, L is multiplied by 0.10.

static func tick(s: GameStateData, delta: float) -> void:
	if Stats.has_rule(&"wildfire"):
		# Damage x3, and the light never stops growing. That is the bet.
		s.wildfire_lum += Constants.WILDFIRE_LUM_RATE * delta

	s.luminance = (Stats.lum_from_tree + s.wildfire_lum) * (1.0 - Stats.shroud)

	var was_hidden: bool = s.was_dousing
	if s.is_dousing():
		s.douse_meter = maxf(s.douse_meter - Stats.douse_drain * delta, 0.0)
		if s.douse_meter <= 0.0:
			# Spent. The key does nothing until the meter recovers, so
			# holding it at empty cannot chatter on and off every frame.
			s.douse_spent = true
	else:
		s.douse_meter = minf(s.douse_meter + Stats.douse_refill * delta, 1.0)
		if s.douse_spent and s.douse_meter >= Constants.DOUSE_RECOVER:
			s.douse_spent = false

	var hidden: bool = s.is_dousing()
	if hidden != was_hidden:
		s.was_dousing = hidden
		if hidden:
			EventBus.douse_started.emit()
		else:
			EventBus.douse_ended.emit()

static func effective(s: GameStateData) -> float:
	return s.luminance * (Constants.DOUSE_FACTOR if s.is_dousing() else 1.0)
