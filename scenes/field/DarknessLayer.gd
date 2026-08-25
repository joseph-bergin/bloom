extends Node2D
## Everything past your light is genuinely not there to see. The lit radius
## is driven by Sight.radius(), so hiding — which cuts luminance hard — pulls
## the darkness right in around you.

const COVER := 1.7   # multiples of the field radius the veil has to span

var _rect: ColorRect
var _mat: ShaderMaterial
var _shown: float = -1.0

func _ready() -> void:
	var span: float = Constants.FIELD_RADIUS * COVER
	_rect = ColorRect.new()
	_rect.position = Vector2(-span, -span)
	_rect.size = Vector2(span * 2.0, span * 2.0)
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mat = ShaderMaterial.new()
	_mat.shader = load("res://scenes/field/shaders/darkness.gdshader")
	_rect.material = _mat
	add_child(_rect)

func _process(delta: float) -> void:
	var span: float = Constants.FIELD_RADIUS * COVER * 2.0
	var want: float = Sight.radius(GameState.s)
	# Eased, so going dark reads as the light closing in rather than a cut.
	_shown = want if _shown < 0.0 else move_toward(_shown, want, delta * 900.0)
	_mat.set_shader_parameter("sight_uv", _shown / span)
	# A wider feather on a bigger pool keeps the edge looking like falloff
	# rather than a drawn circle.
	_mat.set_shader_parameter("feather", clampf(_shown / span * 0.42, 0.012, 0.10))
	# Cold when the light has been pulled in, warm when it is burning.
	var hidden: bool = GameState.s.is_dousing()
	_mat.set_shader_parameter("warm",
		Color(0.36, 0.52, 0.82) if hidden else Color(1.0, 0.74, 0.34))
	_mat.set_shader_parameter("warm_amount", 0.10 if hidden else 0.13)
