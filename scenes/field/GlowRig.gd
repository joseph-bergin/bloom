extends WorldEnvironment
## Everything emits and the dark is genuinely dark. Every subsequent visual
## decision depends on this existing.

var _fade: float = 1.0
var _env: Environment = null

func _ready() -> void:
	_env = Environment.new()
	_env.background_mode = Environment.BG_CANVAS
	_env.glow_enabled = true
	_env.glow_intensity = 1.1
	_env.glow_bloom = 0.15
	_env.glow_hdr_threshold = 0.85
	_env.glow_blend_mode = Environment.GLOW_BLEND_MODE_ADDITIVE
	for i in range(7):
		_env.set_glow_level(i, 1.0 if i in [1, 2, 3, 4] else 0.0)
	environment = _env

## The Cold ending: fade the glow to zero over 30 seconds. No fanfare.
func fade_out(seconds: float = 30.0) -> void:
	var tw := create_tween()
	tw.tween_method(_set_fade, 1.0, 0.0, seconds)

func _set_fade(v: float) -> void:
	_fade = v
	if _env != null:
		_env.glow_intensity = 1.1 * v
		_env.glow_bloom = 0.15 * v
