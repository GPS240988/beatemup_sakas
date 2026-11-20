class_name DifficultySelectMenu
extends Control

## Seleção de dificuldade com uma única arte, destaque neon direto na opção
## selecionada e confirmação separada em PC, gamepad e dispositivos touch.

const CHARACTER_SELECT_SCENE: String = "res://scenes/ui/character_select.tscn"
const MAP_MENU_SCENE: String = "res://scenes/ui/map_menu.tscn"
const INSTRUCTIONS_SCENE: String = "res://scenes/ui/loading_screen.tscn"
const FIRST_LEVEL_SCENE: String = "res://scenes/levels/map_1.tscn"
const MobileScreenAction = preload("res://scripts/mobile/mobile_screen_action.gd")

@onready var background: TextureRect = %BackgroundNormal
@onready var card_easy: Button = %Card_facil
@onready var card_normal: Button = %Card_normal
@onready var card_hard: Button = %Card_dificil
@onready var btn_start_game: Button = %BtnStartGame
@onready var btn_back: Button = %BtnBack
@onready var audio_player: AudioStreamPlayer = %AudioPlayer

var current_difficulty: String = "normal"
var _sfx_move: AudioStream
var _sfx_confirm: AudioStream
var _sfx_cancel: AudioStream
var _is_transitioning: bool = false
var _mobile_action_button: Button = null
var _highlight_alpha: float = 1.0:
	set(value):
		_highlight_alpha = value
		_update_highlight_colors()
var _pulse_tween: Tween = null
var _emphasis_tween: Tween = null
var _focus_strength: float = 1.0
var _highlight_overlay: Node2D = null
var _highlight_lines: Array[Line2D] = []


func _ready() -> void:
	_generate_audio_effects()

	for option in _difficulty_buttons():
		option.flat = true
		option.text = ""
		option.focus_mode = Control.FOCUS_NONE
		option.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		option.mouse_filter = Control.MOUSE_FILTER_STOP

	card_easy.mouse_entered.connect(func(): _select_difficulty("facil", true))
	card_normal.mouse_entered.connect(func(): _select_difficulty("normal", true))
	card_hard.mouse_entered.connect(func(): _select_difficulty("dificil", true))
	card_easy.pressed.connect(func(): _select_difficulty("facil", true))
	card_normal.pressed.connect(func(): _select_difficulty("normal", true))
	card_hard.pressed.connect(func(): _select_difficulty("dificil", true))

	if btn_start_game != null:
		btn_start_game.pressed.connect(_on_start_pressed)
		btn_start_game.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	if btn_back != null:
		btn_back.pressed.connect(_on_back_pressed)
		btn_back.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

	if get_viewport() != null and not get_viewport().size_changed.is_connected(_update_layout_geometry):
		get_viewport().size_changed.connect(_update_layout_geometry)

	var initial_diff := "normal"
	var game_session = get_node_or_null("/root/GameSession")
	if game_session != null and "difficulty_id" in game_session:
		var saved_difficulty := str(game_session.difficulty_id)
		if ["facil", "normal", "dificil"].has(saved_difficulty):
			initial_diff = saved_difficulty
	_select_difficulty(initial_diff, false)

	# O helper cria o dock apenas em mobile e mantém os botões originais no desktop.
	_mobile_action_button = MobileScreenAction.add_primary_action(
		self, "CONFIRMAR: NORMAL", Callable(self, "_on_start_pressed"), Color(0.96, 0.73, 0.22, 1.0), btn_start_game
	)
	MobileScreenAction.add_secondary_action(self, "VOLTAR", Callable(self, "_on_back_pressed"), btn_back)
	_update_mobile_action()
	_create_highlight_overlay()
	_start_selection_emphasis()
	call_deferred("_update_layout_geometry")


func _difficulty_buttons() -> Array[Button]:
	return [card_easy, card_normal, card_hard]


func _get_background_rendered_rect() -> Rect2:
	var vp_size: Vector2 = get_viewport_rect().size
	if vp_size.x <= 0.0 or vp_size.y <= 0.0:
		return Rect2(Vector2.ZERO, Vector2(1280.0, 720.0))
	if MobileScreenAction.is_mobile_runtime():
		return Rect2(Vector2.ZERO, vp_size)
	var texture_aspect: float = 1920.0 / 1080.0
	var viewport_aspect: float = vp_size.x / vp_size.y
	var draw_size: Vector2
	var draw_pos: Vector2
	if viewport_aspect > texture_aspect:
		draw_size = Vector2(vp_size.y * texture_aspect, vp_size.y)
		draw_pos = Vector2((vp_size.x - draw_size.x) * 0.5, 0.0)
	else:
		draw_size = Vector2(vp_size.x, vp_size.x / texture_aspect)
		draw_pos = Vector2(0.0, (vp_size.y - draw_size.y) * 0.5)
	return Rect2(draw_pos, draw_size)


func _update_layout_geometry() -> void:
	if background != null:
		background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		background.stretch_mode = TextureRect.STRETCH_SCALE if MobileScreenAction.is_mobile_runtime() else TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		if MobileScreenAction.is_mobile_runtime():
			background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var bg_rect: Rect2 = _get_background_rendered_rect()
	# Três áreas de toque/clique alinhadas às opções da arte única: Fácil, Normal, Difícil.
	# Hitboxes alinhadas aos três quadros pintados na arte dificuldade.webp.
	# A moldura de foco usa a mesma geometria para não parecer deslocada da opção.
	var option_y: float = bg_rect.position.y + bg_rect.size.y * 0.425
	var option_height: float = bg_rect.size.y * 0.325
	var option_width: float = bg_rect.size.x * 0.250
	var option_starts: Array[float] = [0.135, 0.390, 0.645]
	var buttons := _difficulty_buttons()
	for i in range(buttons.size()):
		buttons[i].global_position = Vector2(bg_rect.position.x + bg_rect.size.x * option_starts[i], option_y)
		buttons[i].size = Vector2(bg_rect.size.x * option_width, option_height)

	if btn_start_game != null and not MobileScreenAction.is_mobile_runtime():
		btn_start_game.global_position = Vector2(bg_rect.position.x + bg_rect.size.x * 0.33, bg_rect.position.y + bg_rect.size.y * 0.88)
		btn_start_game.size = Vector2(bg_rect.size.x * 0.20, bg_rect.size.y * 0.07)
	if btn_back != null and not MobileScreenAction.is_mobile_runtime():
		btn_back.global_position = Vector2(bg_rect.position.x + bg_rect.size.x * 0.54, bg_rect.position.y + bg_rect.size.y * 0.88)
		btn_back.size = Vector2(bg_rect.size.x * 0.15, bg_rect.size.y * 0.07)
	_update_highlight_geometry()


func _input(event: InputEvent) -> void:
	if not MobileScreenAction.is_mobile_runtime() or _is_transitioning:
		return
	if not (event is InputEventScreenTouch) or not event.pressed or event.index != 0:
		return
	var touch_position: Vector2 = event.position
	var buttons := _difficulty_buttons()
	var ids: Array[String] = ["facil", "normal", "dificil"]
	for i in range(buttons.size()):
		if buttons[i] != null and buttons[i].get_global_rect().has_point(touch_position):
			_select_difficulty(ids[i], true)
			_safe_handle_input()
			return


func _select_difficulty(diff_id: String, play_sfx: bool = true) -> void:
	var game_session = get_node_or_null("/root/GameSession")
	var is_valid: bool = false
	if game_session != null:
		is_valid = game_session.is_difficulty_valid(diff_id)
	else:
		is_valid = ["facil", "normal", "dificil"].has(diff_id)
	if not is_valid:
		return

	var changed: bool = current_difficulty != diff_id
	current_difficulty = diff_id
	if changed and play_sfx:
		_play_sound(_sfx_move)
	_update_mobile_action()
	_update_highlight_geometry()
	_update_highlight_colors()
	if play_sfx:
		_start_selection_emphasis()


func _update_mobile_action() -> void:
	if _mobile_action_button == null:
		return
	var label_by_difficulty: Dictionary = {
		"facil": "CONFIRMAR: FÁCIL",
		"normal": "CONFIRMAR: NORMAL",
		"dificil": "CONFIRMAR: DIFÍCIL"
	}
	MobileScreenAction.set_action_state(_mobile_action_button, str(label_by_difficulty.get(current_difficulty, "CONFIRMAR")), current_difficulty == "")


func _create_highlight_overlay() -> void:
	_highlight_overlay = Node2D.new()
	_highlight_overlay.name = "DifficultySelectionGlow"
	_highlight_overlay.z_index = 100
	add_child(_highlight_overlay)

	# Retículo de foco: quatro cantos em três camadas de neon e quatro
	# pequenos marcadores centrais. O desenho permanece aberto, sem formar
	# um painel retangular sobre a arte original.
	var corner_widths: Array[float] = [18.0, 8.0, 2.5]
	for corner_index in range(4):
		for layer in range(3):
			var line := Line2D.new()
			line.name = "FocusCorner_%d_Layer_%d" % [corner_index, layer]
			line.antialiased = false
			line.width = corner_widths[layer]
			_highlight_overlay.add_child(line)
			_highlight_lines.append(line)

	var marker_widths: Array[float] = [7.0, 2.5]
	for marker_index in range(4):
		for layer in range(2):
			var line := Line2D.new()
			line.name = "FocusMarker_%d_Layer_%d" % [marker_index, layer]
			line.antialiased = false
			line.width = marker_widths[layer]
			_highlight_overlay.add_child(line)
			_highlight_lines.append(line)
	_update_highlight_geometry()
	_update_highlight_colors()


func _update_highlight_geometry() -> void:
	if _highlight_lines.size() != 20:
		return
	var selected_button: Button = _get_selected_button()
	if selected_button == null or not is_instance_valid(selected_button):
		return
	var global_rect: Rect2 = selected_button.get_global_rect()
	var rect := Rect2(get_global_transform().affine_inverse() * global_rect.position, global_rect.size)

	var ui_scale: float = clampf(rect.size.x / 480.0, 0.75, 1.35)
	var inset: float = 3.0 * ui_scale
	var left: float = rect.position.x + inset
	var right: float = rect.end.x - inset
	var top: float = rect.position.y + inset
	var bottom: float = rect.end.y - inset
	var corner_length: float = minf(rect.size.x * 0.12, rect.size.y * 0.16)
	corner_length = maxf(18.0 * ui_scale, corner_length)

	var corner_paths: Array[PackedVector2Array] = [
		PackedVector2Array([Vector2(left, top + corner_length), Vector2(left, top), Vector2(left + corner_length, top)]),
		PackedVector2Array([Vector2(right - corner_length, top), Vector2(right, top), Vector2(right, top + corner_length)]),
		PackedVector2Array([Vector2(left, bottom - corner_length), Vector2(left, bottom), Vector2(left + corner_length, bottom)]),
		PackedVector2Array([Vector2(right - corner_length, bottom), Vector2(right, bottom), Vector2(right, bottom - corner_length)])
	]
	var corner_widths: Array[float] = [18.0, 8.0, 2.5]
	for corner_index in range(corner_paths.size()):
		for layer in range(3):
			var line_index: int = corner_index * 3 + layer
			_highlight_lines[line_index].points = corner_paths[corner_index]
			_highlight_lines[line_index].width = corner_widths[layer] * ui_scale * _focus_strength

	# Pequenas marcas nos centros dos quatro lados criam leitura de autofocus,
	# sem fechar o contorno nem cobrir os textos da opção.
	var center_x: float = (left + right) * 0.5
	var center_y: float = (top + bottom) * 0.5
	var marker_length: float = 18.0 * ui_scale
	var marker_paths: Array[PackedVector2Array] = [
		PackedVector2Array([Vector2(center_x, top - marker_length * 0.45), Vector2(center_x, top + marker_length * 0.55)]),
		PackedVector2Array([Vector2(right - marker_length * 0.55, center_y), Vector2(right + marker_length * 0.45, center_y)]),
		PackedVector2Array([Vector2(center_x, bottom - marker_length * 0.55), Vector2(center_x, bottom + marker_length * 0.45)]),
		PackedVector2Array([Vector2(left - marker_length * 0.45, center_y), Vector2(left + marker_length * 0.55, center_y)])
	]
	var marker_widths: Array[float] = [7.0, 2.5]
	for marker_index in range(marker_paths.size()):
		for layer in range(2):
			var line_index: int = 12 + marker_index * 2 + layer
			_highlight_lines[line_index].points = marker_paths[marker_index]
			_highlight_lines[line_index].width = marker_widths[layer] * ui_scale * _focus_strength


func _update_highlight_colors() -> void:
	if _highlight_lines.size() != 20:
		return
	var color := _get_difficulty_color()
	var pulse: float = clampf(_highlight_alpha, 0.0, 1.0)

	# O foco fica mais espesso e luminoso por 2 s após seleção/confirmação inicial.
	# Depois retorna ao pulso discreto de repouso, sem perder a indicação selecionada.
	var glow_boost: float = lerpf(1.0, 1.8, clampf((_focus_strength - 1.0) / 0.65, 0.0, 1.0))
	var corner_alphas: Array[float] = [0.14 * pulse * glow_boost, 0.38 * pulse * glow_boost, 0.96]
	for corner_index in range(4):
		for layer in range(3):
			var line_color := color
			line_color.a = corner_alphas[layer]
			_highlight_lines[corner_index * 3 + layer].default_color = line_color

	var marker_alphas: Array[float] = [0.34 * pulse * glow_boost, 0.92]
	for marker_index in range(4):
		for layer in range(2):
			var line_color := color
			line_color.a = marker_alphas[layer]
			_highlight_lines[12 + marker_index * 2 + layer].default_color = line_color


func _start_selection_emphasis() -> void:
	if _emphasis_tween != null and _emphasis_tween.is_valid():
		_emphasis_tween.kill()
	if _pulse_tween != null and _pulse_tween.is_valid():
		_pulse_tween.kill()

	_focus_strength = 1.65
	_highlight_alpha = 1.0
	_update_highlight_geometry()
	_update_highlight_colors()

	# Quatro ciclos de 0,5 s = 2 segundos de autofocus mais intenso.
	_emphasis_tween = create_tween().set_loops(4)
	_emphasis_tween.tween_property(self, "_highlight_alpha", 0.18, 0.25).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_emphasis_tween.tween_property(self, "_highlight_alpha", 1.0, 0.25).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_emphasis_tween.finished.connect(_on_selection_emphasis_finished)


func _on_selection_emphasis_finished() -> void:
	_emphasis_tween = null
	_focus_strength = 1.0
	_update_highlight_geometry()
	_start_idle_pulse()


func _start_idle_pulse() -> void:
	if _pulse_tween != null and _pulse_tween.is_valid():
		_pulse_tween.kill()
	_pulse_tween = create_tween().set_loops()
	_pulse_tween.tween_property(self, "_highlight_alpha", 0.42, 0.58).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_pulse_tween.tween_property(self, "_highlight_alpha", 1.0, 0.58).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _get_selected_button() -> Button:
	match current_difficulty:
		"facil": return card_easy
		"dificil": return card_hard
		_: return card_normal


func _get_difficulty_color() -> Color:
	# As cores acompanham a moldura pintada em dificuldade.webp:
	# Fácil = verde, Normal = vermelho, Difícil = azul/ciano.
	match current_difficulty:
		"facil": return Color(0.16, 1.0, 0.22, 1.0)
		"dificil": return Color(0.08, 0.72, 1.0, 1.0)
		_: return Color(1.0, 0.16, 0.18, 1.0)


func _cycle_difficulty(direction: int) -> void:
	var ids: Array[String] = ["facil", "normal", "dificil"]
	var current_index: int = ids.find(current_difficulty)
	if current_index < 0:
		current_index = 1
	var next_index: int = posmod(current_index + direction, ids.size())
	_select_difficulty(ids[next_index], true)


func _safe_handle_input() -> void:
	if get_viewport() != null:
		get_viewport().set_input_as_handled()


func _play_sound(stream: AudioStream) -> void:
	if audio_player != null and stream != null:
		audio_player.stream = stream
		audio_player.play()


func _generate_audio_effects() -> void:
	if ResourceLoader.exists("res://assets/audio/sfx/Mover Cursor_sfx_move.mp3"):
		_sfx_move = load("res://assets/audio/sfx/Mover Cursor_sfx_move.mp3")
	else:
		_sfx_move = _create_wav(640.0, 0.04, 0.25)

	if ResourceLoader.exists("res://assets/audio/sfx/Confirmar Seleção_sfx_confirm.mp3"):
		_sfx_confirm = load("res://assets/audio/sfx/Confirmar Seleção_sfx_confirm.mp3")
	else:
		_sfx_confirm = _create_wav(1040.0, 0.12, 0.40)

	if ResourceLoader.exists("res://assets/audio/sfx/Opção Bloqueada_sfx_denied.mp3"):
		_sfx_cancel = load("res://assets/audio/sfx/Opção Bloqueada_sfx_denied.mp3")
	else:
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


func _on_start_pressed() -> void:
	if _is_transitioning or current_difficulty == "":
		return
	_is_transitioning = true
	_play_sound(_sfx_confirm)

	var game_session = get_node_or_null("/root/GameSession")
	var is_replay: bool = false
	var replay_target: String = ""

	if game_session != null:
		var current_context: String = ""
		if game_session.has_meta("map_entry_context"):
			current_context = str(game_session.get_meta("map_entry_context"))

		if current_context == "replay":
			is_replay = true
			if game_session.has_meta("replay_stage_scene"):
				replay_target = str(game_session.get_meta("replay_stage_scene"))
			game_session.remove_meta("replay_stage_index")
			game_session.remove_meta("replay_stage_scene")
			game_session.set_meta("map_entry_context", "continue")

		if is_replay:
			if game_session.has_method("select_difficulty"):
				game_session.select_difficulty(current_difficulty)
			else:
				game_session.difficulty_id = current_difficulty
				game_session.difficulty_selected.emit(current_difficulty)
			if game_session.has_method("clear_player_progression"):
				game_session.clear_player_progression()
		else:
			game_session.set_meta("map_entry_context", "campaign")
			game_session.difficulty_id = current_difficulty
			game_session.difficulty_selected.emit(current_difficulty)

	_safe_handle_input()
	await get_tree().create_timer(0.15).timeout

	if is_replay and not replay_target.is_empty():
		var pack_mgr = get_node_or_null("/root/PackManager")
		if pack_mgr != null and pack_mgr.has_method("ensure_pack_loaded_async"):
			await pack_mgr.ensure_pack_loaded_async("stage1")
			await pack_mgr.ensure_pack_loaded_async("audio_bgm")

		var err := get_tree().change_scene_to_file(replay_target)
		if err == OK:
			return
		printerr("Erro ao carregar a fase de replay: ", err)

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


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		_on_back_pressed()


func _unhandled_input(event: InputEvent) -> void:
	if _is_transitioning:
		return
	if event.is_action_pressed("ui_cancel") or (event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE):
		_safe_handle_input()
		_on_back_pressed()
	elif event.is_action_pressed("ui_accept") or (event is InputEventKey and event.pressed and not event.echo and (event.keycode == KEY_ENTER or event.keycode == KEY_SPACE or event.keycode == KEY_KP_ENTER)):
		_safe_handle_input()
		_on_start_pressed()
	elif event.is_action_pressed("ui_left") or (event is InputEventKey and event.pressed and not event.echo and (event.keycode == KEY_A or event.keycode == KEY_LEFT)):
		_safe_handle_input()
		_cycle_difficulty(-1)
	elif event.is_action_pressed("ui_right") or (event is InputEventKey and event.pressed and not event.echo and (event.keycode == KEY_D or event.keycode == KEY_RIGHT)):
		_safe_handle_input()
		_cycle_difficulty(1)
