// Cabin-owned adoption of the library's soft painted lighting, with real tangent normals.
shader_type spatial;
render_mode unshaded, shadows_disabled, ambient_light_disabled, fog_disabled;

uniform sampler2D albedo_texture : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D normal_texture : hint_normal, filter_linear_mipmap, repeat_enable;
uniform bool use_normal = false;
uniform float normal_depth : hint_range(0.0, 2.0) = 1.0;
uniform vec2 uv_scale = vec2(1.0);
uniform vec4 base_tint : source_color = vec4(1.0);
uniform vec3 light_direction = vec3(-0.45, 0.55, 0.70);
uniform vec4 light_color : source_color = vec4(1.02, 0.94, 0.81, 1.0);
uniform vec4 shadow_color : source_color = vec4(0.64, 0.59, 0.58, 1.0);
uniform float effect_strength : hint_range(0.0, 1.0) = 0.75;
uniform float pool_strength : hint_range(0.0, 1.0) = 0.12;
uniform vec3 warm_pool_position = vec3(-3.8, 1.2, -1.7);
uniform float warm_pool_range = 4.0;
uniform vec2 surface_size = vec2(1.0);
uniform float border_width = 0.0;
uniform vec4 border_color : source_color = vec4(0.52, 0.31, 0.10, 1.0);

void fragment() {
    vec2 tex_uv = UV * uv_scale;
    vec3 n = NORMAL;
    if (use_normal) {
        vec3 tangent_normal = texture(normal_texture, tex_uv).rgb * 2.0 - 1.0;
        tangent_normal.xy *= normal_depth;
        n = normalize(TANGENT * tangent_normal.x + BINORMAL * tangent_normal.y + NORMAL * tangent_normal.z);
    }
    vec3 world_n = normalize((INV_VIEW_MATRIX * vec4(n, 0.0)).xyz);
    vec3 world_pos = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
    float ndotl = dot(world_n, normalize(light_direction));
    float soft_band = smoothstep(-0.2, 0.8, ndotl);
    float level = mix(clamp(0.5 + 0.5 * ndotl, 0.0, 1.0), soft_band, 0.35);
    vec3 base = texture(albedo_texture, tex_uv).rgb * base_tint.rgb;
    if (border_width > 0.0) {
        vec2 edge = min(UV, vec2(1.0) - UV) * surface_size;
        float distance_to_edge = min(edge.x, edge.y);
        float frame = 1.0 - smoothstep(border_width, border_width + 0.012, distance_to_edge);
        float inner_line = 1.0 - smoothstep(0.008, 0.018, abs(distance_to_edge - border_width * 1.6));
        base = mix(base, border_color.rgb, max(frame, inner_line * 0.65));
    }
    vec3 tint = mix(shadow_color.rgb, light_color.rgb, level);
    float pool = pow(clamp(1.0 - distance(world_pos, warm_pool_position) / warm_pool_range, 0.0, 1.0), 2.0);
    tint += pool_strength * pool * vec3(1.0, 0.55, 0.12);
    ALBEDO = base * mix(vec3(1.0), tint, effect_strength);
}
