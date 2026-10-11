shader_type canvas_item;
// Posterise the finished frame. A top coat, not a lighting model: by this point the
// light and the colour are one number per pixel and cannot be separated again - which
// is exactly why this cannot give you a light colour dial.

uniform int levels : hint_range(2, 16) = 6;
uniform float mix_amount : hint_range(0.0, 1.0) = 1.0;

void fragment() {
	vec3 frame = texture(SCREEN_TEXTURE, SCREEN_UV).rgb;
	vec3 stepped = floor(frame * float(levels) + 0.5) / float(levels);
	COLOR = vec4(mix(frame, stepped, mix_amount), 1.0);
}
