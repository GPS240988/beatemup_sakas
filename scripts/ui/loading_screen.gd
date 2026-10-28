class_name LoadingScreen
extends Control

## Tela de Apresentação e Carregamento da Fase 1 (A Locadora: Onde Tudo Começou).
## Exibe a arte oficial da fase, o herói selecionado pronto para a ação,
## e os comandos arcade: [ESPAÇO] para Continuar e [ESC] para Voltar.
## Totalmente compatível com Teclado, Gamepad, Mouse e Toque Mobile.

const CHARACTER_SELECT_SCENE: String = "res://scenes/ui/character_select.tscn"
const DIFFICULTY_SELECT_SCENE: String = "res://scenes/ui/difficulty_select.tscn"
const MAP_MENU_SCENE: String = "res://scenes/ui/map_menu.tscn"
const TARGET_LEVEL_SCENE: String = "res://scenes/levels/map_1.tscn"
const STORY_INTRO_SCENE: String = "res://scenes/story/story_intro.tscn"

const LOADING_IMAGE_PATH: String = "res://assets/backgrounds/Instruções_1.webp"
const FALLBACK_IMAGE_PATH: String = "res://assets/backgrounds/maps/carregar/carregando_fase1.webp"

@onready var background_texture: TextureRect = %BackgroundTexture
@onready var prompt_container: HBoxContainer = %PromptContainer
@onready var hero_badge_label: Label = %HeroBadgeLabel
@onready var btn_continue: Button = %BtnContinue
@onready var btn_back: Button = %BtnBack
@onready var key_space_icon: PanelContainer = %KeySpaceIcon
@onready var key_esc_icon: PanelContainer = %KeyEscIcon
@onready var audio_player: AudioStreamPlayer = %AudioPlayer

var _pulse_tween: Tween
var _sfx_start: AudioStreamWAV
var _sfx_cancel: AudioStreamWAV
var _is_transitioning: bool = false


func _ready() -> void:
	_generate_audio_effects()
	_load_background_image()
	_update_hero_info()
	_setup_buttons()
	_start_prompt_pulse()


func _load_background_image() -> void:
	if background_texture == null:
		return

	var tex: Texture2D = null
	if ResourceLoader.exists(LOADING_IMAGE_PATH):
		tex = load(LOADING_IMAGE_PATH) as Texture2D
	elif ResourceLoader.exists(FALLBACK_IMAGE_PATH):
		tex = load(FALLBACK_IMAGE_PATH) as Texture2D

	if tex == null:
		for path_to_try in [LOADING_IMAGE_PATH, FALLBACK_IMAGE_PATH]:
			var global_p := ProjectSettings.globalize_path(path_to_try)
			if FileAccess.file_exists(global_p):
				var img := Image.load_from_file(global_p)
				if img != null:
					tex = ImageTexture.create_from_image(img)
					tex.resource_path = path_to_try
					break

	if tex != null:
		background_texture.texture = tex


func _update_hero_info() -> void:
	var char_id: String = "guilherme"
	var session = get_node_or_null("/root/GameSession")
	if session != null and "selected_character_id" in session:
		char_id = str(session.selected_character_id).to_lower()

	var char_name: String = char_id.capitalize()
	if session != null and session.has_method("get_character_stats"):
		var stats: Dictionary = session.get_character_stats(char_id)
		var str_val: int = int(stats.get("strength", 3))
		var spd_val: int = int(stats.get("speed", 2))
		var tec_val: int = int(stats.get("technique", 3))
		if hero_badge_label != null:
			hero_badge_label.text = "★ JOGADOR: %s  |  FORÇA %d  VELOCIDADE %d  TÉCNICA %d" % [char_name.to_upper(), str_val, spd_val, tec_val]
	else:
		if hero_badge_label != null:
			hero_badge_label.text = "★ JOGADOR: %s PRONTO PARA COMBATE" % char_name.to_upper()


func _setup_buttons() -> void:
	if btn_continue != null:
		btn_continue.pressed.connect(_on_continue_pressed)
		btn_continue.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	if btn_back != null:
		btn_back.pressed.connect(_on_back_pressed)
		btn_back.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND


func _start_prompt_pulse() -> void:
	if btn_continue == null:
		return

	if _pulse_tween != null and _pulse_tween.is_valid():
		_pulse_tween.kill()

	_pulse_tween = create_tween().set_loops()
	_pulse_tween.tween_property(btn_continue, "modulate", Color(1.2, 1.2, 0.8, 1.0), 0.55).set_trans(Tween.TRANS_SINE)
	_pulse_tween.tween_property(btn_continue, "modulate", Color(0.9, 0.9, 1.0, 0.85), 0.55).set_trans(Tween.TRANS_SINE)


func _gui_input(event: InputEvent) -> void:
	if _is_transitioning:
		return
	if (event is InputEventMouseButton and event.pressed) or (event is InputEventScreenTouch and event.pressed):
		_safe_handle_input()
		_on_continue_pressed()


func _unhandled_input(event: InputEvent) -> void:
	if _is_transitioning:
		return

	if event.is_action_pressed("ui_cancel") or (event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE):
		_safe_handle_input()
		_on_back_pressed()
	elif (event is InputEventKey and event.pressed and not event.echo) or (event is InputEventMouseButton and event.pressed) or (event is InputEventScreenTouch and event.pressed) or event.is_action_pressed("ui_accept"):
		_safe_handle_input()
		_on_continue_pressed()


func _safe_handle_input() -> void:
	if get_viewport() != null:
		get_viewport().set_input_as_handled()


func _on_continue_pressed() -> void:
	if _is_transitioning:
		return
	_is_transitioning = true

	_play_sound(_sfx_start)

	# Garante que a sessão permaneça válida antes de carregar a fase
	var session = get_node_or_null("/root/GameSession")
	if session != null and "selected_character_id" in session:
		print("Iniciando Fase 1 com o personagem: ", session.selected_character_id)

	# Transição protegida: se for Novo Jogo, exibe a cena de abertura narrativa (res://scenes/story/story_intro.tscn)
	var target_scene := TARGET_LEVEL_SCENE
	if session != null and "has_played_intro" in session and not session.has_played_intro:
		if ResourceLoader.exists(STORY_INTRO_SCENE):
			target_scene = STORY_INTRO_SCENE

	_safe_handle_input()
	var err := get_tree().change_scene_to_file(target_scene)
	if err != OK:
		err = get_tree().change_scene_to_file(TARGET_LEVEL_SCENE)
		if err != OK:
			_is_transitioning = false
			printerr("Erro ao carregar a cena do mapa 1: ", err)


func _on_back_pressed() -> void:
	if _is_transitioning:
		return
	_is_transitioning = true

	_play_sound(_sfx_cancel)
	_safe_handle_input()
	var err := get_tree().change_scene_to_file(MAP_MENU_SCENE)
	if err != OK:
		err = get_tree().change_scene_to_file(DIFFICULTY_SELECT_SCENE)
		if err != OK:
			# Fallback para a tela de seleção de personagens
			err = get_tree().change_scene_to_file(CHARACTER_SELECT_SCENE)
			if err != OK:
				_is_transitioning = false
				printerr("Erro ao retornar: ", err)


func _play_sound(stream: AudioStreamWAV) -> void:
	if audio_player != null and stream != null:
		audio_player.stream = stream
		audio_player.play()


func _generate_audio_effects() -> void:
	_sfx_start = _create_wav(880.0, 0.18, 0.45)
	_sfx_cancel = _create_wav(220.0, 0.12, 0.4)


func _create_wav(freq: float, duration: float, volume: float) -> AudioStreamWAV:
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_8_BITS
	wav.mix_rate = 22050
	var sample_count: int = int(22050.0 * duration)
	var data := PackedByteArray()
	data.resize(sample_count)
	for i in range(sample_count):
		var t := float(i) / 22050.0
		var envelope := 1.0 - (float(i) / float(sample_count))
		var wave := sin(t * freq * TAU)
		var val := (wave * volume * envelope) * 127.0 + 128.0
		data[i] = int(clamp(val, 0.0, 255.0))
	wav.data = data
	return wav
