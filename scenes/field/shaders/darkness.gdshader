shader_type canvas_item;

// Real darkness outside the lit radius. Drawing unseen contacts as
// silhouettes only relabelled the information — the player still knew
// exactly where everything was. This removes it instead.

uniform float sight_uv = 0.18;      // lit radius, in UV units
uniform float feather = 0.05;       // how soft the edge of the light is
uniform vec4 dark : source_color = vec4(0.008, 0.010, 0.016, 1.0);
uniform float max_dark = 0.985;     // never quite pitch black

void fragment() {
	float d = distance(UV, vec2(0.5));
	// 1 inside the light, 0 outside, feathered across the boundary.
	float lit = 1.0 - smoothstep(sight_uv - feather, sight_uv + feather, d);
	COLOR = vec4(dark.rgb, (1.0 - lit) * max_dark);
}
