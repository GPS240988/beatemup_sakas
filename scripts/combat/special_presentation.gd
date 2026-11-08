class_name SpecialPresentation
extends CanvasLayer

## Apresentação Cinematográfica do Golpe Especial (FASE COMBATE ARCADE)
## Contrato temporal de 2,50s rigorosamente sincronizado:
## - 0.00s a 0.35s: Abertura cinematográfica (fade-in, zoom inicial suave e entrada da arte oficial)
## - 0.35s a 0.90s: Construção de energia e aproximação rápida (0.55s, zoom progressivo e aura temática)
## - 0.90s a 1.30s: Hold do clímax (0.40s, tensão máxima no ápice aguardando o impacto)
## - 1.30s: impact_reached emitido exatamente no ápice (aplicação atômica do dano global)
## - 1.30s a 1.50s: Flash de impacto (0.20s, flash branco e recuo visual)
## - 1.50s a 2.00s: Respiro pós-impacto (0.50s, absorção de choque e dissipação de energia)
## - 2.00s a 2.50s: Saída cinematográfica (0.50s, fade-out e recolhimento)
## - 2.50s: finished emitido e liberação da cena
##
## Cobre integralmente a viewport em qualquer proporção (16:9, ultrawide mobile 20:9, 4:3)
## preservando rigorosamente o aspecto da arte oficial sem distorções ou barras pretas.

signal impact_reached()
signal finished()

var hero_id: String = "guilherme"
var hero_texture: Texture2D = null
var hero_data: HeroData = null

# Flag de controle de segurança (idempotência)
var _impact_emitted: bool = false
var _finished_emitted: bool = false

var _root_container: Control
var _backdrop: ColorRect
var _image_rect: TextureRect
var _energy_bar: ColorRect
var _flash_rect: ColorRect
var _anim_tween: Tween


func _init(p_hero = "guilherme", p_texture: Texture2D = null) -> void:
	layer = 120 # Acima do jogo e cenário 2.5D, com prioridade visual
	if p_hero is HeroData:
		hero_data = p_hero as HeroData
		hero_id = hero_data.hero_id.to_lower()
		hero_texture = hero_data.special_presentation_texture
		if hero_texture == null and p_texture != null:
			hero_texture = p_texture
	elif p_hero is String:
		hero_id = (p_hero as String).to_lower()
		hero_texture = p_texture


func _ready() -> void:
	_build_ui()
	_update_pivot()
	_animate_presentation()


func _build_ui() -> void:
	# Container raiz cobrindo 100% da viewport
	_root_container = Control.new()
	_root_container.name = "SpecialPresentationRoot"
	_root_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root_container.resized.connect(_update_pivot)
	add_child(_root_container)

	# Fundo escurecido quase preto translúcido
	_backdrop = ColorRect.new()
	_backdrop.name = "Backdrop"
	_backdrop.color = Color(0.015, 0.02, 0.035, 0.0)
	_backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root_container.add_child(_backdrop)

	# Linha/Faixa cinética de energia temática atrás da ilustração
	_energy_bar = ColorRect.new()
	_energy_bar.name = "EnergyBar"
	_energy_bar.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_energy_bar.anchor_top = 0.32
	_energy_bar.anchor_bottom = 0.68
	_energy_bar.offset_top = 0.0
	_energy_bar.offset_bottom = 0.0
	_energy_bar.color = _get_hero_theme_color()
	_energy_bar.color.a = 0.0
	_energy_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root_container.add_child(_energy_bar)

	# Arte principal do Especial: cobre integralmente a tela preservando proporção
	_image_rect = TextureRect.new()
	_image_rect.name = "SpecialImage"
	_image_rect.texture = _resolve_hero_texture()
	_image_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_image_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_image_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_image_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_image_rect.modulate = Color(1.0, 1.0, 1.0, 0.0)
	_image_rect.scale = Vector2.ONE * 0.95
	_root_container.add_child(_image_rect)

	# Flash de impacto cobrindo a tela
	_flash_rect = ColorRect.new()
	_flash_rect.name = "ImpactFlash"
	_flash_rect.color = Color.WHITE
	_flash_rect.color.a = 0.0
	_flash_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_flash_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root_container.add_child(_flash_rect)


## Mantém o ponto de pivô perfeitamente centralizado em qualquer proporção de viewport (16:9, ultrawide mobile 20:9, 4:3)
func _update_pivot() -> void:
	if not is_instance_valid(_image_rect) or not is_instance_valid(_root_container):
		return
	var current_size: Vector2 = _root_container.size
	if current_size.x <= 0.0 or current_size.y <= 0.0:
		if get_viewport() != null:
			current_size = get_viewport().get_visible_rect().size
	if current_size.x <= 0.0 or current_size.y <= 0.0:
		current_size = Vector2(1280.0, 720.0) # Fallback seguro
	_image_rect.pivot_offset = current_size * 0.5


func _resolve_hero_texture() -> Texture2D:
	if hero_texture != null:
		return hero_texture
	if hero_data != null and hero_data.special_presentation_texture != null:
		return hero_data.special_presentation_texture

	# Resolução automática oficial por herói
	var hero_path := "res://assets/sprites/characters/%s/especial_1_%s.webp" % [hero_id, hero_id]
	if ResourceLoader.exists(hero_path):
		return load(hero_path) as Texture2D

	return null


func _get_hero_theme_color() -> Color:
	if hero_data != null and hero_data.special_theme_color != Color.TRANSPARENT:
		return hero_data.special_theme_color
	match hero_id:
		"guilherme":
			return Color(0.95, 0.78, 0.15, 0.90) # Ouro Nobre e Branco
		"gabriel":
			return Color(0.15, 0.85, 0.95, 0.90) # Ciano Neon Alta Velocidade
		"andre":
			return Color(0.95, 0.45, 0.10, 0.90) # Âmbar Sísmico de Alto Impacto
		"juliana":
			return Color(0.85, 0.20, 0.75, 0.90) # Magenta Técnico e Elegante
		_:
			return Color(0.95, 0.80, 0.20, 0.90)


## Sequência temporal canônica estrita de 2,50 segundos
func _animate_presentation() -> void:
	if _anim_tween != null and _anim_tween.is_valid():
		_anim_tween.kill()

	_anim_tween = create_tween()
	if _anim_tween == null:
		_emit_impact()
		_emit_finished()
		queue_free()
		return

	# Garante que roda mesmo se o jogo estiver pausado
	_anim_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)

	_update_pivot()

	# =========================================================================
	# 1. ABERTURA CINEMATOGRÁFICA (0.00s a 0.35s -> 0.35s)
	# Fade-in do backdrop, entrada da imagem com brilho elevado e escala inicial
	# =========================================================================
	_anim_tween.tween_interval(0.35)
	_anim_tween.parallel().tween_property(_backdrop, "color:a", 0.85, 0.35).set_trans(Tween.TRANS_SINE)
	_anim_tween.parallel().tween_property(_image_rect, "modulate", Color(1.25, 1.25, 1.25, 1.0), 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_anim_tween.parallel().tween_property(_image_rect, "scale", Vector2.ONE * 1.0, 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_anim_tween.parallel().tween_property(_energy_bar, "color:a", 0.40, 0.35).set_trans(Tween.TRANS_SINE)

	# =========================================================================
	# 2. CONSTRUÇÃO DE ENERGIA E APROXIMAÇÃO (0.35s a 0.90s -> 0.55s)
	# Zoom contínuo, faixa de energia intensificada e imagem atinge tom normal
	# =========================================================================
	_anim_tween.chain().tween_interval(0.55)
	_anim_tween.parallel().tween_property(_image_rect, "scale", Vector2.ONE * 1.06, 0.55).set_trans(Tween.TRANS_SINE)
	_anim_tween.parallel().tween_property(_image_rect, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.55).set_trans(Tween.TRANS_SINE)
	_anim_tween.parallel().tween_property(_energy_bar, "color:a", 0.70, 0.55).set_trans(Tween.TRANS_SINE)

	# =========================================================================
	# 3. HOLD DO CLÍMAX (0.90s a 1.30s -> 0.40s)
	# Tensão máxima, zoom no ápice até 1.08, aguardando o momento exato do impacto (1.30s)
	# =========================================================================
	_anim_tween.chain().tween_interval(0.40)
	_anim_tween.parallel().tween_property(_image_rect, "scale", Vector2.ONE * 1.08, 0.40).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_anim_tween.parallel().tween_property(_energy_bar, "color:a", 0.90, 0.40).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

	# Ponto exato do impacto (t = 1.30s)
	_anim_tween.chain().tween_callback(Callable(self, "_on_impact_reached"))

	# =========================================================================
	# 4. FLASH DE IMPACTO (1.30s a 1.50s -> 0.20s)
	# Flash branco total no frame de impacto, recuando gradualmente
	# =========================================================================
	_anim_tween.chain().tween_property(_flash_rect, "color:a", 0.95, 0.04)
	_anim_tween.chain().tween_property(_flash_rect, "color:a", 0.0, 0.16).set_trans(Tween.TRANS_SINE)

	# =========================================================================
	# 5. RESPIRO PÓS-IMPACTO (1.50s a 2.00s -> 0.50s)
	# Imagem absorve o choque visual, zoom estabilizado, energia dissipa suavemente
	# =========================================================================
	_anim_tween.chain().tween_interval(0.50)
	_anim_tween.parallel().tween_property(_image_rect, "scale", Vector2.ONE * 1.09, 0.50).set_trans(Tween.TRANS_SINE)
	_anim_tween.parallel().tween_property(_energy_bar, "color:a", 0.25, 0.50).set_trans(Tween.TRANS_SINE)

	# =========================================================================
	# 6. SAÍDA CINEMATOGRÁFICA (2.00s a 2.50s -> 0.50s)
	# Fade-out da imagem com leve zoom-out e desaparecimento do backdrop
	# =========================================================================
	_anim_tween.chain().tween_interval(0.50)
	_anim_tween.parallel().tween_property(_image_rect, "modulate:a", 0.0, 0.50).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_anim_tween.parallel().tween_property(_image_rect, "scale", Vector2.ONE * 1.12, 0.50).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_anim_tween.parallel().tween_property(_backdrop, "color:a", 0.0, 0.50).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_anim_tween.parallel().tween_property(_energy_bar, "color:a", 0.0, 0.40).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

	# Conclusão aos 2.50s
	_anim_tween.chain().tween_callback(Callable(self, "_on_presentation_finished"))


func _on_impact_reached() -> void:
	_emit_impact()


func _on_presentation_finished() -> void:
	_emit_finished()
	queue_free()


func _emit_impact() -> void:
	if not _impact_emitted:
		_impact_emitted = true
		impact_reached.emit()


func _emit_finished() -> void:
	if not _finished_emitted:
		_finished_emitted = true
		finished.emit()
