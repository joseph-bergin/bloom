extends WorldEnvironment
## The whole aesthetic depends on this.

func _ready() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_CANVAS
	env.glow_enabled = true
	env.glow_intensity = 1.1
	env.glow_bloom = 0.15
	env.glow_hdr_threshold = 0.85
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_ADDITIVE
	for i in range(7):
		env.set_glow_level(i, 1.0 if i in [1, 2, 3, 4] else 0.0)
	environment = env
