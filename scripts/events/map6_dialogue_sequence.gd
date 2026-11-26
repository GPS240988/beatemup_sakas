extends CanvasLayer

## Diálogos do Map 6 em dois momentos: conversa de chegada automática e,
## somente após interação com Pelé, negociação guiada por duas escolhas.

signal speaker_line(speaker: String, action: String)
signal arrival_finished
signal sequence_finished
signal starting_speaker_selected(character_id: String)

const StandardDialogueBoxClass = preload("res://scripts/ui/standard_dialogue_box.gd")
const STORY_BACKGROUND_PATH: String = "res://assets/backgrounds/maps/fase2/story_happen.webp"
const ARCADE_FONT: FontFile = preload("res://assets/fonts/arcade_bold.ttf")

const PORTRAITS: Dictionary = {
	"GUILHERME": "res://assets/ui/hud/portraits/portrait_guilherme.png",
	"GABRIEL": "res://assets/ui/hud/portraits/portrait_gabriel.png",
	"ANDRÉ": "res://assets/ui/hud/portraits/portrait_andre.png",
	"JULIANA": "res://assets/ui/hud/portraits/portrait_juliana.png",
	"ALESSANDRO": "res://assets/ui/hud/portraits/portrait_alessandro.png"
}

const CHARACTER_IDS: Array[String] = ["guilherme", "gabriel", "andre"]

## Abertura obrigatória ao carregar o Map 6. Não contém falas de Pelé.
const ARRIVAL_LINES: Array[Dictionary] = [
	{"speaker": "ANDRÉ", "text": "Agora sim! Depois daquela confusão, eu mereço comer até esquecer meu nome."},
	{"speaker": "GABRIEL", "text": "Você fala isso em todo lugar que tem comida."},
	{"speaker": "ANDRÉ", "text": "E em todo lugar eu estou certo."},
	{"speaker": "GUILHERME", "text": "Só vamos entrar, comer e ficar tranquilos. Hoje não precisamos arrumar mais problema."},
	{"speaker": "ALESSANDRO", "text": "Só lembrando que a gente combinou uma coisa antes de chegar."},
	{"speaker": "GABRIEL", "text": "Duas entradas. Cinco pessoas. Vamos manter o plano."},
	{"speaker": "ANDRÉ", "text": "Fácil. É só não entregar a estratégia antes da hora."},
	{"speaker": "JULIANA", "text": "Vocês ensaiaram isso mesmo?"},
	{"speaker": "ANDRÉ", "text": "Não precisa ensaiar o talento."}
]

## Só é reproduzido depois que o jogador se aproxima de Pelé e interage com ele.
const PELE_CONTACT_LINES: Array[Dictionary] = [
	{"speaker": "PELÉ", "text": "Boa noite, rapaziada.", "action": "idle_neutral"},
	{"speaker": "GUILHERME", "text": "Boa noite, tudo certo?"},
	{"speaker": "PELÉ", "text": "Tudo tranquilo. São quantos?", "action": "idle_attentive"},
	{"speaker": "ANDRÉ", "text": "Dois."},
	{"speaker": "PELÉ", "text": "Dois?", "action": "skeptical"},
	{"speaker": "GABRIEL", "text": "Ele quis dizer... dois... dois grupos."},
	{"speaker": "PELÉ", "text": "Ah, tá."},
	{"speaker": "PELÉ", "text": "E os outros três?", "action": "skeptical"},
	{"speaker": "JULIANA", "text": "Começou bem."}
]

const NEGOTIATION_GUILHERME: Array[Dictionary] = [
	{"speaker": "GUILHERME", "text": "Então, Pelé... a gente queria conversar sobre o rodízio."},
	{"speaker": "PELÉ", "text": "Pode falar.", "action": "idle_attentive"},
	{"speaker": "GUILHERME", "text": "Somos cinco, mas será que existe alguma possibilidade de fechar duas entradas e organizar o restante de outra maneira?"},
	{"speaker": "PELÉ", "text": "Duas entradas para cinco pessoas?", "action": "skeptical"},
	{"speaker": "GUILHERME", "text": "É... seria uma situação um pouco diferente."},
	{"speaker": "PELÉ", "text": "Diferente eu percebi.", "action": "skeptical"},
	{"speaker": "ANDRÉ", "text": "A gente tentou."}
]

const NEGOTIATION_GABRIEL: Array[Dictionary] = [
	{"speaker": "GABRIEL", "text": "Pelé, vamos facilitar. A gente paga duas entradas e os outros três ficam acompanhando."},
	{"speaker": "PELÉ", "text": "Acompanhando o quê?", "action": "skeptical"},
	{"speaker": "GABRIEL", "text": "Acompanhando a experiência."},
	{"speaker": "PELÉ", "text": "E vão comer o quê? A experiência?", "action": "skeptical"},
	{"speaker": "GABRIEL", "text": "A gente pode consumir bebida normalmente."},
	{"speaker": "PELÉ", "text": "A bebida também está inclusa no rodízio, meu parceiro.", "action": "skeptical"},
	{"speaker": "JULIANA", "text": "Acho que ele entendeu o plano inteiro."}
]

const NEGOTIATION_ANDRE: Array[Dictionary] = [
	{"speaker": "ANDRÉ", "text": "Pelé, deixa eu te explicar uma situação."},
	{"speaker": "PELÉ", "text": "Estou ouvindo.", "action": "idle_attentive"},
	{"speaker": "ANDRÉ", "text": "Somos cinco amigos, mas nem todos comem a mesma quantidade."},
	{"speaker": "PELÉ", "text": "Certo."},
	{"speaker": "ANDRÉ", "text": "Então, tecnicamente, duas pessoas poderiam representar o consumo de cinco."},
	{"speaker": "PELÉ", "text": "Tecnicamente?", "action": "skeptical"},
	{"speaker": "ANDRÉ", "text": "É uma questão de distribuição."},
	{"speaker": "PELÉ", "text": "Distribuição de quê?", "action": "skeptical"},
	{"speaker": "ANDRÉ", "text": "De pizza."},
	{"speaker": "PELÉ", "text": "Rapaz... vocês vieram jantar ou fazer uma reunião?", "action": "skeptical"}
]

const COMMON_ENDING: Array[Dictionary] = [
	{"speaker": "PELÉ", "text": "Seguinte, rapaziada. Aqui funciona assim: entrou no rodízio, cada um paga o seu.", "action": "gesture_stop"},
	{"speaker": "GABRIEL", "text": "Então não tem como fazer diferente?"},
	{"speaker": "PELÉ", "text": "Não."},
	{"speaker": "ANDRÉ", "text": "Nem uma condição especial?"},
	{"speaker": "PELÉ", "text": "Tem. Paga cinco entradas e come cinco pessoas.", "action": "gesture_stop"},
	{"speaker": "JULIANA", "text": "Acho que acabou a negociação."},
	{"speaker": "ALESSANDRO", "text": "Vamos entrar logo antes que ele cobre pela conversa também."},
	{"speaker": "PELÉ", "text": "Agora vocês começaram a entender.", "action": "amused"},
	{"speaker": "ANDRÉ", "text": "Pelo menos a gente tentou."},
	{"speaker": "GABRIEL", "text": "Tentou muito mal."},
	{"speaker": "GUILHERME", "text": "O importante é que agora estamos aqui."},
	{"speaker": "JULIANA", "text": "E alguém vai ter que pagar a conta."},
	{"speaker": "ALESSANDRO", "text": "Vamos resolver isso lá dentro."},
	{"speaker": "PELÉ", "text": "Podem entrar. E juízo aí dentro.", "action": "gesture_allow_entry"}
]

const STORY_ART_BOTTOM_DESKTOP: float = 0.65
const STORY_DIALOGUE_TOP_DESKTOP: float = 0.67
const STORY_ART_BOTTOM_MOBILE: float = 0.62
const STORY_DIALOGUE_TOP_MOBILE: float = 0.64
const STORY_DIALOGUE_BOTTOM: float = 0.98

var start_mode: String = "arrival"

var _root_control: Control = null
var _art_stage: Control = null
var _dialogue_area: Control = null
var _backdrop_texture: TextureRect = null
var _transition_overlay: ColorRect = null
var _backdrop_zoom_tween: Tween = null
var _portrait: TextureRect = null
var _speaker_label: Label = null
var _dialogue_label: Label = null
var _continue_label: Label = null
var _choice_panel: PanelContainer = null
var _choice_buttons: Array[Button] = []
var _typewriter_tween: Tween = null
var _is_typing: bool = false
var _waiting_for_release: bool = true
var _phase: String = "arrival"
var _lines: Array[Dictionary] = []
var _line_index: int = 0
var _selected_order: Array[String] = []


func _init() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 125


func _ready() -> void:
	if start_mode == "negotiation":
		_phase = "transition"
	_build_dialogue_ui()
	if start_mode == "negotiation":
		await _play_scene_entry_transition()
		_phase = "contact"
		_lines = PELE_CONTACT_LINES.duplicate(true)
	else:
		_phase = "arrival"
		_lines = ARRIVAL_LINES.duplicate(true)
	_show_next_line()


func _build_dialogue_ui() -> void:
	_root_control = Control.new()
	_root_control.name = "Map6DialogueRoot"
	_root_control.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root_control.mouse_filter = Control.MOUSE_FILTER_STOP
	_root_control.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_root_control)

	var is_mobile: bool = _is_mobile_runtime()
	if start_mode == "negotiation":
		_build_happen_story_backdrop(is_mobile)

	var ui: Dictionary = StandardDialogueBoxClass.build_dialogue_ui(_root_control, is_mobile)
	_dialogue_area = ui["dialogue_area"] as Control
	_portrait = ui["portrait"] as TextureRect
	_speaker_label = ui["speaker_label"] as Label
	_dialogue_label = ui["dialogue_label"] as Label
	_continue_label = ui["continue_label"] as Label
	if start_mode == "negotiation":
		_dialogue_area.anchor_top = STORY_DIALOGUE_TOP_MOBILE if is_mobile else STORY_DIALOGUE_TOP_DESKTOP
		_dialogue_area.anchor_bottom = STORY_DIALOGUE_BOTTOM
		_dialogue_area.offset_top = 0.0
		_dialogue_area.offset_bottom = 0.0
		_dialogue_area.custom_minimum_size = Vector2(0.0, 216.0 if not is_mobile else 232.0)
		_dialogue_area.z_index = 2

	if start_mode == "negotiation" and _backdrop_texture != null:
		_transition_overlay = ColorRect.new()
		_transition_overlay.name = "StoryTransitionOverlay"
		_transition_overlay.color = Color.BLACK
		_transition_overlay.modulate.a = 1.0
		_transition_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_transition_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_transition_overlay.z_index = 100
		_root_control.add_child(_transition_overlay)


func _build_happen_story_backdrop(is_mobile: bool) -> void:
	var story_texture := load(STORY_BACKGROUND_PATH) as Texture2D
	if story_texture == null:
		push_error("Map6DialogueSequence: arte da cena HAPPEN ausente: " + STORY_BACKGROUND_PATH)
		return

	var matte := ColorRect.new()
	matte.name = "StoryCinematicMatte"
	matte.color = Color(0.012, 0.013, 0.018, 1.0)
	matte.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	matte.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root_control.add_child(matte)

	_art_stage = Control.new()
	_art_stage.name = "HappenArtStage"
	_art_stage.anchor_left = 0.0
	_art_stage.anchor_top = 0.0
	_art_stage.anchor_right = 1.0
	_art_stage.anchor_bottom = STORY_ART_BOTTOM_MOBILE if is_mobile else STORY_ART_BOTTOM_DESKTOP
	_art_stage.clip_contents = true
	_art_stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root_control.add_child(_art_stage)

	_backdrop_texture = TextureRect.new()
	_backdrop_texture.name = "HappenStoryBackdrop"
	_backdrop_texture.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_backdrop_texture.texture = story_texture
	_backdrop_texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_backdrop_texture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_backdrop_texture.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_backdrop_texture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_art_stage.add_child(_backdrop_texture)

	var ambience_overlay := ColorRect.new()
	ambience_overlay.name = "StoryAmbienceOverlay"
	ambience_overlay.color = Color(0.015, 0.025, 0.055, 0.06)
	ambience_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ambience_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_art_stage.add_child(ambience_overlay)


func _play_scene_entry_transition() -> void:
	if _transition_overlay == null:
		return

	await get_tree().process_frame
	if _backdrop_texture != null:
		_backdrop_texture.pivot_offset = _backdrop_texture.size * 0.5
		_backdrop_texture.scale = Vector2.ONE

	var fade_in := create_tween()
	fade_in.tween_property(
		_transition_overlay,
		"modulate:a",
		0.0,
		0.68
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await fade_in.finished

	# Mantém a arte em escala neutra durante todas as falas. O zoom só acontece
	# depois da autorização, quando a caixa de diálogo já desapareceu.
	if _backdrop_texture != null:
		_backdrop_texture.scale = Vector2.ONE


func _play_restaurant_entry_transition() -> void:
	_phase = "transition"
	if _backdrop_zoom_tween != null and _backdrop_zoom_tween.is_valid():
		_backdrop_zoom_tween.kill()

	await get_tree().process_frame
	if _backdrop_texture != null:
		# O foco do push-in é a porta de vidro, sugerindo a câmera atravessando a entrada.
		_backdrop_texture.pivot_offset = Vector2(
			_backdrop_texture.size.x * 0.655,
			_backdrop_texture.size.y * 0.565
		)

	var exit_tween := create_tween().set_parallel(true)
	if _dialogue_area != null:
		exit_tween.tween_property(_dialogue_area, "modulate:a", 0.0, 0.28)
	if _backdrop_texture != null:
		exit_tween.tween_property(
			_backdrop_texture,
			"scale",
			Vector2(1.18, 1.18),
			1.12
		).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_IN)
	if _transition_overlay != null:
		exit_tween.tween_property(
			_transition_overlay,
			"modulate:a",
			1.0,
			0.78
		).set_delay(0.30).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	await exit_tween.finished
	sequence_finished.emit()
	queue_free()


func _process(_delta: float) -> void:
	if _waiting_for_release and not _is_advance_input_held():
		_waiting_for_release = false


func _input(event: InputEvent) -> void:
	if _phase == "transition" or _waiting_for_release:
		return
	if _phase == "choice":
		_handle_choice_input(event)
		return
	if not _is_advance_event(event):
		return
	get_viewport().set_input_as_handled()
	if _is_typing:
		_finish_typewriter()
	else:
		_advance_line()


func _handle_choice_input(event: InputEvent) -> void:
	if event is InputEventJoypadButton:
		var joy_event := event as InputEventJoypadButton
		if joy_event.pressed and joy_event.button_index == JOY_BUTTON_A:
			var focused_index: int = _get_focused_choice_index()
			if focused_index >= 0:
				_on_choice_selected(str(_choice_buttons[focused_index].get_meta("character_id")))
			get_viewport().set_input_as_handled()
		return

	if not event is InputEventKey:
		return
	var key_event := event as InputEventKey
	if not key_event.pressed or key_event.echo:
		return

	match key_event.keycode:
		KEY_1:
			_on_choice_selected("guilherme")
		KEY_2:
			_on_choice_selected("gabriel")
		KEY_3:
			_on_choice_selected("andre")
		KEY_LEFT, KEY_A:
			_move_choice_focus(-1)
		KEY_RIGHT, KEY_D:
			_move_choice_focus(1)
		KEY_UP, KEY_W:
			_move_choice_focus(-1)
		KEY_DOWN, KEY_S:
			_move_choice_focus(1)
		KEY_J:
			var focused_index: int = _get_focused_choice_index()
			if focused_index >= 0:
				_on_choice_selected(str(_choice_buttons[focused_index].get_meta("character_id")))
		KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
			var focused_index: int = _get_focused_choice_index()
			if focused_index >= 0:
				_on_choice_selected(str(_choice_buttons[focused_index].get_meta("character_id")))
	get_viewport().set_input_as_handled()


func _get_focused_choice_index() -> int:
	for index in range(_choice_buttons.size()):
		if _choice_buttons[index].has_focus() and not _choice_buttons[index].disabled:
			return index
	for index in range(_choice_buttons.size()):
		if not _choice_buttons[index].disabled:
			return index
	return -1


func _move_choice_focus(direction: int) -> void:
	if _choice_buttons.is_empty():
		return
	var current: int = _get_focused_choice_index()
	if current < 0:
		return
	for offset in range(1, _choice_buttons.size() + 1):
		var candidate: int = posmod(current + direction * offset, _choice_buttons.size())
		if not _choice_buttons[candidate].disabled:
			_choice_buttons[candidate].grab_focus()
			return


func _is_advance_input_held() -> bool:
	if Input.is_key_pressed(KEY_ENTER) or Input.is_key_pressed(KEY_KP_ENTER) or Input.is_key_pressed(KEY_SPACE):
		return true
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		return true
	for device_id in Input.get_connected_joypads():
		if Input.is_joy_button_pressed(device_id, JOY_BUTTON_A):
			return true
	return false


func _is_advance_event(event: InputEvent) -> bool:
	if event is InputEventKey:
		var key_event := event as InputEventKey
		return key_event.pressed and not key_event.echo and key_event.keycode in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE]
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		return mouse_event.pressed and mouse_event.button_index == MOUSE_BUTTON_LEFT
	if event is InputEventScreenTouch:
		return (event as InputEventScreenTouch).pressed
	if event is InputEventJoypadButton:
		var joy_event := event as InputEventJoypadButton
		return joy_event.pressed and joy_event.button_index == JOY_BUTTON_A
	return false


func _show_next_line() -> void:
	if _line_index >= _lines.size():
		_match_dialogue_phase_end()
		return

	var line: Dictionary = _lines[_line_index]
	var speaker: String = str(line.get("speaker", ""))
	var text: String = str(line.get("text", ""))
	var action: String = str(line.get("action", ""))
	_update_speaker_portrait(speaker, action)
	_speaker_label.text = speaker
	_dialogue_label.text = text
	_dialogue_label.visible_characters = 0
	_continue_label.visible = false
	speaker_line.emit(speaker, action)
	_start_typewriter()


func _match_dialogue_phase_end() -> void:
	match _phase:
		"arrival":
			arrival_finished.emit()
			queue_free()
		"contact":
			_show_choice()
		"approach":
			if _selected_order.size() == 1:
				_show_choice()
			elif _selected_order.size() == 2:
				var remaining: Array[String] = _get_remaining_characters()
				if not remaining.is_empty():
					_selected_order.append(remaining[0])
					_start_attempt(remaining[0])
				else:
					_start_common_ending()
			else:
				_start_common_ending()
		"ending":
			_play_restaurant_entry_transition()


func _show_choice() -> void:
	_phase = "choice"
	var choice_number: int = _selected_order.size() + 1
	_speaker_label.text = "ESCOLHA %d/2" % choice_number
	_portrait.visible = false
	_dialogue_label.text = "Quem vai tentar convencer o Pelé primeiro?" if choice_number == 1 else "Quem tenta convencer o Pelé agora?"
	_dialogue_label.visible_characters = -1
	_continue_label.visible = false
	if _dialogue_area != null:
		_dialogue_area.visible = false
	_create_choice_panel()


func _create_choice_panel() -> void:
	if _choice_panel != null and is_instance_valid(_choice_panel):
		_choice_panel.queue_free()
	_choice_buttons.clear()

	_choice_panel = PanelContainer.new()
	_choice_panel.name = "NegotiatorChoice"
	_choice_panel.anchor_left = 0.10
	_choice_panel.anchor_top = STORY_DIALOGUE_TOP_DESKTOP
	_choice_panel.anchor_right = 0.90
	_choice_panel.anchor_bottom = 0.98
	_choice_panel.add_theme_stylebox_override("panel", _create_panel_style())
	_root_control.add_child(_choice_panel)

	var is_mobile: bool = _is_mobile_runtime()
	if is_mobile:
		_choice_panel.anchor_left = 0.04
		_choice_panel.anchor_top = STORY_DIALOGUE_TOP_MOBILE
		_choice_panel.anchor_right = 0.96
		_choice_panel.anchor_bottom = 0.98
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 5)
	_choice_panel.add_child(content)
	var prompt := Label.new()
	prompt.text = _dialogue_label.text
	prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt.label_settings = StandardDialogueBoxClass.create_speaker_settings(is_mobile)
	prompt.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	content.add_child(prompt)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8 if is_mobile else 12)
	content.add_child(row)

	_add_choice_button(row, "GUILHERME", "guilherme")
	_add_choice_button(row, "GABRIEL", "gabriel")
	_add_choice_button(row, "ANDRÉ", "andre")
	var first_enabled: int = _get_focused_choice_index()
	if first_enabled >= 0:
		_choice_buttons[first_enabled].grab_focus()


func _add_choice_button(parent: HBoxContainer, label_text: String, character_id: String) -> void:
	var is_mobile: bool = _is_mobile_runtime()
	var button := Button.new()
	button.text = label_text + (" ✓" if _selected_order.has(character_id) else "")
	button.focus_mode = Control.FOCUS_ALL
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.custom_minimum_size = Vector2(0.0, 54.0 if is_mobile else 58.0)
	button.add_theme_font_override("font", ARCADE_FONT)
	button.add_theme_font_size_override("font_size", 16 if is_mobile else 20)
	button.add_theme_color_override("font_color", Color(0.97, 0.94, 0.85, 1.0))
	button.add_theme_color_override("font_hover_color", Color(1.0, 0.84, 0.42, 1.0))
	button.add_theme_color_override("font_focus_color", Color(1.0, 0.84, 0.42, 1.0))
	button.add_theme_color_override("font_disabled_color", Color(0.48, 0.47, 0.45, 1.0))
	button.add_theme_stylebox_override("normal", _create_button_style(false))
	button.add_theme_stylebox_override("hover", _create_button_style(true))
	button.add_theme_stylebox_override("focus", _create_button_style(true))
	button.add_theme_stylebox_override("disabled", _create_button_style(false))
	button.disabled = _selected_order.has(character_id)
	button.set_meta("character_id", character_id)
	button.pressed.connect(_on_choice_selected.bind(character_id))
	parent.add_child(button)
	_choice_buttons.append(button)


func _is_mobile_runtime() -> bool:
	return OS.has_feature("mobile") or OS.has_feature("web_android") or OS.has_feature("web_ios")


func _create_panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.035, 0.045, 0.075, 0.96)
	style.border_color = Color(0.78, 0.59, 0.29, 1.0)
	style.set_border_width_all(2)
	style.set_corner_radius_all(5)
	style.content_margin_left = 12.0
	style.content_margin_right = 12.0
	style.content_margin_top = 8.0
	style.content_margin_bottom = 8.0
	return style


func _create_button_style(highlighted: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.15, 0.13, 0.12, 1.0) if highlighted else Color(0.075, 0.085, 0.12, 1.0)
	style.border_color = Color(0.94, 0.75, 0.39, 1.0) if highlighted else Color(0.35, 0.31, 0.25, 1.0)
	style.set_border_width_all(2 if highlighted else 1)
	style.set_corner_radius_all(4)
	style.content_margin_left = 8.0
	style.content_margin_right = 8.0
	style.content_margin_top = 6.0
	style.content_margin_bottom = 6.0
	return style


func _on_choice_selected(character_id: String) -> void:
	if _phase != "choice" or not CHARACTER_IDS.has(character_id) or _selected_order.has(character_id):
		return
	_selected_order.append(character_id)
	if _selected_order.size() == 1:
		starting_speaker_selected.emit(character_id)
	if _choice_panel != null and is_instance_valid(_choice_panel):
		_choice_panel.queue_free()
	_choice_buttons.clear()
	if _dialogue_area != null:
		_dialogue_area.visible = true
	_start_attempt(character_id)


func _start_attempt(character_id: String) -> void:
	_phase = "approach"
	_lines = _get_negotiation_block(character_id)
	_line_index = 0
	_waiting_for_release = true
	_show_next_line()


func _get_negotiation_block(character_id: String) -> Array[Dictionary]:
	var source: Array[Dictionary] = []
	match character_id:
		"gabriel": source = NEGOTIATION_GABRIEL
		"andre": source = NEGOTIATION_ANDRE
		"guilherme": source = NEGOTIATION_GUILHERME
	var result: Array[Dictionary] = []
	for line in source:
		result.append(line.duplicate(true))
	return result


func _get_remaining_characters() -> Array[String]:
	var remaining: Array[String] = []
	for character_id in CHARACTER_IDS:
		if not _selected_order.has(character_id):
			remaining.append(character_id)
	return remaining


func _start_common_ending() -> void:
	_phase = "ending"
	_lines = COMMON_ENDING.duplicate(true)
	_line_index = 0
	_show_next_line()


func _update_speaker_portrait(speaker: String, action: String = "") -> void:
	if _portrait == null:
		return
	if speaker.strip_edges().to_upper() == "PELÉ":
		var pele: Node = get_tree().get_first_node_in_group("map6_pele")
		var pele_portrait: Texture2D = null
		if pele != null and pele.has_method("get_dialogue_portrait"):
			pele_portrait = pele.call("get_dialogue_portrait", action) as Texture2D
		_portrait.texture = pele_portrait
		_portrait.visible = pele_portrait != null
		_portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		return
	var portrait_path: String = str(PORTRAITS.get(speaker, ""))
	if portrait_path.is_empty() or not ResourceLoader.exists(portrait_path):
		_portrait.texture = null
		_portrait.visible = false
		return
	_portrait.texture = load(portrait_path) as Texture2D
	_portrait.visible = _portrait.texture != null
	_portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


func _start_typewriter() -> void:
	_is_typing = true
	var duration: float = float(_dialogue_label.text.length()) / maxf(StandardDialogueBoxClass.TYPEWRITER_SPEED_CPS, 1.0)
	_typewriter_tween = create_tween()
	_typewriter_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_typewriter_tween.tween_property(
		_dialogue_label,
		"visible_characters",
		_dialogue_label.text.length(),
		duration
	).set_trans(Tween.TRANS_LINEAR)
	_typewriter_tween.finished.connect(_on_typewriter_finished)


func _on_typewriter_finished() -> void:
	_is_typing = false
	_dialogue_label.visible_characters = -1
	_continue_label.visible = true


func _finish_typewriter() -> void:
	if _typewriter_tween != null and _typewriter_tween.is_valid():
		_typewriter_tween.kill()
	_is_typing = false
	_dialogue_label.visible_characters = -1
	_continue_label.visible = true


func _advance_line() -> void:
	_line_index += 1
	_show_next_line()
