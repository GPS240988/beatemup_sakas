class_name ArcadeButton
extends Button

## Componente de Botão Arcade Premium — Projeto Sakas
## Reproduz com fidelidade a identidade visual do protótipo React/CSS (.arcade-button):
## - Geometria chanfrada angular (clip-path hexagonal: 3% 0, 96% 0, 100% 50%, 96% 100%, 3% 100%, 0 50%)
## - 5 estados: Normal, Hover, Focus, Pressed, Primary (JOGAR pulsante) e Disabled
## - Ícone lateral dourado, notch triangular direito, sombra deslocada e bordas duplas
## - Neutralização total do tema padrão do Godot (Zero botões cinzas ou retângulos genéricos)

signal activated()

@export var button_text: String = "JOGAR":
	set(val):
		button_text = val
		queue_redraw()

@export var icon_texture: Texture2D:
	set(val):
		icon_texture = val
		queue_redraw()

@export var is_primary: bool = false:
	set(val):
		is_primary = val
		queue_redraw()

@export var is_danger: bool = false:
	set(val):
		is_danger = val
		queue_redraw()

@export var custom_font_size: int = 28:
	set(val):
		custom_font_size = val
		queue_redraw()

const FONT_PRIMARY_PATH := "res://assets/fonts/barlow_condensed_extrabold_italic.ttf"
const FONT_FALLBACK_PATH := "res://assets/fonts/arcade_bold.ttf"

# Paleta Canônica Sakas / Neo-16-bit Arcade
const COLOR_NAVY_TOP := Color(0.043, 0.059, 0.145, 0.98)      # #0B0F25
const COLOR_NAVY_BOTTOM := Color(0.008, 0.012, 0.047, 0.98)   # #02030C
const COLOR_BORDER_NORMAL := Color(0.459, 0.482, 0.969, 1.0)  # #757BF7
const COLOR_INSET_NORMAL := Color(0.067, 0.102, 0.325, 0.9)   # #111A53

const COLOR_CYAN_FOCUS := Color(0.137, 0.906, 1.0, 1.0)       # #23E7FF
const COLOR_CYAN_OUTLINE := Color(0.137, 0.906, 1.0, 0.3)

const COLOR_PRIMARY_TOP := Color(1.0, 0.251, 0.220, 1.0)      # #FF4038
const COLOR_PRIMARY_MID := Color(0.788, 0.043, 0.153, 1.0)    # #C90B27
const COLOR_PRIMARY_BOT := Color(0.502, 0.020, 0.114, 1.0)    # #80051D
const COLOR_PRIMARY_BORDER := Color(1.0, 0.882, 0.290, 1.0)   # #FFE14A
const COLOR_PRIMARY_INSET := Color(1.0, 0.459, 0.110, 1.0)    # #FF751C

const COLOR_DISABLED_TOP := Color(0.082, 0.086, 0.133, 1.0)   # #151622
const COLOR_DISABLED_BOT := Color(0.035, 0.039, 0.063, 1.0)   # #090A10
const COLOR_DISABLED_BORDER := Color(0.208, 0.224, 0.302, 1.0)# #35394D
const COLOR_DISABLED_TEXT := Color(0.412, 0.427, 0.510, 1.0)  # #696D82

const COLOR_GOLD_ICON := Color(1.0, 0.788, 0.157, 1.0)        # #FFC928
const COLOR_SHADOW := Color(0.0, 0.0, 0.0, 0.55)
const COLOR_TEXT_SHADOW := Color(0.067, 0.075, 0.137, 1.0)   # #111323

var _button_font: Font
var _is_hovered: bool = false
var _is_pressed: bool = false
var _glow_phase: float = 0.0
var _glow_tween: Tween
var _hover_offset_x: float = 0.0


func _init() -> void:
	flat = true
	focus_mode = Control.FOCUS_ALL
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	text = "" # O texto é renderizado customizadamente no _draw


func _ready() -> void:
	_load_font()
	_neutralize_godot_theme()

	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	focus_entered.connect(_on_focus_entered)
	focus_exited.connect(_on_focus_exited)
	button_down.connect(_on_button_down)
	button_up.connect(_on_button_up)
	pressed.connect(_on_pressed_action)

	if is_primary:
		_start_primary_glow()


func _load_font() -> void:
	if ResourceLoader.exists(FONT_PRIMARY_PATH):
		_button_font = load(FONT_PRIMARY_PATH) as Font
	elif ResourceLoader.exists(FONT_FALLBACK_PATH):
		_button_font = load(FONT_FALLBACK_PATH) as Font


func _neutralize_godot_theme() -> void:
	var empty_style := StyleBoxEmpty.new()
	add_theme_stylebox_override("normal", empty_style)
	add_theme_stylebox_override("hover", empty_style)
	add_theme_stylebox_override("pressed", empty_style)
	add_theme_stylebox_override("disabled", empty_style)
	add_theme_stylebox_override("focus", empty_style)


func _on_mouse_entered() -> void:
	if disabled:
		return
	_is_hovered = true
	_animate_hover(true)


func _on_mouse_exited() -> void:
	_is_hovered = false
	_animate_hover(false)


func _on_focus_entered() -> void:
	if disabled:
		return
	_is_hovered = true
	_animate_hover(true)


func _on_focus_exited() -> void:
	_is_hovered = false
	_animate_hover(false)


func _on_button_down() -> void:
	if disabled:
		return
	_is_pressed = true
	queue_redraw()


func _on_button_up() -> void:
	_is_pressed = false
	queue_redraw()


func _on_pressed_action() -> void:
	if disabled:
		return
	activated.emit()


func _animate_hover(active: bool) -> void:
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	var target_x: float = -5.0 if active else 0.0
	tween.tween_property(self, "_hover_offset_x", target_x, 0.08)
	tween.tween_callback(queue_redraw)


func _start_primary_glow() -> void:
	if _glow_tween != null and _glow_tween.is_valid():
		_glow_tween.kill()
	_glow_tween = create_tween().set_loops()
	_glow_tween.tween_property(self, "_glow_phase", 1.0, 0.9).set_trans(Tween.TRANS_SINE)
	_glow_tween.tween_property(self, "_glow_phase", 0.0, 0.9).set_trans(Tween.TRANS_SINE)
	_glow_tween.tween_callback(queue_redraw)


## Gera os pontos do polígono chanfrado proporcionalmente ao tamanho do botão:
## clip-path: polygon(3% 0, 96% 0, 100% 50%, 96% 100%, 3% 100%, 0 50%)
func _get_button_polygon(rect: Rect2, chamfer_ratio_x: float = 0.035) -> PackedVector2Array:
	var w: float = rect.size.x
	var h: float = rect.size.y
	var ox: float = rect.position.x
	var oy: float = rect.position.y

	var c_left: float = ox + (w * chamfer_ratio_x)
	var c_right: float = ox + (w * (1.0 - chamfer_ratio_x))
	var mid_y: float = oy + (h * 0.5)

	return PackedVector2Array([
		Vector2(c_left, oy),           # Topo-Esquerda (início do topo reto)
		Vector2(c_right, oy),          # Topo-Direita
		Vector2(ox + w, mid_y),        # Bico Direito (50% da altura)
		Vector2(c_right, oy + h),      # Base-Direita
		Vector2(c_left, oy + h),       # Base-Esquerda
		Vector2(ox, mid_y),            # Bico Esquerdo (50% da altura)
	])


func _draw() -> void:
	var w: float = size.x
	var h: float = size.y
	if w <= 0.0 or h <= 0.0:
		return

	var is_active_focus := (has_focus() or _is_hovered) and not disabled
	var press_offset := Vector2(2.0, 3.0) if _is_pressed else Vector2(_hover_offset_x, 0.0)

	# 1. Desenha Sombra Deslocada (Drop Shadow)
	var shadow_offset := Vector2(2.0, 3.0) if _is_pressed else (Vector2(6.0, 7.0) if is_primary else Vector2(5.0, 6.0))
	var shadow_rect := Rect2(shadow_offset + press_offset, Vector2(w, h))
	var shadow_poly := _get_button_polygon(shadow_rect)
	draw_colored_polygon(shadow_poly, COLOR_SHADOW)

	# Se for Primary (JOGAR), desenha aura externa avermelhada/magenta suave
	if is_primary and not disabled:
		var aura_glow_alpha: float = lerpf(0.18, 0.35, _glow_phase)
		var aura_color := Color(1.0, 0.15, 0.32, aura_glow_alpha)
		var aura_rect := Rect2(press_offset.x - 3.0, press_offset.y - 2.0, w + 6.0, h + 4.0)
		draw_colored_polygon(_get_button_polygon(aura_rect), aura_color)

	# 2. Polígono do Botão Principal
	var btn_rect := Rect2(press_offset, Vector2(w, h))
	var btn_poly := _get_button_polygon(btn_rect)

	# Define cores de preenchimento (gradiente vertical)
	var col_top: Color
	var col_bot: Color
	var col_border: Color
	var col_inset: Color

	if disabled:
		col_top = COLOR_DISABLED_TOP
		col_bot = COLOR_DISABLED_BOT
		col_border = COLOR_DISABLED_BORDER
		col_inset = COLOR_DISABLED_BORDER
	elif is_primary:
		col_top = COLOR_PRIMARY_TOP
		col_bot = COLOR_PRIMARY_BOT
		col_border = COLOR_PRIMARY_BORDER
		col_inset = COLOR_PRIMARY_INSET
	else:
		col_top = COLOR_NAVY_TOP
		col_bot = COLOR_NAVY_BOTTOM
		col_border = COLOR_CYAN_FOCUS if is_active_focus else COLOR_BORDER_NORMAL
		col_inset = COLOR_CYAN_FOCUS if is_active_focus else COLOR_INSET_NORMAL

	# Modulação de brilho em hover/focus/press
	if is_active_focus:
		col_top = col_top.lightened(0.15)
		col_bot = col_bot.lightened(0.15)
	if _is_pressed:
		col_top = col_top.darkened(0.18)
		col_bot = col_bot.darkened(0.18)

	# Cores por vértice para gradiente vertical
	var poly_colors := PackedColorArray([
		col_top, col_top,
		col_top.lerp(col_bot, 0.5),
		col_bot, col_bot,
		col_top.lerp(col_bot, 0.5)
	])
	draw_polygon(btn_poly, poly_colors)

	# 3. Contorno Externo Principal (2px)
	var border_poly_closed := PackedVector2Array(btn_poly)
	border_poly_closed.append(btn_poly[0])
	draw_polyline(border_poly_closed, col_border, 2.5, true)

	# 4. Moldura Interna (Inset 3px)
	var inset_rect := Rect2(btn_rect.position + Vector2(3.0, 3.0), btn_rect.size - Vector2(6.0, 6.0))
	var inset_poly := _get_button_polygon(inset_rect)
	var inset_poly_closed := PackedVector2Array(inset_poly)
	inset_poly_closed.append(inset_poly[0])
	draw_polyline(inset_poly_closed, col_inset, 1.5, true)

	# 5. Inner Shine Superior (efeito de vidro no topo)
	if not disabled:
		var shine_p1 := btn_poly[0] + Vector2(2.0, 2.0)
		var shine_p2 := btn_poly[1] + Vector2(-2.0, 2.0)
		draw_line(shine_p1, shine_p2, Color(1.0, 1.0, 1.0, 0.35 if is_active_focus else 0.22), 1.5)

	# 6. Outline de Destaque Ciano quando focado/hover
	if is_active_focus and not is_primary:
		var focus_outline_rect := Rect2(btn_rect.position - Vector2(3.0, 3.0), btn_rect.size + Vector2(6.0, 6.0))
		var focus_poly := _get_button_polygon(focus_outline_rect)
		var focus_poly_closed := PackedVector2Array(focus_poly)
		focus_poly_closed.append(focus_poly[0])
		draw_polyline(focus_poly_closed, COLOR_CYAN_OUTLINE, 2.0, true)

	# 7. Ícone Lateral Esquerdo
	var content_start_x := press_offset.x + (w * 0.05) + 12.0
	var icon_size: float = minf(h * 0.58, 36.0)
	var icon_y: float = press_offset.y + (h - icon_size) * 0.5

	if icon_texture != null:
		var icon_rect := Rect2(content_start_x, icon_y, icon_size, icon_size)
		var icon_modulate := COLOR_DISABLED_TEXT if disabled else (Color(1.0, 0.95, 0.7, 1.0) if is_primary else COLOR_GOLD_ICON)
		draw_texture_rect(icon_texture, icon_rect, false, icon_modulate)
		content_start_x += icon_size + 14.0

	# 8. Texto Centralizado Verticalmente com Sombra de Alto Contraste
	if _button_font != null and not button_text.is_empty():
		var f_size: int = custom_font_size
		var text_y: float = press_offset.y + (h * 0.5) + (f_size * 0.36)
		var text_pos := Vector2(content_start_x, text_y)

		var text_color: Color
		if disabled:
			text_color = COLOR_DISABLED_TEXT
		elif is_primary:
			text_color = Color(1.0, 0.98, 0.91, 1.0)
		elif is_danger and not is_active_focus:
			text_color = Color(0.78, 0.78, 0.83, 0.82)
		else:
			text_color = Color(1.0, 1.0, 1.0, 1.0)

		# Sombra do texto (3px 3px)
		draw_string(_button_font, text_pos + Vector2(3.0, 3.0), button_text, HORIZONTAL_ALIGNMENT_LEFT, -1, f_size, COLOR_TEXT_SHADOW)
		# Texto principal
		draw_string(_button_font, text_pos, button_text, HORIZONTAL_ALIGNMENT_LEFT, -1, f_size, text_color)

	# 9. Notch / Indicador Visual Direito (triângulo apontando para a direita)
	var notch_w: float = 8.0
	var notch_h: float = 16.0
	var notch_x: float = press_offset.x + w - (w * 0.05) - notch_w - 10.0
	var notch_mid_y: float = press_offset.y + (h * 0.5)

	var notch_poly := PackedVector2Array([
		Vector2(notch_x, notch_mid_y - (notch_h * 0.5)),
		Vector2(notch_x + notch_w, notch_mid_y),
		Vector2(notch_x, notch_mid_y + (notch_h * 0.5))
	])
	var notch_color := col_border
	notch_color.a = 0.55 if is_active_focus else 0.35
	draw_colored_polygon(notch_poly, notch_color)

