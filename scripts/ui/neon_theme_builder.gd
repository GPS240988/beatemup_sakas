class_name NeonThemeBuilder
extends RefCounted

## Construtor de temas e estilos Cyberpunk Neon usando nós e recursos nativos da Godot.

# Cores da Paleta Cyberpunk Neon
const COLOR_CYAN: Color = Color(0.0, 0.94, 1.0, 1.0)          # #00f0ff
const COLOR_MAGENTA: Color = Color(1.0, 0.0, 0.5, 1.0)        # #ff007f
const COLOR_ELECTRIC_PURPLE: Color = Color(0.58, 0.18, 1.0, 1.0)
const COLOR_LIME: Color = Color(0.22, 1.0, 0.08, 1.0)         # #39ff14
const COLOR_WHITE_COLD: Color = Color(0.94, 0.96, 1.0, 1.0)   # #f0f4ff
const COLOR_DARK_BASE: Color = Color(0.03, 0.04, 0.09, 0.92)  # #080a17
const COLOR_DARK_CARD: Color = Color(0.05, 0.07, 0.15, 0.88)
const COLOR_DISABLED: Color = Color(0.2, 0.22, 0.28, 0.5)


## Cria um StyleBoxFlat com efeito neon para painéis
static func create_panel_style(border_color: Color = COLOR_CYAN, bg_color: Color = COLOR_DARK_BASE, border_width: int = 2) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg_color
	style.set_border_width_all(border_width)
	style.border_color = border_color
	style.set_corner_radius_all(6)
	style.shadow_color = Color(border_color.r, border_color.g, border_color.b, 0.45)
	style.shadow_size = 6
	style.content_margin_left = 16
	style.content_margin_right = 16
	style.content_margin_top = 14
	style.content_margin_bottom = 14
	return style


## Cria um StyleBoxFlat para botões interativos
static func create_button_style(border_color: Color, bg_alpha: float = 0.15, shadow_intensity: float = 0.4) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(border_color.r * 0.15, border_color.g * 0.15, border_color.b * 0.15, bg_alpha)
	style.set_border_width_all(2)
	style.border_color = border_color
	style.set_corner_radius_all(4)
	if shadow_intensity > 0.0:
		style.shadow_color = Color(border_color.r, border_color.g, border_color.b, shadow_intensity)
		style.shadow_size = 5
	style.content_margin_left = 18
	style.content_margin_right = 18
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	return style


## Estiliza um botão específico com a paleta neon
static func style_neon_button(btn: Button, accent_color: Color = COLOR_CYAN) -> void:
	if btn == null:
		return
	btn.flat = false
	btn.focus_mode = Control.FOCUS_ALL
	
	# Cores de texto
	btn.add_theme_color_override("font_color", COLOR_WHITE_COLD)
	btn.add_theme_color_override("font_hover_color", Color.WHITE)
	btn.add_theme_color_override("font_pressed_color", accent_color)
	btn.add_theme_color_override("font_focus_color", COLOR_WHITE_COLD)
	btn.add_theme_color_override("font_disabled_color", Color(0.4, 0.45, 0.52, 0.7))
	
	# Estados de estilo
	var normal_style := create_button_style(accent_color, 0.18, 0.35)
	var hover_style := create_button_style(accent_color.lightened(0.25), 0.35, 0.65)
	var pressed_style := create_button_style(COLOR_MAGENTA, 0.50, 0.75)
	var focus_style := create_button_style(accent_color, 0.25, 0.6)
	focus_style.border_width_bottom = 3
	focus_style.border_width_top = 3
	focus_style.border_width_left = 3
	focus_style.border_width_right = 3
	
	var disabled_style := StyleBoxFlat.new()
	disabled_style.bg_color = Color(0.08, 0.09, 0.13, 0.6)
	disabled_style.set_border_width_all(1)
	disabled_style.border_color = COLOR_DISABLED
	disabled_style.set_corner_radius_all(4)
	disabled_style.content_margin_left = 18
	disabled_style.content_margin_right = 18
	disabled_style.content_margin_top = 10
	disabled_style.content_margin_bottom = 10

	btn.add_theme_stylebox_override("normal", normal_style)
	btn.add_theme_stylebox_override("hover", hover_style)
	btn.add_theme_stylebox_override("pressed", pressed_style)
	btn.add_theme_stylebox_override("focus", focus_style)
	btn.add_theme_stylebox_override("disabled", disabled_style)


## Cria a moldura com visual de cartão Cyberpunk
static func create_card_style(is_selected: bool, is_locked: bool, accent_color: Color = COLOR_CYAN) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	if is_locked:
		style.bg_color = Color(0.04, 0.05, 0.08, 0.85)
		style.set_border_width_all(1)
		style.border_color = Color(0.25, 0.28, 0.36, 0.5)
		style.set_corner_radius_all(6)
	elif is_selected:
		style.bg_color = Color(accent_color.r * 0.12, accent_color.g * 0.12, accent_color.b * 0.12, 0.92)
		style.set_border_width_all(3)
		style.border_color = accent_color
		style.set_corner_radius_all(6)
		style.shadow_color = Color(accent_color.r, accent_color.g, accent_color.b, 0.6)
		style.shadow_size = 10
	else:
		style.bg_color = Color(0.05, 0.07, 0.13, 0.88)
		style.set_border_width_all(1)
		style.border_color = Color(0.15, 0.45, 0.6, 0.6)
		style.set_corner_radius_all(6)
		style.shadow_color = Color(0.0, 0.2, 0.35, 0.3)
		style.shadow_size = 4
	
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 12
	style.content_margin_bottom = 12
	return style
