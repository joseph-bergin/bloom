class_name Luminance
extends RefCounted
## Two readings of the same light, and Shroud is the difference between them.
##
##   visible   — what you burn at. This is what you see by.
##   effective — what the dark can read of you. Drives spawns, tiers, speed.
##
## Shroud cuts the second and not the first: a shroud hides your glow from
## what is out there, it does not blind you. It used to cut s.luminance at
## the source, so buying Shroud shrank your own sight and the branch was a
## straight trap — burn+shroud scored below burn alone.
##
## Douse cuts both, because hiding really is meant to blind you.

static func tick(s: GameStateData, delta: float) -> void:
	if Stats.has_rule(&"wildfire"):
		# Damage x3, and the light never stops growing. That is the bet.
		s.wildfire_lum += Constants.WILDFIRE_LUM_RATE * delta

	s.luminance = Stats.lum_from_tree + s.wildfire_lum
	s.peak_luminance = maxf(s.peak_luminance, s.luminance)

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

## What you see by: your own light, dimmed only by holding your breath.
static func visible(s: GameStateData) -> float:
	return s.luminance * (Constants.DOUSE_FACTOR if s.is_dousing() else 1.0)

## What finds you: the same light, minus whatever Shroud hides.
static func effective(s: GameStateData) -> float:
	return visible(s) * (1.0 - Stats.shroud)
