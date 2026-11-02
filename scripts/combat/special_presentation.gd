class_name SpecialPresentation
extends CanvasLayer

## Apresentação Cinematográfica Procedural do Especial (FASE COMBATE ARCADE)
## Duração rápida (0.35s a 0.55s), sem criar novos sprites.
## Utiliza exclusivamente os frames existentes do herói, ColorRects, CanvasItem drawing,
## efeitos de escala, velocidade e iluminação condizentes com a identidade dos 4 heróis.

signal impact_reached()
signal finished()

var hero_id: String = "guilherme"
var hero_texture: Texture2D = null

var _backdrop: ColorRect
var _hero_display: TextureRect
var _energy_bar: ColorRect
var _title_label: Label


func _init(p_hero_id: String = "guilherme", p_texture: Texture2D = null) -> void:
	hero_id = p_hero_id.to_lower()
	hero_texture = p_texture
	layer = 50 # Renderizado acima do jogo, abaixo do HUD crítico


func _ready() -> void:
	_build_ui()
	_animate_presentation()


func _build_ui() -> void:
	# Fundo escurecido semi-transparente para dar destaque ao golpe
	_backdrop = ColorRect.new()
	_backdrop.color = Color(0.04, 0.04, 0.08, 0.0)
	_backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_backdrop)

	# Linha de energia / faixa cinética atrás do personagem
	_energy_bar = ColorRect.new()
	_energy_bar.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_energy_bar.anchor_top = 0.35
	_energy_bar.anchor_bottom = 0.65
	_energy_bar.color = _get_hero_theme_color()
	_energy_bar.color.a = 0.0
	add_child(_energy_bar)

	# Exibição do personagem utilizando frame nativo existente
	_hero_display = TextureRect.new()
	_hero_display.texture = hero_texture
	_hero_display.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_hero_display.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_hero_display.custom_minimum_size = Vector2(400, 500)
	_hero_display.size = Vector2(400, 500)
	_hero_display.position = Vector2(-450, 110) # Entra deslizando pela esquerda
	_hero_display.modulate = Color(2.0, 2.0, 2.0, 0.0)
	add_child(_hero_display)

	# Título do Especial com tipografia estilizada arcade
	_title_label = Label.new()
	_title_label.text = _get_special_title()
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_title_label.position = Vector2(0, 560)
	_title_label.size = Vector2(1280, 80)
	_title_label.add_theme_font_size_override("font_size", 34)
	_title_label.add_theme_color_override("font_color", Color.WHITE)
	_title_label.add_theme_color_override("font_shadow_color", _get_hero_theme_color())
	_title_label.add_theme_constant_override("shadow_offset_x", 3)
	_title_label.add_theme_constant_override("shadow_offset_y", 3)
	_title_label.modulate.a = 0.0
	add_child(_title_label)


func _get_hero_theme_color() -> Color:
	match hero_id:
		"guilherme":
			return Color(0.95, 0.78, 0.15, 0.75) # Ouro Nobre e Branco
		"gabriel":
			return Color(0.15, 0.85, 0.95, 0.75) # Ciano Neon Alta Velocidade
		"andre":
			return Color(0.95, 0.45, 0.10, 0.85) # Âmbar Sísmico de Alto Impacto
		"juliana":
			return Color(0.85, 0.20, 0.75, 0.75) # Magenta Técnico e Elegante
		_:
			return Color(0.9, 0.8, 0.2, 0.7)


func _get_special_title() -> String:
	match hero_id:
		"guilherme":
			return "★ FURACÃO DE SAKAS ★"
		"gabriel":
			return "⚡ LAMINA VELOZ ⚡"
		"andre":
			return "💥 IMPACTO SÍSMICO 💥"
		"juliana":
			return "✦ DANÇA DA DESTRUIÇÃO ✦"
		_:
			return "★ GOLPE ESPECIAL ★"


func _animate_presentation() -> void:
	var tween := create_tween()
	if tween == null:
		impact_reached.emit()
		finished.emit()
		queue_free()
		return

	# Duração total ajustada entre 0.40s e 0.50s (cinematográfico e ágil)
	# 1. Fade-in do fundo e barra de energia (0.10s)
	tween.parallel().tween_property(_backdrop, "color:a", 0.65, 0.10)
	tween.parallel().tween_property(_energy_bar, "color:a", 0.35, 0.12)
	tween.parallel().tween_property(_title_label, "modulate:a", 1.0, 0.10)

	# 2. Deslocamento dinâmico do personagem entrando em cena com zoom rápido
	tween.parallel().tween_property(_hero_display, "position:x", 440.0, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(_hero_display, "modulate", Color(1.3, 1.3, 1.3, 1.0), 0.18)

	# 3. Frame de impacto no ápice (aos ~0.22s)
	tween.tween_callback(func():
		impact_reached.emit()
		_flash_screen()
	)

	# 4. Pequeno congelamento dramático (0.12s)
	tween.tween_interval(0.12)

	# 5. Saída e fade-out rápido (0.12s)
	tween.parallel().tween_property(_backdrop, "color:a", 0.0, 0.12)
	tween.parallel().tween_property(_energy_bar, "color:a", 0.0, 0.10)
	tween.parallel().tween_property(_hero_display, "modulate:a", 0.0, 0.12)
	tween.parallel().tween_property(_title_label, "modulate:a", 0.0, 0.10)

	# 6. Conclusão e liberação do nó
	tween.tween_callback(func():
		finished.emit()
		queue_free()
	)


func _flash_screen() -> void:
	var flash := ColorRect.new()
	flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	flash.color = Color.WHITE
	add_child(flash)

	var flash_tween := create_tween()
	if flash_tween != null:
		flash_tween.tween_property(flash, "color:a", 0.0, 0.12)
		flash_tween.tween_callback(flash.queue_free)
	else:
		flash.queue_free()
