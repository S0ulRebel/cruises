// Three separate tonal bands with an independent middle color and automatically ordered thresholds.
// Opaque texture-preserving fake lighting. Does not cast geometry-aware shadows.
shader_type spatial;
render_mode unshaded, shadows_disabled, ambient_light_disabled, fog_disabled;

uniform sampler2D albedo_texture : source_color;
uniform vec4 base_tint : source_color = vec4(1.0);
uniform vec4 shadow_color : source_color = vec4(0.30, 0.36, 0.52, 1.0);
uniform vec4 light_color : source_color = vec4(1.0, 0.91, 0.74, 1.0);
// World-space vectors: direction points FROM the surface TOWARD the fake light.
uniform vec3 light_direction = vec3(-0.4, 0.8, 0.5);
uniform vec3 light_position = vec3(-3.0, 4.0, 3.0);
uniform float point_weight : hint_range(0.0, 1.0) = 0.0;
uniform float light_strength : hint_range(0.0, 3.0) = 1.0;
uniform float effect_strength : hint_range(0.0, 1.0) = 1.0;
uniform float lower_threshold : hint_range(-1.0, 1.0) = -0.15;
uniform float upper_threshold : hint_range(-1.0, 1.0) = 0.45;
uniform vec4 midtone_color : source_color = vec4(0.64, 0.69, 0.75, 1.0);

void fragment() {
    vec3 world_position = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
    vec3 world_normal = normalize((INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
    vec3 directional = normalize(light_direction + vec3(0.0, 0.00001, 0.0));
    vec3 positional = normalize(light_position - world_position + vec3(0.0, 0.00001, 0.0));
    vec3 blended_light = mix(directional, positional, point_weight);
    vec3 fake_light = blended_light / max(length(blended_light), 0.00001);
    float ndotl = dot(world_normal, fake_light);
    vec3 base = texture(albedo_texture, UV).rgb * base_tint.rgb;
    float first_band = step(min(lower_threshold, upper_threshold), ndotl);
    float second_band = step(max(lower_threshold, upper_threshold), ndotl);
    vec3 tint = mix(shadow_color.rgb, midtone_color.rgb, first_band);
    tint = mix(tint, light_color.rgb * light_strength, second_band);
    ALBEDO = mix(base, base * tint, effect_strength);
}
