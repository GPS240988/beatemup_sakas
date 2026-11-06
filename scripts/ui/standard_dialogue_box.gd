class_name StandardDialogueBox
extends RefCounted

## Padrão Oficial de Caixa de Diálogo e Inspeção — Projeto Sakas
## Centraliza a identidade visual canônica: moldura 9-patch com StyleBoxTexture,
## avatar em Pixel Art HD (TEXTURE_FILTER_NEAREST), LabelSettings arcade tipografados
## e efeito de preenchimento (typewriter effect) com skip instantâneo.

const FRAME_TEXTURE: Texture2D = preload("res://assets/ui/hud/dialog_frame_9patch.png")
const ARCADE_FONT: FontFile = preload("res://assets/fonts/arcade_bold.ttf")
const DEFAULT_GABRIEL_PORTRAIT: Texture2D = preload("res://assets/ui/hud/portraits/portrait_gabriel.png")

const GOLD_SPEAKER_COLOR: Color = Color(0.94, 0.75, 0.39, 1.0)
const OUTLINE_SPEAKER_COLOR: Color = Color(0.04, 0.035, 0.045, 1.0)
const DIALOGUE_TEXT_COLOR: Color = Color(0.96, 0.95, 0.90, 1.0)
const OUTLINE_DIALOGUE_COLOR: Color = Color(0.035, 0.035, 0.045, 1.0)
const SHADOW_COLOR: Color = Color(0.0, 0.0, 0.0, 0.95)
const DIM_BACKGROUND_COLOR: Color = Color(0.012, 0.015, 0.028, 0.86)

const TYPEWRITER_SPEED_CPS: float = 40.0 # Caracteres por segundo


## Cria o StyleBoxTexture oficial com a moldura 9-patch de 14px
static func create_dialogue_stylebox() -> StyleBoxTexture:
	var style := StyleBoxTexture.new()
	style.texture = FRAME_TEXTURE
	style.texture_margin_left = 14.0
	style.texture_margin_top = 14.0
	style.texture_margin_right = 14.0
	style.texture_margin_bottom = 14.0
	return style


## Retorna o LabelSettings oficial do orador (ouro arcade com contorno e sombra)
static func create_speaker_settings(is_mobile: bool = false) -> LabelSettings:
	var settings := LabelSettings.new()
	settings.font = ARCADE_FONT
	settings.font_size = 32
	settings.font_color = GOLD_SPEAKER_COLOR
	settings.outline_size = 4
	settings.outline_color = OUTLINE_SPEAKER_COLOR
	settings.shadow_size = 2
	settings.shadow_color = SHADOW_COLOR
	settings.shadow_offset = Vector2(2, 2)
	return settings


## Retorna o LabelSettings oficial do texto de diálogo (creme/branco com contorno, sombra e entrelinha)
static func create_dialogue_settings(is_mobile: bool = false) -> LabelSettings:
	var settings := LabelSettings.new()
	settings.font = ARCADE_FONT
	settings.font_size = 30
	settings.font_color = DIALOGUE_TEXT_COLOR
	settings.outline_size = 3
	settings.outline_color = OUTLINE_DIALOGUE_COLOR
	settings.shadow_size = 2
	settings.shadow_color = SHADOW_COLOR
	settings.shadow_offset = Vector2(2, 2)
	settings.line_spacing = 8
	return settings


## Retorna o LabelSettings para avisos de continuação / rodapé
static func create_prompt_settings(is_mobile: bool = false) -> LabelSettings:
	var settings := LabelSettings.new()
	settings.font = ARCADE_FONT
	settings.font_size = 18 if is_mobile else 20
	settings.font_color = Color(0.78, 0.81, 0.87, 1.0)
	settings.shadow_size = 1
	settings.shadow_color = Color(0.0, 0.0, 0.0, 0.90)
	settings.shadow_offset = Vector2(1, 1)
	return settings


## Monta a estrutura canônica de nós da caixa de diálogo:
## MarginContainer (área inferior) -> PanelContainer (com StyleBoxTexture)
## -> MarginContainer (padding) -> HBoxContainer -> Avatar + VBox (Orador + Fala + Prompt)
static func build_dialogue_ui(parent: Control, is_mobile: bool = false) -> Dictionary:
	var dialogue_area := MarginContainer.new()
	dialogue_area.name = "DialogueArea"
	dialogue_area.anchor_left = 0.05
	dialogue_area.anchor_top = 0.67
	dialogue_area.anchor_right = 0.95
	dialogue_area.anchor_bottom = 0.98
	dialogue_area.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(dialogue_area)

	var dialogue_panel := PanelContainer.new()
	dialogue_panel.name = "DialogueFrame"
	dialogue_panel.add_theme_stylebox_override("panel", create_dialogue_stylebox())
	dialogue_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dialogue_area.add_child(dialogue_panel)

	var inner_margin := MarginContainer.new()
	inner_margin.name = "InnerMargin"
	inner_margin.add_theme_constant_override("margin_left", 18)
	inner_margin.add_theme_constant_override("margin_top", 12)
	inner_margin.add_theme_constant_override("margin_right", 18)
	inner_margin.add_theme_constant_override("margin_bottom", 10)
	inner_margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dialogue_panel.add_child(inner_margin)

	var hbox := HBoxContainer.new()
	hbox.name = "DialogueHBox"
	hbox.add_theme_constant_override("separation", 18)
	hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inner_margin.add_child(hbox)

	var portrait := TextureRect.new()
	portrait.name = "Portrait"
	portrait.texture = DEFAULT_GABRIEL_PORTRAIT
	portrait.custom_minimum_size = Vector2(110, 110) if not is_mobile else Vector2(88, 88)
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	portrait.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_child(portrait)

	var vbox := VBoxContainer.new()
	vbox.name = "TextVBox"
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 4)
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_child(vbox)

	var speaker_label := Label.new()
	speaker_label.name = "SpeakerName"
	speaker_label.text = "GABRIEL"
	speaker_label.label_settings = create_speaker_settings(is_mobile)
	speaker_label.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	speaker_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	speaker_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(speaker_label)

	var dialogue_label := Label.new()
	dialogue_label.name = "DialogueText"
	dialogue_label.text = ""
	dialogue_label.label_settings = create_dialogue_settings(is_mobile)
	dialogue_label.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	dialogue_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	dialogue_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dialogue_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dialogue_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(dialogue_label)

	var continue_label := Label.new()
	continue_label.name = "ContinuePrompt"
	continue_label.text = "TOQUE OU PRESSIONE ENTER PARA CONTINUAR"
	continue_label.label_settings = create_prompt_settings(is_mobile)
	continue_label.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	continue_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	continue_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	continue_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(continue_label)

	return {
		"dialogue_area": dialogue_area,
		"dialogue_panel": dialogue_panel,
		"portrait": portrait,
		"speaker_label": speaker_label,
		"dialogue_label": dialogue_label,
		"continue_label": continue_label,
		"text_vbox": vbox
	}

