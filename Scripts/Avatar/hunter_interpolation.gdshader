shader_type canvas_item;

uniform sampler2D next_atlas : source_color, filter_linear, repeat_disable;
uniform vec4 current_region;
uniform vec4 next_region;
uniform float frame_mix : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	vec2 local_uv = (UV - current_region.xy) / current_region.zw;
	vec4 a = texture(TEXTURE, UV);
	vec4 b = texture(next_atlas, next_region.xy + local_uv * next_region.zw);
	// Interpolate premultiplied colors so overlapping poses stay opaque.
	float alpha = mix(a.a, b.a, frame_mix);
	vec3 rgb = mix(a.rgb * a.a, b.rgb * b.a, frame_mix) / max(alpha, 0.00001);
	// Match the cool woodland light, with less fill light near the ground.
	float luminance = dot(rgb, vec3(0.2126, 0.7152, 0.0722));
	rgb = mix(rgb, vec3(luminance), 0.08) * vec3(0.91, 0.97, 0.95);
	rgb *= mix(0.99, 0.85, smoothstep(0.68, 0.99, local_uv.y));
	// Reject faint compression fringes, retaining the main antialiased contour.
	COLOR = vec4(rgb, smoothstep(0.06, 0.98, alpha));
}
