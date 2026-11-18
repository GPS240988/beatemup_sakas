class_name GabrielGunVFX
extends RefCounted

## VFX balístico exclusivo de Gabriel. Mantém o clarão PixelFX amplo já existente
## e acrescenta um núcleo de disparo nítido, projétil legível e impacto dedicado.

const VFX_FRAMES: SpriteFrames = preload("res://scenes/vfx/gabriel_gun_vfx_frames.tres")

const MUZZLE_LAYER: int = 56
const IMPACT_LAYER: int = 57
const MUZZLE_SCALE: float = 0.70
const IMPACT_SCALE: float = 0.82
const HEAVY_IMPACT_SCALE: float = 1.10


static func spawn_muzzle_core(context_node: Node, world_position: Vector2, shot_direction: Vector2) -> AnimatedSprite2D:
	return _spawn_effect(
		context_node,
		world_position,
		shot_direction,
		&"muzzle_core",
		MUZZLE_SCALE,
		MUZZLE_LAYER,
		"GabrielMuzzleCore"
	)


static func spawn_bullet_impact(
	context_node: Node,
	world_position: Vector2,
	shot_direction: Vector2,
	heavy_impact: bool = false
) -> AnimatedSprite2D:
	var effect_scale: float = HEAVY_IMPACT_SCALE if heavy_impact else IMPACT_SCALE
	return _spawn_effect(
		context_node,
		world_position,
		shot_direction,
		&"bullet_impact",
		effect_scale,
		IMPACT_LAYER,
		"GabrielBulletImpact"
	)


static func _spawn_effect(
	context_node: Node,
	world_position: Vector2,
	shot_direction: Vector2,
	animation_name: StringName,
	effect_scale: float,
	layer: int,
	effect_name: String
) -> AnimatedSprite2D:
	if context_node == null or not is_instance_valid(context_node) or not context_node.is_inside_tree():
		return null
	if not VFX_FRAMES.has_animation(animation_name):
		return null

	var effect_tree: SceneTree = context_node.get_tree()
	if effect_tree == null:
		return null

	var effect_host: Node = effect_tree.current_scene
	if effect_host == null:
		effect_host = effect_tree.root
	if effect_host == null:
		return null

	var effect := AnimatedSprite2D.new()
	effect.name = effect_name
	effect.sprite_frames = VFX_FRAMES
	effect.animation = animation_name
	effect.centered = true
	effect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	effect.top_level = true
	effect.z_as_relative = false
	effect.z_index = layer
	effect.scale = Vector2.ONE * effect_scale
	effect.flip_h = shot_direction.x < 0.0
	effect_host.add_child(effect)
	effect.global_position = world_position
	effect.play(animation_name)

	var effect_ref: WeakRef = weakref(effect)
	effect.animation_finished.connect(func() -> void:
		var live_effect: AnimatedSprite2D = effect_ref.get_ref() as AnimatedSprite2D
		if live_effect != null and is_instance_valid(live_effect):
			live_effect.queue_free()
	, Object.CONNECT_ONE_SHOT)

	# Safety cleanup cobre troca de cena e qualquer interrupção da animação.
	var frame_count: int = VFX_FRAMES.get_frame_count(animation_name)
	var fps: float = maxf(VFX_FRAMES.get_animation_speed(animation_name), 1.0)
	var safety_lifetime: float = float(frame_count) / fps + 0.30
	var safety_timer: SceneTreeTimer = effect_tree.create_timer(safety_lifetime, true, false, true)
	safety_timer.timeout.connect(func() -> void:
		var live_effect: AnimatedSprite2D = effect_ref.get_ref() as AnimatedSprite2D
		if live_effect != null and is_instance_valid(live_effect):
			live_effect.queue_free()
	)

	return effect
