class_name MenuCharacterSlot
extends Control

## Slot de Personagem do Menu Principal (Sakas Neo-16-bit)
## Controla o desenho inicial, respiração (idle), sombra de contato no chão,
## aura discreta e efeitos de impacto (dust pop), mantendo nitidez absoluta de pixel art.

signal draw_completed(character_id: String)

const MenuCharacterDataClass = preload("res://scripts/ui/menu_character_data.gd")

var character_aura: TextureRect
var character_shadow: TextureRect
var sprite_container: Control
var character_texture: TextureRect
var dust_container: Control

var character_data: RefCounted

var _breathe_tween: Tween
var _shadow_tween: Tween
var _aura_tween: Tween
var _enter_tween: Tween
var _is_looping_idle: bool = false


func _ready() -> void:
	_ensure_node_refs()
	if character_data != null:
		apply_character_data(character_data)


func _ensure_node_refs() -> void:
	if character_aura == null:
		character_aura = get_node_or_null("CharacterAura") as TextureRect
	if character_shadow == null:
		character_shadow = get_node_or_null("CharacterShadow") as TextureRect
	if sprite_container == null:
		sprite_container = get_node_or_null("SpriteContainer") as Control
	if character_texture == null and sprite_container != null:
		character_texture = sprite_container.get_node_or_null("CharacterTexture") as TextureRect
		if character_texture == null:
			character_texture = sprite_container.get_node_or_null("GuilhermeDrawingCharacter") as TextureRect
	elif character_texture == null:
		character_texture = get_node_or_null("SpriteContainer/CharacterTexture") as TextureRect
		if character_texture == null:
			character_texture = get_node_or_null("SpriteContainer/GuilhermeDrawingCharacter") as TextureRect
	if dust_container == null:
		dust_container = get_node_or_null("DustContainer") as Control


func apply_character_data(data: RefCounted) -> void:
	character_data = data
	_ensure_node_refs()
	if character_data == null or not character_data.get("is_active"):
		visible = false
		_stop_all_tweens()
		return

	visible = true

	# Carrega e associa a textura do personagem
	if character_texture != null:
		character_texture.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		var tex_path: String = character_data.get("texture_path")
		if ResourceLoader.exists(tex_path):
			character_texture.texture = load(tex_path) as Texture2D
		character_texture.flip_h = character_data.get("flip_h")

	# Configura a aura sutil com a cor de destaque do personagem
	if character_aura != null:
		character_aura.modulate = character_data.get("accent_color")
		character_aura.modulate.a = character_data.get("aura_alpha_min")

	# Configura a sombra de contato
	if character_shadow != null:
		character_shadow.modulate.a = character_data.get("shadow_alpha_max")
		character_shadow.pivot_offset = character_shadow.size * 0.5
		character_shadow.scale = Vector2(character_data.get("shadow_scale_x_max"), 1.0)

	# Assegura que o container do sprite tenha o pivô exatamente nos pés
	if sprite_container != null:
		sprite_container.pivot_offset = Vector2(sprite_container.size.x * 0.5, sprite_container.size.y)
		var scale_mult: float = character_data.get("scale_multiplier")
		sprite_container.scale = Vector2.ONE * scale_mult


func start_presentation(start_drawing: bool = true) -> void:
	if character_data == null or not character_data.get("is_active"):
		return

	_stop_all_tweens()

	if start_drawing and character_texture != null and character_texture.material is ShaderMaterial:
		# Duplica o material para ser exclusivo deste slot
		var mat := (character_texture.material as ShaderMaterial).duplicate() as ShaderMaterial
		character_texture.material = mat
		mat.set_shader_parameter("draw_progress", 0.0)

		# Animação de entrada e desenho a lápis da cabeça aos pés
		var delay: float = character_data.get("enter_delay")
		_enter_tween = create_tween()
		_enter_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		if delay > 0.0:
			_enter_tween.tween_interval(delay)

		_enter_tween.tween_method(
			func(prog: float):
				if is_instance_valid(character_texture) and character_texture.material != null:
					(character_texture.material as ShaderMaterial).set_shader_parameter("draw_progress", prog),
			0.0,
			1.0,
			1.8
		)
		_enter_tween.finished.connect(_on_draw_finished)
	else:
		_on_draw_finished()


func _on_draw_finished() -> void:
	if not is_instance_valid(self) or character_data == null:
		return

	if character_texture != null and character_texture.material is ShaderMaterial:
		(character_texture.material as ShaderMaterial).set_shader_parameter("draw_progress", 1.0)

	_play_dust_pop()
	start_idle_loop()
	draw_completed.emit(character_data.get("id"))


func start_idle_loop() -> void:
	if character_data == null or not character_data.get("is_active"):
		return

	_is_looping_idle = true
	_start_breathe_tween()
	_start_shadow_tween()
	_start_aura_tween()


func _start_breathe_tween() -> void:
	if sprite_container == null:
		return

	if _breathe_tween != null and _breathe_tween.is_valid():
		_breathe_tween.kill()

	var dur: float = character_data.get("breathe_duration")
	var half_dur := dur * 0.5
	var y_offset: float = character_data.get("breathe_y_offset")
	var scale_mult: float = character_data.get("scale_multiplier")
	var scale_y: float = character_data.get("breathe_scale_y") * scale_mult
	var base_scale := scale_mult

	_breathe_tween = create_tween().set_loops()
	_breathe_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	# Fase 1: Inalação / Expansão sutil para cima
	_breathe_tween.tween_property(sprite_container, "position:y", y_offset, half_dur)
	_breathe_tween.parallel().tween_property(sprite_container, "scale:y", scale_y, half_dur)

	# Fase 2: Exalação / Retorno suave à base
	_breathe_tween.tween_property(sprite_container, "position:y", 0.0, half_dur)
	_breathe_tween.parallel().tween_property(sprite_container, "scale:y", base_scale, half_dur)


func _start_shadow_tween() -> void:
	if character_shadow == null:
		return

	if _shadow_tween != null and _shadow_tween.is_valid():
		_shadow_tween.kill()

	var dur: float = character_data.get("breathe_duration")
	var half_dur := dur * 0.5
	var scale_min: float = character_data.get("shadow_scale_x_min")
	var scale_max: float = character_data.get("shadow_scale_x_max")
	var alpha_min: float = character_data.get("shadow_alpha_min")
	var alpha_max: float = character_data.get("shadow_alpha_max")

	_shadow_tween = create_tween().set_loops()
	_shadow_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	# Quando o corpo sobe: sombra encolhe e clareia discretamente
	_shadow_tween.tween_property(character_shadow, "scale:x", scale_min, half_dur)
	_shadow_tween.parallel().tween_property(character_shadow, "modulate:a", alpha_min, half_dur)

	# Quando o corpo desce: sombra expande e fixa no solo
	_shadow_tween.tween_property(character_shadow, "scale:x", scale_max, half_dur)
	_shadow_tween.parallel().tween_property(character_shadow, "modulate:a", alpha_max, half_dur)


func _start_aura_tween() -> void:
	if character_aura == null:
		return

	if _aura_tween != null and _aura_tween.is_valid():
		_aura_tween.kill()

	var dur: float = character_data.get("breathe_duration") * 1.3
	var half_dur := dur * 0.5

	_aura_tween = create_tween().set_loops()
	_aura_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_aura_tween.tween_property(character_aura, "modulate:a", character_data.get("aura_alpha_max"), half_dur)
	_aura_tween.tween_property(character_aura, "modulate:a", character_data.get("aura_alpha_min"), half_dur)


func _play_dust_pop() -> void:
	if dust_container == null:
		return

	# Anima pequenos pontos de poeira nos pés (impacto inicial da aterrissagem)
	for i in range(dust_container.get_child_count()):
		var dust := dust_container.get_child(i) as Control
		if dust == null:
			continue
		dust.visible = true
		dust.modulate.a = 0.7
		dust.scale = Vector2(0.5, 0.5)
		var target_x: float = -28.0 if i == 0 else (28.0 if i == 1 else 0.0)
		var dust_tween := create_tween()
		dust_tween.set_parallel(true)
		dust_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		dust_tween.tween_property(dust, "position:x", dust.position.x + target_x, 0.45)
		dust_tween.tween_property(dust, "position:y", dust.position.y - 8.0, 0.45)
		dust_tween.tween_property(dust, "scale", Vector2(1.2, 1.2), 0.45)
		dust_tween.tween_property(dust, "modulate:a", 0.0, 0.45)
		dust_tween.chain().tween_callback(func(): dust.visible = false)


func _stop_all_tweens() -> void:
	if _enter_tween != null and _enter_tween.is_valid():
		_enter_tween.kill()
	if _breathe_tween != null and _breathe_tween.is_valid():
		_breathe_tween.kill()
	if _shadow_tween != null and _shadow_tween.is_valid():
		_shadow_tween.kill()
	if _aura_tween != null and _aura_tween.is_valid():
		_aura_tween.kill()
	_is_looping_idle = false
