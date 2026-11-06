class_name NarrativeDirector
extends CanvasLayer

const MobileScreenAction = preload("res://scripts/mobile/mobile_screen_action.gd")
const StandardDialogueBox = preload("res://scripts/ui/standard_dialogue_box.gd")

## Diretor e Apresentador Narrativo Cinemático para Beat 'em Up 2.5D (Saka's: A Última Ficha).
## Implementa o Padrão Oficial de Apresentação Arcade:
## - Imagem principal preservada em proporção original, sem distorção ou cortes.
## - Laterais em matte escuro neutro (pillarbox), sem duplicar a própria ilustração.
## - Moldura alinhada horizontalmente aos limites visíveis da arte.
## - Moldura arcade premium em preto translúcido com contorno dourado.
## - Tipografia arcade oficial (arcade_bold.ttf) para títulos, orador, diálogos, contador e prompts.
## - Avanço de falas estritamente manual: NENHUMA fala avança ou desaparece por temporizador automático.
## - Proteção contra avanços repetidos acidentais e isolamento de entrada contra sangramento no gameplay.
## - Transições cinematográficas com fade e crossfade sóbrios (~0.32s), glitch analógico e áudio procedural.
## - Suporte a Teclado (Espaço/Enter), Gamepad (A/ui_accept), Mouse e Toque Mobile nativo.
## Em estrita conformidade com Direcao_de_Arte.md e GAME_RULES.md.

signal sequence_started(sequence_id: String)
signal event_started(event_id: String, text_index: int)
signal event_completed(event_id: String)
signal sequence_completed(sequence_id: String)
signal sequence_skipped(sequence_id: String)

const StoryEventClass = preload("res://scripts/events/story_event.gd")
const NarrativeLayoutBuilderClass = preload("res://scripts/events/narrative_layout_builder.gd")
const NarrativeAudioSynthClass = preload("res://scripts/events/narrative_audio_synth.gd")
const StorySequenceClass = preload("res://scripts/events/story_sequence.gd")

const ARCADE_FONT: FontFile = preload("res://assets/fonts/arcade_bold.ttf")
const DIALOG_FRAME_TEXTURE: Texture2D = preload("res://assets/story/ui/narrative_frame_9patch.png")
const SPEAKER_BADGE_TEXTURE: Texture2D = preload("res://assets/ui/hud/speaker_badge_9patch.png")
const ENTER_KEY_BADGE_TEXTURE: Texture2D = preload("res://assets/story/ui/enter_key_badge.png")

# Retratos oficiais usados no diálogo da introdução.
# A normalização do nome permite aceitar ANDRÉ e ANDRE.
const SPEAKER_PORTRAIT_PATHS: Dictionary = {
	"ANDRÉ": "res://assets/ui/hud/portraits/portrait_andre.png",
	"ANDRE": "res://assets/ui/hud/portraits/portrait_andre.png",
	"GABRIEL": "res://assets/ui/hud/portraits/portrait_gabriel.png",
	"GUILHERME": "res://assets/ui/hud/portraits/portrait_guilherme.png",
	"JULIANA": "res://assets/ui/hud/portraits/portrait_juliana.png"
}

const SPEAKER_NAME_COLOR: Color = Color(0.91, 0.72, 0.36, 1.0)
const SPEAKER_NAME_OUTLINE_COLOR: Color = Color(0.09, 0.07, 0.11, 1.0)
const DIALOGUE_TEXT_COLOR: Color = Color(0.95, 0.94, 0.90, 1.0)
const DIALOGUE_GOLD: Color = Color(0.92, 0.72, 0.36, 1.0)

# Preenchimento cinematográfico das laterais quando a arte não ocupa toda a largura.
# Mantemos o matte quase preto para preservar o foco na pixel art original.
const CINEMATIC_MATTE_COLOR: Color = Color(0.012, 0.013, 0.018, 1.0)
const DIALOGUE_IMAGE_INSET_MIN: float = 12.0
const DIALOGUE_IMAGE_INSET_MAX: float = 24.0
const DIALOGUE_MIN_WIDTH_RATIO: float = 0.62
const DIALOGUE_FALLBACK_WIDTH_RATIO: float = 0.82

@export var default_sequence_path: String = "res://resources/story/story_intro_map1.tres"
@export var auto_start_on_ready: bool = false

var is_playing: bool = false
var current_sequence: Resource = null
var current_event_index: int = 0
var current_text_index: int = 0

var _is_transitioning: bool = false
var _active_tween: Tween = null
var _pulse_tween: Tween = null
var _zoom_tween: Tween = null
var _crt_flicker_tween: Tween = null
var _jitter_tween: Tween = null
var _portrait_tween: Tween = null

# Nós visuais internos
var _root_control: Control
var _dark_base: ColorRect
var _ambient_bg: TextureRect
var _art_stage: Control
var _image_rect: TextureRect
var _glitch_bars: Control
var _title_container: CenterContainer
var _title_header_label: Label
var _title_sub_label: Label
var _dialogue_area: MarginContainer
var _dialogue_frame: PanelContainer
var _speaker_badge: Control
var _speaker_portrait: TextureRect
var _speaker_label: Label
var _dialogue_separator: HSeparator
var _dialogue_label: Label
var _scene_counter_label: Label
var _advance_prompt_box: HBoxContainer
var _key_badge: TextureRect
var _key_badge_label: Label
var _prompt_label: Label
var _btn_mobile_advance: Button
var _btn_skip: Button
var _top_overlay: MarginContainer
var _fade_overlay: ColorRect
var _audio_player: AudioStreamPlayer
var _mobile_revelation_button: Button
var _crt_overlay: Control
var _crt_msg_1: Label
var _crt_msg_2: Label
var _crt_msg_3: Label
var _cena4_crt_overlay: Control
var _crt_mon_1: ColorRect
var _crt_mon_2: ColorRect
var _crt_mon_3: ColorRect
var _crt_continue_button: Button = null
var _crt_advance_locked: bool = false
var _mobile_layout_configured: bool = false
var force_mobile_for_test: bool = false
var _is_typing: bool = false
var _typewriter_tween: Tween = null
# WebView removed to prevent black screen issue during intro-to-gameplay transition

# Efeitos sonoros procedurais integrados
var _sfx_deep_hum: AudioStreamWAV
var _sfx_nostalgia: AudioStreamWAV
var _sfx_glitch: AudioStreamWAV
var _sfx_advance: AudioStreamWAV


func _init() -> void:
	layer = 120 # Acima do jogo e da HUD, abaixo de menus críticos de sistema


func _ready() -> void:
	add_to_group("narrative_director")
	if has_node("%RootControl"):
		_bind_scene_nodes()
	elif _root_control == null:
		_build_ui_nodes()
	_generate_sound_effects()
	_configure_visual_layout()

	if auto_start_on_ready and not default_sequence_path.is_empty():
		play_sequence_from_path(default_sequence_path)


func _bind_scene_nodes() -> void:
	_root_control = get_node_or_null("%RootControl") as Control
	_dark_base = get_node_or_null("%DarkBase") as ColorRect
	_ambient_bg = get_node_or_null("%AmbientBackground") as TextureRect
	_art_stage = get_node_or_null("%ArtStage") as Control
	_image_rect = get_node_or_null("%ImageDisplay") as TextureRect
	_glitch_bars = get_node_or_null("%GlitchBars") as Control
	_title_container = get_node_or_null("%TitleCardContainer") as CenterContainer
	_title_header_label = get_node_or_null("%TitleHeader") as Label
	_title_sub_label = get_node_or_null("%TitleSub") as Label
	_dialogue_area = get_node_or_null("%DialogueArea") as MarginContainer
	_dialogue_frame = get_node_or_null("%DialogueFrame") as PanelContainer
	_speaker_badge = get_node_or_null("%SpeakerBadge") as Control
	_speaker_portrait = get_node_or_null("%SpeakerPortrait") as TextureRect
	_speaker_label = get_node_or_null("%SpeakerLabel") as Label
	_dialogue_separator = get_node_or_null("%HeaderDivider") as HSeparator
	_dialogue_label = get_node_or_null("%DialogueLabel") as Label
	_scene_counter_label = get_node_or_null("%SceneCounterLabel") as Label
	_advance_prompt_box = get_node_or_null("%AdvancePromptBox") as HBoxContainer
	_key_badge = get_node_or_null("%KeyBadge") as TextureRect
	_key_badge_label = get_node_or_null("%KeyBadgeLabel") as Label
	_prompt_label = get_node_or_null("%PromptLabel") as Label
	_btn_mobile_advance = get_node_or_null("%BtnMobileAdvance") as Button
	_top_overlay = get_node_or_null("%TopOverlay") as MarginContainer
	_btn_skip = get_node_or_null("%BtnSkip") as Button
	_fade_overlay = get_node_or_null("%FadeOverlay") as ColorRect
	_audio_player = get_node_or_null("%AudioPlayer") as AudioStreamPlayer
	_crt_overlay = get_node_or_null("%CRTScreenOverlay") as Control
	_crt_msg_1 = get_node_or_null("%CRTMsg1") as Label
	_crt_msg_2 = get_node_or_null("%CRTMsg2") as Label
	_crt_msg_3 = get_node_or_null("%CRTMsg3") as Label
	_cena4_crt_overlay = get_node_or_null("%Cena4CRTOverlay") as Control
	_crt_mon_1 = get_node_or_null("%CRTMon1") as ColorRect
	_crt_mon_2 = get_node_or_null("%CRTMon2") as ColorRect
	_crt_mon_3 = get_node_or_null("%CRTMon3") as ColorRect

	if _dark_base != null:
		_dark_base.color = CINEMATIC_MATTE_COLOR
	if _ambient_bg != null:
		_ambient_bg.texture = null
		_ambient_bg.visible = false
	if _top_overlay != null:
		_top_overlay.visible = false
	if _btn_skip != null:
		_btn_skip.visible = false
	if _key_badge != null:
		_key_badge.visible = false
	if _dialogue_frame != null:
		_dialogue_frame.add_theme_stylebox_override("panel", StandardDialogueBox.create_dialogue_stylebox())
	if _speaker_label != null:
		_speaker_label.label_settings = StandardDialogueBox.create_speaker_settings(_is_mobile_runtime())
		_speaker_label.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if _dialogue_label != null:
		_dialogue_label.label_settings = StandardDialogueBox.create_dialogue_settings(_is_mobile_runtime())
		_dialogue_label.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if _speaker_portrait != null:
		_speaker_portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

	if _root_control != null and not _root_control.gui_input.is_connected(_on_root_gui_input):
		_root_control.gui_input.connect(_on_root_gui_input)
	if _btn_skip != null and not _btn_skip.pressed.is_connected(skip_sequence):
		_btn_skip.pressed.connect(skip_sequence)
	if _btn_mobile_advance != null and not _btn_mobile_advance.pressed.is_connected(advance_or_skip_text):
		_btn_mobile_advance.pressed.connect(advance_or_skip_text)

	# CRT Continue Button interativo para Mobile (CENA 05)
	if _crt_overlay != null and _crt_continue_button == null:
		var crt_vbox: VBoxContainer = null
		if _crt_msg_3 != null:
			crt_vbox = _crt_msg_3.get_parent() as VBoxContainer
		if crt_vbox != null:
			_crt_continue_button = Button.new()
			_crt_continue_button.name = "CRTContinueButton"
			_crt_continue_button.text = "CONTINUE?"
			_crt_continue_button.add_theme_font_override("font", ARCADE_FONT)
			_crt_continue_button.add_theme_font_size_override("font_size", 32)
			_crt_continue_button.add_theme_color_override("font_color", Color(1.0, 0.85, 0.15, 1.0))
			_crt_continue_button.add_theme_color_override("font_hover_color", Color(1.0, 1.0, 0.45, 1.0))
			_crt_continue_button.add_theme_color_override("font_pressed_color", Color(0.95, 0.70, 0.10, 1.0))
			_crt_continue_button.add_theme_color_override("font_focus_color", Color(1.0, 0.85, 0.15, 1.0))
			_crt_continue_button.add_theme_color_override("font_outline_color", Color(0.45, 0.3, 0.04, 0.95))
			_crt_continue_button.add_theme_constant_override("outline_size", 3)

			var empty_sb := StyleBoxEmpty.new()
			_crt_continue_button.add_theme_stylebox_override("normal", empty_sb)
			_crt_continue_button.add_theme_stylebox_override("hover", empty_sb)
			_crt_continue_button.add_theme_stylebox_override("pressed", empty_sb)
			_crt_continue_button.add_theme_stylebox_override("focus", empty_sb)
			_crt_continue_button.custom_minimum_size = Vector2(240, 56)
			_crt_continue_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
			_crt_continue_button.mouse_filter = Control.MOUSE_FILTER_STOP
			_crt_continue_button.visible = false
			_crt_continue_button.pressed.connect(_on_crt_continue_button_pressed)
			crt_vbox.add_child(_crt_continue_button)

	if _is_mobile_runtime():
		_setup_mobile_dialogue_layout()


func _unhandled_input(event: InputEvent) -> void:
	if not is_playing or _is_transitioning:
		return

	# ESC não pula nem cancela a sequência narrativa (preserva apenas avanço por ENTER)
	if event.is_action_pressed("ui_cancel") or (event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE):
		return

	# No mobile, CENA 05 (arcade_machine) ignora toques gerais na tela; o avanço é EXCLUSIVO via botão CONTINUE? no monitor CRT
	if _is_mobile_runtime() and _is_current_event_arcade_machine():
		return

	if event.is_action_pressed("ui_accept") or (event is InputEventKey and event.pressed and not event.echo and (event.keycode == KEY_ENTER or event.keycode == KEY_SPACE)) or (event is InputEventMouseButton and event.pressed) or (event is InputEventScreenTouch and event.pressed):
		_safe_handle_input()
		advance_or_skip_text()


func _on_root_gui_input(event: InputEvent) -> void:
	if not is_playing or _is_transitioning:
		return
	# No mobile, CENA 05 ignora toques fora do botão CRT
	if _is_mobile_runtime() and _is_current_event_arcade_machine():
		return
	if (event is InputEventMouseButton and event.pressed) or (event is InputEventScreenTouch and event.pressed):
		_safe_handle_input()
		advance_or_skip_text()


func _on_dialogue_gui_input(event: InputEvent) -> void:
	if not is_playing or _is_transitioning:
		return
	if _is_mobile_runtime() and _is_current_event_arcade_machine():
		return
	if (event is InputEventMouseButton and event.pressed) or (event is InputEventScreenTouch and event.pressed):
		_safe_handle_input()
		advance_or_skip_text()


func _safe_handle_input() -> void:
	if get_viewport() != null:
		get_viewport().set_input_as_handled()


## Carrega e inicia sequência a partir de um caminho de recurso .tres
func play_sequence_from_path(res_path: String) -> void:
	if ResourceLoader.exists(res_path):
		var res := load(res_path)
		if res != null:
			play_sequence(res)
			return

	printerr("NarrativeDirector: Não foi possível carregar sequência em: ", res_path)
	_finish_sequence()


## Inicia a reprodução de uma sequência StorySequence
func play_sequence(sequence: Resource) -> void:
	if sequence == null:
		_finish_sequence()
		return

	if _fade_overlay == null or _root_control == null:
		if has_node("%RootControl"):
			_bind_scene_nodes()
		else:
			_build_ui_nodes()

	current_sequence = sequence
	current_event_index = 0
	current_text_index = 0
	is_playing = true
	_is_transitioning = true

	# Bloqueia movimentação e combate do jogador durante a cena
	_set_gameplay_suspended(true)

	visible = true
	if _fade_overlay != null:
		_fade_overlay.modulate.a = 1.0 # Inicia totalmente em preto
	if _title_container != null:
		_title_container.visible = false
	if _dialogue_area != null:
		_dialogue_area.visible = false
	if _image_rect != null:
		_image_rect.visible = false
	if _ambient_bg != null:
		_ambient_bg.texture = null
		_ambient_bg.visible = false
	if _dark_base != null:
		_dark_base.color = CINEMATIC_MATTE_COLOR
	if _glitch_bars != null:
		_glitch_bars.visible = false

	var seq_id: String = str(current_sequence.get("sequence_id"))
	sequence_started.emit(seq_id)

	# Fade inicial a partir do preto (~0.32s)
	_play_initial_fade_in()


func _play_initial_fade_in() -> void:
	_kill_tweens()
	_active_tween = create_tween()
	if _fade_overlay != null:
		_active_tween.tween_property(_fade_overlay, "modulate:a", 0.0, 0.32).set_trans(Tween.TRANS_SINE)
	_active_tween.tween_interval(0.15) # Pausa sóbria
	_active_tween.tween_callback(func():
		_is_transitioning = false
		_process_current_event()
	)


func _process_current_event() -> void:
	if not is_playing or current_sequence == null:
		_finish_sequence()
		return

	var events: Array = current_sequence.get("events")
	if current_event_index >= events.size():
		_finish_sequence()
		return

	var ev: Resource = events[current_event_index]
	current_text_index = 0

	var ev_id: String = str(ev.get("id"))
	var img_path: String = str(ev.get("image_path"))
	var sound_name: String = str(ev.get("sound_effect_name"))
	var entry_eff: String = str(ev.get("entry_effect"))
	var zoom_start: float = maxf(float(ev.get("zoom_start")), 0.01)
	var zoom_end: float = maxf(float(ev.get("zoom_end")), 0.01)
	var glitch_frames: int = int(ev.get("glitch_frames"))

	_play_audio_by_name(sound_name)

	# Identifica se é Tela de Abertura (CENA 01) ou Cena Narrativa com Imagem
	if ev_id == "title_card" or img_path.is_empty():
		_display_title_card(ev)
	else:
		_display_image_event(ev, img_path, entry_eff, zoom_start, zoom_end, glitch_frames)


## CENA 01 — Cartão de Título Cinemático (Saka's / A ÚLTIMA FICHA)
func _display_title_card(ev: Resource) -> void:
	if _image_rect != null:
		_image_rect.visible = false
	if _ambient_bg != null:
		_ambient_bg.texture = null
		_ambient_bg.visible = false
	if _dialogue_area != null:
		_dialogue_area.visible = false
	if _title_container != null:
		_title_container.visible = true
		_title_container.modulate.a = 0.0

	var texts: Array = ev.get("texts")
	var header_text: String = str(texts[0]) if texts.size() > 0 else "Saka's"
	var sub_text: String = str(texts[1]) if texts.size() > 1 else "A ÚLTIMA FICHA"

	if _title_header_label != null:
		_title_header_label.text = header_text
	if _title_sub_label != null:
		_title_sub_label.text = sub_text
		_title_sub_label.modulate.a = 0.0

	var ev_id: String = str(ev.get("id"))
	event_started.emit(ev_id, 0)

	_kill_tweens()
	_active_tween = create_tween()

	# 1. Fade In "Saka's" (0.50s)
	_active_tween.tween_property(_title_container, "modulate:a", 1.0, 0.20)
	if _title_header_label != null:
		_title_header_label.modulate.a = 0.0
		_active_tween.tween_property(_title_header_label, "modulate:a", 1.0, 0.50).set_trans(Tween.TRANS_SINE)
	_active_tween.tween_interval(0.25)
	# 2. Fade In "A ÚLTIMA FICHA" (0.50s)
	if _title_sub_label != null:
		_title_sub_label.modulate.a = 0.0
		_active_tween.tween_property(_title_sub_label, "modulate:a", 1.0, 0.50).set_trans(Tween.TRANS_SINE)
	# 3. Hold confortável (2.0s)
	_active_tween.tween_interval(2.0)
	# 4. Fade Out suave para o próximo evento (0.50s)
	_active_tween.tween_property(_title_container, "modulate:a", 0.0, 0.50).set_trans(Tween.TRANS_SINE)
	_active_tween.tween_interval(0.20)
	_active_tween.tween_callback(func():
		_advance_to_next_event()
	)


## CENAS COM IMAGEM (CENA 02, CENA 03 e Próximas Cenas)
func _display_image_event(
	ev: Resource,
	img_path: String,
	entry_eff: String,
	zoom_start: float,
	zoom_end: float,
	glitch_frames: int
) -> void:
	if _title_container != null:
		_title_container.visible = false

	_load_texture_to_rect(img_path)
	var mobile_safe_framing: bool = _is_mobile_runtime()
	if _mobile_revelation_button != null:
		_mobile_revelation_button.visible = false

	# Letterbox/pillarbox profissional: não repetimos a ilustração nas laterais.
	# As áreas externas ficam em matte quase preto para evitar duplicação visual.
	if _ambient_bg != null:
		_ambient_bg.texture = null
		_ambient_bg.visible = false
	if _dark_base != null:
		_dark_base.color = CINEMATIC_MATTE_COLOR
	if _image_rect != null:
		_image_rect.visible = true
		# Guarda contra size zero (antes do layout no Web) para evitar affine_invert det==0
		var img_size: Vector2 = _image_rect.size
		if img_size.x > 0.0 and img_size.y > 0.0:
			_image_rect.pivot_offset = img_size * 0.5
		# Em mobile, mantém a escala neutra para não cortar bordas da arte.
		# Fade/glitch continuam como animações de entrada.
		var safe_zoom: float = maxf(zoom_start, 0.01)
		_image_rect.scale = Vector2.ONE * (1.0 if mobile_safe_framing else safe_zoom)
		_image_rect.position = Vector2.ZERO
		_image_rect.modulate = Color.WHITE

	# Recalcula a largura útil após definir a escala inicial da imagem.
	call_deferred("_align_dialogue_area_to_image")

	# Limpa overlays e tweens anteriores
	if _cena4_crt_overlay != null:
		_cena4_crt_overlay.visible = false
	if _crt_overlay != null:
		_crt_overlay.visible = false

	_is_transitioning = true
	_kill_tweens()
	_active_tween = create_tween()

	var trans_dur: float = 0.60
	var ev_id: String = str(ev.get("id"))

	# CENA 02 — OS QUATRO: Fade In lento (0.7s) + zoom suave contínuo de 100% para 103%
	if ev_id == "the_four" or entry_eff == "slow_zoom":
		if _image_rect != null:
			_image_rect.modulate.a = 0.0
			_active_tween.tween_property(_image_rect, "modulate:a", 1.0, 0.70).set_trans(Tween.TRANS_SINE)
			if _zoom_tween != null and _zoom_tween.is_valid():
				_zoom_tween.kill()
			if not mobile_safe_framing:
				_zoom_tween = create_tween()
				_zoom_tween.tween_property(_image_rect, "scale", Vector2.ONE * 1.03, 10.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

	# CENA 03 — OS QUE NÃO ESTÃO: Fade In suave
	elif ev_id == "the_missing" or entry_eff == "crossfade_glitch" or entry_eff == "glitch":
		if _image_rect != null:
			_image_rect.modulate.a = 0.0
			_active_tween.tween_property(_image_rect, "modulate:a", 1.0, trans_dur).set_trans(Tween.TRANS_SINE)

	# CENA 04 — A SALA SECRETA: Fade In suave da imagem; apenas os monitores CRT oscilam sutilmente em luminosidade
	elif ev_id == "secret_room" or entry_eff == "crt_flicker":
		if _image_rect != null:
			_image_rect.modulate.a = 0.0
			_active_tween.tween_property(_image_rect, "modulate:a", 1.0, trans_dur).set_trans(Tween.TRANS_SINE)

		if _cena4_crt_overlay != null:
			_cena4_crt_overlay.visible = true

		if _crt_flicker_tween != null and _crt_flicker_tween.is_valid():
			_crt_flicker_tween.kill()
		_crt_flicker_tween = create_tween().set_loops()

		if _crt_mon_1 != null:
			_crt_mon_1.modulate.a = 0.05
			_crt_flicker_tween.tween_property(_crt_mon_1, "modulate:a", 0.14, 0.85).set_trans(Tween.TRANS_SINE)
			_crt_flicker_tween.tween_property(_crt_mon_1, "modulate:a", 0.03, 0.65).set_trans(Tween.TRANS_SINE)
			_crt_flicker_tween.tween_property(_crt_mon_1, "modulate:a", 0.11, 1.10).set_trans(Tween.TRANS_SINE)
		if _crt_mon_2 != null:
			_crt_mon_2.modulate.a = 0.04
			_crt_flicker_tween.parallel().tween_property(_crt_mon_2, "modulate:a", 0.13, 1.20).set_trans(Tween.TRANS_SINE)
			_crt_flicker_tween.parallel().tween_property(_crt_mon_2, "modulate:a", 0.02, 0.75).set_trans(Tween.TRANS_SINE)
		if _crt_mon_3 != null:
			_crt_mon_3.modulate.a = 0.04
			_crt_flicker_tween.parallel().tween_property(_crt_mon_3, "modulate:a", 0.12, 0.95).set_trans(Tween.TRANS_SINE)
			_crt_flicker_tween.parallel().tween_property(_crt_mon_3, "modulate:a", 0.04, 0.80).set_trans(Tween.TRANS_SINE)

	# CENA 05 — A MÁQUINA (CRT DISPLAY INTEGRADO):
	# Zoom em direção ao monitor, espera 1s após término completo, e exibe mensagens sequenciais dentro do CRT:
	# INSERT COIN -> 4 PLAYER DETECTED -> CONTINUE
	elif ev_id == "arcade_machine" or entry_eff == "arcade_power_on":
		if _dialogue_area != null:
			_dialogue_area.visible = false
		if _image_rect != null:
			_image_rect.modulate = Color(1.2, 1.2, 1.2, 0.0)
			var crt_size: Vector2 = _image_rect.size
			if crt_size.x > 0.0 and crt_size.y > 0.0:
				_image_rect.pivot_offset = Vector2(crt_size.x * 0.5, crt_size.y * 0.42)
			_active_tween.tween_property(_image_rect, "modulate:a", 1.0, 0.45).set_trans(Tween.TRANS_SINE)
			_active_tween.tween_property(_image_rect, "modulate", Color.WHITE, 0.25).set_trans(Tween.TRANS_QUAD)

			if _zoom_tween != null and _zoom_tween.is_valid():
				_zoom_tween.kill()
			if not mobile_safe_framing:
				_zoom_tween = create_tween()
				_zoom_tween.tween_property(_image_rect, "scale", Vector2.ONE * 1.18, 1.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

		if _crt_overlay != null:
			_crt_overlay.visible = true
			if _crt_msg_1 != null: _crt_msg_1.modulate.a = 0.0
			if _crt_msg_2 != null: _crt_msg_2.modulate.a = 0.0
			if _crt_msg_3 != null: _crt_msg_3.modulate.a = 0.0
		if _crt_continue_button != null:
			_crt_continue_button.modulate.a = 0.0
			_crt_continue_button.visible = false
			_crt_continue_button.disabled = false
			_crt_advance_locked = false

		# Aguarda conclusão do zoom (1.6s) + 1.0s de pausa obrigatória
		_active_tween.tween_interval(1.6 + 1.0)

		# Sequência CRT na tela:
		_active_tween.tween_callback(func():
			_play_sound(_sfx_deep_hum)
			if _crt_msg_1 != null:
				var t1 := create_tween()
				t1.tween_property(_crt_msg_1, "modulate:a", 1.0, 0.25)
		)
		_active_tween.tween_interval(0.8)

		_active_tween.tween_callback(func():
			_play_sound(_sfx_glitch)
			if _crt_msg_2 != null:
				var t2 := create_tween()
				t2.tween_property(_crt_msg_2, "modulate:a", 1.0, 0.25)
		)
		_active_tween.tween_interval(0.8)

		_active_tween.tween_callback(func():
			_play_sound(_sfx_nostalgia)
			if _is_mobile_runtime() and _crt_continue_button != null:
				_crt_continue_button.visible = true
				_crt_continue_button.disabled = false
				_crt_advance_locked = false
				var t_btn := create_tween()
				t_btn.tween_property(_crt_continue_button, "modulate:a", 1.0, 0.25)
				if _crt_flicker_tween != null and _crt_flicker_tween.is_valid():
					_crt_flicker_tween.kill()
				_crt_flicker_tween = create_tween().set_loops()
				_crt_flicker_tween.tween_property(_crt_continue_button, "modulate:a", 0.35, 0.45).set_trans(Tween.TRANS_SINE)
				_crt_flicker_tween.tween_property(_crt_continue_button, "modulate:a", 1.0, 0.45).set_trans(Tween.TRANS_SINE)
				if _crt_msg_3 != null:
					_crt_msg_3.visible = false
			elif _crt_msg_3 != null:
				_crt_msg_3.visible = true
				var t3 := create_tween()
				t3.tween_property(_crt_msg_3, "modulate:a", 1.0, 0.25)
				if _crt_flicker_tween != null and _crt_flicker_tween.is_valid():
					_crt_flicker_tween.kill()
				_crt_flicker_tween = create_tween().set_loops()
				_crt_flicker_tween.tween_property(_crt_msg_3, "modulate:a", 0.35, 0.45).set_trans(Tween.TRANS_SINE)
				_crt_flicker_tween.tween_property(_crt_msg_3, "modulate:a", 1.0, 0.45).set_trans(Tween.TRANS_SINE)
		)
		_active_tween.tween_interval(0.4)

	# CENA 06 — PASSADO E PRESENTE: Fade suave
	elif ev_id == "past_present" or entry_eff == "past_present_crossfade":
		if _image_rect != null:
			_image_rect.modulate.a = 0.0
			_active_tween.tween_property(_image_rect, "modulate:a", 1.0, trans_dur).set_trans(Tween.TRANS_SINE)

	else: # CENA 07 ou default crossfade
		if _image_rect != null:
			_image_rect.modulate.a = 0.0
			_active_tween.tween_property(_image_rect, "modulate:a", 1.0, trans_dur).set_trans(Tween.TRANS_SINE)

	_active_tween.tween_callback(func():
		_is_transitioning = false
		_show_current_text_block(ev)
	)


## Apresenta o bloco de diálogo atual dentro da Moldura Oficial Arcade
## COMPORTAMENTO CANÔNICO: Permanece na tela INDEFINIDAMENTE até que o jogador confirme o avanço!
func _show_current_text_block(ev: Resource) -> void:
	var ev_id: String = str(ev.get("id"))

	# Na CENA 05, o texto é exibido diretamente no monitor CRT, mantendo a moldura externa oculta
	if ev_id == "arcade_machine":
		if _dialogue_area != null:
			_dialogue_area.visible = false
		if _btn_mobile_advance != null:
			_btn_mobile_advance.visible = false
		if _mobile_revelation_button != null:
			_mobile_revelation_button.visible = false
		_start_prompt_pulse()
		event_started.emit(ev_id, current_text_index)
		return

	if _is_mobile_runtime():
		_setup_mobile_dialogue_layout()

	var texts: Array = ev.get("texts")
	if texts.is_empty() or current_text_index >= texts.size():
		_advance_to_next_event()
		return

	var text_content: String = str(texts[current_text_index])

	# Suporte a múltiplos oradores (CENA 07) ou orador único
	var speaker_name: String = ""
	var speakers_arr: Array = ev.get("speakers") if ev.get("speakers") != null else []
	if current_text_index < speakers_arr.size() and not str(speakers_arr[current_text_index]).is_empty():
		speaker_name = str(speakers_arr[current_text_index]).strip_edges()
	else:
		speaker_name = str(ev.get("speaker")).strip_edges()

	# Cabeçalho em fluxo: retrato e nome ficam na mesma linha.
	# O dimensionamento considera largura e altura, inclusive em celulares deitados.
	_apply_dialogue_density()

	var viewport_size: Vector2 = _root_control.size if _root_control != null else Vector2(1280.0, 720.0)
	var ultra_compact: bool = viewport_size.y < 420.0
	var compact_dialogue_ui: bool = ultra_compact or viewport_size.x < 760.0 or viewport_size.y < 540.0
	var is_mob := _is_mobile_runtime()
	var is_narration: bool = speaker_name.strip_edges().to_upper() in ["NARRAÇÃO", "NARRACAO"]
	var portrait_side: float = 88.0 if is_mob else (40.0 if ultra_compact else (56.0 if compact_dialogue_ui else 72.0))

	# Narração não usa avatar: reduz a altura do cabeçalho sem perder destaque.
	# Isso reserva espaço para a frase em duas linhas e mantém o rodapé dentro da moldura.
	if is_narration:
		portrait_side = 0.0 if is_mob else (28.0 if ultra_compact else (34.0 if compact_dialogue_ui else 42.0))

	if _speaker_badge != null:
		_speaker_badge.visible = not speaker_name.is_empty()
		_speaker_badge.custom_minimum_size = Vector2(0.0, portrait_side)

	if _speaker_portrait != null:
		if is_mob:
			_speaker_portrait.custom_minimum_size = Vector2(88, 88)
			_speaker_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			_speaker_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			_speaker_portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		else:
			_speaker_portrait.custom_minimum_size = Vector2(portrait_side, portrait_side)
		var portrait_texture: Texture2D = _resolve_speaker_portrait(speaker_name, ev)
		_speaker_portrait.texture = portrait_texture
		_speaker_portrait.visible = portrait_texture != null and not speaker_name.is_empty()
		if portrait_texture != null and not speaker_name.is_empty():
			if _portrait_tween != null and _portrait_tween.is_valid():
				_portrait_tween.kill()
			_speaker_portrait.modulate.a = 0.0
			_portrait_tween = create_tween()
			_portrait_tween.tween_property(
				_speaker_portrait,
				"modulate:a",
				1.0,
				0.18
			).set_trans(Tween.TRANS_SINE)
		else:
			_speaker_portrait.modulate.a = 1.0

	var has_portrait: bool = _speaker_portrait != null and _speaker_portrait.visible and _speaker_portrait.texture != null
	var spk_min_h: float = portrait_side if has_portrait else 32.0

	if _speaker_label != null:
		_speaker_label.visible = not speaker_name.is_empty()
		_speaker_label.text = speaker_name.to_upper()
		_speaker_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		_speaker_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_speaker_label.label_settings = StandardDialogueBox.create_speaker_settings(is_mob)
		_speaker_label.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		_speaker_label.custom_minimum_size = Vector2(0.0, spk_min_h)
		_speaker_label.add_theme_font_size_override("font_size", _speaker_label.label_settings.font_size)

	if _speaker_badge != null:
		_speaker_badge.custom_minimum_size = Vector2(0.0, spk_min_h)

	# Linha dourada entre a identificação e o conteúdo da fala.
	if _dialogue_separator != null:
		_dialogue_separator.visible = not speaker_name.is_empty()

	# Margens seguras oficiais: nunca encostam nas cantoneiras 9-patch e
	# mantêm a posição estável independentemente do número de linhas do texto.
	if _dialogue_frame != null:
		var content_margin := _dialogue_frame.get_node_or_null("FrameContent/ContentMargin") as MarginContainer
		if content_margin != null:
			var m_side: int = 24 if is_mob else 32
			var m_top: int = 12 if is_mob else 14
			var m_bottom: int = 10 if is_mob else 12
			content_margin.add_theme_constant_override("margin_left", m_side)
			content_margin.add_theme_constant_override("margin_right", m_side)
			content_margin.add_theme_constant_override("margin_top", m_top)
			content_margin.add_theme_constant_override("margin_bottom", m_bottom)
		var content_vbox := _dialogue_frame.get_node_or_null("FrameContent/ContentMargin/VBox") as VBoxContainer
		if content_vbox != null:
			content_vbox.add_theme_constant_override("separation", 4 if is_mob else 6)
		var text_margin := _dialogue_frame.get_node_or_null("FrameContent/ContentMargin/VBox/TextMargin") as MarginContainer
		if text_margin != null:
			text_margin.add_theme_constant_override("margin_top", 2)
			text_margin.add_theme_constant_override("margin_bottom", 2)

	# A fala fica sempre abaixo do divisor e alinhada à esquerda.
	if _dialogue_label != null:
		_dialogue_label.text = text_content
		_dialogue_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		_dialogue_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_dialogue_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_dialogue_label.label_settings = StandardDialogueBox.create_dialogue_settings(is_mob)
		_dialogue_label.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		_dialogue_label.add_theme_font_size_override("font_size", _dialogue_label.label_settings.font_size)
		_start_typewriter()

	# Atualiza Tecla e Indicador de Avanço (Oculta moldura duplicada ENTER)
	if _key_badge != null:
		_key_badge.visible = false
	if _key_badge_label != null:
		_key_badge_label.text = "ENTER"
	if _prompt_label != null:
		_prompt_label.text = "ENTER"
		_prompt_label.add_theme_color_override("font_color", Color(1.0, 0.92, 0.25, 1.0))

	# Adapta controle de avanço: no PC exibe prompt arcade do teclado; no mobile exibe flechinha indicativa
	var is_mobile := _is_mobile_runtime()
	if _btn_mobile_advance != null:
		_btn_mobile_advance.visible = is_mobile
		if is_mobile:
			_btn_mobile_advance.text = "►"
			_style_mobile_advance_button()
	if _advance_prompt_box != null:
		_advance_prompt_box.visible = not is_mobile

	# Configura Identificação da Cena (CENA 01 a 07)
	if _scene_counter_label != null:
		_scene_counter_label.visible = true
		_scene_counter_label.text = "CENA %02d" % (current_event_index + 1)

	# Exibe Área de Diálogo com animação suave de entrada da moldura
	if _dialogue_area != null:
		_dialogue_area.visible = true
		_dialogue_area.modulate.a = 1.0

	_start_prompt_pulse()
	event_started.emit(ev_id, current_text_index)

	# NOTA ARQUITETURAL CANÔNICA (Padrão Sakas):
	# NENHUM temporizador é agendado aqui. A fala NÃO avança automaticamente.
	# O avanço ocorre exclusivamente via interação do jogador em advance_or_skip_text().


## Resolve o retrato pelo nome do orador; usa portrait_path como fallback.
func _resolve_speaker_portrait(speaker_name: String, ev: Resource) -> Texture2D:
	if speaker_name.strip_edges().is_empty():
		return null

	var normalized_name: String = speaker_name.strip_edges().to_upper()
	var portrait_path: String = str(
		SPEAKER_PORTRAIT_PATHS.get(normalized_name, "")
	)

	# Mantém compatibilidade com eventos antigos que já usam portrait_path.
	if portrait_path.is_empty():
		portrait_path = str(ev.get("portrait_path")).strip_edges()

	if portrait_path.is_empty():
		return null

	if not ResourceLoader.exists(portrait_path):
		push_warning(
			"NarrativeDirector: retrato não encontrado para %s: %s"
			% [normalized_name, portrait_path]
		)
		return null

	return load(portrait_path) as Texture2D


## Avanço Manual de Fala: acionado por [Espaço], [Enter], Gamepad (A) ou Toque Mobile
func advance_or_skip_text() -> void:
	if not is_playing or current_sequence == null:
		return

	if _is_typing:
		_skip_typewriter()
		return

	var events: Array = current_sequence.get("events")
	if current_event_index >= events.size():
		_finish_sequence()
		return

	var ev: Resource = events[current_event_index]
	var ev_id: String = str(ev.get("id"))

	# Se estiver na tela de título (CENA 01), avança imediatamente mesmo se em transição
	if ev_id == "title_card":
		_kill_tweens()
		_is_transitioning = false
		_advance_to_next_event()
		return

	# Na CENA 05 (A Máquina CRT), avança para a Cena 06
	if ev_id == "arcade_machine":
		_kill_tweens()
		_is_transitioning = false
		if _crt_continue_button != null:
			_crt_continue_button.visible = false
			_crt_continue_button.disabled = true
		_crt_advance_locked = false
		_play_sound(_sfx_advance)
		_advance_to_next_event()
		return

	if _is_transitioning:
		return

	var texts: Array = ev.get("texts")
	_play_sound(_sfx_advance)

	# Avança para o próximo bloco de diálogo da mesma cena
	if current_text_index + 1 < texts.size():
		current_text_index += 1
		_on_text_block_advanced(ev)
	else:
		_advance_to_next_event()


## Executa efeitos cinematográficos específicos na transição interna de falas/textos
func _on_text_block_advanced(ev: Resource) -> void:
	var ev_id: String = str(ev.get("id"))

	# CENA 06 — PASSADO E PRESENTE: Glitch curto (2 frames) entre cada mudança + pequena distorção de posição
	if ev_id == "past_present":
		_trigger_glitch_effect(2)
		_trigger_horizontal_jitter(2.5, 0.12)
		_show_current_text_block(ev)

	# CENA 07 — DIÁLOGO ENTRE PERSONAGENS: Transição suave entre falas (fade sutil do texto do diálogo)
	elif ev_id == "back_to_arcade" or str(ev.get("event_type")) == "dialogue" or str(ev.get("entry_effect")) == "quick_dialogue_crossfade":
		if _dialogue_label != null:
			var text_fade := create_tween()
			text_fade.tween_property(_dialogue_label, "modulate:a", 0.0, 0.10).set_trans(Tween.TRANS_SINE)
			text_fade.tween_callback(func():
				_show_current_text_block(ev)
				if _dialogue_label != null:
					_dialogue_label.modulate.a = 0.0
			)
			text_fade.tween_property(_dialogue_label, "modulate:a", 1.0, 0.15).set_trans(Tween.TRANS_SINE)
		else:
			_show_current_text_block(ev)

	else:
		_show_current_text_block(ev)


func _trigger_horizontal_jitter(offset_px: float = 3.0, duration: float = 0.2) -> void:
	if _image_rect == null:
		return
	if _jitter_tween != null and _jitter_tween.is_valid():
		_jitter_tween.kill()
	var orig_x: float = 0.0
	_jitter_tween = create_tween()
	_jitter_tween.tween_property(_image_rect, "position:x", orig_x + offset_px, duration * 0.25)
	_jitter_tween.tween_property(_image_rect, "position:x", orig_x - offset_px, duration * 0.25)
	_jitter_tween.tween_property(_image_rect, "position:x", orig_x + (offset_px * 0.5), duration * 0.25)
	_jitter_tween.tween_property(_image_rect, "position:x", orig_x, duration * 0.25)


func _trigger_crt_pulse(duration: float = 0.2) -> void:
	if _image_rect == null:
		return
	var pulse_t := create_tween()
	pulse_t.tween_property(_image_rect, "modulate", Color(1.3, 1.3, 1.3, 1.0), duration * 0.4).set_trans(Tween.TRANS_QUAD)
	pulse_t.tween_property(_image_rect, "modulate", Color.WHITE, duration * 0.6).set_trans(Tween.TRANS_QUAD)


func _advance_to_next_event() -> void:
	if _mobile_revelation_button != null:
		_mobile_revelation_button.visible = false
	if _crt_continue_button != null:
		_crt_continue_button.visible = false
		_crt_continue_button.disabled = true
	_crt_advance_locked = false
	var events: Array = current_sequence.get("events") if current_sequence != null else []
	if current_event_index < events.size():
		var prev_ev: Resource = events[current_event_index]
		event_completed.emit(str(prev_ev.get("id")))

	current_event_index += 1
	if current_event_index >= events.size():
		_finish_sequence()
	else:
		_process_current_event()


## Pula toda a sequência cinematográfica com segurança imediata
func skip_sequence() -> void:
	if not is_playing:
		return
	var seq_id: String = str(current_sequence.get("sequence_id")) if current_sequence != null else ""
	sequence_skipped.emit(seq_id)
	_finish_sequence()


func _finish_sequence() -> void:
	if not is_playing:
		return

	if _mobile_revelation_button != null:
		_mobile_revelation_button.visible = false
	is_playing = false
	_is_transitioning = true
	_kill_tweens()

	# Registra no GameSession que o prólogo já foi assistido
	var session = get_node_or_null("/root/GameSession")
	if session != null and "has_played_intro" in session:
		session.has_played_intro = true

	# Fade out suave da camada narrativa (~0.32s)
	var exit_tween := create_tween()
	if _fade_overlay != null:
		exit_tween.tween_property(_fade_overlay, "modulate:a", 1.0, 0.25)
	exit_tween.tween_callback(func():
		if _image_rect != null:
			_image_rect.visible = false
		if _ambient_bg != null:
			_ambient_bg.texture = null
			_ambient_bg.visible = false
		if _title_container != null:
			_title_container.visible = false
		if _dialogue_area != null:
			_dialogue_area.visible = false
		if _glitch_bars != null:
			_glitch_bars.visible = false
	)
	if _fade_overlay != null:
		exit_tween.tween_property(_fade_overlay, "modulate:a", 0.0, 0.32)
	exit_tween.tween_callback(func():
		visible = false
		_is_transitioning = false
		_set_gameplay_suspended(false)
		var seq_id: String = str(current_sequence.get("sequence_id")) if current_sequence != null else ""
		sequence_completed.emit(seq_id)
	)


## Efeito de glitch visual analógico de 2 a 3 frames
func _trigger_glitch_effect(frames_count: int = 3) -> void:
	if _glitch_bars == null:
		return

	_glitch_bars.visible = true
	for c in _glitch_bars.get_children():
		c.queue_free()

	var colors := [Color(0.2, 0.9, 1.0, 0.6), Color(1.0, 0.2, 0.4, 0.6), Color(0.9, 0.9, 0.9, 0.7)]
	for i in range(5):
		var bar := ColorRect.new()
		bar.color = colors[i % colors.size()]
		var bar_h: float = randf_range(8.0, 24.0)
		var bar_y: float = randf_range(50.0, 700.0)
		bar.position = Vector2(randf_range(-15.0, 15.0), bar_y)
		bar.size = Vector2(1920.0 + 30.0, bar_h)
		_glitch_bars.add_child(bar)

	var delay: float = maxf(float(frames_count) * 0.02, 0.05)
	get_tree().create_timer(delay).timeout.connect(func():
		if _glitch_bars != null and is_instance_valid(_glitch_bars):
			_glitch_bars.visible = false
	)


## Suspende/Restabelece física e controle do jogador durante cutscenes
func _set_gameplay_suspended(suspended: bool) -> void:
	if not is_inside_tree() or get_tree() == null:
		return
	var player = get_tree().get_first_node_in_group("player")
	if player != null and is_instance_valid(player):
		if suspended:
			player.set_physics_process(false)
			player.set_process_unhandled_input(false)
			if "velocity" in player:
				player.velocity = Vector2.ZERO
		else:
			player.set_physics_process(true)
			player.set_process_unhandled_input(true)

	var combat_director = get_tree().get_first_node_in_group("combat_director")
	if combat_director != null and is_instance_valid(combat_director):
		if "is_encounter_active" in combat_director:
			combat_director.set_process(not suspended)


func _load_texture_to_rect(path: String) -> void:
	if path.is_empty():
		return

	var tex: Texture2D = null

	# Mapeamento oficial para as imagens canônicas em res://assets/backgrounds/
	var bg_mapped := ""
	if path.contains("intro_group") or path.contains("the_four") or path.contains("cena02"):
		bg_mapped = "res://assets/backgrounds/intro_cena02.webp"
	elif path.contains("missing_friends") or path.contains("the_missing") or path.contains("cena03"):
		bg_mapped = "res://assets/backgrounds/intro_cena03.webp"
	elif path.contains("secret_room") or path.contains("cena04"):
		bg_mapped = "res://assets/backgrounds/intro_cena04.webp"
	elif path.contains("arcade_machine") or path.contains("cena05"):
		bg_mapped = "res://assets/backgrounds/intro_cena05.webp"
	elif path.contains("past_present") or path.contains("cena06"):
		bg_mapped = "res://assets/backgrounds/intro_cena06.webp"
	elif path.contains("street_memory") or path.contains("back_to_arcade") or path.contains("cena07"):
		bg_mapped = "res://assets/backgrounds/intro_cena07.webp"

	if not bg_mapped.is_empty() and ResourceLoader.exists(bg_mapped):
		tex = load(bg_mapped) as Texture2D

	if tex == null and ResourceLoader.exists(path):
		tex = load(path) as Texture2D

	if tex == null:
		var global_p := ProjectSettings.globalize_path(path)
		if FileAccess.file_exists(global_p):
			var img := Image.load_from_file(global_p)
			if img != null:
				tex = ImageTexture.create_from_image(img)

	if tex == null:
		push_warning("NarrativeDirector: não foi possível carregar a imagem narrativa: %s" % path)
		if _image_rect != null:
			_image_rect.texture = null
		if _ambient_bg != null:
			_ambient_bg.texture = null
			_ambient_bg.visible = false
		return

	# Imagem principal: preenche a tela inteira em celulares (sem barras pretas laterais)
	# e preserva enquadramento original no desktop.
	if _image_rect != null:
		_image_rect.texture = tex
		_image_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_image_rect.stretch_mode = TextureRect.STRETCH_SCALE if _is_mobile_runtime() else TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		_image_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

	# Não criamos uma segunda cópia da imagem.
	# As laterais permanecem com a cor do matte, atrás da arte principal.
	if _ambient_bg != null:
		_ambient_bg.texture = null
		_ambient_bg.visible = false
		_ambient_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE

	call_deferred("_align_dialogue_area_to_image")


func _configure_visual_layout() -> void:
	# Configuração consistente tanto para a cena .tscn quanto para a UI
	# construída programaticamente como fallback.
	if _dark_base != null:
		_dark_base.color = CINEMATIC_MATTE_COLOR
		_dark_base.set_anchors_preset(Control.PRESET_FULL_RECT)
		_dark_base.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# O fundo ambiental fica sem textura: nenhuma cópia ampliada da ilustração.
	if _ambient_bg != null:
		_ambient_bg.texture = null
		_ambient_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_ambient_bg.visible = false

	if _art_stage != null:
		_art_stage.clip_contents = true
		if not _art_stage.resized.is_connected(_on_narrative_layout_resized):
			_art_stage.resized.connect(_on_narrative_layout_resized)

	if _image_rect != null:
		_image_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_image_rect.stretch_mode = TextureRect.STRETCH_SCALE if _is_mobile_runtime() else TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		_image_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		_image_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE

	if _root_control != null:
		if not _root_control.resized.is_connected(_on_narrative_layout_resized):
			_root_control.resized.connect(_on_narrative_layout_resized)

	_apply_responsive_layout()
	if _root_control != null and _is_mobile_runtime() and _mobile_revelation_button == null:
		_mobile_revelation_button = MobileScreenAction.add_inline_primary_action(
			_root_control,
			"AVANÇAR",
			Callable(self, "advance_or_skip_text"),
			Color(0.96, 0.73, 0.22, 1.0),
			0.77, 0.86, 0.95, 0.96
		)
		if _mobile_revelation_button != null:
			_mobile_revelation_button.visible = false
	call_deferred("_align_dialogue_area_to_image")


func _on_narrative_layout_resized() -> void:
	_apply_responsive_layout()
	_apply_dialogue_density()
	call_deferred("_align_dialogue_area_to_image")


func _apply_responsive_layout() -> void:
	# A arte e a moldura ficam em áreas independentes no desktop, sem sobreposição.
	# Em celulares verticais, a arte fica na faixa superior e o painel ganha altura.
	# Em paisagem com pouca altura, a composição e a tipografia ficam compactas.
	if _root_control == null or _art_stage == null or _dialogue_area == null:
		return

	var viewport_size: Vector2 = _root_control.size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return

	var aspect_ratio: float = viewport_size.x / viewport_size.y
	var is_portrait: bool = aspect_ratio < 1.0
	var is_compact_landscape: bool = not is_portrait and viewport_size.y < 520.0

	var art_bottom: float
	var dialogue_top: float

	if _is_mobile_runtime() and not is_portrait:
		# Mobile landscape: a ilustração ocupa o viewport; o painel fica compacto na faixa inferior (74% a 98.5%)
		# garantindo que quase três quartos da tela fiquem visíveis para a imagem e personagens.
		art_bottom = 1.0
		dialogue_top = 0.74
	elif is_portrait:
		# Celular vertical: arte na metade superior (58%) e painel na inferior (40%).
		art_bottom = 0.58
		dialogue_top = 0.60
	elif viewport_size.y < 420.0:
		# Paisagem muito baixa: preserva arte 100% visível e painel compacto no terço inferior.
		art_bottom = 0.68
		dialogue_top = 0.70
	elif is_compact_landscape:
		# Paisagem compacta: preserva 100% da ilustração visível sem cortes verticais
		art_bottom = 0.72
		dialogue_top = 0.73
	else:
		# Desktop/tablet: painel mais alto para caber cabeçalho, fala e rodapé.
		# A arte perde apenas 3% da altura em relação à versão anterior.
		art_bottom = 0.71
		dialogue_top = 0.735

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
	_dialogue_area.anchor_top = dialogue_top
	_dialogue_area.anchor_right = 1.0
	_dialogue_area.anchor_bottom = 0.985 if _is_mobile_runtime() else 0.99
	_dialogue_area.offset_top = 0.0
	_dialogue_area.offset_bottom = -6.0
	_dialogue_area.offset_left = 12.0 if _is_mobile_runtime() else 0.0
	_dialogue_area.offset_right = -12.0 if _is_mobile_runtime() else 0.0
	_dialogue_area.add_theme_constant_override("margin_left", 0)
	_dialogue_area.add_theme_constant_override("margin_right", 0)


func _is_mobile_runtime() -> bool:
	if force_mobile_for_test:
		return true
	return (
		OS.has_feature("mobile")
		or OS.has_feature("web_android")
		or OS.has_feature("web_ios")
	)


func _apply_dialogue_density() -> void:
	# Tipografia e retrato acompanham largura e altura, não apenas a plataforma.
	if _root_control == null:
		return

	var viewport_size: Vector2 = _root_control.size
	var is_mobile: bool = _is_mobile_runtime()
	var ultra_compact: bool = viewport_size.y > 0.0 and viewport_size.y < 420.0
	var compact: bool = is_mobile or ultra_compact or (viewport_size.x > 0.0 and viewport_size.x < 760.0)

	# Dimensões equilibradas para que avatar, texto e rodapé NUNCA ultrapassem a moldura
	# Preserva estritamente os tamanhos canônicos da StandardDialogueBox, sem regressão de tamanho
	var portrait_side: float = 34.0 if ultra_compact else (88.0 if is_mobile else 56.0)
	var speaker_size: int = 28 if ultra_compact else 32
	var dialogue_size: int = 26 if ultra_compact else 30

	var has_portrait: bool = _speaker_portrait != null and _speaker_portrait.visible and _speaker_portrait.texture != null
	var spk_min_h: float = portrait_side if has_portrait else 32.0

	if _speaker_badge != null:
		_speaker_badge.custom_minimum_size = Vector2(0.0, spk_min_h)

	if _speaker_portrait != null:
		_speaker_portrait.custom_minimum_size = Vector2(portrait_side, portrait_side)
		_speaker_portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

	if _speaker_label != null:
		_speaker_label.custom_minimum_size = Vector2(0.0, spk_min_h)
		if _speaker_label.label_settings == null:
			_speaker_label.label_settings = StandardDialogueBox.create_speaker_settings(is_mobile)
		_speaker_label.label_settings.font_size = speaker_size
		_speaker_label.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		_speaker_label.add_theme_font_size_override("font_size", speaker_size)

	if _dialogue_label != null:
		if _dialogue_label.label_settings == null:
			_dialogue_label.label_settings = StandardDialogueBox.create_dialogue_settings(is_mobile)
		_dialogue_label.label_settings.font_size = dialogue_size
		_dialogue_label.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		_dialogue_label.add_theme_font_size_override("font_size", dialogue_size)

	if _dialogue_separator != null:
		_dialogue_separator.custom_minimum_size = Vector2(0.0, 1.0 if compact else 2.0)

	if _scene_counter_label != null:
		_scene_counter_label.add_theme_font_size_override("font_size", 10 if compact else 12)

	if _prompt_label != null:
		_prompt_label.add_theme_font_size_override("font_size", 14 if compact else 16)

	if _btn_mobile_advance != null:
		if is_mobile:
			# Flecha indicativa moderna de avanço sem moldura retangular
			_btn_mobile_advance.custom_minimum_size = Vector2(28.0, 24.0)
			_btn_mobile_advance.add_theme_font_size_override("font_size", 22)
			_btn_mobile_advance.text = "►"
			_style_mobile_advance_button()
		else:
			_btn_mobile_advance.custom_minimum_size = Vector2(120.0, 32.0)
			_btn_mobile_advance.add_theme_font_size_override("font_size", 14)
			_btn_mobile_advance.text = "AVANÇAR"

	# Margens seguras oficiais: nunca encostam nas cantoneiras e mantêm a posição estável
	if _dialogue_frame != null:
		var content_margin := _dialogue_frame.get_node_or_null("FrameContent/ContentMargin") as MarginContainer
		if content_margin != null:
			var m_side: int = 20 if ultra_compact else 32
			var m_top: int = 10 if ultra_compact else (12 if compact else 14)
			var m_bottom: int = 8 if ultra_compact else (10 if compact else 12)
			content_margin.add_theme_constant_override("margin_left", m_side)
			content_margin.add_theme_constant_override("margin_right", m_side)
			content_margin.add_theme_constant_override("margin_top", m_top)
			content_margin.add_theme_constant_override("margin_bottom", m_bottom)

		var content_vbox := _dialogue_frame.get_node_or_null("FrameContent/ContentMargin/VBox") as VBoxContainer
		if content_vbox != null:
			content_vbox.add_theme_constant_override("separation", 3 if compact else 4)

		var text_margin := _dialogue_frame.get_node_or_null("FrameContent/ContentMargin/VBox/TextMargin") as MarginContainer
		if text_margin != null:
			text_margin.add_theme_constant_override("margin_top", 2)
			text_margin.add_theme_constant_override("margin_bottom", 2)


func _style_mobile_advance_button() -> void:
	if _btn_mobile_advance == null:
		return
	_btn_mobile_advance.text = "►"
	_btn_mobile_advance.add_theme_font_override("font", ARCADE_FONT)
	_btn_mobile_advance.add_theme_font_size_override("font_size", 22)
	_btn_mobile_advance.add_theme_color_override("font_color", Color(1.0, 0.92, 0.25, 1.0))
	_btn_mobile_advance.add_theme_color_override("font_hover_color", Color(1.0, 1.0, 0.6, 1.0))
	_btn_mobile_advance.add_theme_color_override("font_pressed_color", Color(1.0, 0.85, 0.4, 1.0))
	_btn_mobile_advance.add_theme_constant_override("outline_size", 2)
	_btn_mobile_advance.add_theme_color_override("font_outline_color", Color(0.015, 0.02, 0.035, 1.0))

	var empty_sb := StyleBoxEmpty.new()
	_btn_mobile_advance.add_theme_stylebox_override("normal", empty_sb)
	_btn_mobile_advance.add_theme_stylebox_override("hover", empty_sb)
	_btn_mobile_advance.add_theme_stylebox_override("pressed", empty_sb)
	_btn_mobile_advance.add_theme_stylebox_override("focus", empty_sb)
	_btn_mobile_advance.add_theme_stylebox_override("disabled", empty_sb)
	_btn_mobile_advance.custom_minimum_size = Vector2(28.0, 24.0)
	_btn_mobile_advance.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND


func _align_dialogue_area_to_image() -> void:
	# Alinha as laterais da moldura à área realmente ocupada pela textura,
	# sem alterar a altura/posição vertical já aprovada do painel.
	if _dialogue_area == null or _root_control == null:
		return

	if _is_mobile_runtime():
		_dialogue_area.anchor_left = 0.0
		_dialogue_area.anchor_right = 1.0
		_dialogue_area.offset_left = 12.0
		_dialogue_area.offset_right = -12.0
		return

	if _art_stage == null or _image_rect == null or _image_rect.texture == null:
		return

	var viewport_size: Vector2 = _root_control.size
	var stage_size: Vector2 = _art_stage.size
	var texture_size: Vector2 = Vector2(_image_rect.texture.get_size())

	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return
	if stage_size.x <= 0.0 or stage_size.y <= 0.0:
		return
	if texture_size.x <= 0.0 or texture_size.y <= 0.0:
		return

	# Mesma regra de STRETCH_KEEP_ASPECT_CENTERED usada pela imagem principal.
	var fit_scale: float = minf(
		stage_size.x / texture_size.x,
		stage_size.y / texture_size.y
	)

	# Considera o zoom atual, mantendo a moldura alinhada durante os efeitos.
	var zoom_factor: float = maxf(absf(_image_rect.scale.x), 0.01)
	var displayed_width: float = texture_size.x * fit_scale * zoom_factor

	var stage_left: float = _art_stage.position.x
	var stage_right: float = stage_left + stage_size.x
	var stage_center_x: float = stage_left + stage_size.x * 0.5

	# Limita a medição aos limites do palco, pois ele usa clip_contents.
	var image_left: float = maxf(
		stage_center_x - displayed_width * 0.5,
		stage_left
	)
	var image_right: float = minf(
		stage_center_x + displayed_width * 0.5,
		stage_right
	)

	var visible_image_width: float = image_right - image_left
	if visible_image_width <= 0.0:
		return

	var inset: float = clampf(
		visible_image_width * 0.012,
		DIALOGUE_IMAGE_INSET_MIN,
		DIALOGUE_IMAGE_INSET_MAX
	)

	var panel_left: float = image_left + inset
	var panel_right: float = image_right - inset
	var panel_width: float = panel_right - panel_left

	# Em artes muito estreitas (ex.: retrato), amplia apenas a caixa de texto
	# para preservar a legibilidade, mantendo-a centralizada no palco.
	var minimum_width: float = minf(
		viewport_size.x - 48.0,
		viewport_size.x * DIALOGUE_MIN_WIDTH_RATIO
	)
	if panel_width < minimum_width:
		var fallback_width: float = minf(
			viewport_size.x - 48.0,
			maxf(minimum_width, viewport_size.x * DIALOGUE_FALLBACK_WIDTH_RATIO)
		)
		panel_left = (viewport_size.x - fallback_width) * 0.5
		panel_right = panel_left + fallback_width

	# Usa coordenadas fixas do RootControl para manter o alinhamento
	# em diferentes resoluções e proporções de tela.
	_dialogue_area.anchor_left = 0.0
	_dialogue_area.anchor_right = 0.0
	_dialogue_area.offset_left = panel_left
	_dialogue_area.offset_right = panel_right

	# Remove margens laterais internas antigas que poderiam desalinhá-la
	# novamente depois do cálculo externo.
	_dialogue_area.add_theme_constant_override("margin_left", 0)
	_dialogue_area.add_theme_constant_override("margin_right", 0)


func _start_prompt_pulse() -> void:
	var target_node: Control
	if _is_mobile_runtime():
		target_node = _btn_mobile_advance
	else:
		target_node = _advance_prompt_box if _advance_prompt_box != null else _prompt_label
	if target_node == null:
		return
	if _pulse_tween != null and _pulse_tween.is_valid():
		_pulse_tween.kill()

	_pulse_tween = create_tween().set_loops()
	_pulse_tween.tween_property(target_node, "modulate:a", 0.35, 0.45).set_trans(Tween.TRANS_SINE)
	_pulse_tween.tween_property(target_node, "modulate:a", 1.00, 0.45).set_trans(Tween.TRANS_SINE)


func _kill_tweens() -> void:
	if _typewriter_tween != null and _typewriter_tween.is_valid():
		_typewriter_tween.kill()
		_typewriter_tween = null
	_is_typing = false
	if _active_tween != null and _active_tween.is_valid():
		_active_tween.kill()
		_active_tween = null
	if _pulse_tween != null and _pulse_tween.is_valid():
		_pulse_tween.kill()
		_pulse_tween = null
	if _zoom_tween != null and _zoom_tween.is_valid():
		_zoom_tween.kill()
		_zoom_tween = null
	if _crt_flicker_tween != null and _crt_flicker_tween.is_valid():
		_crt_flicker_tween.kill()
		_crt_flicker_tween = null
	if _jitter_tween != null and _jitter_tween.is_valid():
		_jitter_tween.kill()
		_jitter_tween = null
	if _portrait_tween != null and _portrait_tween.is_valid():
		_portrait_tween.kill()
		_portrait_tween = null
	if _image_rect != null:
		_image_rect.position.x = 0.0
		_image_rect.modulate = Color.WHITE
	if _cena4_crt_overlay != null:
		_cena4_crt_overlay.visible = false


func _play_audio_by_name(sound_name: String) -> void:
	match sound_name:
		"deep_intro_hum":
			_play_sound(_sfx_deep_hum)
		"nostalgia_chime":
			_play_sound(_sfx_nostalgia)
		"glitch_static":
			_play_sound(_sfx_glitch)
		_:
			pass


func _play_sound(stream: AudioStreamWAV) -> void:
	if _audio_player != null and stream != null:
		_audio_player.stream = stream
		_audio_player.play()


## Constrói os nós visuais programaticamente com estilização Neo-16-bit oficial
func _build_ui_nodes() -> void:
	NarrativeLayoutBuilderClass.build_and_bind(self, _is_mobile_runtime())


func _generate_sound_effects() -> void:
	var sfx: Dictionary = NarrativeAudioSynthClass.generate_effects_library()
	_sfx_deep_hum = sfx.get("deep_hum")
	_sfx_nostalgia = sfx.get("nostalgia")
	_sfx_glitch = sfx.get("glitch")
	_sfx_advance = sfx.get("advance")


func _create_wav(freq: float, duration: float, volume: float) -> AudioStreamWAV:
	return NarrativeAudioSynthClass.create_tone_wav(freq, duration, volume)


func _create_noise_wav(duration: float, volume: float) -> AudioStreamWAV:
	return NarrativeAudioSynthClass.create_noise_wav(duration, volume)


func _start_typewriter() -> void:
	if _dialogue_label == null:
		return
	var text_len: int = _dialogue_label.text.length()
	if text_len == 0:
		_is_typing = false
		return
	_dialogue_label.visible_characters = 0
	_is_typing = true
	if _typewriter_tween != null and _typewriter_tween.is_valid():
		_typewriter_tween.kill()
	_typewriter_tween = create_tween()
	_typewriter_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	var duration: float = float(text_len) / StandardDialogueBox.TYPEWRITER_SPEED_CPS
	_typewriter_tween.tween_property(_dialogue_label, "visible_characters", text_len, duration)
	_typewriter_tween.tween_callback(func():
		_is_typing = false
	)


func _skip_typewriter() -> void:
	if _typewriter_tween != null and _typewriter_tween.is_valid():
		_typewriter_tween.kill()
	if _dialogue_label != null:
		_dialogue_label.visible_characters = -1
	_is_typing = false


func _on_crt_continue_button_pressed() -> void:
	if not is_playing or _is_transitioning or _crt_advance_locked:
		return
	_crt_advance_locked = true
	if _crt_continue_button != null:
		_crt_continue_button.disabled = true
	advance_or_skip_text()


func _is_current_event_arcade_machine() -> bool:
	if current_sequence == null:
		return false
	var events: Array = current_sequence.get("events") if current_sequence != null else []
	if current_event_index < events.size():
		var ev: Resource = events[current_event_index]
		if ev != null and str(ev.get("id")) == "arcade_machine":
			return true
	return false


func _setup_mobile_dialogue_layout() -> void:
	if _mobile_layout_configured or not _is_mobile_runtime():
		return
	if _dialogue_frame == null:
		return

	# Garante que toques no painel e na área de diálogo avancem o texto
	if _dialogue_frame != null:
		_dialogue_frame.mouse_filter = Control.MOUSE_FILTER_PASS
		if not _dialogue_frame.gui_input.is_connected(_on_dialogue_gui_input):
			_dialogue_frame.gui_input.connect(_on_dialogue_gui_input)
	if _dialogue_area != null:
		_dialogue_area.mouse_filter = Control.MOUSE_FILTER_PASS
		if not _dialogue_area.gui_input.is_connected(_on_dialogue_gui_input):
			_dialogue_area.gui_input.connect(_on_dialogue_gui_input)

	var content_margin := _dialogue_frame.get_node_or_null("FrameContent/ContentMargin") as MarginContainer
	if content_margin == null:
		return

	content_margin.add_theme_constant_override("margin_left", 22)
	content_margin.add_theme_constant_override("margin_right", 22)
	content_margin.add_theme_constant_override("margin_top", 8)
	content_margin.add_theme_constant_override("margin_bottom", 8)

	var old_vbox := content_margin.get_node_or_null("VBox") as VBoxContainer
	if old_vbox != null:
		var mobile_hbox := HBoxContainer.new()
		mobile_hbox.name = "MobileDialogueHBox"
		mobile_hbox.add_theme_constant_override("separation", 18)
		mobile_hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
		mobile_hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		mobile_hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
		content_margin.add_child(mobile_hbox)

		if _speaker_portrait != null:
			var prev_parent = _speaker_portrait.get_parent()
			if prev_parent != null:
				prev_parent.remove_child(_speaker_portrait)
			_speaker_portrait.custom_minimum_size = Vector2(88, 88)
			_speaker_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			_speaker_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			_speaker_portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			_speaker_portrait.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			mobile_hbox.add_child(_speaker_portrait)

		var right_vbox := VBoxContainer.new()
		right_vbox.name = "RightVBox"
		right_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		right_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
		right_vbox.add_theme_constant_override("separation", 4)
		mobile_hbox.add_child(right_vbox)

		var header_hbox := HBoxContainer.new()
		header_hbox.name = "MobileHeaderHBox"
		header_hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		right_vbox.add_child(header_hbox)

		if _speaker_label != null:
			var spk_parent = _speaker_label.get_parent()
			if spk_parent != null:
				spk_parent.remove_child(_speaker_label)
			_speaker_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			_speaker_label.label_settings = StandardDialogueBox.create_speaker_settings(true)
			_speaker_label.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			_speaker_label.add_theme_font_size_override("font_size", _speaker_label.label_settings.font_size)
			header_hbox.add_child(_speaker_label)

		if _scene_counter_label != null:
			var cnt_parent = _scene_counter_label.get_parent()
			if cnt_parent != null:
				cnt_parent.remove_child(_scene_counter_label)
			_scene_counter_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			_scene_counter_label.add_theme_font_override("font", ARCADE_FONT)
			_scene_counter_label.add_theme_font_size_override("font_size", 13)
			_scene_counter_label.add_theme_color_override("font_color", Color(0.58, 0.64, 0.72, 0.85))
			header_hbox.add_child(_scene_counter_label)

		if _dialogue_separator != null:
			var sep_parent = _dialogue_separator.get_parent()
			if sep_parent != null:
				sep_parent.remove_child(_dialogue_separator)
			right_vbox.add_child(_dialogue_separator)

		if _dialogue_label != null:
			var dlg_parent = _dialogue_label.get_parent()
			if dlg_parent != null:
				dlg_parent.remove_child(_dialogue_label)
			_dialogue_label.label_settings = StandardDialogueBox.create_dialogue_settings(true)
			_dialogue_label.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			_dialogue_label.add_theme_font_size_override("font_size", _dialogue_label.label_settings.font_size)
			_dialogue_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			_dialogue_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
			_dialogue_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			right_vbox.add_child(_dialogue_label)

		var footer_hbox := HBoxContainer.new()
		footer_hbox.name = "MobileFooterHBox"
		footer_hbox.alignment = BoxContainer.ALIGNMENT_END
		right_vbox.add_child(footer_hbox)

		if _btn_mobile_advance != null:
			var btn_parent = _btn_mobile_advance.get_parent()
			if btn_parent != null:
				btn_parent.remove_child(_btn_mobile_advance)
			_btn_mobile_advance.custom_minimum_size = Vector2(28, 24)
			_btn_mobile_advance.text = "►"
			_style_mobile_advance_button()
			footer_hbox.add_child(_btn_mobile_advance)

		content_margin.remove_child(old_vbox)
		old_vbox.queue_free()

	_mobile_layout_configured = true
