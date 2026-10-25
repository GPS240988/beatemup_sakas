class_name CombatFeedback
extends RefCounted

## Sistema Centralizado e Reutilizável de Feedback Audiovisual de Impacto (FASE COMBATE ARCADE)
## Responsável por Hitstop controlado, Screen Shake, Partículas de Impacto (CPUParticles2D),
## Flashes de impacto e Afterimages procedurais. Não aloca infinitamente nem trava a interface.

const SPARK_LIFETIME: float = 0.22


## Aplica Hitstop controlado no atacante e na vítima sem travar o SceneTree nem o HUD
static func apply_hitstop(attacker: Node, victim: Node, duration: float) -> void:
	if duration <= 0.0:
		return

	if attacker != null and is_instance_valid(attacker) and attacker.has_method("apply_hitstop"):
		attacker.apply_hitstop(duration)

	if victim != null and is_instance_valid(victim) and victim.has_method("apply_hitstop"):
		victim.apply_hitstop(duration)


## Dispara tremor de câmera (Screen Shake) baseado em trauma amortecido
static func trigger_screen_shake(context_node: Node, intensity: float = 8.0, duration: float = 0.25) -> void:
	if context_node == null or not context_node.is_inside_tree():
		return

	var viewport := context_node.get_viewport()
	if viewport == null:
		return

	var camera := viewport.get_camera_2d()
	if camera == null:
		return

	# Aplica tremor via Tween suave amortecido
	var original_offset: Vector2 = camera.offset
	var tween: Tween = camera.create_tween()
	if tween == null:
		return

	var steps: int = 4
	var step_time: float = duration / float(steps)
	for i in range(steps):
		var damp: float = 1.0 - (float(i) / float(steps))
		var shake_offset: Vector2 = Vector2(
			randf_range(-intensity, intensity) * damp,
			randf_range(-intensity * 0.5, intensity * 0.5) * damp
		)
		tween.tween_property(camera, "offset", original_offset + shake_offset, step_time * 0.5)
	tween.tween_property(camera, "offset", original_offset, step_time * 0.5)


## Gera partículas de impacto direcionais (CPUParticles2D) e efeitos visuais animados (Pixel Art HD)
static func spawn_hit_spark(parent: Node, pos: Vector2, direction: Vector2, profile: String = "punch") -> void:
	if parent == null or not parent.is_inside_tree():
		return

	# 1. Faíscas animadas em Pixel Art HD dos Beat 'em Ups clássicos
	var vfx_frames: SpriteFrames = load("res://scenes/vfx/hit_effects_frames.tres") as SpriteFrames
	if vfx_frames != null:
		var effect_sprite := AnimatedSprite2D.new()
		effect_sprite.name = "AnimatedHitSpark"
		effect_sprite.top_level = true
		effect_sprite.sprite_frames = vfx_frames
		effect_sprite.global_position = pos
		effect_sprite.z_index = 50

		var anim_name: StringName = &"impacto"
		var sprite_scale: float = 0.65
		match profile:
			"light", "punch":
				anim_name = &"impacto"
				sprite_scale = 0.65
			"medium", "kick":
				anim_name = &"impacto"
				sprite_scale = 0.80
			"heavy", "finisher":
				anim_name = &"combinado"
				sprite_scale = 0.85
			"special":
				anim_name = &"impactoazul"
				sprite_scale = 0.95
			_:
				anim_name = &"impacto"
				sprite_scale = 0.70

		effect_sprite.scale = Vector2(sprite_scale, sprite_scale)
		effect_sprite.rotation = randf_range(-0.25, 0.25)
		parent.add_child(effect_sprite)
		effect_sprite.play(anim_name)
		effect_sprite.animation_finished.connect(effect_sprite.queue_free)

		# Timer de segurança para remoção
		var safety_timer: SceneTreeTimer = parent.get_tree().create_timer(0.4)
		safety_timer.timeout.connect(func():
			if is_instance_valid(effect_sprite):
				effect_sprite.queue_free()
		)

	# 2. Partículas direcionais de alta velocidade (CPUParticles2D)
	var particles := CPUParticles2D.new()
	particles.name = "ImpactSpark"
	particles.top_level = true
	particles.global_position = pos
	particles.emitting = false
	particles.one_shot = true
	particles.lifetime = SPARK_LIFETIME
	particles.explosiveness = 0.95

	# Configurações de física e dispersão das partículas
	var dir_norm := direction.normalized()
	if dir_norm == Vector2.ZERO:
		dir_norm = Vector2.RIGHT
	particles.direction = dir_norm
	particles.spread = 45.0
	particles.gravity = Vector2(0, 180)

	match profile:
		"light", "punch":
			particles.amount = 8
			particles.initial_velocity_min = 120.0
			particles.initial_velocity_max = 220.0
			particles.color = Color(1.0, 0.92, 0.35, 1.0) # Faísca amarela dourada
			particles.scale_amount_min = 2.0
			particles.scale_amount_max = 3.5
		"medium", "kick":
			particles.amount = 12
			particles.initial_velocity_min = 160.0
			particles.initial_velocity_max = 280.0
			particles.color = Color(1.0, 0.55, 0.2, 1.0) # Laranja vibrante
			particles.scale_amount_min = 2.5
			particles.scale_amount_max = 4.5
		"heavy", "finisher":
			particles.amount = 18
			particles.initial_velocity_min = 200.0
			particles.initial_velocity_max = 360.0
			particles.color = Color(1.0, 0.25, 0.25, 1.0) # Vermelho rubi de alto impacto
			particles.scale_amount_min = 3.0
			particles.scale_amount_max = 5.5
		"special":
			particles.amount = 26
			particles.initial_velocity_min = 250.0
			particles.initial_velocity_max = 480.0
			particles.color = Color(0.3, 0.85, 1.0, 1.0) # Azul elétrico sobrenatural
			particles.scale_amount_min = 3.5
			particles.scale_amount_max = 6.5
		_:
			particles.amount = 10
			particles.initial_velocity_min = 140.0
			particles.initial_velocity_max = 240.0
			particles.color = Color(1.0, 0.8, 0.4, 1.0)
			particles.scale_amount_min = 2.0
			particles.scale_amount_max = 3.5

	parent.add_child(particles)
	particles.emitting = true

	# Auto-destruição limpa após emissão
	var cleanup_timer: SceneTreeTimer = parent.get_tree().create_timer(SPARK_LIFETIME + 0.1)
	cleanup_timer.timeout.connect(func():
		if is_instance_valid(particles):
			particles.queue_free()
	)


## Gera nuvem de poeira de impacto no solo (Knockdown / Aterrissagem)
static func spawn_dust(parent: Node, pos: Vector2, scale_factor: float = 0.65) -> void:
	if parent == null or not parent.is_inside_tree():
		return

	var vfx_frames: SpriteFrames = load("res://scenes/vfx/hit_effects_frames.tres") as SpriteFrames
	if vfx_frames != null and vfx_frames.has_animation(&"poeira"):
		var dust := AnimatedSprite2D.new()
		dust.name = "LandingDust"
		dust.top_level = true
		dust.sprite_frames = vfx_frames
		dust.global_position = pos
		dust.scale = Vector2(scale_factor, scale_factor)
		dust.z_index = 10
		parent.add_child(dust)
		dust.play(&"poeira")
		dust.animation_finished.connect(dust.queue_free)

		var safety_timer: SceneTreeTimer = parent.get_tree().create_timer(0.4)
		safety_timer.timeout.connect(func():
			if is_instance_valid(dust):
				dust.queue_free()
		)


## Produz flash visual rápido na entidade (modulação clara momentânea)
static func flash_node(node: CanvasItem, flash_color: Color = Color(2.5, 2.5, 2.5, 1.0), duration: float = 0.08) -> void:
	if node == null or not is_instance_valid(node) or not node.is_inside_tree():
		return

	var orig_color: Color = node.modulate
	node.modulate = flash_color

	var timer: SceneTreeTimer = node.get_tree().create_timer(duration)
	timer.timeout.connect(func():
		if is_instance_valid(node):
			node.modulate = orig_color
	)


## Cria uma silhueta / afterimage procedural sem novos sprites
static func spawn_afterimage(actor: CharacterBody2D, tint: Color = Color(0.3, 0.8, 1.0, 0.6), fade_time: float = 0.25) -> void:
	if actor == null or not is_instance_valid(actor) or not actor.is_inside_tree():
		return

	var visual: Node2D = actor.get_node_or_null("Visual") as Node2D
	if visual == null:
		return

	var anim_sprite: AnimatedSprite2D = visual.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	if anim_sprite == null or anim_sprite.sprite_frames == null:
		return

	var curr_anim: StringName = anim_sprite.animation
	var curr_frame: int = anim_sprite.frame
	var texture: Texture2D = anim_sprite.sprite_frames.get_frame_texture(curr_anim, curr_frame)
	if texture == null:
		return

	var ghost := Sprite2D.new()
	ghost.top_level = true
	ghost.texture = texture
	ghost.global_position = anim_sprite.global_position
	ghost.scale = anim_sprite.global_scale
	ghost.flip_h = anim_sprite.flip_h
	ghost.modulate = tint
	ghost.z_index = visual.z_index - 1

	actor.get_parent().add_child(ghost)

	var tween: Tween = ghost.create_tween()
	if tween != null:
		tween.tween_property(ghost, "modulate:a", 0.0, fade_time)
		tween.tween_callback(ghost.queue_free)
	else:
		ghost.queue_free()
