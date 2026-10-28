class_name DifficultySelectMenu
extends Control

## Tela de Seleção de Dificuldade do Projeto Sakas.
## Apresenta as artes oficiais em alta definição sem hitboxes sobrepostas.
## Estado inicial: Modo Normal (borda vermelha em evidência, azul apagada).
## Ao alternar para Difícil: a borda azul fica em evidência e a vermelha apagada e pra trás.
## Ao confirmar, armazena a dificuldade no GameSession e avança para a tela de instruções (loading_screen.tscn).
## Ao retornar, volta para a Seleção de Personagens (character_select.tscn).

const CHARACTER_SELECT_SCENE: String = "res://scenes/ui/character_select.tscn"
const MAP_MENU_SCENE: String = "res://scenes/ui/map_menu.tscn"
const INSTRUCTIONS_SCENE: String = "res://scenes/ui/loading_screen.tscn"
const FIRST_LEVEL_SCENE: String = "res://scenes/levels/map_1.tscn"

@onready var bg_normal: TextureRect = %BackgroundNormal
@onready var bg_dificil: TextureRect = %BackgroundDificil
@onready var card_normal: Button = %Card_normal
@onready var card_dificil: Button = %Card_dificil
@onready var btn_start_game: Button = %BtnStartGame
@onready var btn_back: Button = %BtnBack
@onready var audio_player: AudioStreamPlayer = %AudioPlayer

var current_difficulty: String = "normal"
var _fade_tween: Tween
var _sfx_move: AudioStreamWAV
var _sfx_confirm: AudioStreamWAV
var _sfx_cancel: AudioStreamWAV
var _is_transitioning: bool = false


func _ready() -> void:
	_generate_audio_effects()

	if btn_start_game != null:
		btn_start_game.pressed.connect(_on_start_pressed)

	if btn_back != null:
		btn_back.pressed.connect(_on_back_pressed)

	if card_normal != null:
		card_normal.mouse_entered.connect(func(): _select_difficulty("normal", true))
		card_normal.pressed.connect(func():
			if current_difficulty == "normal":
				_on_start_pressed()
			else:
				_select_difficulty("normal", true)
		)

	if card_dificil != null:
		card_dificil.mouse_entered.connect(func(): _select_difficulty("dificil", true))
		card_dificil.pressed.connect(func():
			if current_difficulty == "dificil":
				_on_start_pressed()
			else:
				_select_difficulty("dificil", true)
		)

	# Inicia no modo Normal: borda vermelha em evidência
	_select_difficulty("normal", false)


func _select_difficulty(diff_id: String, play_sfx: bool = true) -> void:
	var game_session = get_node_or_null("/root/GameSession")
	var is_valid: bool = false
	if game_session != null:
		is_valid = game_session.is_difficulty_valid(diff_id)
	else:
		is_valid = (diff_id == "normal" or diff_id == "dificil")

	if is_valid:
		var changed: bool = (current_difficulty != diff_id)
		current_difficulty = diff_id
		if changed and play_sfx:
			_play_sound(_sfx_move)

	_update_visuals()


func _update_visuals() -> void:
	var is_dif_active: bool = (current_difficulty == "dificil")

	if bg_dificil != null:
		if _fade_tween != null and _fade_tween.is_valid():
			_fade_tween.kill()
		_fade_tween = create_tween()
		var target_alpha: float = 1.0 if is_dif_active else 0.0
		_fade_tween.tween_property(bg_dificil, "modulate:a", target_alpha, 0.16).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


func _on_start_pressed() -> void:
	if _is_transitioning or current_difficulty == "":
		return
	_is_transitioning = true
	_play_sound(_sfx_confirm)

	var game_session = get_node_or_null("/root/GameSession")
	if game_session != null:
		game_session.difficulty_id = current_difficulty
		game_session.difficulty_selected.emit(current_difficulty)

	_safe_handle_input()
	await get_tree().create_timer(0.15).timeout
	var err := get_tree().change_scene_to_file(MAP_MENU_SCENE)
	if err != OK:
		err = get_tree().change_scene_to_file(INSTRUCTIONS_SCENE)
		if err != OK:
			get_tree().change_scene_to_file(FIRST_LEVEL_SCENE)


func _on_back_pressed() -> void:
	if _is_transitioning:
		return
	_is_transitioning = true
	_play_sound(_sfx_cancel)

	_safe_handle_input()
	var err := get_tree().change_scene_to_file(CHARACTER_SELECT_SCENE)
	if err != OK:
		printerr("Erro ao retornar à seleção de personagens: ", err)


func _unhandled_input(event: InputEvent) -> void:
	if _is_transitioning:
		return

	if event.is_action_pressed("ui_cancel") or (event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE):
		_safe_handle_input()
		_on_back_pressed()
	elif event.is_action_pressed("ui_accept") or (event is InputEventKey and event.pressed and not event.echo and (event.keycode == KEY_ENTER or event.keycode == KEY_SPACE)):
		_safe_handle_input()
		_on_start_pressed()
	elif event.is_action_pressed("ui_left") or (event is InputEventKey and event.pressed and not event.echo and (event.keycode == KEY_A or event.keycode == KEY_LEFT)):
		_safe_handle_input()
		_select_difficulty("normal", true)
	elif event.is_action_pressed("ui_right") or (event is InputEventKey and event.pressed and not event.echo and (event.keycode == KEY_D or event.keycode == KEY_RIGHT)):
		_safe_handle_input()
		_select_difficulty("dificil", true)


func _safe_handle_input() -> void:
	if get_viewport() != null:
		get_viewport().set_input_as_handled()


func _play_sound(stream: AudioStreamWAV) -> void:
	if audio_player != null and stream != null:
		audio_player.stream = stream
		audio_player.play()


func _generate_audio_effects() -> void:
	_sfx_move = _create_wav(640.0, 0.04, 0.25)
	_sfx_confirm = _create_wav(1040.0, 0.12, 0.40)
	_sfx_cancel = _create_wav(160.0, 0.14, 0.40)


func _create_wav(freq: float, duration: float, volume: float) -> AudioStreamWAV:
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_8_BITS
	wav.mix_rate = 22050
	var sample_count: int = int(22050.0 * duration)
	var data := PackedByteArray()
	data.resize(sample_count)
	for i in range(sample_count):
		var t: float = float(i) / 22050.0
		var envelope: float = 1.0 - (float(i) / float(sample_count))
		var sample: float = sin(t * freq * TAU) * volume * envelope
		var byte_val: int = clampi(int(sample * 127.0 + 128.0), 0, 255)
		data[i] = byte_val
	wav.data = data
	return wav
