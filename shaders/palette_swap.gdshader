shader_type canvas_item;

// ============================================================
// PALETTE SWAP SHADER — RGB canônico seletivo para inimigos
// Projeto Sakas — Beat 'em Up 2.5D
// ============================================================
// Identifica os pixels azuis do casaco e aplica a cor RGB solicitada
// pelo EnemyAI. Matiz e saturação vêm da cor-alvo; o value original
// controla o sombreamento para preservar o volume do pixel art.
// ============================================================

/// Cor RGB canônica da variante selecionada no EnemyAI.
uniform vec3 palette_color = vec3(1.0, 0.23529412, 0.0);

/// Centro da matiz original do casaco azul.
uniform float source_hue : hint_range(0.0, 360.0, 1.0) = 220.0;

/// Tolerância ampliada para capturar os tons azuis das luzes e sombras do casaco.
uniform float hue_tolerance : hint_range(5.0, 120.0, 1.0) = 85.0;

/// Faixa adicional opcional para inimigos com outra cor de roupa-base (-1 desativa).
uniform float secondary_source_hue : hint_range(-1.0, 360.0, 1.0) = -1.0;
uniform float secondary_hue_tolerance : hint_range(5.0, 120.0, 1.0) = 32.0;

/// Protege pixels praticamente acromáticos, como cinzas, pretos e brancos.
uniform float min_saturation : hint_range(0.0, 1.0, 0.01) = 0.06;

/// Saturação mínima para impedir que uma variante perca vivacidade.
uniform float palette_saturation_floor : hint_range(0.0, 1.0, 0.01) = 0.0;

/// Reforço específico de brilho para levantar sombras sem achatar o sprite.
uniform float brightness_adjust : hint_range(0.0, 0.5, 0.01) = 0.0;


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
	if (tex_color.a < 0.01) {
		// Pixel quase transparente — preserva como está, sem processar paleta.
		COLOR = tex_color * COLOR;
	} else {
		vec3 source_hsv = rgb_to_hsv(tex_color.rgb);
		float source_pixel_hue = source_hsv.x * 360.0;
		float blend = 0.0;

		if (source_hsv.y >= min_saturation) {
			float primary_diff = abs(source_pixel_hue - source_hue);
			if (primary_diff > 180.0) {
				primary_diff = 360.0 - primary_diff;
			}
			if (primary_diff <= hue_tolerance) {
				blend = max(blend, 1.0 - smoothstep(hue_tolerance * 0.92, hue_tolerance, primary_diff));
			}

			// Segunda faixa é usada apenas por sprites que possuem roupa-base não azul.
			if (secondary_source_hue >= 0.0) {
				float secondary_diff = abs(source_pixel_hue - secondary_source_hue);
				if (secondary_diff > 180.0) {
					secondary_diff = 360.0 - secondary_diff;
				}
				if (secondary_diff <= secondary_hue_tolerance) {
					blend = max(
						blend,
						1.0 - smoothstep(secondary_hue_tolerance * 0.92, secondary_hue_tolerance, secondary_diff)
					);
				}
			}
		}

		if (blend > 0.0) {
			// Quase toda a faixa recebe a cor integral; apenas as bordas fazem feather.
			vec3 target_hsv = rgb_to_hsv(palette_color);
			target_hsv.y = max(target_hsv.y, palette_saturation_floor);

			// Levanta sombras para tornar a cor legível em cenários noturnos,
			// preservando a hierarquia claro/escuro original do sprite.
			float shadow_floor = clamp(0.72 + brightness_adjust * 0.18, 0.72, 0.82);
			float shade = mix(
				shadow_floor,
				1.0,
				smoothstep(0.08, 0.92, source_hsv.z)
			);
			target_hsv.z *= shade;

			source_hsv = mix(source_hsv, target_hsv, blend);
		}

		COLOR = vec4(hsv_to_rgb(source_hsv) * COLOR.rgb, tex_color.a * COLOR.a);
	}
}
