class_name CharacterSelectMenu
extends Control

## Tela de Seleção de Personagem — Projeto Sakas
## Apresenta as 4 artes cinematográficas 16:9 oficiais em alta definição:
## - selecao_personagem_guilherme.webp (Desbloqueado / Único habilitado nesta versão)
## - selecao_personagem_gabriel.webp (Bloqueado)
## - selecao_personagem_andre.webp (Bloqueado)
## - selecao_personagem_juliana.webp (Bloqueada)
##
## Transição fluida (slide horizontal + crossfade cúbico) ao alternar personagens.
## Nada além da arte cinematográfica limpa é exibido durante a navegação.
## Suporta Teclado (A/D, Setas, Enter, Esc), Gamepad, Mouse e Toque nos 4 heróis.

const MAIN_MENU_SCENE: String = "res://scenes/ui/main_menu.tscn"
const LOADING_SCREEN_SCENE: String = "res://scenes/ui/loading_screen.tscn"
const DIFFICULTY_SELECT_SCENE: String = "res://scenes/ui/difficulty_select.tscn"
const FIRST_LEVEL_SCENE: String = "res://scenes/levels/map_1.tscn"

const HERO_ORDER: Array[String] = ["guilherme", "gabriel", "andre", "juliana"]

const HERO_TEXTURES: Dictionary = {
	"guilherme": preload("res://assets/ui/character_select/selecao_personagem_guilherme.webp"),
	"gabriel": preload("res://assets/ui/character_select/selecao_personagem_gabriel.webp"),
	"andre": preload("res://assets/ui/character_select/selecao_personagem_andre.webp"),
	"juliana": preload("res://assets/ui/character_select/selecao_personagem_juliana.webp")
}

const STATS_TEXTURES: Dictionary = {
	"guilherme": "res://assets/ui/character_select/stats_guilherme.webp",
	"gabriel": "res://assets/ui/character_select/stats_gabriel.webp",
	"andre": "res://assets/ui/character_select/stats_andre.webp",
	"juliana": "res://assets/ui/character_select/stats_juliana.webp"
}

@onready var aspect_wrapper: AspectRatioContainer = %AspectWrapper
@onready var display_layer: Control = %DisplayLayer
@onready var background_slot: TextureRect = %BackgroundSlot
@onready var incoming_slot: TextureRect = %IncomingSlot
@onready var flash_rect: ColorRect = %FlashRect
@onready var audio_player: AudioStreamPlayer = %AudioPlayer

# Hitboxes transparentes sobre as 4 colunas de heróis
@onready var btn_touch_guilherme: Button = %BtnTouchGuilherme
@onready var btn_touch_gabriel: Button = %BtnTouchGabriel
@onready var btn_touch_andre: Button = %BtnTouchAndre
@onready var btn_touch_juliana: Button = %BtnTouchJuliana

# Referências de nós no LayoutRoot (compatibilidade total com a suíte de testes unitários)
@onready var grid_container: GridContainer = %GridCharacters
@onready var selection_frame: TextureRect = %SelectionFrame
@onready var stats_texture_rect: TextureRect = %StatsTextureRect
@onready var status_label: Label = %StatusNoticeLabel
@onready var char_desc_label: Label = %CharDescLabel
@onready var btn_confirm: Button = %BtnConfirm
@onready var btn_back: Button = %BtnBack
@onready var stat_forca_label: Label = %StatForcaLabel
@onready var stat_vel_label: Label = %StatVelLabel
@onready var stat_tec_label: Label = %StatTecLabel

var current_hover_id: String = "guilherme"
var current_index: int = 0
var card_nodes: Dictionary = {}
var _stats_cache: Dictionary = {}

var _slide_tween: Tween
var _shake_tween: Tween
var _flash_tween: Tween
var _frame_tween: Tween
var _is_transitioning_scene: bool = false

var _sfx_move: AudioStreamWAV
var _sfx_confirm: AudioStreamWAV
var _sfx_denied: AudioStreamWAV


func _ready() -> void:
	_generate_audio_effects()
	_load_stats_textures()
	_setup_character_cards()
	_setup_action_buttons()
	_setup_touch_hitboxes()

	# Configura o estado inicial da cena no primeiro herói (Guilherme)
	current_index = 0
	current_hover_id = HERO_ORDER[0]
	if background_slot != null and HERO_TEXTURES.has("guilherme"):
		background_slot.texture = HERO_TEXTURES["guilherme"]
		background_slot.modulate = Color.WHITE
		background_slot.position = Vector2.ZERO
	if incoming_slot != null:
		incoming_slot.modulate = Color(1.0, 1.0, 1.0, 0.0)
		incoming_slot.position = Vector2.ZERO

	_select_character_by_index(0, false, 0)


func _setup_touch_hitboxes() -> void:
	var hitboxes: Array[Button] = [
		btn_touch_guilherme,
		btn_touch_gabriel,
		btn_touch_andre,
		btn_touch_juliana
	]

	for idx in range(hitboxes.size()):
		var btn: Button = hitboxes[idx]
		if btn != null:
			btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
			btn.mouse_entered.connect(_on_touch_hover.bind(idx))
			btn.pressed.connect(_on_touch_clicked.bind(idx))


func _on_touch_hover(idx: int) -> void:
	if current_index != idx:
		var delta: int = idx - current_index
		_select_character_by_index(idx, true, 1 if delta > 0 else -1)


func _on_touch_clicked(idx: int) -> void:
	if current_index != idx:
		var delta: int = idx - current_index
		_select_character_by_index(idx, true, 1 if delta > 0 else -1)
	else:
		_on_confirm_pressed()


func _load_stats_textures() -> void:
	for k in STATS_TEXTURES.keys():
		var path: String = STATS_TEXTURES[k]
		var tex := load(path) as Texture2D
		if tex == null:
			var global_p: String = ProjectSettings.globalize_path(path)
			if FileAccess.file_exists(global_p):
				var img := Image.load_from_file(global_p)
				if img != null:
					tex = ImageTexture.create_from_image(img)
		if tex != null:
			_stats_cache[k] = tex


func _setup_action_buttons() -> void:
	if btn_confirm != null:
		btn_confirm.pressed.connect(_on_confirm_pressed)
		btn_confirm.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	if btn_back != null:
		btn_back.pressed.connect(_on_back_pressed)
		btn_back.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND


func _setup_character_cards() -> void:
	card_nodes.clear()
	if grid_container == null:
		return

	for idx in range(HERO_ORDER.size()):
		var char_id: String = HERO_ORDER[idx]
		var card_btn: Button = grid_container.get_node_or_null("Card_" + char_id) as Button
		if card_btn != null:
			card_nodes[char_id] = card_btn
			card_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
			card_btn.focus_mode = Control.FOCUS_NONE
			card_btn.mouse_entered.connect(_on_card_hovered.bind(idx))
			card_btn.pressed.connect(_on_card_clicked.bind(idx))

	for extra_id in ["alessandro", "fernando"]:
		var extra_btn: Button = grid_container.get_node_or_null("Card_" + extra_id) as Button
		if extra_btn != null:
			card_nodes[extra_id] = extra_btn


func _unhandled_input(event: InputEvent) -> void:
	if _is_transitioning_scene:
		return

	if event.is_action_pressed("ui_left") or (event is InputEventKey and event.pressed and not event.echo and (event.keycode == KEY_A or event.keycode == KEY_LEFT)):
		_move_selection(-1)
		_safe_handle_input()
	elif event.is_action_pressed("ui_right") or (event is InputEventKey and event.pressed and not event.echo and (event.keycode == KEY_D or event.keycode == KEY_RIGHT)):
		_move_selection(1)
		_safe_handle_input()
	elif event.is_action_pressed("ui_accept") or (event is InputEventKey and event.pressed and not event.echo and (event.keycode == KEY_ENTER or event.keycode == KEY_SPACE)):
		_safe_handle_input()
		_on_confirm_pressed()
	elif event.is_action_pressed("ui_cancel") or (event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE):
		_safe_handle_input()
		_on_back_pressed()


func _safe_handle_input() -> void:
	if get_viewport() != null:
		get_viewport().set_input_as_handled()


func _move_selection(delta: int) -> void:
	var next_idx: int = (current_index + delta) % HERO_ORDER.size()
	if next_idx < 0:
		next_idx += HERO_ORDER.size()
	_select_character_by_index(next_idx, true, delta)


func _on_card_hovered(idx: int) -> void:
	if current_index != idx:
		var delta: int = idx - current_index
		_select_character_by_index(idx, true, 1 if delta > 0 else -1)


func _on_card_clicked(idx: int) -> void:
	if current_index != idx:
		var delta: int = idx - current_index
		_select_character_by_index(idx, true, 1 if delta > 0 else -1)
	else:
		_on_confirm_pressed()


func _select_character_by_index(idx: int, play_sound_fx: bool = true, explicit_direction: int = 0) -> void:
	if idx < 0 or idx >= HERO_ORDER.size():
		return

	var prev_idx: int = current_index
	current_index = idx
	current_hover_id = HERO_ORDER[idx]

	if play_sound_fx:
		_play_sound(_sfx_move)

	var dir: int = explicit_direction
	if dir == 0:
		dir = 1 if current_index > prev_idx else (-1 if current_index < prev_idx else 0)

	_animate_character_slide(current_hover_id, dir, play_sound_fx)
	_update_selection_frame(current_hover_id)
	_update_stats_display(current_hover_id)


func _animate_character_slide(char_id: String, _direction: int, animated: bool) -> void:
	var next_texture: Texture2D = HERO_TEXTURES.get(char_id)
	if next_texture == null or background_slot == null or incoming_slot == null:
		return

	if not animated:
		if _slide_tween != null and _slide_tween.is_valid():
			_slide_tween.kill()
		background_slot.texture = next_texture
		background_slot.position = Vector2.ZERO
		background_slot.modulate = Color.WHITE
		incoming_slot.modulate = Color(1.0, 1.0, 1.0, 0.0)
		incoming_slot.position = Vector2.ZERO
		return

	# Interrompe qualquer transição anterior com segurança e aplica o estado imediatamente
	if _slide_tween != null and _slide_tween.is_valid():
		_slide_tween.kill()
		if incoming_slot.texture != null and incoming_slot.modulate.a > 0.0:
			background_slot.texture = incoming_slot.texture
		incoming_slot.modulate = Color(1.0, 1.0, 1.0, 0.0)

	# Fundo permanece 100% opaco e imóvel: elimina qualquer piscada escura ou vertigem
	background_slot.position = Vector2.ZERO
	background_slot.modulate = Color.WHITE

	incoming_slot.texture = next_texture
	incoming_slot.position = Vector2.ZERO
	incoming_slot.modulate = Color(1.0, 1.0, 1.0, 0.0)

	# Dissolvência suave e estável (0.13s): apenas o realce do herói e os stats transicionam
	_slide_tween = create_tween()
	_slide_tween.tween_property(incoming_slot, "modulate:a", 1.0, 0.13).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_slide_tween.tween_callback(func():
		background_slot.texture = next_texture
		incoming_slot.modulate = Color(1.0, 1.0, 1.0, 0.0)
	)


func _update_selection_frame(char_id: String) -> void:
	var target_card: Button = card_nodes.get(char_id) as Button
	if target_card == null or selection_frame == null:
		return

	var card_global_pos: Vector2 = target_card.global_position
	var card_size: Vector2 = target_card.size
	var glow_margin := Vector2(16.0, 16.0)
	var target_pos: Vector2 = card_global_pos - glow_margin
	var target_sz: Vector2 = card_size + (glow_margin * 2.0)

	if _frame_tween != null and _frame_tween.is_valid():
		_frame_tween.kill()

	_frame_tween = create_tween().set_parallel(true)
	_frame_tween.tween_property(selection_frame, "global_position", target_pos, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_frame_tween.tween_property(selection_frame, "size", target_sz, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_frame_tween.tween_property(selection_frame, "modulate:a", 1.0, 0.08)


func _update_stats_display(char_id: String) -> void:
	var game_session = get_node_or_null("/root/GameSession")
	var is_unlocked: bool = (char_id == "guilherme")
	if game_session != null and game_session.has_method("is_character_unlocked"):
		is_unlocked = game_session.is_character_unlocked(char_id)

	if stats_texture_rect != null and _stats_cache.has(char_id):
		stats_texture_rect.texture = _stats_cache[char_id]

	var stats: Dictionary = {"strength": 3, "speed": 2, "technique": 3}
	if game_session != null and game_session.has_method("get_character_stats"):
		stats = game_session.get_character_stats(char_id)

	var forca: int = int(stats.get("strength", 3))
	var vel: int = int(stats.get("speed", 2))
	var tec: int = int(stats.get("technique", 3))

	if stat_forca_label != null:
		stat_forca_label.text = "FORÇA:      " + _generate_bar_string(forca)
	if stat_vel_label != null:
		stat_vel_label.text = "VELOCIDADE: " + _generate_bar_string(vel)
	if stat_tec_label != null:
		stat_tec_label.text = "TÉCNICA:    " + _generate_bar_string(tec)

	if is_unlocked:
		if status_label != null:
			status_label.text = "HERÓI SELECIONADO: GUILHERME (DISPONÍVEL)"
			status_label.modulate = Color(1.0, 0.85, 0.15, 1.0)
		if char_desc_label != null:
			char_desc_label.text = "O Guerreiro de Sakas — Equilibrado e pronto para o combate nas ruas da Vila Prudente."
			char_desc_label.modulate = Color(0.85, 0.9, 0.95, 1.0)
		if btn_confirm != null:
			btn_confirm.disabled = false
			btn_confirm.text = "⚡ ESCOLHER GUILHERME — INICIAR FASE 1"
			btn_confirm.modulate = Color(1.0, 1.0, 1.0, 1.0)
	else:
		var hero_name: String = char_id.capitalize()
		if status_label != null:
			status_label.text = "⚠️ %s ESTÁ BLOQUEADO (EM DESENVOLVIMENTO)" % hero_name.to_upper()
			status_label.modulate = Color(0.95, 0.25, 0.35, 1.0)
		if char_desc_label != null:
			char_desc_label.text = "Guerreiro trancado nesta versão arcade. Derrote os chefões para desbloquear."
			char_desc_label.modulate = Color(0.7, 0.7, 0.75, 1.0)
		if btn_confirm != null:
			btn_confirm.disabled = true
			btn_confirm.text = "🔒 BLOQUEADO"
			btn_confirm.modulate = Color(0.6, 0.6, 0.65, 0.7)


func _generate_bar_string(val: int) -> String:
	var result: String = ""
	for i in range(5):
		result += "■ " if i < val else "□ "
	return result.strip_edges()


func _on_confirm_pressed() -> void:
	if _is_transitioning_scene:
		return

	# Restrição master do jogo: apenas Guilherme inicia a partida
	if current_hover_id != "guilherme":
		_deny_character_selection()
		return

	_is_transitioning_scene = true
	_play_sound(_sfx_confirm)

	# Efeito sutil de confirmação arcade (sem flash ofuscante)
	if flash_rect != null:
		flash_rect.color = Color(1.0, 0.95, 0.85, 0.18)
		if _flash_tween != null and _flash_tween.is_valid():
			_flash_tween.kill()
		_flash_tween = create_tween()
		_flash_tween.tween_property(flash_rect, "color:a", 0.0, 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	var game_session = get_node_or_null("/root/GameSession")
	if game_session != null:
		game_session.select_character("guilherme")

	_safe_handle_input()
	await get_tree().create_timer(0.20).timeout
	var err := get_tree().change_scene_to_file(DIFFICULTY_SELECT_SCENE)
	if err != OK:
		printerr("Erro ao carregar a tela de dificuldade: ", err)


func _deny_character_selection() -> void:
	_play_sound(_sfx_denied)

	# Micro-vibração suave e localizada (sem deslocamento brusco da tela)
	if display_layer != null:
		if _shake_tween != null and _shake_tween.is_valid():
			_shake_tween.kill()
		_shake_tween = create_tween()
		_shake_tween.tween_property(display_layer, "position:x", -3.0, 0.03)
		_shake_tween.tween_property(display_layer, "position:x", 3.0, 0.03)
		_shake_tween.tween_property(display_layer, "position:x", -1.5, 0.03)
		_shake_tween.tween_property(display_layer, "position:x", 1.5, 0.03)
		_shake_tween.tween_property(display_layer, "position:x", 0.0, 0.03)

	# Pulso avermelhado muito suave de acesso bloqueado (sem piscar forte)
	if flash_rect != null:
		flash_rect.color = Color(0.9, 0.15, 0.2, 0.14)
		if _flash_tween != null and _flash_tween.is_valid():
			_flash_tween.kill()
		_flash_tween = create_tween()
		_flash_tween.tween_property(flash_rect, "color:a", 0.0, 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _on_back_pressed() -> void:
	if _is_transitioning_scene:
		return
	_is_transitioning_scene = true
	_play_sound(_sfx_denied)
	get_tree().change_scene_to_file(MAIN_MENU_SCENE)


func _play_sound(stream: AudioStreamWAV) -> void:
	if audio_player != null and stream != null:
		audio_player.stream = stream
		audio_player.play()


func _generate_audio_effects() -> void:
	_sfx_move = _create_wav(680.0, 0.035, 0.25)
	_sfx_confirm = _create_wav(1080.0, 0.12, 0.4)
	_sfx_denied = _create_wav(140.0, 0.15, 0.45)


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
