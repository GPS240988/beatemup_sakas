shader_type canvas_item;
render_mode unshaded;

// Retângulo UV normalizado do vidro do CRT. Fora dele, a textura permanece intacta.
uniform vec4 screen_rect = vec4(0.174, 0.165, 0.651, 0.535);
uniform float flicker_intensity : hint_range(0.0, 1.0) = 0.82;
uniform float scanline_intensity : hint_range(0.0, 0.4) = 0.13;
uniform float rgb_shift : hint_range(0.0, 0.01) = 0.0017;
uniform float jitter_strength : hint_range(0.0, 0.01) = 0.0020;

float hash_value(float value) {
	return fract(sin(value * 127.1) * 43758.5453123);
}

float rounded_screen_mask(vec2 local_uv) {
	vec2 centered = abs(local_uv - vec2(0.5)) * 2.0;
	vec2 q = centered - vec2(0.91);
	float distance_to_edge = length(max(q, vec2(0.0)))
		+ min(max(q.x, q.y), 0.0) - 0.09;
	return 1.0 - smoothstep(0.0, 0.025, distance_to_edge);
}

void fragment() {
	vec4 original = texture(TEXTURE, UV);
	vec2 local_uv = (UV - screen_rect.xy) / screen_rect.zw;
	bool inside_rect = all(greaterThanEqual(local_uv, vec2(0.0)))
		&& all(lessThanEqual(local_uv, vec2(1.0)));

	if (!inside_rect) {
		COLOR = original;
		return;
	}

	float mask = rounded_screen_mask(local_uv);
	if (mask <= 0.001) {
		COLOR = original;
		return;
	}

	float scanline_id = floor(local_uv.y * 420.0);
	float frame_id = floor(TIME * 18.0);
	float line_noise = hash_value(scanline_id + frame_id * 31.0);
	float frame_noise = hash_value(frame_id + 7.0);

	float jitter = (line_noise - 0.5) * jitter_strength;
	float pulse = 0.945
		+ 0.035 * sin(TIME * 18.0)
		+ 0.018 * sin(TIME * 41.0);
	float dropout = step(0.965, frame_noise) * 0.22;
	pulse *= 1.0 - dropout;

	vec2 sample_uv = UV + vec2(jitter, 0.0);
	sample_uv.x = clamp(
		sample_uv.x,
		screen_rect.x + 0.001,
		screen_rect.x + screen_rect.z - 0.001
	);

	float chroma = rgb_shift * (0.45 + 0.55 * sin(TIME * 7.0));
	float red = texture(TEXTURE, sample_uv + vec2(chroma, 0.0)).r;
	float green = texture(TEXTURE, sample_uv).g;
	float blue = texture(TEXTURE, sample_uv - vec2(chroma, 0.0)).b;
	vec3 crt_color = vec3(red, green, blue);

	float scanline = 1.0 - scanline_intensity
		* (0.5 + 0.5 * cos(local_uv.y * 420.0 * 3.14159265));
	float roll_position = fract(TIME * 0.21);
	float roll_band = 1.0 - smoothstep(
		0.0,
		0.028,
		abs(local_uv.y - roll_position)
	);

	crt_color *= pulse * scanline;
	crt_color += vec3(0.035, 0.075, 0.095) * roll_band * 0.16;
	float effect_strength = mask * flicker_intensity;
	COLOR = vec4(mix(original.rgb, crt_color, effect_strength), original.a);
}
