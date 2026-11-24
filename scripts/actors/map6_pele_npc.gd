extends "res://scripts/actors/npc.gd"

## Segurança da entrada da HAPPEN. Mantém o contrato de BaseNPC e não participa
## de combate; sua atuação é controlada pelo evento narrativo do Map 6.

signal interaction_requested(pele: Node, player: Node)

const IDLE_TEXTURE_PATH: String = "res://assets/sprites/characters/npc/pele/pele_idle.png"
const EXPRESSIONS_TEXTURE_PATH: String = "res://assets/sprites/characters/npc/pele/pele_expressions.png"
const GESTURES_TEXTURE_PATH: String = "res://assets/sprites/characters/npc/pele/pele_gestures.png"
const ARCADE_FONT: FontFile = preload("res://assets/fonts/arcade_bold.ttf")
const FRAME_SIZE: Vector2 = Vector2(220.0, 300.0)
const PELE_DISPLAY_SCALE: float = 0.92

var _animated_sprite: AnimatedSprite2D = null
var _interaction_area: Area2D = null
var _interaction_player: Node = null
var _interaction_enabled: bool = true
var _dialogue_active: bool = false
var _exclamation: Label = null
var _bob_tween: Tween = null
var _dialogue_portraits: Dictionary = {}


func _ready() -> void:
	add_to_group("map6_pele")
	npc_name = "Pelé"
	is_damageable = false
	default_state = NPCState.IDLE
	super._ready()
	_build_visual_animation()
	_create_interaction_area()
	_create_interaction_indicator()


func _build_visual_animation() -> void:
	if visual_root == null:
		push_error("Map6PeleNPC: nó Visual ausente.")
		return

	var idle_texture := load(IDLE_TEXTURE_PATH) as Texture2D
	var expressions := load(EXPRESSIONS_TEXTURE_PATH) as Texture2D
	var gestures := load(GESTURES_TEXTURE_PATH) as Texture2D
	if idle_texture == null or expressions == null or gestures == null:
		push_error("Map6PeleNPC: um ou mais spritesheets do Pelé não foram encontrados.")
		return

	if expressions.get_width() < 4 or expressions.get_height() < 3:
		push_error("Map6PeleNPC: grade de expressões inválida (esperada 4x3).")
		return
	if gestures.get_width() < 4 or gestures.get_height() < 2:
		push_error("Map6PeleNPC: grade de gestos inválida (esperada 4x2).")
		return

	# As folhas geradas pela IA podem sair maiores que 880x900/880x600.
	# As células são recortadas pelas dimensões reais e normalizadas abaixo
	# para o mesmo tamanho visual do idle aprovado (220x300).
	var frames := SpriteFrames.new()
	_add_single_frame_animation(frames, "idle_neutral", idle_texture, true, 3.0)
	_add_grid_animation(frames, "idle_attentive", expressions, 0, 3, true, 5.0)
	_add_grid_animation(frames, "reaction_skeptical", expressions, 1, 3, false, 7.0)
	_add_grid_animation(frames, "reaction_amused", expressions, 2, 3, false, 6.0)
	_add_grid_animation(frames, "gesture_stop", gestures, 0, 2, false, 7.0)
	_add_grid_animation(frames, "gesture_allow_entry", gestures, 1, 2, false, 7.0)
	_build_dialogue_portraits(idle_texture, expressions, gestures)

	_animated_sprite = AnimatedSprite2D.new()
	_animated_sprite.name = "AnimatedSprite2D"
	_animated_sprite.position = Vector2(0.0, -(FRAME_SIZE.y * PELE_DISPLAY_SCALE * 0.5))
	_animated_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_animated_sprite.sprite_frames = frames
	_animated_sprite.animation = &"idle_neutral"
	_animated_sprite.animation_finished.connect(_on_animation_finished)
	visual_root.add_child(_animated_sprite)
	_apply_animation_scale("idle_neutral")
	_animated_sprite.play("idle_neutral")


func _add_single_frame_animation(
	frames: SpriteFrames,
	animation_name: StringName,
	texture: Texture2D,
	loop: bool,
	fps: float
) -> void:
	frames.add_animation(animation_name)
	frames.set_animation_loop(animation_name, loop)
	frames.set_animation_speed(animation_name, fps)
	frames.add_frame(animation_name, texture)


func _add_grid_animation(
	frames: SpriteFrames,
	animation_name: StringName,
	sheet: Texture2D,
	row: int,
	total_rows: int,
	loop: bool,
	fps: float
) -> void:
	frames.add_animation(animation_name)
	frames.set_animation_loop(animation_name, loop)
	frames.set_animation_speed(animation_name, fps)
	for column in range(4):
		# Arredonda cada limite da célula separadamente. Isso suporta folhas
		# de IA com largura não divisível exatamente por quatro, sem UV fracionário.
		var left: int = roundi(float(column * sheet.get_width()) / 4.0)
		var right: int = roundi(float((column + 1) * sheet.get_width()) / 4.0)
		var top: int = roundi(float(row * sheet.get_height()) / float(total_rows))
		var bottom: int = roundi(float((row + 1) * sheet.get_height()) / float(total_rows))
		var atlas_frame := AtlasTexture.new()
		atlas_frame.atlas = sheet
		atlas_frame.region = Rect2(left, top, right - left, bottom - top)
		atlas_frame.filter_clip = true
		frames.add_frame(animation_name, atlas_frame)


func _apply_animation_scale(animation_name: StringName) -> void:
	if _animated_sprite == null or _animated_sprite.sprite_frames == null:
		return
	var frame_texture: Texture2D = _animated_sprite.sprite_frames.get_frame_texture(animation_name, 0)
	if frame_texture == null:
		return
	var frame_size: Vector2 = frame_texture.get_size()
	if frame_size.x <= 0.0 or frame_size.y <= 0.0:
		return
	_animated_sprite.scale = Vector2(
		FRAME_SIZE.x * PELE_DISPLAY_SCALE / frame_size.x,
		FRAME_SIZE.y * PELE_DISPLAY_SCALE / frame_size.y
	)
	# Todas as animações compartilham a mesma base física dos pés.
	_animated_sprite.position = Vector2(0.0, -(FRAME_SIZE.y * PELE_DISPLAY_SCALE * 0.5))


func _create_interaction_area() -> void:
	_interaction_area = Area2D.new()
	_interaction_area.name = "InteractionArea"
	_interaction_area.collision_layer = 0
	_interaction_area.collision_mask = 1
	_interaction_area.monitoring = true
	_interaction_area.monitorable = false

	var shape_node := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(240.0, 108.0)
	shape_node.shape = shape
	shape_node.position = Vector2(0.0, -6.0)
	_interaction_area.add_child(shape_node)
	add_child(_interaction_area)
	_interaction_area.body_entered.connect(_on_interaction_body_entered)
	_interaction_area.body_exited.connect(_on_interaction_body_exited)


func _create_interaction_indicator() -> void:
	if visual_root == null:
		return

	_exclamation = Label.new()
	_exclamation.name = "InteractionIndicator"
	_exclamation.text = "!"
	_exclamation.position = Vector2(-18.0, -292.0)
	_exclamation.size = Vector2(36.0, 44.0)
	_exclamation.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_exclamation.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_exclamation.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

	var settings := LabelSettings.new()
	settings.font = ARCADE_FONT
	settings.font_size = 42
	settings.font_color = Color(0.94, 0.75, 0.39, 1.0)
	settings.outline_size = 4
	settings.outline_color = Color(0.04, 0.035, 0.045, 1.0)
	settings.shadow_size = 2
	settings.shadow_color = Color(0.0, 0.0, 0.0, 0.9)
	settings.shadow_offset = Vector2(2.0, 2.0)
	_exclamation.label_settings = settings
	visual_root.add_child(_exclamation)

	_bob_tween = create_tween().set_loops()
	_bob_tween.tween_property(_exclamation, "position:y", -300.0, 0.55).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_bob_tween.tween_property(_exclamation, "position:y", -292.0, 0.55).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _on_interaction_body_entered(body: Node) -> void:
	if not _interaction_enabled or body == null or not body.is_in_group("player"):
		return
	_interaction_player = body
	if body.has_method("register_interactable"):
		body.call("register_interactable", self)


func _on_interaction_body_exited(body: Node) -> void:
	if body != _interaction_player:
		return
	if is_instance_valid(body) and body.has_method("unregister_interactable"):
		body.call("unregister_interactable", self)
	_interaction_player = null


## Chamado pelo PlayerController quando J é pressionado dentro do alcance.
func interact(player: Node) -> bool:
	if not _interaction_enabled or _dialogue_active:
		return false
	if player == null or not is_instance_valid(player) or player != _interaction_player:
		return false
	_dialogue_active = true
	enter_event()
	if _exclamation != null:
		_exclamation.visible = false
	interaction_requested.emit(self, player)
	return true


func set_dialogue_active(active: bool) -> void:
	_dialogue_active = active
	if active:
		enter_event()
	else:
		change_state(NPCState.IDLE)
		if _interaction_enabled and _exclamation != null:
			_exclamation.visible = true


func set_interaction_enabled(enabled: bool) -> void:
	_interaction_enabled = enabled
	if _interaction_area != null:
		_interaction_area.set_deferred("monitoring", enabled)
	if _exclamation != null:
		_exclamation.visible = enabled and not _dialogue_active
	if not enabled:
		if _interaction_player != null and is_instance_valid(_interaction_player):
			if _interaction_player.has_method("unregister_interactable"):
				_interaction_player.call("unregister_interactable", self)
		_interaction_player = null


func play_animation(animation_name: String) -> void:
	if _animated_sprite == null or _animated_sprite.sprite_frames == null:
		return
	if not _animated_sprite.sprite_frames.has_animation(animation_name):
		push_warning("Map6PeleNPC: animação não encontrada: " + animation_name)
		return
	_apply_animation_scale(animation_name)
	_animated_sprite.play(animation_name)
	_animated_sprite.frame = 0


func _on_animation_finished() -> void:
	if _animated_sprite == null:
		return
	var finished_animation: StringName = _animated_sprite.animation
	if finished_animation in [&"reaction_skeptical", &"reaction_amused", &"gesture_stop"]:
		play_animation("idle_attentive")
	elif finished_animation == &"gesture_allow_entry":
		# Mantém o gesto final enquanto a cena executa a aproximação à porta.
		_animated_sprite.pause()


## Retrato dinâmico para a caixa de diálogo. Usa o mesmo frame/expressão exibido
## no corpo do NPC, evitando um retrato genérico que contradiga a atuação.
func get_dialogue_portrait(action: String = "") -> Texture2D:
	var key: String = action.strip_edges().to_lower()
	if key in ["skeptical", "reaction_skeptical"]:
		key = "reaction_skeptical"
	elif key in ["amused", "reaction_amused"]:
		key = "reaction_amused"
	elif key == "gesture_stop":
		key = "gesture_stop"
	elif key == "gesture_allow_entry":
		key = "gesture_allow_entry"
	elif key in ["idle_attentive", "attentive"]:
		key = "idle_attentive"
	else:
		key = "idle_neutral"
	return _dialogue_portraits.get(key) as Texture2D


func _build_dialogue_portraits(idle_texture: Texture2D, expressions: Texture2D, gestures: Texture2D) -> void:
	_dialogue_portraits["idle_neutral"] = _create_portrait_from_frame(idle_texture, Rect2i(0, 0, idle_texture.get_width(), idle_texture.get_height()))
	_dialogue_portraits["idle_attentive"] = _create_portrait_from_grid(expressions, 0, 4, 3, 1)
	_dialogue_portraits["reaction_skeptical"] = _create_portrait_from_grid(expressions, 1, 4, 3, 2)
	_dialogue_portraits["reaction_amused"] = _create_portrait_from_grid(expressions, 2, 4, 3, 2)
	_dialogue_portraits["gesture_stop"] = _create_portrait_from_grid(gestures, 0, 4, 2, 2)
	_dialogue_portraits["gesture_allow_entry"] = _create_portrait_from_grid(gestures, 1, 4, 2, 2)


func _create_portrait_from_grid(sheet: Texture2D, row: int, columns: int, rows: int, frame_column: int) -> Texture2D:
	var left: int = roundi(float(frame_column * sheet.get_width()) / float(columns))
	var right: int = roundi(float((frame_column + 1) * sheet.get_width()) / float(columns))
	var top: int = roundi(float(row * sheet.get_height()) / float(rows))
	var bottom: int = roundi(float((row + 1) * sheet.get_height()) / float(rows))
	return _create_portrait_from_frame(sheet, Rect2i(left, top, right - left, bottom - top))


func _create_portrait_from_frame(texture: Texture2D, frame_region: Rect2i) -> Texture2D:
	if texture == null:
		return null
	var source_image: Image = texture.get_image()
	if source_image == null or source_image.is_empty():
		return null
	var frame_image: Image = source_image.get_region(frame_region)
	# Recorte quadrado da cabeça e ombros; a caixa oficial exibe o retrato em 110px.
	var side: int = mini(160, mini(frame_image.get_width(), frame_image.get_height()))
	var crop_x: int = clampi((frame_image.get_width() - side) / 2, 0, frame_image.get_width() - side)
	var portrait_image: Image = frame_image.get_region(Rect2i(crop_x, 0, side, side))
	return ImageTexture.create_from_image(portrait_image)
