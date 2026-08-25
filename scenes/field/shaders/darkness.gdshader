shader_type canvas_item;

// The light and the dark are the same gradient, so they are one pass.
//
// Outside the lit radius the field is genuinely black — drawing unseen
// contacts as outlines only relabelled the information, and leaving a few
// percent of the starfield showing through flattened the contrast until the
// lit pool read as a tint rather than the only place there is light.

uniform float sight_uv = 0.18;        // lit radius, in UV units
uniform float feather = 0.05;         // softness of the boundary
uniform vec4 dark : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform vec4 warm : source_color = vec4(1.0, 0.74, 0.34, 1.0);
uniform float warm_amount = 0.10;     // how strongly the pool is tinted
// Faster than linear, so the ground goes properly black a short way past
// the edge rather than fading across the whole field.
uniform float falloff = 1.6;

void fragment() {
	float d = distance(UV, vec2(0.5));
	float lit = 1.0 - smoothstep(sight_uv - feather, sight_uv + feather, d);

	float darkness = pow(1.0 - lit, falloff);
	// Brightest at the middle and gone by the rim, which is what makes the
	// pool look cast rather than drawn.
	float warmth = pow(lit, 2.5) * warm_amount;

	// Weighted by contribution rather than mixed by darkness alone. Mixing
	// left a bright warm band around the rim, where darkness was high
	// enough to paint but the colour was still mostly warm — a halo, and
	// exactly backwards from a light falling off.
	float total = darkness + warmth;
	vec3 c = (dark.rgb * darkness + warm.rgb * warmth) / max(total, 0.0001);
	COLOR = vec4(c, clamp(total, 0.0, 1.0));
}
