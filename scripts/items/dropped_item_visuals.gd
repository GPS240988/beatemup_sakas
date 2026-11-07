class_name DroppedItemVisuals
extends Node2D

## Componente visual reutilizável para itens dropados no Beat 'em Up Sakas.
## Garante:
## 1. Sombra fixa no solo (Polygon2D) sem acompanhar a flutuação.
## 2. Aura/círculo luminoso suave no solo com pulsação e contraste com o chão.
## 3. Flutuação sutil de target_visual no eixo Y sem alterar a raiz física/Y-sort.
## 4. Partículas discretas procedurais (CPUParticles2D) com emissão moderada.
## 5. Animação de surgimento arcade com leve pop/bounce.
## 6. Identidade por categoria: Consumível (verde-limão) ou Colecionável/História (dourado/âmbar).

@export var category_color: Color = Color(0.98, 0.78, 0.22, 1.0)
@export var aura_color: Color = Color(0.95, 0.75, 0.20, 0.42)
@export var glow_tint: Color = Color(1.30, 1.20, 1.05, 1.0)
@export var float_amplitude: float = 3.5
@export var float_speed: float = 3.0
@export var shadow_radius: Vector2 = Vector2(22.0, 8.0)
@export var aura_radius: Vector2 = Vector2(28.0, 11.0)
@export var ground_clearance: float = 2.0

var _target_visual: Node2D = null
var _base_visual_y: float = 0.0
var _base_visual_scale: Vector2 = Vector2.ONE
var _clock: float = 0.0
var _is_spawning: bool = false
var _spawn_tween: Tween = null

var _ground_anchor: Node2D
var _ground_shadow: Polygon2D
var _ground_aura: Polygon2D
var _particles: CPUParticles2D


## Normaliza a geometria vertical de qualquer elemento visual para que a sua base
## fique perfeitamente assentada no chão (Y = 0) com a folga configurada.
## Garante o padrão canônico para QUALQUER dropped item presente ou futuro no jogo.
func normalize_target_base(target: Node2D) -> void:
	if target == null:
		return

	if target is Sprite2D:
		var sprite := target as Sprite2D
		if sprite.texture != null:
			var tex_h: float = sprite.texture.get_size().y * absf(sprite.scale.y)
			var half_h: float = tex_h * 0.5 if sprite.centered else tex_h
			var current_bottom: float = sprite.position.y + half_h + (sprite.offset.y * sprite.scale.y)
			# Se o sprite estiver cortando o chão (ex: centralizado em Y=0 ou com base abaixo de -ground_clearance):
			if current_bottom > -ground_clearance or current_bottom > 0.0:
				sprite.position.y = -half_h - ground_clearance - (sprite.offset.y * sprite.scale.y)
	elif target is AnimatedSprite2D:
		var anim_sprite := target as AnimatedSprite2D
		if anim_sprite.sprite_frames != null and anim_sprite.sprite_frames.has_animation(anim_sprite.animation):
			var tex: Texture2D = anim_sprite.sprite_frames.get_frame_texture(anim_sprite.animation, anim_sprite.frame)
			if tex != null:
				var tex_h: float = tex.get_size().y * absf(anim_sprite.scale.y)
				var half_h: float = tex_h * 0.5 if anim_sprite.centered else tex_h
				var current_bottom: float = anim_sprite.position.y + half_h + (anim_sprite.offset.y * anim_sprite.scale.y)
				if current_bottom > -ground_clearance or current_bottom > 0.0:
					anim_sprite.position.y = -half_h - ground_clearance - (anim_sprite.offset.y * anim_sprite.scale.y)


func setup(
	target: Node2D,
	is_green: bool = false,
	custom_shadow_r: Vector2 = Vector2.ZERO,
	custom_aura_r: Vector2 = Vector2.ZERO
) -> void:
	_target_visual = target
	if _target_visual != null:
		normalize_target_base(_target_visual)
		_base_visual_y = _target_visual.position.y
		_base_visual_scale = _target_visual.scale

	if is_green:
		category_color = Color(0.25, 0.95, 0.40, 1.0)
		aura_color = Color(0.20, 0.90, 0.35, 0.42)
		glow_tint = Color(1.15, 1.35, 1.20, 1.0)
	else:
		category_color = Color(0.98, 0.78, 0.22, 1.0)
		aura_color = Color(0.95, 0.75, 0.20, 0.42)
		glow_tint = Color(1.35, 1.25, 1.10, 1.0)

	if custom_shadow_r != Vector2.ZERO:
		shadow_radius = custom_shadow_r
	if custom_aura_r != Vector2.ZERO:
		aura_radius = custom_aura_r

	_build_ground_elements()
	_build_particles()
	play_spawn_animation()


func _build_ground_elements() -> void:
	if _ground_anchor != null:
		return

	_ground_anchor = Node2D.new()
	_ground_anchor.name = "GroundAnchor"
	_ground_anchor.position = Vector2.ZERO
	_ground_anchor.z_index = 0
	add_child(_ground_anchor)

	# 1. Aura luminosa no chão (aditiva, circular/elíptica achatada para perspectiva 2.5D)
	_ground_aura = Polygon2D.new()
	_ground_aura.name = "GroundAura"
	_ground_aura.color = aura_color
	_ground_aura.polygon = _generate_ellipse_points(aura_radius.x, aura_radius.y, 16)
	_ground_aura.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var add_mat := CanvasItemMaterial.new()
	add_mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_ground_aura.material = add_mat
	_ground_anchor.add_child(_ground_aura)

	# 2. Sombra fixa no chão (física 2.5D - não acompanha a flutuação do item)
	_ground_shadow = Polygon2D.new()
	_ground_shadow.name = "GroundShadow"
	_ground_shadow.color = Color(0.02, 0.03, 0.06, 0.48)
	_ground_shadow.polygon = _generate_ellipse_points(shadow_radius.x, shadow_radius.y, 16)
	_ground_shadow.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_ground_anchor.add_child(_ground_shadow)


static func _generate_ellipse_points(rx: float, ry: float, count: int = 16) -> PackedVector2Array:
	var pts := PackedVector2Array()
	pts.resize(count)
	for i in range(count):
		var theta: float = (float(i) / float(count)) * TAU
		pts[i] = Vector2(cos(theta) * rx, sin(theta) * ry)
	return pts


func _build_particles() -> void:
	if _particles != null:
		return

	_particles = CPUParticles2D.new()
	_particles.name = "SparkleParticles"
	_particles.position = Vector2.ZERO
	_particles.amount = 5
	_particles.lifetime = 1.2
	_particles.preprocess = 0.4
	_particles.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	_particles.emission_rect_extents = Vector2(maxf(shadow_radius.x * 0.7, 8.0), 4.0)
	_particles.direction = Vector2(0.0, -1.0)
	_particles.spread = 22.0
	_particles.gravity = Vector2(0.0, -16.0)
	_particles.initial_velocity_min = 10.0
	_particles.initial_velocity_max = 22.0
	_particles.scale_amount_min = 1.5
	_particles.scale_amount_max = 2.5
	_particles.color = category_color

	var ramp := Gradient.new()
	ramp.set_color(0, Color(category_color.r, category_color.g, category_color.b, 0.0))
	ramp.add_point(0.25, Color(category_color.r, category_color.g, category_color.b, 0.95))
	ramp.set_color(ramp.get_point_count() - 1, Color(category_color.r, category_color.g, category_color.b, 0.0))
	_particles.color_ramp = ramp

	add_child(_particles)


func play_spawn_animation() -> void:
	if _target_visual == null or not is_inside_tree():
		return

	if _spawn_tween != null and _spawn_tween.is_valid():
		_spawn_tween.kill()

	_is_spawning = true
	_target_visual.scale = _base_visual_scale * 0.25
	_target_visual.position.y = _base_visual_y

	if _ground_anchor != null:
		_ground_anchor.scale = Vector2(0.2, 0.2)
		_ground_anchor.modulate.a = 0.0

	_spawn_tween = create_tween().set_parallel(true)
	# Subida suave com arco de recompensa
	_spawn_tween.tween_property(_target_visual, "position:y", _base_visual_y - 24.0, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_spawn_tween.tween_property(_target_visual, "scale", _base_visual_scale, 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	if _ground_anchor != null:
		_spawn_tween.tween_property(_ground_anchor, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		_spawn_tween.tween_property(_ground_anchor, "modulate:a", 1.0, 0.20)

	# Queda e assentamento suave
	_spawn_tween.chain().tween_property(_target_visual, "position:y", _base_visual_y, 0.18).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	_spawn_tween.chain().tween_callback(func():
		_is_spawning = false
		if _target_visual != null and is_instance_valid(_target_visual):
			_target_visual.scale = _base_visual_scale
	)


func _process(delta: float) -> void:
	_clock += delta

	if not _is_spawning and _target_visual != null and is_instance_valid(_target_visual):
		# Flutuação vertical suave exclusiva do nó visual
		var bob: float = sin(_clock * float_speed) * float_amplitude
		_target_visual.position.y = _base_visual_y + bob

		# Pulsação do contorno luminoso
		var pulse: float = (sin(_clock * 3.5) + 1.0) * 0.5
		_target_visual.modulate = Color.WHITE.lerp(glow_tint, pulse * 0.28)

	if _ground_aura != null and is_instance_valid(_ground_aura) and not _is_spawning:
		var aura_pulse: float = (sin(_clock * 2.8) + 1.0) * 0.5
		_ground_aura.modulate.a = lerpf(0.35, 0.65, aura_pulse)
		_ground_aura.scale = Vector2.ONE * lerpf(0.96, 1.06, aura_pulse)


func _exit_tree() -> void:
	if _spawn_tween != null and _spawn_tween.is_valid():
		_spawn_tween.kill()

