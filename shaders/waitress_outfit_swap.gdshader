shader_type canvas_item;

// Shader dedicado para variar apenas a roupa (e opcionalmente o tom de pele natural)
// das garçonetes de fundo no Map 7 sem alterar a pele para cores artificiais.

uniform vec3 outfit_color = vec3(0.68, 0.20, 0.78);
uniform vec3 apron_color = vec3(0.95, 0.90, 0.96);
uniform bool dark_skin = false;

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	if (tex.a < 0.05) {
		COLOR = tex;
	} else {
		vec3 c = tex.rgb;
		float max_c = max(c.r, max(c.g, c.b));
		float min_c = min(c.r, min(c.g, c.b));
		float sat = (max_c > 0.001) ? ((max_c - min_c) / max_c) : 0.0;

		// Detecta pele quente (r > g > b, brilho medio/alto)
		bool is_skin = (c.r > c.g + 0.05) && (c.g > c.b + 0.04) && (max_c > 0.35) && (sat > 0.18);
		// Detecta detalhe vermelho/laranja saturado (laco/detalhe da roupa)
		bool is_red_trim = (c.r > 0.55) && (c.g < 0.42) && (c.b < 0.35);

		if (is_skin && !is_red_trim) {
			if (dark_skin) {
				// Converte pele clara para tom de pele negra natural preservando sombreamento
				float lum = dot(c, vec3(0.299, 0.587, 0.114));
				vec3 dark_tone = vec3(0.46, 0.27, 0.17) * (lum * 1.18 + 0.10);
				COLOR = vec4(clamp(dark_tone, 0.0, 1.0), tex.a);
			} else {
				COLOR = tex;
			}
		} else if (max_c > 0.68 && sat < 0.16) {
			// Avental claro: tinge suavemente preservando luz e sombra
			COLOR = vec4(c * apron_color, tex.a);
		} else if (max_c > 0.05 && max_c < 0.38 && sat < 0.45) {
			// Vestido/uniforme escuro (preserva contorno preto puro <= 0.05)
			float lum = max(max_c, 0.08);
			vec3 tinted = outfit_color * (lum * 2.35 + 0.12);
			COLOR = vec4(clamp(tinted, 0.0, 1.0), tex.a);
		} else if (is_red_trim) {
			COLOR = vec4(clamp(outfit_color * 1.15, 0.0, 1.0), tex.a);
		} else {
			COLOR = tex;
		}
	}
}
