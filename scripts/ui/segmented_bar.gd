class_name SegmentedBar
extends Control

## Componente de Barra Segmentada Arcade (Godot 4.x)
## Renderiza exatamente 8 segmentos em paralelogramo inclinado rigorosamente
## dentro dos limites da moldura, com estados Vazio, Preenchido e Buffer (Dano).

@export var total_segments: int = 8:
	set(val):
		total_segments = maxi(val, 1)
		queue_redraw()

@export var filled_segments: int = 8:
	set(val):
		filled_segments = clampi(val, 0, total_segments)
		queue_redraw()

@export var buffer_segments: int = 8:
	set(val):
		buffer_segments = clampi(val, 0, total_segments)
		queue_redraw()

## Propriedades numéricas com suporte à interface progress bar (compatibilidade total)
@export var value: float = 100.0:
	set(val):
		value = clampf(val, 0.0, max_value)
		filled_segments = calculate_segments(value, max_value, total_segments)
		queue_redraw()

@export var max_value: float = 100.0:
	set(val):
		max_value = maxf(val, 1.0)
		value = clampf(value, 0.0, max_value)
		filled_segments = calculate_segments(value, max_value, total_segments)
		queue_redraw()

@export var buffer_value: float = 100.0:
	set(val):
		buffer_value = clampf(val, 0.0, max_value)
		buffer_segments = calculate_segments(buffer_value, max_value, total_segments)
		queue_redraw()

## Cores temáticas dos estados
@export var filled_color: Color = Color(0.95, 0.10, 0.10, 1.0)
@export var filled_highlight: Color = Color(1.0, 0.60, 0.60, 0.85)
@export var filled_shadow: Color = Color(0.55, 0.02, 0.02, 0.70)

@export var buffer_color: Color = Color(1.0, 0.72, 0.15, 1.0)
@export var buffer_highlight: Color = Color(1.0, 0.90, 0.60, 0.85)
@export var buffer_shadow: Color = Color(0.70, 0.40, 0.05, 0.70)

@export var empty_color: Color = Color(0.09, 0.13, 0.19, 1.0)
@export var empty_border_color: Color = Color(0.18, 0.25, 0.35, 1.0)
@export var empty_highlight: Color = Color(0.28, 0.36, 0.48, 0.50)

@export var frame_color: Color = Color(0.0, 0.64, 1.0, 1.0)
@export var frame_bg_color: Color = Color(0.03, 0.05, 0.09, 0.95)
@export var draw_frame: bool = true

## Parâmetros de Geometria e Inclinação dos Segmentos
@export var slant_offset: float = 10.0
@export var padding_left: float = 8.0
@export var padding_right: float = 16.0
@export var padding_top: float = 6.0
@export var padding_bottom: float = 6.0
@export var segment_gap: float = 4.0


func _init() -> void:
	custom_minimum_size = Vector2(320, 36)


func _draw() -> void:
	var w: float = size.x
	var h: float = size.y
	if w <= 0.0 or h <= 0.0:
		return

	# 1. Moldura externa angulada com chassi cyber-arcade profissional de alto impacto
	if draw_frame:
		# Paralelogramo externo rigoroso acompanhando a diagonal do layout
		var f_p0 := Vector2(slant_offset, 0.0)
		var f_p1 := Vector2(w - 1.0, 0.0)
		var f_p2 := Vector2(w - 1.0 - slant_offset, h - 1.0)
		var f_p3 := Vector2(0.0, h - 1.0)

		# Camada 1: Halo Difuso de Neon Arcade (Outer Glow de gabinete)
		var glow_expand: float = 3.0
		var g_p0 := Vector2(slant_offset - glow_expand * 0.5, -glow_expand)
		var g_p1 := Vector2(w - 1.0 + glow_expand, -glow_expand)
		var g_p2 := Vector2(w - 1.0 - slant_offset + glow_expand * 0.5, h - 1.0 + glow_expand)
		var g_p3 := Vector2(-glow_expand, h - 1.0 + glow_expand)
		draw_colored_polygon([g_p0, g_p1, g_p2, g_p3], Color(frame_color.r, frame_color.g, frame_color.b, 0.22))

		# Camada 2: Chassi Metálico Carbono/Obsidiana
		draw_colored_polygon([f_p0, f_p1, f_p2, f_p3], Color(0.05, 0.07, 0.12, 0.98))

		# Camada 3: Fundo Rebaixado Interno dos 8 Segmentos (Inner Recess)
		var inner_inset: float = 3.0
		var in_p0 := Vector2(slant_offset + inner_inset * 0.6, inner_inset)
		var in_p1 := Vector2(w - 1.0 - inner_inset * 0.8, inner_inset)
		var in_p2 := Vector2(w - 1.0 - slant_offset - inner_inset * 0.6, h - 1.0 - inner_inset)
		var in_p3 := Vector2(inner_inset * 0.8, h - 1.0 - inner_inset)
		draw_colored_polygon([in_p0, in_p1, in_p2, in_p3], Color(0.02, 0.04, 0.08, 1.0))

		# Camada 4: Borda de Relevo Escuro e Chanfros Metálicos
		draw_polyline([f_p0, f_p1, f_p2, f_p3, f_p0], Color(0.02, 0.03, 0.06, 1.0), 2.0, true)

		# Camada 5: Trilho Laser Superior Neon (Linha Saturada + Núcleo Intenso Incandescente)
		var neon_glow_col: Color = frame_color.lightened(0.25)
		draw_line(f_p0 + Vector2(1, 1), f_p1 + Vector2(-1, 1), neon_glow_col, 2.5, true)
		draw_line(f_p0 + Vector2(2, 1.5), f_p1 + Vector2(-2, 1.5), Color.WHITE.lerp(neon_glow_col, 0.4), 1.2, true)

		# Camada 6: Trilho Inferior Metálico de Sustentação
		draw_line(f_p3 + Vector2(1, -1), f_p2 + Vector2(-1, -1), frame_color.darkened(0.35), 2.0, true)

		# Camada 7: Chanfros Diagonais e Cantoneiras Cyber nas Extremidades
		draw_line(f_p3, f_p0, frame_color.lightened(0.4), 2.5, true)
		draw_line(f_p2, f_p1, frame_color.darkened(0.45), 2.5, true)

		# Ponto de Brilho nos Vértices Diagonais (Hotspots luminosos)
		draw_circle(f_p0 + Vector2(1, 1), 2.0, Color.WHITE)
		draw_circle(f_p1 + Vector2(-1, 1), 1.5, neon_glow_col)

	# 2. Geometria interna dos paralelogramos inclinados
	var avail_w: float = w - padding_left - padding_right - slant_offset
	if avail_w <= 0.0:
		return

	var seg_w: float = (avail_w - (total_segments - 1) * segment_gap) / float(total_segments)
	var y_top: float = padding_top
	var y_bot: float = h - padding_bottom

	for i in range(total_segments):
		var xb: float = padding_left + float(i) * (seg_w + segment_gap)
		var p0 := Vector2(xb + slant_offset, y_top)
		var p1 := Vector2(xb + seg_w + slant_offset, y_top)
		var p2 := Vector2(xb + seg_w, y_bot)
		var p3 := Vector2(xb, y_bot)
		var seg_poly: PackedVector2Array = [p0, p1, p2, p3]

		var base_col: Color
		var hi_col: Color
		var sh_col: Color
		var stroke_col: Color

		if i < filled_segments:
			# Estado PREENCHIDO
			base_col = filled_color
			hi_col = filled_highlight
			sh_col = filled_shadow
			stroke_col = filled_shadow
		elif i < buffer_segments:
			# Estado DAMAGE BUFFER (temporário em redução)
			base_col = buffer_color
			hi_col = buffer_highlight
			sh_col = buffer_shadow
			stroke_col = buffer_shadow
		else:
			# Estado VAZIO
			base_col = empty_color
			hi_col = empty_highlight
			sh_col = empty_border_color
			stroke_col = empty_border_color

		# Corpo do paralelogramo
		draw_colored_polygon(seg_poly, base_col)

		# Chanfro superior luminoso (Highlight)
		draw_line(p0 + Vector2(1, 1), p1 + Vector2(-1, 1), hi_col, 2.0, true)

		# Sombra inferior e lateral direita (3D Relief)
		draw_line(p1, p2, sh_col, 1.5, true)
		draw_line(p2, p3, sh_col, 1.5, true)

		# Contorno nítido do segmento
		var poly_stroke: PackedVector2Array = [p0, p1, p2, p3, p0]
		draw_polyline(poly_stroke, stroke_col, 1.0, true)


## Cálculo canônico da quantidade de segmentos preenchidos
static func calculate_segments(cur: float, max_v: float, total: int = 8) -> int:
	max_v = maxf(max_v, 1.0)
	var norm: float = clampf(cur / max_v, 0.0, 1.0)
	var segs: int = int(floor(norm * float(total)))
	if cur > 0.0 and segs == 0:
		segs = 1 # Enquanto vivo, mantém o primeiro segmento ativo
	if is_equal_approx(norm, 1.0):
		segs = total
	return clampi(segs, 0, total)


## Define a paleta de cores temática do herói
func set_theme_colors(primary: Color, primary_hi: Color, primary_sh: Color, frame_col: Color = Color.TRANSPARENT) -> void:
	filled_color = primary
	filled_highlight = primary_hi
	filled_shadow = primary_sh
	if frame_col != Color.TRANSPARENT:
		frame_color = frame_col
	queue_redraw()
