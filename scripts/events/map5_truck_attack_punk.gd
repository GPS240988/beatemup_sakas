class_name Map5TruckAttackPunk
extends CharacterBody2D

## Punk da set piece pós-Bêbado.
## Não participa do CombatDirector nem do encontro normal de inimigos.
## O sprite usa as sete poses normalizadas do spritesheet 4x2.

signal bottle_hit(punk: Map5TruckAttackPunk)

const CELL_SIZE := Vector2i(220, 300)
const BASE_VISUAL_SCALE: float = 0.44
const VISUAL_BASE_OFFSET_Y: float = -142.0

const PUNK_TEXTURES: Array[Texture2D] = [
	preload("res://assets/sprites/stage2/truck_attack_sequence/punks/punk_01_spritesheet.png"),
	preload("res://assets/sprites/stage2/truck_attack_sequence/punks/punk_02_spritesheet.png"),
	preload("res://assets/sprites/stage2/truck_attack_sequence/punks/punk_03_spritesheet.png"),
]

const STATE_NAMES: Array[StringName] = [
	&"idle_caçamba",
	&"pegar_pedra",
	&"telegraph_arremesso",
	&"arremesso",
	&"hit",
	&"derrotado_caçamba",
	&"caido_caçamba",
]

@export_range(0, 2, 1) var punk_index: int = 0

var _visual: Node2D
var _sprite: AnimatedSprite2D
var _hurtbox: Area2D
var _defeated: bool = false
var _stone_spawn_offset := Vector2(34.0, -78.0)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_INHERIT
	collision_layer = 0
	collision_mask = 0
	add_to_group("actors")
	add_to_group("setpiece_punk")

	_build_visual()
	_build_hurtbox()
	play_state(&"idle_caçamba")


func _build_visual() -> void:
	_visual = Node2D.new()
	_visual.name = "Visual"
	_visual.position = Vector2(0.0, VISUAL_BASE_OFFSET_Y)
	_visual.scale = Vector2(BASE_VISUAL_SCALE, BASE_VISUAL_SCALE)
	_visual.z_index = 0
	add_child(_visual)

	_sprite = AnimatedSprite2D.new()
	_sprite.name = "AnimatedSprite2D"
	_sprite.sprite_frames = _build_sprite_frames(PUNK_TEXTURES[clampi(punk_index, 0, 2)])
	_sprite.animation = &"idle_caçamba"
	_sprite.frame = 0
	_sprite.centered = true
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_sprite.speed_scale = 1.0
	_visual.add_child(_sprite)


func _build_sprite_frames(sheet: Texture2D) -> SpriteFrames:
	var frames := SpriteFrames.new()
	for i in STATE_NAMES.size():
		var row: int = i / 4
		var col: int = i % 4
		var atlas := AtlasTexture.new()
		atlas.atlas = sheet
		atlas.region = Rect2(
			float(col * CELL_SIZE.x),
			float(row * CELL_SIZE.y),
			float(CELL_SIZE.x),
			float(CELL_SIZE.y)
		)
		var state_name: StringName = STATE_NAMES[i]
		frames.add_animation(state_name)
		frames.set_animation_loop(state_name, false)
		frames.set_animation_speed(state_name, 1.0)
		frames.add_frame(state_name, atlas)
	return frames


func _build_hurtbox() -> void:
	_hurtbox = Area2D.new()
	_hurtbox.name = "Hurtbox"
	_hurtbox.collision_layer = 4
	_hurtbox.collision_mask = 0
	_hurtbox.monitoring = false
	_hurtbox.monitorable = true
	add_child(_hurtbox)

	var shape := CollisionShape2D.new()
	shape.name = "CollisionShape2D"
	var capsule := CapsuleShape2D.new()
	capsule.radius = 26.0
	capsule.height = 104.0
	shape.shape = capsule
	shape.position = Vector2(0.0, -54.0)
	_hurtbox.add_child(shape)


func play_state(state_name: StringName) -> void:
	if _sprite == null or not _sprite.sprite_frames.has_animation(state_name):
		return
	_sprite.animation = state_name
	_sprite.frame = 0
	_sprite.stop()


func play_stone_throw() -> Vector2:
	if _defeated:
		return Vector2.ZERO

	play_state(&"pegar_pedra")
	await get_tree().create_timer(0.10, true).timeout
	if _defeated:
		return Vector2.ZERO

	play_state(&"telegraph_arremesso")
	await get_tree().create_timer(0.34, true).timeout
	if _defeated:
		return Vector2.ZERO

	play_state(&"arremesso")
	var spawn_position: Vector2 = global_position + _stone_spawn_offset

	await get_tree().create_timer(0.10, true).timeout
	if not _defeated:
		play_state(&"idle_caçamba")

	return spawn_position


func take_damage(damage_input: Variant) -> bool:
	if _defeated:
		return false
	if not (damage_input is RefCounted):
		return false

	var damage_type: String = str(damage_input.get("damage_type"))
	var impact_profile: String = str(damage_input.get("impact_profile"))
	if damage_type != "bottle_projectile" or impact_profile != "bottle":
		return false

	_defeated = true
	if _hurtbox != null:
		_hurtbox.set_deferred("monitorable", false)
		_hurtbox.set_deferred("monitoring", false)

	play_state(&"hit")
	bottle_hit.emit(self)

	var tween := create_tween()
	if tween != null:
		tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		tween.tween_interval(0.16)
		tween.tween_callback(func() -> void:
			if is_inside_tree():
				play_state(&"derrotado_caçamba")
		)
		tween.tween_interval(0.24)
		tween.tween_callback(func() -> void:
			if is_inside_tree():
				play_state(&"caido_caçamba")
		)
	else:
		play_state(&"caido_caçamba")

	return true


func is_defeated() -> bool:
	return _defeated


func get_impact_point(_probe_position: Vector2 = Vector2.ZERO, _facing: float = 1.0) -> Vector2:
	return global_position + Vector2(0.0, -72.0)
