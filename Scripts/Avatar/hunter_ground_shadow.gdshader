shader_type canvas_item;
render_mode unshaded;

float soft_footprint(vec2 uv, vec2 center, vec2 radius) {
	vec2 offset = (uv - center) / radius;
	return exp(-2.0 * dot(offset, offset));
}

void fragment() {
	// Coordinates follow the fixed-camera clip, in the same space as the sprite.
	float left = soft_footprint(UV, vec2(0.36, 0.978), vec2(0.105, 0.018));
	float right = soft_footprint(UV, vec2(0.71, 0.939), vec2(0.12, 0.017));
	float ambient = soft_footprint(UV, vec2(0.53, 0.96), vec2(0.28, 0.035));
	float opacity = 1.0 - (1.0 - 0.42 * left) * (1.0 - 0.40 * right) * (1.0 - 0.13 * ambient);
	COLOR = vec4(0.025, 0.04, 0.033, opacity);
}
