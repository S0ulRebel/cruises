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

// Analytic spherical blocker projected along the fake light ray. No shadow map.
uniform vec3 occluder_position = vec3(0.0, 0.7, 1.0);
uniform float occluder_radius : hint_range(0.01, 5.0) = 0.6;
uniform float occluder_softness : hint_range(0.001, 1.0) = 0.25;
uniform float occlusion_strength : hint_range(0.0, 1.0) = 0.85;

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

    vec3 delta = occluder_position - world_pos;
    float along_ray = dot(delta, light_dir);
    vec3 closest = delta - light_dir * max(along_ray, 0.0);
    float radius = max(occluder_radius, 0.001);
    float softness = clamp(occluder_softness, 0.001, 1.0);
    float blob = 1.0 - smoothstep(radius * (1.0 - softness), radius, length(closest));
    // Ignore blockers behind the surface, and beyond a point light.
    float before_light = step(along_ray, length(light_position - world_pos));
    blob *= step(0.0, along_ray) * mix(1.0, before_light, point_weight);
    level = diffuse * (1.0 - blob * occlusion_strength);

    vec3 tint = mix(shadow_color.rgb, light_color.rgb * light_strength, level);
    ALBEDO = mix(base, base * tint + additive, effect_strength);
}
