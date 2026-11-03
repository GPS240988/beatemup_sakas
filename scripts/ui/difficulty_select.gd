class_name DifficultySelectMenu
extends Control

## Tela de Seleção de Dificuldade do Projeto Sakas.
## Apresenta as artes oficiais em alta definição sem hitboxes sobrepostas.
## Estado inicial: Modo Normal; ao alternar, a arte Difícil ganha destaque.

const CHARACTER_SELECT_SCENE: String = "res://scenes/ui/character_select.tscn"
const MAP_MENU_SCENE: String = "res://scenes/ui/map_menu.tscn"
const INSTRUCTIONS_SCENE: String = "res://scenes/ui/loading_screen.tscn"
const FIRST_LEVEL_SCENE: String = "res://scenes/levels/map_1.tscn"
const MobileScreenAction = preload("res://scripts/mobile/mobile_screen_action.gd")

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
var _mobile_action_button: Button


func _ready() -> void:
	_generate_audio_effects()

	if btn_start_game != null:
		btn_start_game.pressed.connect(_on_start_pressed)

	if btn_back != null:
		btn_back.pressed.connect(_on_back_pressed)

	if card_normal != null:
		card_normal.mouse_entered.connect(func(): _select_difficulty("normal", true))
		card_normal.pressed.connect(func():
			if MobileScreenAction.is_mobile_runtime():
				_select_difficulty("normal", true)
			elif current_difficulty == "normal":
				_on_start_pressed()
			else:
				_select_difficulty("normal", true)
		)

	if card_dificil != null:
		card_dificil.mouse_entered.connect(func(): _select_difficulty("dificil", true))
		card_dificil.pressed.connect(func():
			if MobileScreenAction.is_mobile_runtime():
				_select_difficulty("dificil", true)
			elif current_difficulty == "dificil":
				_on_start_pressed()
			else:
				_select_difficulty("dificil", true)
		)

	_select_difficulty("normal", false)
	_mobile_action_button = MobileScreenAction.add_primary_action(
		self, "INICIAR NO NORMAL", Callable(self, "_on_start_pressed"), Color(0.0, 0.82, 0.88, 1.0), btn_start_game
	)
	MobileScreenAction.add_secondary_action(
		self, "VOLTAR", Callable(self, "_on_back_pressed"), btn_back
	)
	_update_mobile_action()


func _input(event: InputEvent) -> void:
	# Alguns navegadores mobile entregam ScreenTouch sem produzir mouse_entered.
	# Trate o toque diretamente nas áreas das duas cartas.
	if not MobileScreenAction.is_mobile_runtime() or _is_transitioning:
		return
	if not (event is InputEventScreenTouch) or not event.pressed or event.index != 0:
		return
	var touch_position: Vector2 = event.position
	if card_normal != null and card_normal.get_global_rect().has_point(touch_position):
		_select_difficulty("normal", true)
		_safe_handle_input()
	elif card_dificil != null and card_dificil.get_global_rect().has_point(touch_position):
		_select_difficulty("dificil", true)
		_safe_handle_input()


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
	_update_mobile_action()


func _update_mobile_action() -> void:
	if _mobile_action_button == null:
		return
	var label := "CONFIRMAR DIFÍCIL" if current_difficulty == "dificil" else "CONFIRMAR NORMAL"
	MobileScreenAction.set_action_state(_mobile_action_button, label, current_difficulty == "")


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
		game_session.set_meta("map_entry_context", "campaign")
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
