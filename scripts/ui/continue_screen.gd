class_name ContinueScreen
extends Control

## Tela de Continuar / Carregamento de Slot (assets/backgrounds/continuar.webp).
## Exibe metadados de cada slot salvo: Mapa, Herói, Dificuldade, Data e Horário.
## Se o slot estiver vazio, nenhuma transição de jogo ocorre ao clicar.

const MAIN_MENU_SCENE: String = "res://scenes/ui/main_menu.tscn"

@onready var slot_1: Button = %Slot1
@onready var slot_2: Button = %Slot2
@onready var slot_3: Button = %Slot3
@onready var slot_4: Button = %Slot4

@onready var slot_1_title: Label = %Slot1Title
@onready var slot_1_details: Label = %Slot1Details
@onready var slot_2_title: Label = %Slot2Title
@onready var slot_2_details: Label = %Slot2Details
@onready var slot_3_title: Label = %Slot3Title
@onready var slot_3_details: Label = %Slot3Details
@onready var slot_4_title: Label = %Slot4Title
@onready var slot_4_details: Label = %Slot4Details

@onready var notice_label: Label = %NoticeLabel
@onready var btn_confirm: Button = %BtnConfirm
@onready var btn_back: Button = %BtnBack
@onready var audio_player: AudioStreamPlayer = %AudioPlayer

var current_slot: int = 1
var _is_transitioning: bool = false
var _slot_buttons: Array[Button] = []
var _title_labels: Array[Label] = []
var _detail_labels: Array[Label] = []
var _shake_tween: Tween = null

var _sfx_move: AudioStreamWAV
var _sfx_confirm: AudioStreamWAV
var _sfx_cancel: AudioStreamWAV


func _ready() -> void:
	_generate_audio_effects()

	_slot_buttons = [slot_1, slot_2, slot_3, slot_4]
	_title_labels = [slot_1_title, slot_2_title, slot_3_title, slot_4_title]
	_detail_labels = [slot_1_details, slot_2_details, slot_3_details, slot_4_details]

	if btn_confirm != null:
		btn_confirm.pressed.connect(_on_confirm_pressed)
	if btn_back != null:
		btn_back.pressed.connect(_on_back_pressed)

	if slot_1 != null:
		slot_1.pressed.connect(func(): _on_slot_clicked(1))
	if slot_2 != null:
		slot_2.pressed.connect(func(): _on_slot_clicked(2))
	if slot_3 != null:
		slot_3.pressed.connect(func(): _on_slot_clicked(3))
	if slot_4 != null:
		slot_4.pressed.connect(func(): _on_slot_clicked(4))

	_refresh_all_slots()
	_select_slot(1, false)


func _refresh_all_slots() -> void:
	var session = get_node_or_null("/root/GameSession")
	for i in range(4):
		var slot_idx: int = i + 1
		var title_lbl: Label = _title_labels[i] if i < _title_labels.size() else null
		var det_lbl: Label = _detail_labels[i] if i < _detail_labels.size() else null

		if session != null and session.has_method("has_save_in_slot") and session.has_save_in_slot(slot_idx):
			var data: Dictionary = session.get_save_info(slot_idx)
			var lvl: String = str(data.get("level_name", "Fase Desconhecida")).to_upper()
			var hero: String = str(data.get("character_id", "Guilherme")).to_upper()
			var diff_raw: String = str(data.get("difficulty_id", "Normal")).to_lower()
			var diff: String = "DIFÍCIL" if diff_raw.begins_with("dific") else ("FÁCIL" if diff_raw.begins_with("fac") else diff_raw.to_upper())
			var dt: String = str(data.get("date_time", ""))

			if title_lbl != null:
				title_lbl.text = "SLOT %d: %s — %s" % [slot_idx, lvl, hero]
				title_lbl.modulate = Color(1.0, 0.9, 0.4, 1.0)
			if det_lbl != null:
				det_lbl.text = "DIFICULDADE: %s  •  SALVO EM: %s" % [diff, dt]
				det_lbl.modulate = Color(0.85, 0.92, 1.0, 0.95)
		else:
			if title_lbl != null:
				title_lbl.text = "SLOT %d: — VAZIO —" % slot_idx
				title_lbl.modulate = Color(0.65, 0.70, 0.78, 0.6)
			if det_lbl != null:
				det_lbl.text = "Nenhum progresso gravado neste slot"
				det_lbl.modulate = Color(0.55, 0.60, 0.68, 0.5)


func _select_slot(slot_idx: int, play_sfx: bool = true) -> void:
	var changed: bool = (current_slot != slot_idx)
	current_slot = clampi(slot_idx, 1, 4)

	for i in range(_slot_buttons.size()):
		var btn := _slot_buttons[i]
		if btn != null:
			if (i + 1) == current_slot:
				btn.modulate = Color(1.25, 1.2, 0.85, 1.0)
			else:
				btn.modulate = Color(0.88, 0.88, 0.92, 0.85)

	if notice_label != null:
		notice_label.text = ""

	if changed and play_sfx:
		_play_sound(_sfx_move)


func _on_slot_clicked(slot_idx: int) -> void:
	if current_slot != slot_idx:
		_select_slot(slot_idx, true)
	else:
		_on_confirm_pressed()


func _on_confirm_pressed() -> void:
	if _is_transitioning:
		return

	var session = get_node_or_null("/root/GameSession")
	var has_save: bool = false
	if session != null and session.has_method("has_save_in_slot"):
		has_save = session.has_save_in_slot(current_slot)

	# REGRA ESTREITA: Para slots vazios, absolutamente NADA acontece (não entra no jogo)
	if not has_save:
		_play_sound(_sfx_cancel)
		_show_notice("⚠️ ESTE SLOT ESTÁ VAZIO! ESCOLHA UM SLOT SALVO.")
		_shake_slot_button(current_slot)
		return

	_is_transitioning = true
	_play_sound(_sfx_confirm)
	_show_notice("CARREGANDO SLOT %d..." % current_slot, Color(0.4, 1.0, 0.5, 1.0))

	_safe_handle_input()
	await get_tree().create_timer(0.20).timeout

	var ok: bool = session.load_game_from_slot(current_slot)
	if not ok:
		_is_transitioning = false
		_show_notice("Erro ao carregar o arquivo do Slot %d." % current_slot)


func _shake_slot_button(slot_idx: int) -> void:
	var btn_idx: int = slot_idx - 1
	if btn_idx < 0 or btn_idx >= _slot_buttons.size():
		return
	var target_btn := _slot_buttons[btn_idx]
	if target_btn == null:
		return

	if _shake_tween != null and _shake_tween.is_valid():
		_shake_tween.kill()

	var orig_x: float = target_btn.position.x
	_shake_tween = create_tween()
	_shake_tween.tween_property(target_btn, "position:x", orig_x - 8.0, 0.04)
	_shake_tween.tween_property(target_btn, "position:x", orig_x + 8.0, 0.04)
	_shake_tween.tween_property(target_btn, "position:x", orig_x - 4.0, 0.04)
	_shake_tween.tween_property(target_btn, "position:x", orig_x, 0.04)


func _show_notice(msg: String, col: Color = Color(1.0, 0.35, 0.35, 1.0)) -> void:
	if notice_label != null:
		notice_label.text = msg
		notice_label.modulate = col


func _on_back_pressed() -> void:
	if _is_transitioning:
		return
	_is_transitioning = true
	_play_sound(_sfx_cancel)

	_safe_handle_input()
	var err := get_tree().change_scene_to_file(MAIN_MENU_SCENE)
	if err != OK:
		_is_transitioning = false
		printerr("Erro ao retornar ao menu principal: ", err)


func _unhandled_input(event: InputEvent) -> void:
	if _is_transitioning:
		return

	if event.is_action_pressed("ui_cancel") or (event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE):
		_safe_handle_input()
		_on_back_pressed()
	elif event.is_action_pressed("ui_accept") or (event is InputEventKey and event.pressed and not event.echo and (event.keycode == KEY_ENTER or event.keycode == KEY_SPACE)):
		_safe_handle_input()
		_on_confirm_pressed()
	elif event.is_action_pressed("ui_up") or (event is InputEventKey and event.pressed and not event.echo and (event.keycode == KEY_W or event.keycode == KEY_UP)):
		_safe_handle_input()
		_select_slot(current_slot - 1, true)
	elif event.is_action_pressed("ui_down") or (event is InputEventKey and event.pressed and not event.echo and (event.keycode == KEY_S or event.keycode == KEY_DOWN)):
		_safe_handle_input()
		_select_slot(current_slot + 1, true)


func _safe_handle_input() -> void:
	if get_viewport() != null:
		get_viewport().set_input_as_handled()


func _play_sound(stream: AudioStreamWAV) -> void:
	if audio_player != null and stream != null:
		audio_player.stream = stream
		audio_player.play()


func _generate_audio_effects() -> void:
	_sfx_move = _create_wav(680.0, 0.04, 0.25)
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
		var t := float(i) / 22050.0
		var envelope := 1.0 - (float(i) / float(sample_count))
		var wave := sin(t * freq * TAU)
		var val := (wave * volume * envelope) * 127.0 + 128.0
		data[i] = int(clamp(val, 0.0, 255.0))
	wav.data = data
	return wav
