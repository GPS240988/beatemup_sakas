extends Node

## Sequência final do Estágio 2 (Map 8 -> Map 7 HAPPEN):
## - Caminhada de retorno do banheiro até o caixa
## - Diálogo completo com expressões e animações de Gabriel, Guilherme, Garçonete e Juliana
## - Ação cinematográfica do disparo na comanda (comanda.png -> comanda_furada.png)
## - Tela final "FIM DO ESTÁGIO 2 / Até breve." e registro de conclusão do Estágio 2

signal finale_completed

const StandardDialogueBoxClass = preload("res://scripts/ui/standard_dialogue_box.gd")
const ARCADE_FONT: FontFile = preload("res://assets/fonts/arcade_bold.ttf")

const PORTRAIT_GABRIEL: String = "res://assets/ui/hud/portraits/portrait_gabriel.png"
const PORTRAIT_GUILHERME: String = "res://assets/ui/hud/portraits/portrait_guilherme.png"
const PORTRAIT_JULIANA: String = "res://assets/ui/hud/portraits/portrait_juliana.png"
const GARCONETE_IDLE_FRAME: String = "res://assets/sprites/characters/npc/garconete/frames/idle_01.png"
const GARCONETE_REACT_FRAME: String = "res://assets/sprites/characters/npc/garconete/frames/react_01.png"
const COMANDA_TEXTURE_PATH: String = "res://assets/sprites/stage2/happen_props/comanda.png"
const COMANDA_FURADA_TEXTURE_PATH: String = "res://assets/sprites/stage2/happen_props/comanda_furada.png"
const GUNSHOT_SFX_PATH: String = "res://assets/audio/sfx/tiro1.mp3"
const MAP_MENU_SCENE: String = "res://scenes/ui/map_menu.tscn"

const DIALOGUE_LINES: Array[Dictionary] = [
	{
		"id": "waitress_1",
		"speaker": "GARÇONETE",
		"portrait": "garconete_idle",
		"text": "Finalmente! E aí, quem vai pagar essa conta?",
	},
	{
		"id": "gabriel_fernando",
		"speaker": "GABRIEL",
		"portrait": "gabriel",
		"text": "Fernando...",
		"pre_pause": 0.35,
	},
	{
		"id": "guilherme_1",
		"speaker": "GUILHERME",
		"portrait": "guilherme",
		"text": "Nossa, mijei na comanda a toa, o Fernando morreu.",
	},
	{
		"id": "waitress_2",
		"speaker": "GARÇONETE",
		"portrait": "garconete_idle",
		"text": "Tá bom. Só espero que vocês tenham mais cuidado com a comanda da próxima vez.",
	},
	{
		"id": "gabriel_inteira",
		"speaker": "GABRIEL",
		"portrait": "gabriel",
		"text": "Olha, pelo menos dessa vez ela chegou inteira.",
	},
	{
		"id": "guilherme_encharcada",
		"speaker": "GUILHERME",
		"portrait": "guilherme",
		"text": "Gabriel, o papel está encharcado.",
	},
	{
		"id": "gabriel_seca",
		"speaker": "GABRIEL",
		"portrait": "gabriel",
		"text": "Eu disse inteira, não disse seca.",
	},
	{
		"id": "waitress_3",
		"speaker": "GARÇONETE",
		"portrait": "garconete_react",
		"text": "Me entrega logo essa comanda!",
	},
	{
		"id": "gabriel_marca",
		"speaker": "GABRIEL",
		"portrait": "gabriel",
		"text": "Vou deixar uma marca registrada.",
		"triggers_gunshot_after": true,
	},
	{
		"id": "juliana_final",
		"speaker": "JULIANA",
		"portrait": "juliana",
		"text": "Tira os 10% de serviço por favor!",
	},
]

var _level: Node = null
var _player: Node2D = null
var _gabriel_actor: Node2D = null
var _guilherme_actor: Node2D = null
var _garconete: Node2D = null
var _juliana: Node2D = null
var _camera: Camera2D = null

var _dialogue_layer: CanvasLayer = null
var _portrait_rect: TextureRect = null
var _speaker_label: Label = null
var _dialogue_label: Label = null
var _continue_label: Label = null
var _typewriter_tween: Tween = null

var _comanda_prop: Sprite2D = null
var _ending_layer: CanvasLayer = null

var _line_index: int = -1
var _dialogue_active: bool = false
var _gunshot_playing: bool = false
var _gunshot_executed: bool = false
var _ending_active: bool = false
var _ending_confirmed: bool = false
var _finale_started: bool = false
var _text_fully_revealed: bool = false

var _garconete_idle_portrait: Texture2D = null
var _garconete_react_portrait: Texture2D = null


func setup(
	level_node: Node,
	player_node: Node2D,
	gabriel_node: Node2D,
	guilherme_node: Node2D,
	garconete_node: Node2D,
	juliana_node: Node2D,
	camera_node: Camera2D
) -> void:
	_level = level_node
	_player = player_node
	_gabriel_actor = gabriel_node
	_guilherme_actor = guilherme_node
	_garconete = garconete_node
	_juliana = juliana_node
	_camera = camera_node


func start_finale(walk_target: Vector2) -> void:
	if _finale_started:
		return
	_finale_started = true

	if _player != null and is_instance_valid(_player):
		_player.set_physics_process(false)
		if _player.has_method("set_qte_locked"):
			_player.call("set_qte_locked", true)
		_set_actor_facing(_player, -1.0)
		_play_actor_anim(_player, &"walk")

		var walk_tw := create_tween()
		walk_tw.tween_property(_player, "position", walk_target, 1.15).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		walk_tw.tween_callback(_on_player_arrived_at_counter)
	else:
		_on_player_arrived_at_counter()


func _on_player_arrived_at_counter() -> void:
	if _player != null and is_instance_valid(_player):
		_set_actor_facing(_player, 1.0)
		_play_actor_anim(_player, &"idle")
	_set_actor_facing(_gabriel_actor, 1.0)
	_set_actor_facing(_guilherme_actor, 1.0)
	_set_actor_facing(_garconete, -1.0)

	if _camera != null and is_instance_valid(_camera):
		var cam_tw := create_tween()
		cam_tw.tween_property(_camera, "global_position:x", 1420.0, 0.55).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

	_spawn_held_comanda_in_guilherme_hand()
	_build_dialogue_ui()
	_dialogue_active = true
	_line_index = -1
	_advance_dialogue()


func _spawn_held_comanda_in_guilherme_hand() -> void:
	if _comanda_prop != null and is_instance_valid(_comanda_prop):
		return
	var hand_pos := Vector2(1590.0, 424.0)
	if _guilherme_actor != null and is_instance_valid(_guilherme_actor):
		hand_pos = _guilherme_actor.global_position + Vector2(36.0, -98.0)

	_comanda_prop = Sprite2D.new()
	_comanda_prop.name = "FinaleComandaProp"
	_comanda_prop.texture = _load_texture_safe(COMANDA_TEXTURE_PATH)
	_comanda_prop.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_comanda_prop.position = hand_pos
	_comanda_prop.scale = Vector2(0.40, 0.40)
	_comanda_prop.modulate = Color(0.95, 0.88, 0.44, 1.0)
	_comanda_prop.z_index = 12
	_get_world_props_parent().add_child(_comanda_prop)


func _build_dialogue_ui() -> void:
	if _dialogue_layer != null and is_instance_valid(_dialogue_layer):
		return
	_dialogue_layer = CanvasLayer.new()
	_dialogue_layer.name = "FinaleDialogueLayer"
	_dialogue_layer.layer = 125
	_dialogue_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_dialogue_layer)

	var root_ctrl := Control.new()
	root_ctrl.name = "DialogueInputRoot"
	root_ctrl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root_ctrl.mouse_filter = Control.MOUSE_FILTER_STOP
	_dialogue_layer.add_child(root_ctrl)

	var is_mobile: bool = _is_mobile_runtime()
	var ui: Dictionary = StandardDialogueBoxClass.build_dialogue_ui(root_ctrl, is_mobile)
	_portrait_rect = ui["portrait"] as TextureRect
	_speaker_label = ui["speaker_label"] as Label
	_dialogue_label = ui["dialogue_label"] as Label
	_continue_label = ui["continue_label"] as Label

	root_ctrl.gui_input.connect(func(ev: InputEvent) -> void:
		if ev is InputEventMouseButton and (ev as InputEventMouseButton).pressed:
			confirm_current_step()
		elif ev is InputEventScreenTouch and (ev as InputEventScreenTouch).pressed:
			confirm_current_step()
	)


func _unhandled_input(event: InputEvent) -> void:
	if not _dialogue_active and not _ending_active:
		return
	if _gunshot_playing:
		return
	var triggered: bool = false
	if event is InputEventKey:
		var ke := event as InputEventKey
		if ke.pressed and not ke.echo and ke.keycode in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE, KEY_J]:
			triggered = true
	elif event is InputEventJoypadButton:
		var je := event as InputEventJoypadButton
		if je.pressed and je.button_index == JOY_BUTTON_A:
			triggered = true

	if triggered:
		get_viewport().set_input_as_handled()
		confirm_current_step()


func confirm_current_step() -> void:
	if _gunshot_playing:
		return
	if _ending_active:
		_confirm_stage2_ending()
		return
	if not _dialogue_active:
		return
	if not _text_fully_revealed:
		_reveal_full_text_immediately()
		return

	if _line_index >= 0 and _line_index < DIALOGUE_LINES.size():
		var current_line: Dictionary = DIALOGUE_LINES[_line_index]
		if bool(current_line.get("triggers_gunshot_after", false)) and not _gunshot_executed:
			_play_gunshot_cinematic()
			return

	_advance_dialogue()


func _advance_dialogue() -> void:
	_line_index += 1
	if _line_index >= DIALOGUE_LINES.size():
		_finish_dialogue_and_show_ending()
		return

	var line: Dictionary = DIALOGUE_LINES[_line_index]
	_apply_line_visual_reactions(str(line.get("id", "")))

	var pre_pause: float = float(line.get("pre_pause", 0.0))
	if pre_pause > 0.0 and is_inside_tree():
		_dialogue_label.text = ""
		_speaker_label.text = str(line.get("speaker", ""))
		_portrait_rect.texture = _get_portrait_for_key(str(line.get("portrait", "")))
		_continue_label.visible = false
		_text_fully_revealed = false
		var pause_tw := create_tween()
		pause_tw.tween_interval(pre_pause)
		pause_tw.tween_callback(_present_line_content.bind(line))
	else:
		_present_line_content(line)


func _present_line_content(line: Dictionary) -> void:
	if not is_instance_valid(_speaker_label) or not is_instance_valid(_dialogue_label):
		return
	_speaker_label.text = str(line.get("speaker", ""))
	_portrait_rect.texture = _get_portrait_for_key(str(line.get("portrait", "")))
	_portrait_rect.modulate = _get_portrait_tint_for_line(str(line.get("id", "")))

	var full_text: String = str(line.get("text", ""))
	_dialogue_label.text = full_text
	_dialogue_label.visible_characters = 0
	_continue_label.visible = false
	_text_fully_revealed = false

	if _typewriter_tween != null and _typewriter_tween.is_valid():
		_typewriter_tween.kill()

	var duration: float = maxf(0.18, float(full_text.length()) / StandardDialogueBoxClass.TYPEWRITER_SPEED_CPS)
	_typewriter_tween = create_tween()
	_typewriter_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_typewriter_tween.tween_property(_dialogue_label, "visible_characters", full_text.length(), duration)
	_typewriter_tween.tween_callback(_on_line_text_revealed)


func _reveal_full_text_immediately() -> void:
	if _typewriter_tween != null and _typewriter_tween.is_valid():
		_typewriter_tween.kill()
	if _dialogue_label != null:
		_dialogue_label.visible_characters = -1
	_on_line_text_revealed()


func _on_line_text_revealed() -> void:
	_text_fully_revealed = true
	if _continue_label != null:
		_continue_label.visible = true


func _apply_line_visual_reactions(line_id: String) -> void:
	match line_id:
		"gabriel_fernando":
			_pulse_actor_nod(_gabriel_actor, 0.96, 0.22)
			# Guilherme reage discretamente com o olhar ao ouvir o nome de Fernando
			if _guilherme_actor != null and is_instance_valid(_guilherme_actor):
				_set_actor_facing(_guilherme_actor, -1.0 if _gabriel_actor != null and _gabriel_actor.global_position.x < _guilherme_actor.global_position.x else 1.0)
				_pulse_actor_nod(_guilherme_actor, 0.97, 0.24)
		"guilherme_1":
			_set_actor_facing(_guilherme_actor, 1.0)
			_play_actor_anim(_guilherme_actor, &"idle")
		"waitress_2":
			_play_actor_anim(_garconete, &"idle")
		"gabriel_inteira":
			_pulse_actor_nod(_gabriel_actor, 1.04, 0.16)
		"guilherme_encharcada":
			_play_actor_anim(_guilherme_actor, &"guard")
			_shake_actor_x(_guilherme_actor, 4.0)
		"gabriel_seca":
			_play_actor_anim(_guilherme_actor, &"idle")
			_pulse_actor_nod(_gabriel_actor, 1.05, 0.16)
		"waitress_3":
			_play_actor_anim(_garconete, &"react")
		"gabriel_marca":
			_pulse_actor_nod(_gabriel_actor, 1.06, 0.18)
			# Gabriel só saca a arma exatamente no momento em que fala que vai deixar uma marca
			_set_actor_facing(_gabriel_actor, 1.0)
			_play_actor_anim(_gabriel_actor, &"shot_1")
		"juliana_final":
			_pulse_actor_nod(_juliana, 1.08, 0.20)
			if _camera != null and is_instance_valid(_camera):
				var cam_tw := create_tween()
				cam_tw.tween_property(_camera, "global_position:x", 1340.0, 0.45).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


func _play_gunshot_cinematic() -> void:
	if _gunshot_playing or _gunshot_executed:
		return
	_gunshot_playing = true
	_gunshot_executed = true

	if _dialogue_layer != null:
		_dialogue_layer.visible = false

	# 1. Garçonete estende a mão para receber a comanda + comanda molhada aparece estendida
	_play_actor_anim(_garconete, &"react")
	var garconete_start_x: float = _garconete.position.x if _garconete != null and is_instance_valid(_garconete) else 1690.0
	if _garconete != null and is_instance_valid(_garconete):
		var reach_tw := create_tween()
		reach_tw.tween_property(_garconete, "position:x", garconete_start_x - 16.0, 0.25).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

	var comanda_pos := Vector2(1612.0, 438.0)
	if _guilherme_actor != null and is_instance_valid(_guilherme_actor):
		comanda_pos = Vector2(
			(_guilherme_actor.global_position.x + garconete_start_x) * 0.5 + 4.0,
			438.0
		)

	if _comanda_prop == null or not is_instance_valid(_comanda_prop):
		_spawn_held_comanda_in_guilherme_hand()
	if _comanda_prop != null and is_instance_valid(_comanda_prop):
		var extend_tw := create_tween().set_parallel(true)
		extend_tw.tween_property(_comanda_prop, "position", comanda_pos, 0.22).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		extend_tw.tween_property(_comanda_prop, "scale", Vector2(0.46, 0.46), 0.22)

	# 2. Gabriel mantém a arma sacada mirando a comanda
	_set_actor_facing(_gabriel_actor, 1.0)
	_play_actor_anim(_gabriel_actor, &"shot_1")

	# 3. Guilherme demonstra surpresa
	var seq := create_tween()
	seq.tween_interval(0.24)
	seq.tween_callback(func() -> void:
		if _guilherme_actor != null and is_instance_valid(_guilherme_actor):
			_play_actor_anim(_guilherme_actor, &"hurt")
			CombatFeedback.spawn_floating_text(self, _guilherme_actor.global_position + Vector2(0.0, -195.0), "?!", Color(1.0, 0.90, 0.35, 1.0), 22)
	)
	seq.tween_interval(0.18)

	# 4 & 5 & 6. Gabriel dispara exclusivamente na comanda + VFX + SFX
	seq.tween_callback(func() -> void:
		_play_actor_anim(_gabriel_actor, &"heavy")
		_spawn_muzzle_and_bullet_vfx(comanda_pos)
		CombatFeedback.play_sound(self, GUNSHOT_SFX_PATH, 2.0, 0.04)

		# 7. Substitui comanda original pela comanda furada
		if _comanda_prop != null and is_instance_valid(_comanda_prop):
			_comanda_prop.texture = _load_texture_safe(COMANDA_FURADA_TEXTURE_PATH)
			var punch_tw := _comanda_prop.create_tween()
			punch_tw.tween_property(_comanda_prop, "scale", Vector2(0.58, 0.58), 0.06)
			punch_tw.tween_property(_comanda_prop, "rotation", 0.14, 0.08)
			punch_tw.tween_property(_comanda_prop, "scale", Vector2(0.46, 0.46), 0.12)
			punch_tw.parallel().tween_property(_comanda_prop, "rotation", 0.0, 0.12)

		# 8. Garçonete reage ao susto (sem dano / sem combate)
		if _garconete != null and is_instance_valid(_garconete):
			_play_actor_anim(_garconete, &"react")
			var jump_tw := _garconete.create_tween()
			jump_tw.tween_property(_garconete, "position:x", garconete_start_x + 12.0, 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			jump_tw.tween_property(_garconete, "position:x", garconete_start_x, 0.22)
			CombatFeedback.spawn_floating_text(self, _garconete.global_position + Vector2(0.0, -210.0), "!", Color(1.0, 0.42, 0.36, 1.0), 26)
	)
	seq.tween_interval(0.65)
	seq.tween_callback(func() -> void:
		# Retorna Gabriel e Guilherme à pose idle e exibe a fala final da Juliana
		_play_actor_anim(_gabriel_actor, &"idle")
		_play_actor_anim(_guilherme_actor, &"idle")
		_gunshot_playing = false
		if _dialogue_layer != null and is_instance_valid(_dialogue_layer):
			_dialogue_layer.visible = true
		_advance_dialogue()
	)


func _spawn_muzzle_and_bullet_vfx(target_pos: Vector2) -> void:
	var origin: Vector2 = target_pos + Vector2(-95.0, 4.0)
	if _gabriel_actor != null and is_instance_valid(_gabriel_actor):
		var muzzle := _gabriel_actor.get_node_or_null("Visual/MuzzleMarker") as Node2D
		if muzzle != null:
			origin = muzzle.global_position
		else:
			origin = _gabriel_actor.global_position + Vector2(58.0, -138.0)

	var props_parent := _get_world_props_parent()

	var tracer := Line2D.new()
	tracer.name = "FinaleBulletTracer"
	tracer.width = 4.0
	tracer.default_color = Color(1.0, 0.94, 0.48, 0.95)
	tracer.z_index = 14
	tracer.add_point(origin)
	tracer.add_point(target_pos)
	props_parent.add_child(tracer)

	var impact := Polygon2D.new()
	impact.name = "FinaleComandaSpark"
	impact.position = target_pos
	impact.z_index = 15
	impact.color = Color(1.0, 0.86, 0.32, 0.95)
	impact.polygon = PackedVector2Array([
		-14, 0, -4, -4, 0, -14, 4, -4, 14, 0, 4, 4, 0, 14, -4, 4
	])
	props_parent.add_child(impact)

	var vfx_tw := create_tween().set_parallel(true)
	vfx_tw.tween_property(tracer, "modulate:a", 0.0, 0.14)
	vfx_tw.tween_property(impact, "scale", Vector2(1.5, 1.5), 0.14)
	vfx_tw.tween_property(impact, "modulate:a", 0.0, 0.18)
	vfx_tw.chain().tween_callback(func() -> void:
		if is_instance_valid(tracer):
			tracer.queue_free()
		if is_instance_valid(impact):
			impact.queue_free()
	)


func _finish_dialogue_and_show_ending() -> void:
	_dialogue_active = false
	if _dialogue_layer != null and is_instance_valid(_dialogue_layer):
		_dialogue_layer.queue_free()
	_dialogue_layer = null

	if _comanda_prop != null and is_instance_valid(_comanda_prop):
		var fade_prop := _comanda_prop.create_tween()
		fade_prop.tween_property(_comanda_prop, "modulate:a", 0.0, 0.35)
		fade_prop.tween_callback(_comanda_prop.queue_free)
		_comanda_prop = null

	if _player != null and is_instance_valid(_player):
		_player.set_physics_process(false)
		if _player.has_method("set_qte_locked"):
			_player.call("set_qte_locked", true)

	# Registra a conclusão do Estágio 2 somente após a execução integral da sequência
	var session := get_node_or_null("/root/GameSession")
	if session != null and session.has_method("complete_stage"):
		session.complete_stage(2)

	_show_stage2_ending_screen()


func _show_stage2_ending_screen() -> void:
	if _ending_active:
		return
	_ending_active = true

	_ending_layer = CanvasLayer.new()
	_ending_layer.name = "Stage2EndingLayer"
	_ending_layer.layer = 140
	_ending_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_ending_layer)

	var root := Control.new()
	root.name = "Stage2EndingRoot"
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	_ending_layer.add_child(root)

	var backdrop := ColorRect.new()
	backdrop.name = "Backdrop"
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.color = Color(0.035, 0.042, 0.068, 0.0)
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(backdrop)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(center)

	var panel := PanelContainer.new()
	panel.name = "EndingCard"
	panel.custom_minimum_size = Vector2(560.0, 220.0)
	panel.modulate.a = 0.0
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.055, 0.065, 0.105, 0.94)
	style.border_color = Color(0.94, 0.75, 0.39, 1.0)
	style.set_border_width_all(3)
	style.set_corner_radius_all(6)
	style.content_margin_left = 40.0
	style.content_margin_right = 40.0
	style.content_margin_top = 32.0
	style.content_margin_bottom = 28.0
	panel.add_theme_stylebox_override("panel", style)
	center.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 16)
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(vbox)

	var title := Label.new()
	title.name = "EndingTitleLabel"
	title.text = "FIM DO ESTÁGIO 2"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var title_ls := LabelSettings.new()
	title_ls.font = ARCADE_FONT
	title_ls.font_size = 44
	title_ls.font_color = Color(0.94, 0.75, 0.39, 1.0)
	title_ls.outline_size = 4
	title_ls.outline_color = Color(0.04, 0.03, 0.05, 1.0)
	title_ls.shadow_size = 3
	title_ls.shadow_color = Color(0.0, 0.0, 0.0, 0.9)
	title_ls.shadow_offset = Vector2(2, 2)
	title.label_settings = title_ls
	vbox.add_child(title)

	var subtitle := Label.new()
	subtitle.name = "EndingSubtitleLabel"
	subtitle.text = "Até breve."
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var sub_ls := LabelSettings.new()
	sub_ls.font = ARCADE_FONT
	sub_ls.font_size = 26
	sub_ls.font_color = Color(0.97, 0.94, 0.85, 1.0)
	sub_ls.outline_size = 3
	sub_ls.outline_color = Color(0.04, 0.03, 0.05, 1.0)
	subtitle.label_settings = sub_ls
	vbox.add_child(subtitle)

	var prompt := Label.new()
	prompt.name = "EndingPromptLabel"
	prompt.text = "TOQUE OU PRESSIONE ENTER PARA CONTINUAR"
	prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var prompt_ls := LabelSettings.new()
	prompt_ls.font = ARCADE_FONT
	prompt_ls.font_size = 16
	prompt_ls.font_color = Color(0.78, 0.81, 0.87, 0.92)
	prompt.label_settings = prompt_ls
	vbox.add_child(prompt)

	var fade_tw := create_tween()
	fade_tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	fade_tw.tween_property(backdrop, "color:a", 0.92, 0.70).set_trans(Tween.TRANS_SINE)
	fade_tw.parallel().tween_property(panel, "modulate:a", 1.0, 0.70).set_trans(Tween.TRANS_SINE)

	var pulse_tw := prompt.create_tween().set_loops()
	pulse_tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	pulse_tw.tween_property(prompt, "modulate:a", 0.35, 0.55)
	pulse_tw.tween_property(prompt, "modulate:a", 1.0, 0.55)

	root.gui_input.connect(func(ev: InputEvent) -> void:
		if ev is InputEventMouseButton and (ev as InputEventMouseButton).pressed:
			_confirm_stage2_ending()
		elif ev is InputEventScreenTouch and (ev as InputEventScreenTouch).pressed:
			_confirm_stage2_ending()
	)

	finale_completed.emit()


func _confirm_stage2_ending() -> void:
	if not _ending_active or _ending_confirmed:
		return
	_ending_confirmed = true
	if is_inside_tree() and get_tree() != null:
		get_tree().change_scene_to_file(MAP_MENU_SCENE)


func _get_portrait_for_key(key: String) -> Texture2D:
	match key:
		"gabriel":
			return _load_texture_safe(PORTRAIT_GABRIEL)
		"guilherme":
			return _load_texture_safe(PORTRAIT_GUILHERME)
		"juliana":
			return _load_texture_safe(PORTRAIT_JULIANA)
		"garconete_idle":
			if _garconete_idle_portrait == null:
				_garconete_idle_portrait = _build_garconete_portrait_atlas(GARCONETE_IDLE_FRAME)
			return _garconete_idle_portrait
		"garconete_react":
			if _garconete_react_portrait == null:
				_garconete_react_portrait = _build_garconete_portrait_atlas(GARCONETE_REACT_FRAME)
			return _garconete_react_portrait
	return _load_texture_safe(PORTRAIT_GABRIEL)


func _get_portrait_tint_for_line(line_id: String) -> Color:
	if line_id == "gabriel_fernando":
		return Color(0.84, 0.87, 0.96, 1.0)
	if line_id == "gabriel_marca":
		return Color(1.06, 1.02, 0.90, 1.0)
	return Color.WHITE


func _build_garconete_portrait_atlas(frame_path: String) -> Texture2D:
	var base_tex := _load_texture_safe(frame_path)
	if base_tex == null:
		return null
	var atlas := AtlasTexture.new()
	atlas.atlas = base_tex
	atlas.region = Rect2(62.0, 26.0, 96.0, 96.0)
	atlas.filter_clip = true
	return atlas


func _load_texture_safe(res_path: String) -> Texture2D:
	if ResourceLoader.exists(res_path):
		var tex := load(res_path) as Texture2D
		if tex != null:
			return tex
	var abs_path: String = ProjectSettings.globalize_path(res_path)
	if FileAccess.file_exists(abs_path):
		var img := Image.load_from_file(abs_path)
		if img != null and not img.is_empty():
			return ImageTexture.create_from_image(img)
	return null


func _get_world_props_parent() -> Node:
	if _level != null:
		var props := _level.get_node_or_null("World/Props")
		if props != null:
			return props
		return _level
	return self


func _set_actor_facing(actor: Node2D, dir: float) -> void:
	if actor == null or not is_instance_valid(actor):
		return
	if "facing_direction" in actor:
		actor.set("facing_direction", dir)
	var visual := actor.get_node_or_null("Visual") as Node2D
	if visual != null:
		visual.scale.x = absf(visual.scale.y) * (1.0 if dir >= 0.0 else -1.0)
		return
	var anim := actor.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	if anim != null:
		anim.scale.x = absf(anim.scale.y) * (1.0 if dir >= 0.0 else -1.0)


func _play_actor_anim(actor: Node2D, anim_name: StringName) -> void:
	if actor == null or not is_instance_valid(actor):
		return
	var anim := actor.get("anim_sprite") as AnimatedSprite2D
	if anim == null:
		anim = actor.get_node_or_null("Visual/AnimatedSprite2D") as AnimatedSprite2D
	if anim == null:
		anim = actor.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	if anim != null and anim.sprite_frames != null and anim.sprite_frames.has_animation(anim_name):
		anim.play(anim_name)


func _pulse_actor_nod(actor: Node2D, scale_y_factor: float, duration: float) -> void:
	if actor == null or not is_instance_valid(actor):
		return
	var base_scale: Vector2 = actor.scale
	var tw := actor.create_tween()
	tw.tween_property(actor, "scale", Vector2(base_scale.x, base_scale.y * scale_y_factor), duration * 0.5).set_trans(Tween.TRANS_SINE)
	tw.tween_property(actor, "scale", base_scale, duration * 0.5).set_trans(Tween.TRANS_SINE)


func _shake_actor_x(actor: Node2D, offset_x: float) -> void:
	if actor == null or not is_instance_valid(actor):
		return
	var start_x: float = actor.position.x
	var tw := actor.create_tween()
	tw.tween_property(actor, "position:x", start_x - offset_x, 0.06)
	tw.tween_property(actor, "position:x", start_x + offset_x, 0.06)
	tw.tween_property(actor, "position:x", start_x, 0.06)


func _is_mobile_runtime() -> bool:
	var os_name := OS.get_name()
	if os_name == "Android" or os_name == "iOS":
		return true
	if os_name == "Web":
		return DisplayServer.is_touchscreen_available()
	return false


func is_dialogue_active() -> bool:
	return _dialogue_active


func is_gunshot_executed() -> bool:
	return _gunshot_executed


func is_ending_active() -> bool:
	return _ending_active


func get_current_line_index() -> int:
	return _line_index


func get_dialogue_line_count() -> int:
	return DIALOGUE_LINES.size()
