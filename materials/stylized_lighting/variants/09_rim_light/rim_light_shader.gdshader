shader_type spatial;
render_mode unshaded, shadows_disabled, ambient_light_disabled, fog_disabled;

// Opaque stylized fake lighting. Scene Light3D nodes do not illuminate this shader.
// light_direction points TOWARD the light; light_position is in world units.
uniform sampler2D albedo_texture : source_color;
uniform vec4 base_tint : source_color = vec4(1.0);
uniform vec4 shadow_color : source_color = vec4(0.30, 0.36, 0.52, 1.0);
uniform vec4 light_color : source_color = vec4(1.0, 0.91, 0.74, 1.0);
uniform vec3 light_direction = vec3(-0.4, 0.8, 0.5);
uniform vec3 light_position = vec3(-3.0, 4.0, 3.0);
uniform float point_weight : hint_range(0.0, 1.0) = 0.0;
uniform float light_strength : hint_range(0.0, 3.0) = 1.0;
uniform float effect_strength : hint_range(0.0, 1.0) = 1.0;

// View-dependent silhouette highlight, with optional light-facing gating.
uniform float rim_power : hint_range(0.2, 12.0) = 3.0;
uniform float rim_strength : hint_range(0.0, 2.0) = 0.75;
uniform float rim_directionality : hint_range(0.0, 1.0) = 0.8;
uniform vec4 rim_color : source_color = vec4(1.0, 0.84, 0.52, 1.0);

void fragment() {
    vec3 world_pos = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
    vec3 world_n = normalize((INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
    vec3 view_world = normalize((INV_VIEW_MATRIX * vec4(VIEW, 0.0)).xyz);
    vec3 toward_point = normalize(light_position - world_pos + vec3(0.0, 0.00001, 0.0));
    vec3 toward_direction = normalize(light_direction + vec3(0.0, 0.00001, 0.0));
    vec3 blended_light = mix(toward_direction, toward_point, point_weight);
    vec3 light_dir = blended_light / max(length(blended_light), 0.00001);
    float ndotl = dot(world_n, light_dir);
    float diffuse = max(ndotl, 0.0);
    float level = diffuse;
    vec3 additive = vec3(0.0);
    vec3 base = texture(albedo_texture, UV).rgb * base_tint.rgb;

    float facing = clamp(dot(world_n, view_world), 0.0, 1.0);
    float rim = pow(1.0 - facing, max(rim_power, 0.001));
    float rim_gate = mix(1.0, diffuse, rim_directionality);
    additive = rim_color.rgb * rim * rim_gate * rim_strength * light_strength;

    vec3 tint = mix(shadow_color.rgb, light_color.rgb * light_strength, level);
    ALBEDO = mix(base, base * tint + additive, effect_strength);
}
