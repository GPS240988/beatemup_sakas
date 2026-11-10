shader_type canvas_item;
render_mode blend_mix;

// Shader de Desenho / Traçado Artístico de Personagem (Sakas Neo-16-bit)
// Simula o personagem sendo desenhado progressivamente a lápis/grafite
// da cabeça aos pés com hachuras e traço analógico, antes da revelação da Pixel Art.

uniform float draw_progress : hint_range(0.0, 1.0) = 1.0;
uniform vec4 pencil_lead_color : source_color = vec4(0.18, 0.16, 0.24, 1.0); // Grafite escuro
uniform vec4 sketch_highlight_color : source_color = vec4(0.92, 0.76, 0.42, 1.0); // Ocre / brilho de grafite
uniform float line_density : hint_range(10.0, 150.0) = 60.0;
uniform float lead_edge_width : hint_range(0.01, 0.25) = 0.08;
uniform float transition_width : hint_range(0.01, 0.25) = 0.10;

float hatch(vec2 uv, float density, float angle_deg) {
	float rad = radians(angle_deg);
	vec2 dir = vec2(cos(rad), sin(rad));
	float val = sin(dot(uv, dir) * density * 3.14159);
	return step(0.0, val);
}

void fragment() {
	vec4 tex_color = texture(TEXTURE, UV);
	if (tex_color.a < 0.01) {
		discard;
	}

	// Varredura anatômica: de cima para baixo (da cabeça aos pés, levemente inclinada)
	float sweep = UV.y * 0.85 + UV.x * 0.15;
	float threshold = draw_progress * 1.25 - 0.05;

	if (sweep > threshold + lead_edge_width) {
		// Região ainda não desenhada
		COLOR = vec4(0.0);
	} else if (sweep > threshold) {
		// Ponta ativa do lápis: grafite traçando contorno e anatomia com hachura
		float edge_t = (sweep - threshold) / lead_edge_width;
		float h1 = hatch(UV, line_density, 45.0);
		float h2 = hatch(UV, line_density * 0.75, -35.0);
		float h = mix(h1, h2, 0.5);
		vec4 pencil_col = mix(sketch_highlight_color, pencil_lead_color, h * 0.65);
		pencil_col.a = tex_color.a * (1.0 - edge_t * 0.3);
		COLOR = pencil_col;
	} else if (sweep > threshold - transition_width) {
		// Transição: esboço a lápis integrando-se e preenchendo as cores da Pixel Art
		float blend = (threshold - sweep) / transition_width;
		float h = hatch(UV, line_density * 1.2, -45.0);
		vec3 sketch_rgb = mix(pencil_lead_color.rgb, sketch_highlight_color.rgb, h * 0.35 + 0.15);
		float lum = dot(tex_color.rgb, vec3(0.299, 0.587, 0.114));
		vec3 shaded_sketch = sketch_rgb * (lum * 0.8 + 0.4);
		vec3 final_rgb = mix(shaded_sketch, tex_color.rgb, smoothstep(0.0, 1.0, blend));
		COLOR = vec4(final_rgb, tex_color.a);
	} else {
		// Região completamente traçada: Pixel Art HD canônica
		COLOR = tex_color;
	}
}

