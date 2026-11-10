class_name NarrativeLayoutBuilder
extends RefCounted

## Construtor e montador oficial de layout e nós visuais para o NarrativeDirector
## Desacoplado do NarrativeDirector para conformidade com SRP (Single Responsibility Principle).

const ARCADE_FONT: FontFile = preload("res://assets/fonts/arcade_bold.ttf")
const ENTER_KEY_BADGE_TEXTURE: Texture2D = preload("res://assets/story/ui/enter_key_badge.png")
const StandardDialogueBox = preload("res://scripts/ui/standard_dialogue_box.gd")

const CINEMATIC_MATTE_COLOR: Color = Color(0.012, 0.013, 0.018, 1.0)
const DIALOGUE_GOLD: Color = Color(0.92, 0.72, 0.36, 1.0)
const SPEAKER_NAME_COLOR: Color = Color(0.98, 0.86, 0.40, 1.0)
const SPEAKER_NAME_OUTLINE_COLOR: Color = Color(0.08, 0.06, 0.02, 1.0)
const DIALOGUE_TEXT_COLOR: Color = Color(0.96, 0.95, 0.90, 1.0)


static func build_and_bind(director: CanvasLayer, is_mobile: bool) -> void:
	var root_control := Control.new()
	root_control.name = "RootControl"
	root_control.set_anchors_preset(Control.PRESET_FULL_RECT)
	root_control.anchor_right = 1.0
	root_control.anchor_bottom = 1.0
	root_control.custom_minimum_size = Vector2(1280, 720)
	root_control.mouse_filter = Control.MOUSE_FILTER_PASS
	if director.has_method("_on_root_gui_input"):
		root_control.gui_input.connect(director._on_root_gui_input)
	director.add_child(root_control)
	director._root_control = root_control

	# Fundo escuro absoluto
	var dark_base := ColorRect.new()
	dark_base.name = "DarkBase"
	dark_base.set_anchors_preset(Control.PRESET_FULL_RECT)
	dark_base.color = CINEMATIC_MATTE_COLOR
	dark_base.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root_control.add_child(dark_base)
	director._dark_base = dark_base

	# Placeholder legado mantido para compatibilidade de nós
	var ambient_bg := TextureRect.new()
	ambient_bg.name = "AmbientBackground"
	ambient_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	ambient_bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ambient_bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	ambient_bg.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	ambient_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ambient_bg.visible = false
	root_control.add_child(ambient_bg)
	director._ambient_bg = ambient_bg

	# Palco Superior da Imagem
	var art_stage := Control.new()
	art_stage.name = "ArtStage"
	art_stage.anchor_top = 0.0
	art_stage.anchor_bottom = 0.68 if is_mobile else 0.74
	art_stage.anchor_left = 0.0
	art_stage.anchor_right = 1.0
	art_stage.clip_contents = true
	art_stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root_control.add_child(art_stage)
	director._art_stage = art_stage

	var image_rect := TextureRect.new()
	image_rect.name = "ImageDisplay"
	image_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	image_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED if is_mobile else TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	image_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	image_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	art_stage.add_child(image_rect)
	director._image_rect = image_rect

	var glitch_bars := Control.new()
	glitch_bars.name = "GlitchBars"
	glitch_bars.set_anchors_preset(Control.PRESET_FULL_RECT)
	glitch_bars.mouse_filter = Control.MOUSE_FILTER_IGNORE
	glitch_bars.visible = false
	art_stage.add_child(glitch_bars)
	director._glitch_bars = glitch_bars

	# CRT Monitor Overlay (CENA 05)
	var crt_overlay := Control.new()
	crt_overlay.name = "CRTScreenOverlay"
	crt_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	crt_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	crt_overlay.visible = false
	art_stage.add_child(crt_overlay)
	director._crt_overlay = crt_overlay

	var crt_center := CenterContainer.new()
	crt_center.set_anchors_preset(Control.PRESET_FULL_RECT)
	crt_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	crt_overlay.add_child(crt_center)

	var crt_vbox := VBoxContainer.new()
	crt_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	crt_vbox.add_theme_constant_override("separation", 14)
	crt_center.add_child(crt_vbox)

	var crt_msg_1 := Label.new()
	crt_msg_1.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	crt_msg_1.add_theme_font_override("font", ARCADE_FONT)
	crt_msg_1.add_theme_font_size_override("font_size", 28)
	crt_msg_1.add_theme_color_override("font_color", Color(0.2, 1.0, 0.45, 1.0))
	crt_msg_1.text = "FICHA INSERIDA"
	crt_vbox.add_child(crt_msg_1)
	director._crt_msg_1 = crt_msg_1

	var crt_msg_2 := Label.new()
	crt_msg_2.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	crt_msg_2.add_theme_font_override("font", ARCADE_FONT)
	crt_msg_2.add_theme_font_size_override("font_size", 28)
	crt_msg_2.add_theme_color_override("font_color", Color(0.2, 1.0, 0.45, 1.0))
	crt_msg_2.text = "4 JOGADORES DETECTADOS"
	crt_vbox.add_child(crt_msg_2)
	director._crt_msg_2 = crt_msg_2

	var crt_msg_3 := Label.new()
	crt_msg_3.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	crt_msg_3.add_theme_font_override("font", ARCADE_FONT)
	crt_msg_3.add_theme_font_size_override("font_size", 32)
	crt_msg_3.add_theme_color_override("font_color", Color(1.0, 0.85, 0.15, 1.0))
	crt_msg_3.text = "CONTINUE?"
	crt_vbox.add_child(crt_msg_3)
	director._crt_msg_3 = crt_msg_3

	var crt_continue_button := Button.new()
	crt_continue_button.name = "CRTContinueButton"
	crt_continue_button.text = "CONTINUE?"
	crt_continue_button.add_theme_font_override("font", ARCADE_FONT)
	crt_continue_button.add_theme_font_size_override("font_size", 32)
	crt_continue_button.add_theme_color_override("font_color", Color(1.0, 0.85, 0.15, 1.0))
	crt_continue_button.add_theme_color_override("font_hover_color", Color(1.0, 1.0, 0.45, 1.0))
	crt_continue_button.add_theme_color_override("font_pressed_color", Color(0.95, 0.70, 0.10, 1.0))
	crt_continue_button.add_theme_color_override("font_focus_color", Color(1.0, 0.85, 0.15, 1.0))
	crt_continue_button.add_theme_color_override("font_outline_color", Color(0.45, 0.3, 0.04, 0.95))
	crt_continue_button.add_theme_constant_override("outline_size", 3)

	var empty_sb := StyleBoxEmpty.new()
	crt_continue_button.add_theme_stylebox_override("normal", empty_sb)
	crt_continue_button.add_theme_stylebox_override("hover", empty_sb)
	crt_continue_button.add_theme_stylebox_override("pressed", empty_sb)
	crt_continue_button.add_theme_stylebox_override("focus", empty_sb)
	crt_continue_button.custom_minimum_size = Vector2(240, 56)
	crt_continue_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	crt_continue_button.mouse_filter = Control.MOUSE_FILTER_STOP
	crt_continue_button.visible = false
	if director.has_method("_on_crt_continue_button_pressed"):
		crt_continue_button.pressed.connect(director._on_crt_continue_button_pressed)
	crt_vbox.add_child(crt_continue_button)
	director._crt_continue_button = crt_continue_button

	# CRT Monitor Lights (CENA 04)
	var cena4_crt_overlay := Control.new()
	cena4_crt_overlay.name = "Cena4CRTOverlay"
	cena4_crt_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	cena4_crt_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cena4_crt_overlay.visible = false
	art_stage.add_child(cena4_crt_overlay)
	director._cena4_crt_overlay = cena4_crt_overlay

	var crt_mon_1 := ColorRect.new()
	crt_mon_1.name = "CRTMon1"
	crt_mon_1.anchor_left = 0.76
	crt_mon_1.anchor_top = 0.19
	crt_mon_1.anchor_right = 0.93
	crt_mon_1.anchor_bottom = 0.31
	crt_mon_1.color = Color(0.2, 0.85, 1.0, 0.08)
	crt_mon_1.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cena4_crt_overlay.add_child(crt_mon_1)
	director._crt_mon_1 = crt_mon_1

	var crt_mon_2 := ColorRect.new()
	crt_mon_2.name = "CRTMon2"
	crt_mon_2.anchor_left = 0.07
	crt_mon_2.anchor_top = 0.16
	crt_mon_2.anchor_right = 0.18
	crt_mon_2.anchor_bottom = 0.26
	crt_mon_2.color = Color(0.2, 0.85, 1.0, 0.08)
	crt_mon_2.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cena4_crt_overlay.add_child(crt_mon_2)
	director._crt_mon_2 = crt_mon_2

	var crt_mon_3 := ColorRect.new()
	crt_mon_3.name = "CRTMon3"
	crt_mon_3.anchor_left = 0.65
	crt_mon_3.anchor_top = 0.70
	crt_mon_3.anchor_right = 0.76
	crt_mon_3.anchor_bottom = 0.82
	crt_mon_3.color = Color(0.2, 0.85, 1.0, 0.08)
	crt_mon_3.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cena4_crt_overlay.add_child(crt_mon_3)
	director._crt_mon_3 = crt_mon_3

	# CENA 01: Cartão de Título Centralizado
	var title_container := CenterContainer.new()
	title_container.name = "TitleCardContainer"
	title_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	title_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_container.visible = false
	root_control.add_child(title_container)
	director._title_container = title_container

	var title_vbox := VBoxContainer.new()
	title_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	title_vbox.add_theme_constant_override("separation", 14)
	title_container.add_child(title_vbox)

	var title_header_label := Label.new()
	title_header_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_header_label.add_theme_font_override("font", ARCADE_FONT)
	title_header_label.add_theme_font_size_override("font_size", 32)
	title_header_label.add_theme_color_override("font_color", Color(0.92, 0.72, 0.10, 1.0))
	title_header_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	title_header_label.add_theme_constant_override("shadow_offset_x", 3)
	title_header_label.add_theme_constant_override("shadow_offset_y", 3)
	title_header_label.text = "Saka's"
	title_vbox.add_child(title_header_label)
	director._title_header_label = title_header_label

	var title_sub_label := Label.new()
	title_sub_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_sub_label.add_theme_font_override("font", ARCADE_FONT)
	title_sub_label.add_theme_font_size_override("font_size", 48)
	title_sub_label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 1.0))
	title_sub_label.add_theme_color_override("font_shadow_color", Color(0.1, 0.1, 0.15, 0.95))
	title_sub_label.add_theme_constant_override("shadow_offset_x", 4)
	title_sub_label.add_theme_constant_override("shadow_offset_y", 4)
	title_sub_label.text = "A ÚLTIMA FICHA"
	title_vbox.add_child(title_sub_label)
	director._title_sub_label = title_sub_label

	# Área de Diálogo com Moldura Oficial Arcade
	var dialogue_area := MarginContainer.new()
	dialogue_area.name = "DialogueArea"
	dialogue_area.anchor_top = 0.68 if is_mobile else 0.735
	dialogue_area.anchor_bottom = 0.995 if is_mobile else 0.99
	dialogue_area.anchor_left = 0.0
	dialogue_area.anchor_right = 1.0
	dialogue_area.add_theme_constant_override("margin_left", 0)
	dialogue_area.add_theme_constant_override("margin_right", 0)
	dialogue_area.add_theme_constant_override("margin_bottom", 12)
	dialogue_area.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dialogue_area.visible = false
	root_control.add_child(dialogue_area)
	director._dialogue_area = dialogue_area

	var dialogue_frame := PanelContainer.new()
	dialogue_frame.name = "DialogueFrame"
	dialogue_frame.add_theme_stylebox_override("panel", StandardDialogueBox.create_dialogue_stylebox())
	dialogue_frame.mouse_filter = Control.MOUSE_FILTER_PASS
	dialogue_area.add_child(dialogue_frame)
	director._dialogue_frame = dialogue_frame

	var frame_content := Control.new()
	frame_content.name = "FrameContent"
	frame_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	frame_content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	frame_content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dialogue_frame.add_child(frame_content)

	# Detalhes de realce âmbar Neo-16-bit
	var top_accent := ColorRect.new()
	top_accent.name = "TopAccentBar"
	top_accent.offset_left = 42.0
	top_accent.offset_top = 0.0
	top_accent.offset_right = 150.0
	top_accent.offset_bottom = 3.0
	top_accent.color = Color(0.918, 0.757, 0.424, 1.0) # #eac16c
	top_accent.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame_content.add_child(top_accent)

	var bottom_accent := ColorRect.new()
	bottom_accent.name = "BottomAccentBar"
	bottom_accent.anchor_left = 1.0
	bottom_accent.anchor_top = 1.0
	bottom_accent.anchor_right = 1.0
	bottom_accent.anchor_bottom = 1.0
	bottom_accent.offset_left = -102.0
	bottom_accent.offset_top = -3.0
	bottom_accent.offset_right = -42.0
	bottom_accent.offset_bottom = 0.0
	bottom_accent.color = Color(0.710, 0.541, 0.247, 1.0) # #b58a3f
	bottom_accent.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame_content.add_child(bottom_accent)

	var content_margin := MarginContainer.new()
	content_margin.name = "ContentMargin"
	content_margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	content_margin.add_theme_constant_override("margin_left", 32)
	content_margin.add_theme_constant_override("margin_right", 32)
	content_margin.add_theme_constant_override("margin_top", 14)
	content_margin.add_theme_constant_override("margin_bottom", 12)
	content_margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame_content.add_child(content_margin)

	var content_vbox := VBoxContainer.new()
	content_vbox.name = "VBox"
	content_vbox.alignment = BoxContainer.ALIGNMENT_BEGIN
	content_vbox.add_theme_constant_override("separation", 7)
	content_margin.add_child(content_vbox)

	var speaker_badge := HBoxContainer.new()
	speaker_badge.name = "SpeakerBadge"
	speaker_badge.visible = false
	speaker_badge.custom_minimum_size = Vector2(0, 72)
	speaker_badge.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	speaker_badge.add_theme_constant_override("separation", 16)
	speaker_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content_vbox.add_child(speaker_badge)
	director._speaker_badge = speaker_badge

	var speaker_portrait := TextureRect.new()
	speaker_portrait.name = "SpeakerPortrait"
	speaker_portrait.custom_minimum_size = Vector2(96, 96) if is_mobile else Vector2(72, 72)
	speaker_portrait.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	speaker_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	speaker_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	speaker_portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	speaker_portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	speaker_portrait.visible = false
	speaker_badge.add_child(speaker_portrait)
	director._speaker_portrait = speaker_portrait

	var speaker_label := Label.new()
	speaker_label.name = "SpeakerLabel"
	speaker_label.custom_minimum_size = Vector2(0, 68)
	speaker_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	speaker_label.label_settings = StandardDialogueBox.create_speaker_settings(is_mobile)
	speaker_label.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	speaker_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	speaker_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	speaker_label.text = ""
	speaker_badge.add_child(speaker_label)
	director._speaker_label = speaker_label

	var dialogue_separator := HSeparator.new()
	dialogue_separator.name = "HeaderDivider"
	dialogue_separator.visible = false
	dialogue_separator.custom_minimum_size = Vector2(0, 2)
	var dialogue_separator_style := StyleBoxLine.new()
	dialogue_separator_style.color = Color(0.78, 0.60, 0.31, 0.90)
	dialogue_separator_style.thickness = 1.0
	dialogue_separator.add_theme_stylebox_override("separator", dialogue_separator_style)
	content_vbox.add_child(dialogue_separator)
	director._dialogue_separator = dialogue_separator

	var text_margin := MarginContainer.new()
	text_margin.name = "TextMargin"
	text_margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	text_margin.add_theme_constant_override("margin_left", 10)
	text_margin.add_theme_constant_override("margin_right", 10)
	text_margin.add_theme_constant_override("margin_top", 2)
	text_margin.add_theme_constant_override("margin_bottom", 2)
	text_margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content_vbox.add_child(text_margin)

	var dialogue_label := Label.new()
	dialogue_label.name = "DialogueLabel"
	dialogue_label.label_settings = StandardDialogueBox.create_dialogue_settings(is_mobile)
	dialogue_label.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	dialogue_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	dialogue_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	dialogue_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dialogue_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dialogue_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	text_margin.add_child(dialogue_label)
	director._dialogue_label = dialogue_label

	var footer_hbox := HBoxContainer.new()
	footer_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	content_vbox.add_child(footer_hbox)

	var scene_counter_label := Label.new()
	scene_counter_label.name = "SceneCounterLabel"
	scene_counter_label.add_theme_font_override("font", ARCADE_FONT)
	scene_counter_label.add_theme_font_size_override("font_size", 13)
	scene_counter_label.add_theme_color_override("font_color", Color(0.58, 0.64, 0.72, 0.85))
	scene_counter_label.text = "CENA 02 / 03"
	footer_hbox.add_child(scene_counter_label)
	director._scene_counter_label = scene_counter_label

	var footer_spacer := Control.new()
	footer_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer_hbox.add_child(footer_spacer)

	var advance_prompt_box := HBoxContainer.new()
	advance_prompt_box.name = "AdvancePromptBox"
	advance_prompt_box.add_theme_constant_override("separation", 8)
	advance_prompt_box.alignment = BoxContainer.ALIGNMENT_END
	footer_hbox.add_child(advance_prompt_box)
	director._advance_prompt_box = advance_prompt_box

	var key_badge := TextureRect.new()
	key_badge.name = "KeyBadge"
	key_badge.custom_minimum_size = Vector2(56, 26)
	key_badge.texture = ENTER_KEY_BADGE_TEXTURE
	key_badge.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	key_badge.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	key_badge.visible = false
	advance_prompt_box.add_child(key_badge)
	director._key_badge = key_badge

	var key_badge_label := Label.new()
	key_badge_label.name = "KeyBadgeLabel"
	key_badge_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	key_badge_label.add_theme_font_override("font", ARCADE_FONT)
	key_badge_label.add_theme_font_size_override("font_size", 12)
	key_badge_label.add_theme_color_override("font_color", Color(0.98, 0.80, 0.08, 1.0))
	key_badge_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	key_badge_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	key_badge_label.text = "ENTER"
	key_badge.add_child(key_badge_label)
	director._key_badge_label = key_badge_label

	var prompt_label := Label.new()
	prompt_label.name = "PromptLabel"
	prompt_label.add_theme_font_override("font", ARCADE_FONT)
	prompt_label.add_theme_font_size_override("font_size", 16)
	prompt_label.add_theme_color_override("font_color", Color(1.0, 0.92, 0.25, 1.0))
	prompt_label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.95))
	prompt_label.add_theme_constant_override("shadow_offset_x", 2)
	prompt_label.add_theme_constant_override("shadow_offset_y", 2)
	prompt_label.text = "ENTER"
	advance_prompt_box.add_child(prompt_label)
	director._prompt_label = prompt_label

	var btn_mobile_advance := Button.new()
	btn_mobile_advance.name = "BtnMobileAdvance"
	btn_mobile_advance.text = "►" if is_mobile else "AVANÇAR"
	btn_mobile_advance.custom_minimum_size = Vector2(28, 24) if is_mobile else Vector2(130, 36)
	btn_mobile_advance.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	btn_mobile_advance.add_theme_font_override("font", ARCADE_FONT)
	btn_mobile_advance.add_theme_font_size_override("font_size", 22 if is_mobile else 15)
	if is_mobile:
		var btn_empty_sb := StyleBoxEmpty.new()
		btn_mobile_advance.add_theme_stylebox_override("normal", btn_empty_sb)
		btn_mobile_advance.add_theme_stylebox_override("hover", btn_empty_sb)
		btn_mobile_advance.add_theme_stylebox_override("pressed", btn_empty_sb)
		btn_mobile_advance.add_theme_stylebox_override("focus", btn_empty_sb)
		btn_mobile_advance.add_theme_stylebox_override("disabled", btn_empty_sb)
	if director.has_method("advance_or_skip_text"):
		btn_mobile_advance.pressed.connect(director.advance_or_skip_text)
	footer_hbox.add_child(btn_mobile_advance)
	director._btn_mobile_advance = btn_mobile_advance

	# Barra de Ações Superior
	var top_overlay := MarginContainer.new()
	top_overlay.name = "TopOverlay"
	top_overlay.anchor_top = 0.0
	top_overlay.anchor_right = 1.0
	top_overlay.offset_bottom = 60.0
	top_overlay.add_theme_constant_override("margin_top", 14)
	top_overlay.add_theme_constant_override("margin_right", 24)
	top_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_overlay.visible = false
	root_control.add_child(top_overlay)
	director._top_overlay = top_overlay

	var top_hbox := HBoxContainer.new()
	top_hbox.alignment = BoxContainer.ALIGNMENT_END
	top_overlay.add_child(top_hbox)

	var btn_skip := Button.new()
	btn_skip.name = "BtnSkip"
	btn_skip.text = "PULAR ⏩"
	btn_skip.custom_minimum_size = Vector2(105, 34)
	btn_skip.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	btn_skip.add_theme_font_override("font", ARCADE_FONT)
	btn_skip.add_theme_font_size_override("font_size", 12)
	btn_skip.visible = false
	if director.has_method("skip_sequence"):
		btn_skip.pressed.connect(director.skip_sequence)
	top_hbox.add_child(btn_skip)
	director._btn_skip = btn_skip

	var fade_overlay := ColorRect.new()
	fade_overlay.name = "FadeOverlay"
	fade_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	fade_overlay.color = Color(0, 0, 0, 1)
	fade_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fade_overlay.modulate.a = 0.0
	root_control.add_child(fade_overlay)
	director._fade_overlay = fade_overlay

	var audio_player := AudioStreamPlayer.new()
	audio_player.name = "AudioPlayer"
	director.add_child(audio_player)
	director._audio_player = audio_player

	if director.has_method("_on_narrative_layout_resized"):
		if not root_control.resized.is_connected(director._on_narrative_layout_resized):
			root_control.resized.connect(director._on_narrative_layout_resized)
		if art_stage != null and not art_stage.resized.is_connected(director._on_narrative_layout_resized):
			art_stage.resized.connect(director._on_narrative_layout_resized)

