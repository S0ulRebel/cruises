shader_type spatial;
render_mode diffuse_burley, specular_disabled, ambient_light_disabled;
// ambient_light_disabled is not optional. light() only replaces what the DIRECTIONAL
// lights contribute; the engine adds ambient on top whatever this does, and a flat
// wash over the whole room is exactly the double-lit look the bands are meant to
// remove. The shadow side is this shader's job - shadow_floor and shadow_tint below -
// so the environment's ambient must get out of the way.
// Same choice as pillage_people/world/terrain.gdshader, for the same reason.
// Cel shading, ported from pillage_people/world/terrain.gdshader.
//
// The whole look is one idea: take how lit a surface is, which is a smooth 0..1, and
// quantise it into a few steps. Everything else here is a dial on that.

uniform sampler2D albedo : source_color, filter_linear_mipmap;
uniform vec3 tint : source_color = vec3(1.0);

group_uniforms Stylisation;
// How many steps the light is cut into. 2 is a hard cartoon, 6 is nearly smooth.
uniform int bands : hint_range(2, 6) = 3;
// How soft each step's edge is. 0 is a razor line; it is clamped to a pixel's worth
// of derivative so the edge never aliases however hard it is pushed.
uniform float band_softness : hint_range(0.0, 0.5) = 0.06;
// Where the surface counts as fully lit. Below 1.0 the lit side saturates early,
// which is what makes the terminator sit where a painter would put it rather than
// where the maths does.
uniform float lit_threshold : hint_range(0.1, 1.0) = 0.70;

group_uniforms Shadow;
// The colour the unlit side goes, and how much of it. In a painted picture the
// shadow colour is a decision, not a leftover.
uniform vec3 shadow_tint : source_color = vec3(0.42, 0.52, 0.62);
uniform float shadow_tint_strength : hint_range(0.0, 1.0) = 0.32;
// How dark the darkest band is allowed to get. Stops the shadow side going to black.
uniform float shadow_floor : hint_range(0.0, 1.0) = 0.40;

float toon_ramp(float x) {
	int count = clamp(bands, 2, 6);
	float intervals = float(count - 1);
	// A pixel's worth of the value, so the step edge antialiases no matter how hard
	// band_softness is driven.
	float aa = max(fwidth(x), 0.0001);
	float softness = max(band_softness / intervals, aa);
	float result = 0.0;
	for (int i = 0; i < 5; i++) {
		if (i < count - 1) {
			float boundary = (float(i) + 0.5) / intervals;
			result += smoothstep(boundary - softness, boundary + softness, x) / intervals;
		}
	}
	return clamp(result, 0.0, 1.0);
}

void fragment() {
	ALBEDO = texture(albedo, UV).rgb * tint;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
}

void light() {
	float level = clamp(max(dot(NORMAL, LIGHT), 0.0) / max(lit_threshold, 0.001), 0.0, 1.0);
	float toon = toon_ramp(level);
	// The floor is the shadow side: tinted, and never black.
	vec3 fill = mix(vec3(1.0), shadow_tint, shadow_tint_strength) * shadow_floor;
	DIFFUSE_LIGHT += (vec3(1.0) - fill) * toon * ATTENUATION * LIGHT_COLOR / PI;
}
