class_name MenuCharacterSlot
extends Control

## Slot de personagem do menu principal (Sakas Neo-16-bit).
## A respiração escala o corpo pelo pivô inferior; pés e sombra mantêm o contato com o chão.

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

	if sprite_container != null:
		if not sprite_container.resized.is_connected(_update_ground_pivot):
			sprite_container.resized.connect(_update_ground_pivot)
		_update_ground_pivot()


func _update_ground_pivot() -> void:
	if sprite_container == null:
		return
	# Centro inferior: respirar não altera a coordenada de contato dos pés.
	sprite_container.pivot_offset = Vector2(sprite_container.size.x * 0.5, sprite_container.size.y)
	sprite_container.position = Vector2.ZERO


func apply_character_data(data: RefCounted) -> void:
	character_data = data
	_ensure_node_refs()
	if character_data == null or not character_data.get("is_active"):
		visible = false
		_stop_all_tweens()
		return

	visible = true

	if character_texture != null:
		character_texture.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		var tex_path: String = character_data.get("texture_path")
		if ResourceLoader.exists(tex_path):
			character_texture.texture = load(tex_path) as Texture2D
		else:
			push_warning("MenuCharacterSlot: sprite idle não encontrado: %s" % tex_path)
		character_texture.flip_h = character_data.get("flip_h")

	# O briefing pede silhuetas limpas: sem aura pulsante nem poeira de entrada.
	if character_aura != null:
		character_aura.visible = false
	if dust_container != null:
		dust_container.visible = false

	if character_shadow != null:
		character_shadow.modulate.a = character_data.get("shadow_alpha_max")
		character_shadow.pivot_offset = character_shadow.size * 0.5
		character_shadow.scale = Vector2(character_data.get("shadow_scale_x_max"), 1.0)

	if sprite_container != null:
		_update_ground_pivot()
		var scale_mult: float = character_data.get("scale_multiplier")
		sprite_container.scale = Vector2.ONE * scale_mult
		sprite_container.position = Vector2.ZERO


func start_presentation(start_drawing: bool = true) -> void:
	if character_data == null or not character_data.get("is_active"):
		return

	_stop_all_tweens()

	if start_drawing and character_texture != null and character_texture.material is ShaderMaterial:
		var mat := (character_texture.material as ShaderMaterial).duplicate() as ShaderMaterial
		character_texture.material = mat
		mat.set_shader_parameter("draw_progress", 0.0)

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

	start_idle_loop()
	draw_completed.emit(character_data.get("id"))


func start_idle_loop() -> void:
	if character_data == null or not character_data.get("is_active"):
		return

	_is_looping_idle = true
	_start_breathe_tween()
	_start_shadow_tween()


func _start_breathe_tween() -> void:
	if sprite_container == null:
		return

	if _breathe_tween != null and _breathe_tween.is_valid():
		_breathe_tween.kill()

	_update_ground_pivot()
	var duration: float = character_data.get("breathe_duration")
	var half_duration: float = duration * 0.5
	var base_scale: Vector2 = sprite_container.scale
	var inhale_scale: Vector2 = Vector2(
		base_scale.x * float(character_data.get("breathe_scale_x")),
		base_scale.y * float(character_data.get("breathe_scale_y"))
	)

	_breathe_tween = create_tween().set_loops()
	_breathe_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_breathe_tween.tween_property(sprite_container, "scale", inhale_scale, half_duration)
	_breathe_tween.tween_property(sprite_container, "scale", base_scale, half_duration)


func _start_shadow_tween() -> void:
	if character_shadow == null:
		return

	if _shadow_tween != null and _shadow_tween.is_valid():
		_shadow_tween.kill()

	var duration: float = character_data.get("breathe_duration")
	var half_duration: float = duration * 0.5
	var scale_min: float = character_data.get("shadow_scale_x_min")
	var scale_max: float = character_data.get("shadow_scale_x_max")
	var alpha_min: float = character_data.get("shadow_alpha_min")
	var alpha_max: float = character_data.get("shadow_alpha_max")

	_shadow_tween = create_tween().set_loops()
	_shadow_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_shadow_tween.tween_property(character_shadow, "scale:x", scale_min, half_duration)
	_shadow_tween.parallel().tween_property(character_shadow, "modulate:a", alpha_min, half_duration)
	_shadow_tween.tween_property(character_shadow, "scale:x", scale_max, half_duration)
	_shadow_tween.parallel().tween_property(character_shadow, "modulate:a", alpha_max, half_duration)


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
