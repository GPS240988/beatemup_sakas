class_name DifficultySelectMenu
extends Control

## Tela de Seleção de Dificuldade do Projeto Sakas.
## Apresenta as artes oficiais em alta definição com hitboxes responsivas
## e moldura de destaque evidente (Dark Premium Medieval / Arcade Neo-16-bit).

const CHARACTER_SELECT_SCENE: String = "res://scenes/ui/character_select.tscn"
const MAP_MENU_SCENE: String = "res://scenes/ui/map_menu.tscn"
const INSTRUCTIONS_SCENE: String = "res://scenes/ui/loading_screen.tscn"
const FIRST_LEVEL_SCENE: String = "res://scenes/levels/map_1.tscn"
const MobileScreenAction = preload("res://scripts/mobile/mobile_screen_action.gd")
const ARCADE_FONT: FontFile = preload("res://assets/fonts/arcade_bold.ttf")

@onready var bg_normal: TextureRect = %BackgroundNormal
@onready var bg_dificil: TextureRect = %BackgroundDificil
@onready var card_normal: Button = %Card_normal
@onready var card_dificil: Button = %Card_dificil
@onready var btn_start_game: Button = %BtnStartGame
@onready var btn_back: Button = %BtnBack
@onready var audio_player: AudioStreamPlayer = %AudioPlayer

var current_difficulty: String = "normal"
var _fade_tween: Tween
var _frame_tween: Tween
var _sfx_move: AudioStreamWAV
var _sfx_confirm: AudioStreamWAV
var _sfx_cancel: AudioStreamWAV
var _is_transitioning: bool = false
var _mobile_action_button: Button

# Moldura de seleção dinâmica para tornar o modo evidente
var _selection_frame: Panel
var _selection_badge: Label


func _ready() -> void:
	_generate_audio_effects()
	# A HUD de seleção (moldura + badge) foi removida por decisão de UX:
	# a arte cinematográfica já indica claramente o modo ativo via crossfade.

	if btn_start_game != null:
		btn_start_game.pressed.connect(_on_start_pressed)
		btn_start_game.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

	if btn_back != null:
		btn_back.pressed.connect(_on_back_pressed)
		btn_back.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

	if card_normal != null:
		card_normal.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		card_normal.mouse_entered.connect(func():
			if not MobileScreenAction.is_mobile_runtime():
				_select_difficulty("normal", true)
		)
		card_normal.pressed.connect(func():
			if current_difficulty == "normal":
				_on_start_pressed()
			else:
				_select_difficulty("normal", true)
		)

	if card_dificil != null:
		card_dificil.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		card_dificil.mouse_entered.connect(func():
			if not MobileScreenAction.is_mobile_runtime():
				_select_difficulty("dificil", true)
		)
		card_dificil.pressed.connect(func():
			if current_difficulty == "dificil":
				_on_start_pressed()
			else:
				_select_difficulty("dificil", true)
		)

	if get_viewport() != null:
		if not get_viewport().size_changed.is_connected(_update_layout_geometry):
			get_viewport().size_changed.connect(_update_layout_geometry)

	_select_difficulty("normal", false)
	if MobileScreenAction.is_mobile_runtime():
		# No mobile, o toque direto nos cards seleciona/confirma; sem dock buttons.
		if btn_start_game != null:
			btn_start_game.visible = false
		if btn_back != null:
			btn_back.visible = false
	else:
		_mobile_action_button = MobileScreenAction.add_primary_action(
			self, "INICIAR NO MODO NORMAL", Callable(self, "_on_start_pressed"), Color(0.96, 0.73, 0.22, 1.0), btn_start_game
		)
		MobileScreenAction.add_secondary_action(
			self, "VOLTAR", Callable(self, "_on_back_pressed"), btn_back
		)
	_update_mobile_action()
	call_deferred("_update_layout_geometry")


func _create_selection_frame() -> void:
	var click_zones: Control = get_node_or_null("ClickZones") as Control
	var parent_node: Node = click_zones if click_zones != null else self

	_selection_frame = Panel.new()
	_selection_frame.name = "DifficultySelectionFrame"
	_selection_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_selection_frame.z_index = 5
	parent_node.add_child(_selection_frame)

	_selection_badge = Label.new()
	_selection_badge.name = "SelectionBadge"
	_selection_badge.anchor_left = 0.5
	_selection_badge.anchor_right = 0.5
	_selection_badge.anchor_top = 0.0
	_selection_badge.anchor_bottom = 0.0
	_selection_badge.offset_left = -110.0
	_selection_badge.offset_top = -18.0
	_selection_badge.offset_right = 110.0
	_selection_badge.offset_bottom = 12.0
	_selection_badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_selection_badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_selection_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_selection_badge.add_theme_font_override("font", ARCADE_FONT)
	_selection_badge.add_theme_font_size_override("font_size", 14)
	_selection_badge.add_theme_constant_override("outline_size", 4)
	_selection_frame.add_child(_selection_badge)


func _get_background_rendered_rect() -> Rect2:
	var vp_size: Vector2 = get_viewport_rect().size
	if vp_size.x <= 0.0 or vp_size.y <= 0.0:
		return Rect2(Vector2.ZERO, Vector2(1280.0, 720.0))
	if MobileScreenAction.is_mobile_runtime():
		return Rect2(Vector2.ZERO, vp_size)
	var tex_aspect: float = 1920.0 / 1080.0
	var vp_aspect: float = vp_size.x / vp_size.y
	var draw_size: Vector2
	var draw_pos: Vector2
	if vp_aspect > tex_aspect:
		draw_size = Vector2(vp_size.y * tex_aspect, vp_size.y)
		draw_pos = Vector2((vp_size.x - draw_size.x) * 0.5, 0.0)
	else:
		draw_size = Vector2(vp_size.x, vp_size.x / tex_aspect)
		draw_pos = Vector2(0.0, (vp_size.y - draw_size.y) * 0.5)
	return Rect2(draw_pos, draw_size)


func _update_layout_geometry() -> void:
	if MobileScreenAction.is_mobile_runtime():
		if bg_normal != null:
			bg_normal.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			bg_normal.stretch_mode = TextureRect.STRETCH_SCALE
			bg_normal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		if bg_dificil != null:
			bg_dificil.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			bg_dificil.stretch_mode = TextureRect.STRETCH_SCALE
			bg_dificil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	else:
		if bg_normal != null:
			bg_normal.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			bg_normal.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		if bg_dificil != null:
			bg_dificil.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			bg_dificil.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED

	var bg_rect: Rect2 = _get_background_rendered_rect()

	# Posiciona as hitboxes responsivas exatamente sobre os cards desenhados na arte
	if card_normal != null:
		var n_pos := Vector2(bg_rect.position.x + bg_rect.size.x * 0.170, bg_rect.position.y + bg_rect.size.y * 0.355)
		var n_size := Vector2(bg_rect.size.x * 0.330, bg_rect.size.y * 0.425)
		card_normal.global_position = n_pos
		card_normal.size = n_size

	if card_dificil != null:
		var d_pos := Vector2(bg_rect.position.x + bg_rect.size.x * 0.505, bg_rect.position.y + bg_rect.size.y * 0.355)
		var d_size := Vector2(bg_rect.size.x * 0.325, bg_rect.size.y * 0.425)
		card_dificil.global_position = d_pos
		card_dificil.size = d_size

	# Desktop: posiciona os botões de rodapé caso estejam em modo PC
	if btn_start_game != null and not MobileScreenAction.is_mobile_runtime():
		btn_start_game.global_position = Vector2(bg_rect.position.x + bg_rect.size.x * 0.33, bg_rect.position.y + bg_rect.size.y * 0.88)
		btn_start_game.size = Vector2(bg_rect.size.x * 0.20, bg_rect.size.y * 0.07)
	if btn_back != null and not MobileScreenAction.is_mobile_runtime():
		btn_back.global_position = Vector2(bg_rect.position.x + bg_rect.size.x * 0.54, bg_rect.position.y + bg_rect.size.y * 0.88)
		btn_back.size = Vector2(bg_rect.size.x * 0.15, bg_rect.size.y * 0.07)

	_update_visuals(false)


func _input(event: InputEvent) -> void:
	if not MobileScreenAction.is_mobile_runtime() or _is_transitioning:
		return
	if not (event is InputEventScreenTouch) or not event.pressed or event.index != 0:
		return
	var touch_pos: Vector2 = event.position
	if card_normal != null and card_normal.get_global_rect().has_point(touch_pos):
		if current_difficulty == "normal":
			_on_start_pressed()
		else:
			_select_difficulty("normal", true)
		_safe_handle_input()
	elif card_dificil != null and card_dificil.get_global_rect().has_point(touch_pos):
		if current_difficulty == "dificil":
			_on_start_pressed()
		else:
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

	_update_visuals(true)
	_update_mobile_action()


func _update_mobile_action() -> void:
	if _mobile_action_button == null:
		return
	var label := "INICIAR NO MODO DIFÍCIL" if current_difficulty == "dificil" else "INICIAR NO MODO NORMAL"
	MobileScreenAction.set_action_state(_mobile_action_button, label, current_difficulty == "")


func _update_visuals(animate: bool = true) -> void:
	var is_dif_active: bool = (current_difficulty == "dificil")

	# Crossfade do background oficial
	if bg_dificil != null:
		if _fade_tween != null and _fade_tween.is_valid():
			_fade_tween.kill()
		_fade_tween = create_tween()
		var target_alpha: float = 1.0 if is_dif_active else 0.0
		_fade_tween.tween_property(bg_dificil, "modulate:a", target_alpha, 0.16).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

	# Atualiza o frame de seleção evidente
	if _selection_frame != null and is_instance_valid(_selection_frame):
		var target_button: Button = card_dificil if is_dif_active else card_normal
		if target_button != null:
			var target_rect: Rect2 = target_button.get_global_rect()
			# Adiciona margem externa de 6px ao redor da carta
			var frame_rect := Rect2(
				target_rect.position - Vector2(6.0, 6.0),
				target_rect.size + Vector2(12.0, 12.0)
			)

			var style := StyleBoxFlat.new()
			if is_dif_active:
				# Modo Difícil: Neon Vermelho/Âmbar Flamejante
				style.bg_color = Color(0.95, 0.18, 0.12, 0.14)
				style.border_color = Color(1.0, 0.28, 0.20, 0.95)
				style.set_border_width_all(3)
				style.set_corner_radius_all(10)
				style.shadow_color = Color(1.0, 0.15, 0.10, 0.45)
				style.shadow_size = 8
				if _selection_badge != null:
					_selection_badge.text = "[ MODO DIFÍCIL ATIVO ]"
					_selection_badge.add_theme_color_override("font_color", Color(1.0, 0.85, 0.85, 1.0))
					_selection_badge.add_theme_color_override("font_outline_color", Color(0.4, 0.05, 0.05, 1.0))
			else:
				# Modo Normal: Dourado Premium Medieval
				style.bg_color = Color(0.96, 0.73, 0.22, 0.12)
				style.border_color = Color(0.96, 0.73, 0.22, 0.95)
				style.set_border_width_all(3)
				style.set_corner_radius_all(10)
				style.shadow_color = Color(0.96, 0.73, 0.22, 0.45)
				style.shadow_size = 8
				if _selection_badge != null:
					_selection_badge.text = "[ MODO NORMAL ATIVO ]"
					_selection_badge.add_theme_color_override("font_color", Color(1.0, 0.95, 0.82, 1.0))
					_selection_badge.add_theme_color_override("font_outline_color", Color(0.25, 0.18, 0.05, 1.0))

			_selection_frame.add_theme_stylebox_override("panel", style)

			if animate and is_inside_tree():
				if _frame_tween != null and _frame_tween.is_valid():
					_frame_tween.kill()
				_frame_tween = create_tween().set_parallel(true)
				_frame_tween.tween_property(_selection_frame, "global_position", frame_rect.position, 0.14).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
				_frame_tween.tween_property(_selection_frame, "size", frame_rect.size, 0.14).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
			else:
				_selection_frame.global_position = frame_rect.position
				_selection_frame.size = frame_rect.size

	# Desktop: atualiza o rótulo do botão Iniciar
	if btn_start_game != null and not MobileScreenAction.is_mobile_runtime():
		btn_start_game.text = "INICIAR DIFÍCIL" if is_dif_active else "INICIAR NORMAL"


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
