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

// Thresholded Blinn half-vector highlight. This is added without replacing texture detail.
uniform float specular_gloss : hint_range(1.0, 96.0) = 24.0;
uniform float specular_threshold : hint_range(0.0, 1.0) = 0.35;
uniform float specular_softness : hint_range(0.001, 0.3) = 0.04;
uniform float specular_strength : hint_range(0.0, 2.0) = 0.65;
uniform vec4 specular_color : source_color = vec4(1.0, 0.97, 0.82, 1.0);

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

    vec3 half_vector = normalize(light_dir + view_world + vec3(0.0, 0.00001, 0.0));
    float specular_lobe = pow(max(dot(world_n, half_vector), 0.0), max(specular_gloss, 0.001));
    float softness = max(specular_softness, 0.001);
    float highlight = smoothstep(specular_threshold - softness, specular_threshold + softness, specular_lobe) * step(0.0, ndotl);
    additive = specular_color.rgb * highlight * specular_strength * light_strength;

    vec3 tint = mix(shadow_color.rgb, light_color.rgb * light_strength, level);
    ALBEDO = mix(base, base * tint + additive, effect_strength);
}
