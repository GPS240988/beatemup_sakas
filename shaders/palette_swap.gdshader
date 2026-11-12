shader_type canvas_item;

// ============================================================
// PALETTE SWAP SHADER — Substituição seletiva de matiz para inimigos
// Projeto Sakas — Beat 'em Up 2.5D
// ============================================================
// Recolore os pixels azuis do casaco com uma matiz de destino fixa.
// A luminosidade e a estrutura de sombras originais são preservadas,
// evitando que variações de azul produzam manchas de cores diferentes.
// Pele, cabelo, calça e botas permanecem intactos fora da faixa-alvo.
// ============================================================

/// Ângulo de rotação relativo da paleta em graus.
/// Com target_hue = 220°: 140° gera vermelho; 260° gera verde.
uniform float hue_shift : hint_range(0.0, 360.0, 1.0) = 0.0;

/// Centro da matiz original a ser substituída (azul do casaco ≈ 220°).
uniform float target_hue : hint_range(0.0, 360.0, 1.0) = 220.0;

/// Tolerância da faixa de matiz ao redor do azul original.
uniform float hue_tolerance : hint_range(5.0, 90.0, 1.0) = 45.0;

/// Saturação mínima para o pixel ser elegível ao swap.
/// Pixels praticamente acromáticos continuam protegidos.
uniform float min_saturation : hint_range(0.0, 1.0, 0.01) = 0.08;

/// Ajuste de saturação adicional (+/- sobre a saturação original).
uniform float saturation_adjust : hint_range(-0.5, 0.5, 0.01) = 0.0;

/// Ajuste de valor/brilho adicional (+/- sobre o value original).
uniform float value_adjust : hint_range(-0.5, 0.5, 0.01) = 0.0;


// --- Funções de conversão RGB ↔ HSV ---
vec3 rgb_to_hsv(vec3 c) {
	vec4 K = vec4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
	vec4 p = mix(vec4(c.bg, K.wz), vec4(c.gb, K.xy), step(c.b, c.g));
	vec4 q = mix(vec4(p.xyw, c.r), vec4(c.r, p.yzx), step(p.x, c.r));
	float d = q.x - min(q.w, q.y);
	float e = 1.0e-10;
	return vec3(abs(q.z + (q.w - q.y) / (6.0 * d + e)), d / (q.x + e), q.x);
}

vec3 hsv_to_rgb(vec3 c) {
	vec4 K = vec4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
	vec3 p = abs(fract(c.xxx + K.xyz) * 6.0 - K.www);
	return c.z * mix(K.xxx, clamp(p - K.xxx, 0.0, 1.0), c.y);
}


void fragment() {
	vec4 tex_color = texture(TEXTURE, UV);

	if (tex_color.a >= 0.01) {
		vec3 hsv = rgb_to_hsv(tex_color.rgb);
		float pixel_hue_deg = hsv.x * 360.0;
		float pixel_sat = hsv.y;

		// Distância angular mínima entre o pixel e o azul-base do casaco.
		float hue_diff = abs(pixel_hue_deg - target_hue);
		if (hue_diff > 180.0) {
			hue_diff = 360.0 - hue_diff;
		}

		if (hue_diff <= hue_tolerance && pixel_sat >= min_saturation) {
			// Feather curto: quase toda a faixa recebe a cor integral.
			// Isso evita bordas longas com mistura azul/vermelho ou azul/verde.
			float feather_start = hue_tolerance * 0.90;
			float blend = 1.0 - smoothstep(feather_start, hue_tolerance, hue_diff);

			// Usa uma matiz final única para todo o casaco, em vez de girar
			// cada matiz original individualmente (causa comum de aspecto manchado).
			float palette_hue = mod(target_hue + hue_shift, 360.0) / 360.0;
			hsv.x = mix(hsv.x, palette_hue, blend);

			// Todas as variantes recebem um piso de vivacidade.
			// Vermelho continua usando o brilho extra definido no EnemyAI;
			// verde, roxo, laranja e ciano deixam de ficar apagados.
			float effective_saturation_adjust = max(saturation_adjust, 0.24);
			float effective_value_adjust = max(value_adjust, 0.58);
			hsv.y = clamp(hsv.y + effective_saturation_adjust * blend, 0.0, 1.0);
			// Eleva a luminosidade em direção ao branco, com roll-off natural nas áreas já claras.
			// Isso clareia sombras e meios-tons sem estourar tanto os highlights.
			hsv.z = mix(hsv.z, 1.0, clamp(effective_value_adjust * blend, 0.0, 1.0));
		}

		COLOR = vec4(hsv_to_rgb(hsv) * COLOR.rgb, tex_color.a * COLOR.a);
	} else {
		COLOR = tex_color * COLOR;
	}
}
