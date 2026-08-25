class_name Luminance
extends RefCounted
## L_structural = sum over purchased nodes (node.lum * rank), * lum_mult
## L_effective  = L_structural * (1 - shroud) + L_transient

static func tick(data: GameStateData, delta: float) -> void:
	data.luminance_structural = Constants.LUMINANCE_BASELINE + Stats.structural_from_tree \
		+ float(data.flags.get("wildfire_lum", 0.0))
	if Stats.has_rule(&"wildfire"):
		# Structural luminance grows forever. There is no off switch.
		data.flags["wildfire_lum"] = float(data.flags.get("wildfire_lum", 0.0)) + 0.4 * delta
	# Exponential decay toward zero. tau is reducible via Shroud.
	if data.luminance_transient > 0.0:
		data.luminance_transient *= exp(-delta / maxf(Stats.transient_tau, 0.01))
		if data.luminance_transient < 0.001:
			data.luminance_transient = 0.0

static func add_transient(data: GameStateData, amount: float) -> void:
	data.luminance_transient += maxf(amount, 0.0)

## True detectability, which Cinder decouples from raw luminance.
static func detectable(data: GameStateData) -> float:
	var l: float = data.luminance_effective()
	if Stats.has_rule(&"cinder") and l < 20.0:
		return 0.0
	return l
