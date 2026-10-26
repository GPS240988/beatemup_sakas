shader_type canvas_item;

// ============================================================
// PALETTE SWAP SHADER — Hue Shift Seletivo para Inimigos
// Projeto Sakas — Beat 'em Up 2.5D
// ============================================================
// Rotaciona a matiz (hue) de pixels dentro de uma faixa de
// cor alvo (ex: azuis do casaco), preservando pele, cabelo,
// calça e botas intactos.
// ============================================================

/// Ângulo de rotação da matiz em graus (0 = original, 120 = verde, 240 = vermelho)
uniform float hue_shift : hint_range(0.0, 360.0, 1.0) = 0.0;

/// Centro da matiz alvo a ser substituída (em graus, 0-360).
/// Azul padrão do casaco ≈ 220°
uniform float target_hue : hint_range(0.0, 360.0, 1.0) = 220.0;

/// Tolerância da faixa de matiz ao redor do alvo (em graus).
/// Quanto maior, mais cores similares serão afetadas.
uniform float hue_tolerance : hint_range(5.0, 90.0, 1.0) = 45.0;

/// Saturação mínima para o pixel ser elegível ao swap.
/// Pixels dessaturados (cinzas, pretos, brancos) são ignorados.
uniform float min_saturation : hint_range(0.0, 1.0, 0.01) = 0.08;

/// Ajuste de saturação adicional (+/- sobre a saturação original)
uniform float saturation_adjust : hint_range(-0.5, 0.5, 0.01) = 0.0;

/// Ajuste de valor/brilho adicional (+/- sobre o value original)
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

		// Converte hue de [0,1] para graus [0,360]
		float pixel_hue_deg = hsv.x * 360.0;
		float pixel_sat = hsv.y;

		// Calcula a distância angular mínima entre o hue do pixel e o hue alvo
		float hue_diff = abs(pixel_hue_deg - target_hue);
		if (hue_diff > 180.0) {
			hue_diff = 360.0 - hue_diff;
		}

		// Verifica se o pixel está dentro da faixa de cor alvo E tem saturação suficiente
		if (hue_diff <= hue_tolerance && pixel_sat >= min_saturation) {
			// Fator de suavização nas bordas da faixa (feathering)
			float blend = 1.0 - smoothstep(hue_tolerance * 0.6, hue_tolerance, hue_diff);

			// Aplica rotação de hue
			float new_hue = mod(pixel_hue_deg + hue_shift, 360.0) / 360.0;
			float original_hue = hsv.x;

			// Interpola suavemente entre original e novo nas bordas
			hsv.x = mix(original_hue, new_hue, blend);

			// Aplica ajustes de saturação e valor
			hsv.y = clamp(hsv.y + saturation_adjust * blend, 0.0, 1.0);
			hsv.z = clamp(hsv.z + value_adjust * blend, 0.0, 1.0);
		}

		COLOR = vec4(hsv_to_rgb(hsv) * COLOR.rgb, tex_color.a * COLOR.a);
	} else {
		COLOR = tex_color * COLOR;
	}
}
