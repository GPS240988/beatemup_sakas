extends "res://scripts/events/narrative_director.gd"

## Variante de apresentação narrativa para desktop e navegador desktop.
## Mantém a imagem e a caixa em áreas separadas, exceto na revelação do fliperama,
## que utiliza o viewport completo durante o zoom.

var _desktop_layout_update_in_progress: bool = false
var _arcade_fullscreen_mode: bool = false


func _is_mobile_runtime() -> bool:
	if force_mobile_for_test:
		return true
	# Não classifica um desktop com monitor touchscreen como celular.
	# A plataforma deve informar explicitamente uma feature mobile.
	return (
		OS.has_feature("mobile")
		or OS.has_feature("web_android")
		or OS.has_feature("web_ios")
	)


func _ready() -> void:
	super._ready()
	_configure_desktop_advance_prompt()


func _build_ui_nodes() -> void:
	super._build_ui_nodes()
	if _scene_counter_label != null:
		_scene_counter_label.text = ""
	_configure_desktop_advance_prompt()


func _configure_visual_layout() -> void:
	super._configure_visual_layout()
	_apply_desktop_presentation_mode()
	_configure_desktop_advance_prompt()


func _load_texture_to_rect(path: String) -> void:
	super._load_texture_to_rect(path)
	_apply_desktop_presentation_mode()


func _display_image_event(
	ev: Resource,
	img_path: String,
	entry_eff: String,
	zoom_start: float,
	zoom_end: float,
	glitch_frames: int
) -> void:
	# O fliperama usa o viewport inteiro: não há faixa vazia nem moldura de diálogo.
	_arcade_fullscreen_mode = (
		str(ev.get("id")) == "arcade_machine"
		or entry_eff == "arcade_power_on"
	)
	_apply_responsive_layout()

	if _arcade_fullscreen_mode:
		if _dialogue_area != null:
			_dialogue_area.visible = false
	else:
		# Prepara texto, orador e moldura antes do fade da imagem. Assim, a caixa
		# já está montada no primeiro frame em que a ilustração começa a aparecer.
		_prepare_dialogue_preview(ev)

	super._display_image_event(ev, img_path, entry_eff, zoom_start, zoom_end, glitch_frames)

	if _arcade_fullscreen_mode and _dialogue_area != null:
		_dialogue_area.visible = false


func _prepare_dialogue_preview(ev: Resource) -> void:
	if _dialogue_area == null:
		return

	var texts: Array = ev.get("texts") if ev.get("texts") != null else []
	var text_content: String = str(texts[0]) if not texts.is_empty() else ""
	var speakers_arr: Array = ev.get("speakers") if ev.get("speakers") != null else []
	var speaker_name: String = ""
	if not speakers_arr.is_empty() and not str(speakers_arr[0]).strip_edges().is_empty():
		speaker_name = str(speakers_arr[0]).strip_edges()
	else:
		speaker_name = str(ev.get("speaker")).strip_edges()

	_apply_dialogue_density()

	if _speaker_badge != null:
		_speaker_badge.visible = not speaker_name.is_empty()
	var is_mob: bool = _is_mobile_runtime()
	if _speaker_label != null:
		_speaker_label.text = speaker_name.to_upper()
		_speaker_label.visible = not speaker_name.is_empty()
		_speaker_label.label_settings = StandardDialogueBox.create_speaker_settings(is_mob)
		_speaker_label.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		_speaker_label.add_theme_font_size_override("font_size", _speaker_label.label_settings.font_size)
	if _speaker_portrait != null:
		var portrait_texture: Texture2D = _resolve_speaker_portrait(speaker_name, ev)
		_speaker_portrait.texture = portrait_texture
		_speaker_portrait.visible = portrait_texture != null and not speaker_name.is_empty()
		_speaker_portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if _dialogue_separator != null:
		_dialogue_separator.visible = not speaker_name.is_empty()
	if _dialogue_label != null:
		_dialogue_label.text = text_content
		_dialogue_label.visible_characters = 0
		_dialogue_label.label_settings = StandardDialogueBox.create_dialogue_settings(is_mob)
		_dialogue_label.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		_dialogue_label.add_theme_font_size_override("font_size", _dialogue_label.label_settings.font_size)
	if _scene_counter_label != null:
		_scene_counter_label.visible = false
		_scene_counter_label.text = ""

	_configure_desktop_advance_prompt()
	var is_mobile: bool = _is_mobile_runtime()
	if _advance_prompt_box != null:
		_advance_prompt_box.visible = not is_mobile
	if _btn_mobile_advance != null:
		_btn_mobile_advance.visible = is_mobile
		if is_mobile:
			_btn_mobile_advance.text = "►"
			_style_mobile_advance_button()
	_dialogue_area.visible = true
	_dialogue_area.modulate.a = 1.0
	_apply_mobile_dialogue_contract()


func _show_current_text_block(ev: Resource) -> void:
	super._show_current_text_block(ev)

	# Padroniza a identificação e o prompt em desktop nativo e desktop web.
	if str(ev.get("id")) == "arcade_machine":
		return
	if _scene_counter_label != null:
		_scene_counter_label.visible = false
		_scene_counter_label.text = ""
	if _key_badge != null:
		_key_badge.visible = false
	if _prompt_label != null:
		_prompt_label.text = "►"
		_prompt_label.add_theme_font_size_override("font_size", 22)

	# O método-base reaplica LabelSettings e dimensões genéricas ao montar cada
	# bloco. Reaplicamos aqui o contrato específico da narrativa mobile depois
	# dessa montagem, antes do próximo frame ser desenhado.
	_apply_mobile_dialogue_contract()


func _configure_desktop_advance_prompt() -> void:
	# Evita fontes/ícones diferentes entre execução nativa e navegador desktop.
	# Padronizado para flecha arcade '►' unificada entre mobile e desktop.
	if _key_badge != null:
		_key_badge.visible = false
	if _key_badge_label != null:
		_key_badge_label.text = "►"
	if _prompt_label != null:
		_prompt_label.text = "►"
		_prompt_label.add_theme_font_size_override("font_size", 22)


func _apply_responsive_layout() -> void:
	if _root_control == null or _art_stage == null or _dialogue_area == null:
		return
	if _desktop_layout_update_in_progress:
		return

	_desktop_layout_update_in_progress = true

	if _arcade_fullscreen_mode:
		# Revelação do fliperama: imagem até o limite inferior do viewport.
		_art_stage.anchor_left = 0.0
		_art_stage.anchor_top = 0.0
		_art_stage.anchor_right = 1.0
		_art_stage.anchor_bottom = 1.0
		_art_stage.offset_left = 0.0
		_art_stage.offset_top = 0.0
		_art_stage.offset_right = 0.0
		_art_stage.offset_bottom = 0.0
		_art_stage.clip_contents = true
		_dialogue_area.visible = false
		_apply_desktop_presentation_mode()
		_desktop_layout_update_in_progress = false
		return

	if _is_mobile_runtime():
		# Calcula a geometria mobile em uma única passagem. Não chama o layout-base
		# para depois sobrescrever os anchors: isso evitaria ciclos de resize do ArtStage.
		var viewport_size: Vector2 = _root_control.size
		if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
			_desktop_layout_update_in_progress = false
			return

		var aspect_ratio: float = viewport_size.x / viewport_size.y
		var is_portrait: bool = aspect_ratio < 1.0
		var ultra_compact: bool = viewport_size.y < 420.0 and not is_portrait
		var compact_landscape: bool = viewport_size.y < 600.0 and not is_portrait
		# Aumenta a faixa vertical do diálogo em paisagem. Em telas baixas,
		# reserva mais altura para falas multilinha sem comprimir o cabeçalho.
		var mobile_art_bottom: float = 0.58 if is_portrait else (0.38 if ultra_compact else (0.48 if compact_landscape else 0.54))
		var mobile_dialogue_top: float = 0.60 if is_portrait else mobile_art_bottom
		var mobile_bottom_inset: float = 18.0 if is_portrait else (14.0 if ultra_compact else 20.0)

		_art_stage.anchor_left = 0.0
		_art_stage.anchor_top = 0.0
		_art_stage.anchor_right = 1.0
		_art_stage.anchor_bottom = mobile_art_bottom
		_art_stage.offset_left = 0.0
		_art_stage.offset_top = 0.0
		_art_stage.offset_right = 0.0
		_art_stage.offset_bottom = 0.0
		_art_stage.clip_contents = true

		_dialogue_area.anchor_left = 0.0
		_dialogue_area.anchor_top = mobile_dialogue_top
		_dialogue_area.anchor_right = 1.0
		# Âncora em 100% com recuo em pixels: evita que a borda inferior
		# dependa de arredondamento percentual em viewports mobile escalados.
		_dialogue_area.anchor_bottom = 1.0
		_dialogue_area.offset_left = 0.0
		_dialogue_area.offset_top = 0.0
		_dialogue_area.offset_right = 0.0
		_dialogue_area.offset_bottom = -mobile_bottom_inset

		var margin_h: float = 18.0
		if aspect_ratio >= 1.95:
			var ultrawide_extra: float = maxf(0.0, viewport_size.x - (viewport_size.y * (16.0 / 9.0)))
			margin_h = clampf(ultrawide_extra * 0.25 + 24.0, 36.0, 84.0)
		_dialogue_area.offset_left = margin_h
		_dialogue_area.offset_right = -margin_h
		_dialogue_area.add_theme_constant_override("margin_left", 0)
		_dialogue_area.add_theme_constant_override("margin_right", 0)
		_dialogue_area.add_theme_constant_override("margin_bottom", 0)

		_apply_mobile_dialogue_contract()
		_apply_desktop_presentation_mode()
		_desktop_layout_update_in_progress = false
		return

	# Desktop: imagem e caixa ocupam áreas adjacentes e não se sobrepõem.
	var art_bottom: float = 0.72
	if _root_control.size.y < 420.0:
		art_bottom = 0.66
	elif _root_control.size.y < 520.0:
		art_bottom = 0.69

	_art_stage.anchor_left = 0.0
	_art_stage.anchor_top = 0.0
	_art_stage.anchor_right = 1.0
	_art_stage.anchor_bottom = art_bottom
	_art_stage.offset_left = 0.0
	_art_stage.offset_top = 0.0
	_art_stage.offset_right = 0.0
	_art_stage.offset_bottom = 0.0
	_art_stage.clip_contents = true

	_dialogue_area.anchor_left = 0.0
	_dialogue_area.anchor_top = art_bottom
	_dialogue_area.anchor_right = 1.0
	_dialogue_area.anchor_bottom = 1.0
	_dialogue_area.offset_left = 0.0
	_dialogue_area.offset_top = 0.0
	_dialogue_area.offset_right = 0.0
	_dialogue_area.offset_bottom = 0.0
	_dialogue_area.add_theme_constant_override("margin_left", 0)
	_dialogue_area.add_theme_constant_override("margin_right", 0)

	_apply_desktop_presentation_mode()
	_desktop_layout_update_in_progress = false


func _apply_dialogue_density() -> void:
	super._apply_dialogue_density()
	_apply_mobile_dialogue_contract()


func _apply_mobile_dialogue_contract() -> void:
	if not _is_mobile_runtime() or _root_control == null or _dialogue_area == null:
		return

	var viewport_size: Vector2 = _root_control.size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return

	var aspect_ratio: float = viewport_size.x / viewport_size.y
	var is_portrait: bool = aspect_ratio < 1.0
	var ultra_compact: bool = viewport_size.y < 420.0 and not is_portrait

	# A geometria externa já foi calculada em uma única passagem por
	# _apply_responsive_layout(). Aqui são normalizados apenas os elementos internos.
	_dialogue_area.add_theme_constant_override("margin_bottom", 0)

	var portrait_size: float = 40.0 if ultra_compact else 88.0
	var speaker_size: int = 22 if ultra_compact else 28
	var dialogue_size: int = 18 if ultra_compact else 26
	var speaker_row_height: float = 34.0 if ultra_compact else 44.0
	var line_spacing: int = 4 if ultra_compact else 8

	if _speaker_portrait != null:
		_speaker_portrait.custom_minimum_size = Vector2(portrait_size, portrait_size)
		_speaker_portrait.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		_speaker_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_speaker_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		_speaker_portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

	if _speaker_label != null:
		if _speaker_label.label_settings == null:
			_speaker_label.label_settings = StandardDialogueBox.create_speaker_settings(true)
		_speaker_label.label_settings.font_size = speaker_size
		_speaker_label.custom_minimum_size = Vector2(0.0, speaker_row_height)
		_speaker_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_speaker_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		_speaker_label.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		_speaker_label.add_theme_font_size_override("font_size", speaker_size)

	if _dialogue_label != null:
		if _dialogue_label.label_settings == null:
			_dialogue_label.label_settings = StandardDialogueBox.create_dialogue_settings(true)
		_dialogue_label.label_settings.font_size = dialogue_size
		_dialogue_label.label_settings.line_spacing = line_spacing
		_dialogue_label.custom_minimum_size = Vector2.ZERO
		_dialogue_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_dialogue_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
		_dialogue_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_dialogue_label.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		_dialogue_label.add_theme_font_size_override("font_size", dialogue_size)

	if _dialogue_separator != null:
		_dialogue_separator.custom_minimum_size = Vector2(0.0, 1.0)

	var content_margin: MarginContainer = null
	if _dialogue_frame != null:
		content_margin = _dialogue_frame.get_node_or_null("FrameContent/ContentMargin") as MarginContainer
	if content_margin != null:
		# A StyleBoxTexture já fornece 14px de margem de conteúdo pelo 9-patch.
		# Zera apenas o padding vertical duplicado do container interno.
		content_margin.add_theme_constant_override("margin_top", 0)
		content_margin.add_theme_constant_override("margin_bottom", 0)

	var mobile_hbox: HBoxContainer = null
	if _dialogue_frame != null:
		mobile_hbox = _dialogue_frame.get_node_or_null("FrameContent/ContentMargin/MobileDialogueHBox") as HBoxContainer
	if mobile_hbox != null:
		mobile_hbox.add_theme_constant_override("separation", 14 if ultra_compact else 18)
		var right_vbox := mobile_hbox.get_node_or_null("RightVBox") as VBoxContainer
		if right_vbox != null:
			right_vbox.add_theme_constant_override("separation", 3)

	var frame_content: Control = null
	if _dialogue_frame != null:
		frame_content = _dialogue_frame.get_node_or_null("FrameContent") as Control
	if frame_content != null:
		# Mantém os elementos internos contidos na moldura.
		frame_content.clip_contents = true

	# A barra dourada inferior é desenhada por último para não ficar encoberta
	# pela árvore dinâmica de conteúdo criada para o layout mobile.
	if _dialogue_frame != null:
		var bottom_accent := _dialogue_frame.get_node_or_null("FrameContent/BottomAccentBar") as ColorRect
		if bottom_accent != null:
			bottom_accent.visible = true
			bottom_accent.z_index = 2
			bottom_accent.move_to_front()


func _align_dialogue_area_to_image() -> void:
	if _arcade_fullscreen_mode:
		return
	if _is_mobile_runtime():
		super._align_dialogue_area_to_image()
		_apply_mobile_dialogue_contract()
		return
	if _dialogue_area == null:
		return

	# A faixa inferior usa toda a largura do viewport no desktop.
	_dialogue_area.anchor_left = 0.0
	_dialogue_area.anchor_right = 1.0
	_dialogue_area.offset_left = 0.0
	_dialogue_area.offset_right = 0.0
	_dialogue_area.add_theme_constant_override("margin_left", 0)
	_dialogue_area.add_theme_constant_override("margin_right", 0)


func _apply_desktop_presentation_mode() -> void:
	if _image_rect == null or _art_stage == null:
		return

	# O TextureRect acompanha exatamente os limites do ArtStage.
	_image_rect.anchor_left = 0.0
	_image_rect.anchor_top = 0.0
	_image_rect.anchor_right = 1.0
	_image_rect.anchor_bottom = 1.0
	_image_rect.offset_left = 0.0
	_image_rect.offset_top = 0.0
	_image_rect.offset_right = 0.0
	_image_rect.offset_bottom = 0.0
	_image_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_image_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

	# COVERED preenche o palco sem barras laterais ou faixas vazias,
	# mantendo o aspect ratio original (sem distorção) em desktop e mobile.
	_image_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
