class_name CombatFeedback
extends RefCounted

## Sistema Centralizado e Reutilizável de Feedback Audiovisual de Impacto (FASE COMBATE ARCADE)
## Responsável por Hitstop controlado, Screen Shake, Partículas de Impacto (CPUParticles2D),
## Flashes de impacto e Afterimages procedurais. Não aloca infinitamente nem trava a interface.

const ObjectPoolClass = preload("res://scripts/core/object_pool.gd")

const SPARK_LIFETIME: float = 0.22


## Aplica Hitstop controlado no atacante e na vítima sem travar o SceneTree nem o HUD
static func apply_hitstop(attacker: Node, victim: Node, duration: float) -> void:
	if duration <= 0.0:
		return

	_apply_single_actor_hitstop(attacker, duration)
	_apply_single_actor_hitstop(victim, duration)


static func _apply_single_actor_hitstop(actor: Node, duration: float) -> void:
	if actor == null or not is_instance_valid(actor):
		return
	if actor.has_method("apply_hitstop"):
		actor.apply_hitstop(duration)
	elif actor.get_parent() != null and is_instance_valid(actor.get_parent()) and actor.get_parent().has_method("apply_hitstop"):
		actor.get_parent().apply_hitstop(duration)


## Dispara tremor de câmera (Screen Shake) baseado em trauma amortecido e seguro contra concorrência
static func trigger_screen_shake(context_node: Node, intensity: float = 8.0, duration: float = 0.25) -> void:
	if context_node == null or not context_node.is_inside_tree() or intensity <= 0.0 or duration <= 0.0:
		return

	var viewport := context_node.get_viewport()
	if viewport == null:
		return

	var camera := viewport.get_camera_2d()
	if camera == null or not is_instance_valid(camera):
		return

	# 1. Garante que o offset de repouso canônico da câmera é preservado mesmo sob múltiplos tremores
	if not camera.has_meta(&"_base_camera_offset"):
		camera.set_meta(&"_base_camera_offset", camera.offset)
	var base_offset: Vector2 = camera.get_meta(&"_base_camera_offset")

	# 2. Interrompe tween concorrente anterior para impedir disputa sobre a propriedade offset
	if camera.has_meta(&"_shake_tween"):
		var prev_tween = camera.get_meta(&"_shake_tween")
		if prev_tween is Tween and prev_tween.is_valid():
			prev_tween.kill()

	var tween: Tween = camera.create_tween()
	if tween == null:
		camera.offset = base_offset
		return
	camera.set_meta(&"_shake_tween", tween)

	# 3. Interpolação amortecida dos passos de tremor
	var steps: int = 4
	var step_time: float = duration / float(steps)
	for i in range(steps):
		var damp: float = 1.0 - (float(i) / float(steps))
		var shake_offset: Vector2 = Vector2(
			randf_range(-intensity, intensity) * damp,
			randf_range(-intensity * 0.5, intensity * 0.5) * damp
		)
		tween.tween_property(camera, "offset", base_offset + shake_offset, step_time * 0.5)

	# 4. Retorno estrito e garantido ao offset original de repouso
	tween.tween_property(camera, "offset", base_offset, step_time * 0.5)
	tween.tween_callback(func():
		if is_instance_valid(camera):
			camera.offset = base_offset
			if camera.has_meta(&"_shake_tween") and camera.get_meta(&"_shake_tween") == tween:
				camera.remove_meta(&"_shake_tween")
	)


# =========================================================================
# REPRODUÇÃO E SINCRONIZAÇÃO DE EFEITOS SONOROS DE COMBATE (SFX)
# =========================================================================

const SFX_SOCO_1: String = "res://assets/audio/sfx/soco_1_guilherme.mp3"
const SFX_SOCO_2: String = "res://assets/audio/sfx/soco_2_guilherme.mp3"
const SFX_FINALIZADOR: String = "res://assets/audio/sfx/finalizador_3_guilherme.mp3"
const SFX_JUMPKICK: String = "res://assets/audio/sfx/jumpkick_guilherme.mp3"
const SFX_ESPECIAL: String = "res://assets/audio/sfx/especial_1.1_guilherme.mp3"
const SFX_INIMIGO_DANO_1: String = "res://assets/audio/sfx/inimigo_apanhando_1.mp3"
const SFX_INIMIGO_DANO_2: String = "res://assets/audio/sfx/inimigo_apanhando_2.mp3"
const SFX_INIMIGO_QUEDA: String = "res://assets/audio/sfx/inimigo_queda_1.mp3"

const SFX_COCA_PICKUP: String = "res://assets/audio/sfx/Coca-Cola.mp3"
const SFX_REVISTA_PICKUP: String = "res://assets/audio/sfx/Revista.mp3"
const SFX_EMMANUELLE_PICKUP: String = "res://assets/audio/sfx/emmanuelle.mp3"
const SFX_PROP_BOX_HIT: String = "res://assets/audio/sfx/Pancada na Caixa.mp3"
const SFX_PROP_BOX_BREAK: String = "res://assets/audio/sfx/Quebra da Caixa.mp3"
const SFX_PROP_TRASH_HIT: String = "res://assets/audio/sfx/Lata de Lixo  Metal.mp3"
const SFX_MENU_MOVE: String = "res://assets/audio/sfx/Mover Cursor_sfx_move.mp3"
const SFX_MENU_CONFIRM: String = "res://assets/audio/sfx/Confirmar Seleção_sfx_confirm.mp3"
const SFX_MENU_DENIED: String = "res://assets/audio/sfx/Opção Bloqueada_sfx_denied.mp3"
const SFX_NARRATIVE_HUM: String = "res://assets/audio/sfx/deep_intro_hum.mp3"
const SFX_NARRATIVE_GLITCH: String = "res://assets/audio/sfx/glitch_static.mp3"

static var _sound_cache: Dictionary = {}
static var _punch_toggle: bool = false
static var _hurt_toggle: bool = false


static func _get_cached_stream(path: String) -> AudioStream:
	if not _sound_cache.has(path):
		if ResourceLoader.exists(path):
			_sound_cache[path] = load(path) as AudioStream
		else:
			_sound_cache[path] = null
	return _sound_cache[path]


## Toca um efeito sonoro de combate com pitch levemente variado e reciclagem segura no pool.
static func play_sound(context_node: Node, path: String, volume_db: float = 0.0, pitch_var: float = 0.05) -> AudioStreamPlayer:
	if context_node == null or not context_node.is_inside_tree():
		return null
	var scene_root: Node = null
	if context_node.get_tree() != null and context_node.get_tree().current_scene != null:
		scene_root = context_node.get_tree().current_scene
	else:
		scene_root = context_node
	if scene_root == null:
		return null

	var stream := _get_cached_stream(path)
	if stream == null:
		return null

	var audio_pool := ObjectPoolClass.get_or_create(
		scene_root,
		"_Pool_CombatSFX",
		null,
		func():
			var p := AudioStreamPlayer.new()
			p.name = "CombatAudioPlayer"
			p.bus = &"Master"
			p.process_mode = Node.PROCESS_MODE_ALWAYS
			return p,
		8
	)

	var player: AudioStreamPlayer = null
	if audio_pool != null and audio_pool.has_method("acquire"):
		player = audio_pool.call("acquire") as AudioStreamPlayer

	if player == null:
		player = AudioStreamPlayer.new()
		player.name = "CombatAudioPlayer"
		player.bus = &"Master"
		player.process_mode = Node.PROCESS_MODE_ALWAYS
		scene_root.add_child(player)

	player.stream = stream
	player.volume_db = volume_db
	player.pitch_scale = 1.0 if pitch_var <= 0.0 else randf_range(1.0 - pitch_var, 1.0 + pitch_var)
	player.process_mode = Node.PROCESS_MODE_ALWAYS
	player.play()

	var stream_len: float = stream.get_length() if stream.has_method("get_length") else 0.5
	var player_id: int = player.get_instance_id()
	var pool_id: int = audio_pool.get_instance_id() if audio_pool != null else 0
	var timer := context_node.get_tree().create_timer(maxf(0.1, stream_len + 0.05), false, false, true)
	timer.timeout.connect(func():
		var p_inst := instance_from_id(player_id) as AudioStreamPlayer
		var pool_inst := instance_from_id(pool_id)
		if is_instance_valid(p_inst) and is_instance_valid(pool_inst):
			if pool_inst.has_method("release"):
				pool_inst.call("release", p_inst)
	)
	return player


## Reproduz o efeito de impacto com base no perfil do ataque (punch, kick, finisher, special)
static func play_impact_sound(context_node: Node, profile: String = "punch") -> void:
	match profile:
		"punch", "light":
			var path := SFX_SOCO_1 if _punch_toggle else SFX_SOCO_2
			_punch_toggle = not _punch_toggle
			play_sound(context_node, path, -0.5, 0.05)
		"kick", "medium":
			play_sound(context_node, SFX_JUMPKICK, 0.0, 0.04)
		"heavy", "finisher":
			play_sound(context_node, SFX_FINALIZADOR, 1.5, 0.03)
		"special":
			play_sound(context_node, SFX_ESPECIAL, 2.5, 0.02)
		_:
			play_sound(context_node, SFX_SOCO_2, -0.5, 0.05)


## Reproduz o som de dor / reação a golpe dos inimigos de rua
static func play_enemy_hurt_sound(context_node: Node) -> void:
	var path := SFX_INIMIGO_DANO_1 if _hurt_toggle else SFX_INIMIGO_DANO_2
	_hurt_toggle = not _hurt_toggle
	play_sound(context_node, path, -1.5, 0.06)


## Reproduz o som de impacto no solo quando um inimigo sofre queda (Knockdown)
static func play_enemy_fall_sound(context_node: Node) -> void:
	play_sound(context_node, SFX_INIMIGO_QUEDA, 1.0, 0.04)


## Reproduz som de impacto em objeto destrutível (madeira ou metal)
static func play_prop_hit_sound(context_node: Node, is_metal: bool = false) -> void:
	var path := SFX_PROP_TRASH_HIT if is_metal else SFX_PROP_BOX_HIT
	play_sound(context_node, path, -0.5, 0.05)


## Reproduz som de quebra/destruição de objeto destrutível
static func play_prop_break_sound(context_node: Node, is_metal: bool = false) -> void:
	var path := SFX_PROP_TRASH_HIT if is_metal else SFX_PROP_BOX_BREAK
	play_sound(context_node, path, 1.0, 0.04)


## Reproduz som de coleta de item (Coca, Revista de História ou Emmanuelle)
static func play_pickup_sound(context_node: Node, item_type: String = "coca") -> AudioStreamPlayer:
	match item_type:
		"coca", "health":
			return play_sound(context_node, SFX_COCA_PICKUP, 0.0, 0.03)
		"magazine", "story", "revista":
			return play_sound(context_node, SFX_REVISTA_PICKUP, 0.5, 0.02)
		"emmanuelle", "emmanuele":
			return play_sound(context_node, SFX_EMMANUELLE_PICKUP, 1.0, 0.0)
		_:
			return play_sound(context_node, SFX_COCA_PICKUP, 0.0, 0.03)


## Reproduz som de interface / navegação de menus
static func play_menu_sound(context_node: Node, action: String = "move") -> void:
	match action:
		"move":
			play_sound(context_node, SFX_MENU_MOVE, -1.0, 0.04)
		"confirm":
			play_sound(context_node, SFX_MENU_CONFIRM, 0.5, 0.02)
		"denied":
			play_sound(context_node, SFX_MENU_DENIED, 0.5, 0.02)
		_:
			play_sound(context_node, SFX_MENU_MOVE, -1.0, 0.04)


## Gera partículas de impacto direcionais (CPUParticles2D) e efeitos visuais animados (Pixel Art HD)
## Utiliza ObjectPool leve para eliminar picos de alocação/destruição durante combos intensos no mobile.
static func spawn_hit_spark(parent: Node, pos: Vector2, direction: Vector2, profile: String = "punch", region: String = "") -> void:
	if parent == null or not parent.is_inside_tree():
		return

	var scene_root: Node = parent.get_tree().current_scene if parent.get_tree() != null else parent
	if scene_root == null:
		scene_root = parent

	# 1. Faíscas animadas em Pixel Art HD dos Beat 'em Ups clássicos via ObjectPool
	var vfx_frames: SpriteFrames = load("res://scenes/vfx/hit_effects_frames.tres") as SpriteFrames
	if vfx_frames != null:
		var spark_pool := ObjectPoolClass.get_or_create(
			scene_root,
			"_Pool_HitSparks",
			null,
			func():
				var spr := AnimatedSprite2D.new()
				spr.name = "AnimatedHitSpark"
				spr.top_level = true
				spr.sprite_frames = vfx_frames
				spr.z_index = 50
				return spr,
			8
		)

		var effect_sprite: AnimatedSprite2D = null
		if spark_pool != null and spark_pool.has_method("acquire"):
			effect_sprite = spark_pool.call("acquire") as AnimatedSprite2D

		if effect_sprite == null:
			effect_sprite = AnimatedSprite2D.new()
			effect_sprite.name = "AnimatedHitSpark"
			effect_sprite.top_level = true
			effect_sprite.sprite_frames = vfx_frames
			effect_sprite.z_index = 50
			parent.add_child(effect_sprite)

		effect_sprite.global_position = pos
		effect_sprite.set_meta("impact_region", region)
		effect_sprite.set_meta("impact_position", pos)
		effect_sprite.set_meta("impact_profile", profile)

		var anim_name: StringName = &"impacto"
		var sprite_scale: float = 0.65
		# Calibração do centro visual: as texturas originais (195x196) possuem o miolo da explosão
		# no quadrante superior esquerdo (x ~ 50-75, y ~ 60-72) em vez do centro geométrico (97.5, 98.0).
		# O offset local compensa o pivô para que o centro visual da faísca fique exatamente no ponto de impacto 'pos'.
		var visual_offset := Vector2(43.0, 35.0)
		match profile:
			"punch":
				if vfx_frames.has_animation(&"blunt_hit"):
					anim_name = &"blunt_hit"
					sprite_scale = 1.05
					visual_offset = Vector2(0.0, -6.0)
				else:
					anim_name = &"impacto"
					sprite_scale = 0.65
					visual_offset = Vector2(43.0, 35.0)
			"light":
				anim_name = &"impacto"
				sprite_scale = 0.65
				visual_offset = Vector2(43.0, 35.0)
			"medium", "kick":
				if vfx_frames.has_animation(&"hit_spark"):
					anim_name = &"hit_spark"
					sprite_scale = 1.05
					visual_offset = Vector2.ZERO
				else:
					anim_name = &"impacto"
					sprite_scale = 0.80
					visual_offset = Vector2(43.0, 35.0)
			"heavy", "finisher":
				if vfx_frames.has_animation(&"crit_hit"):
					anim_name = &"crit_hit"
					sprite_scale = 0.95
					visual_offset = Vector2.ZERO
				else:
					anim_name = &"combinado"
					sprite_scale = 0.85
					visual_offset = Vector2(21.0, 26.0)
			"special":
				anim_name = &"impactoazul"
				sprite_scale = 0.95
				visual_offset = Vector2(46.0, 27.0)
			_:
				anim_name = &"impacto"
				sprite_scale = 0.70
				visual_offset = Vector2(43.0, 35.0)

		var facing_sign: float = -1.0 if direction.x < 0.0 else 1.0
		effect_sprite.offset = Vector2(visual_offset.x * facing_sign, visual_offset.y)
		effect_sprite.scale = Vector2(sprite_scale * facing_sign, sprite_scale)
		effect_sprite.rotation = 0.0 if anim_name in [&"blunt_hit", &"hit_spark", &"crit_hit"] else randf_range(-0.25, 0.25)
		if not effect_sprite.is_inside_tree():
			parent.add_child(effect_sprite)

		effect_sprite.play(anim_name)

		var spr_ref: WeakRef = weakref(effect_sprite)
		var pool_ref: WeakRef = weakref(spark_pool)

		var on_spark_finished: Callable = func():
			var spr: AnimatedSprite2D = spr_ref.get_ref() as AnimatedSprite2D
			var pool: Node = pool_ref.get_ref() as Node
			if spr != null and is_instance_valid(spr):
				if pool != null and is_instance_valid(pool) and pool.has_method("release"):
					pool.call("release", spr)
				else:
					spr.queue_free()

		effect_sprite.animation_finished.connect(on_spark_finished, Object.CONNECT_ONE_SHOT)

		# Timer de segurança dinâmico calculado a partir da velocidade e duração real da animação
		var frame_count: int = vfx_frames.get_frame_count(anim_name)
		var anim_speed: float = vfx_frames.get_animation_speed(anim_name)
		var anim_duration: float = float(frame_count) / maxf(anim_speed, 1.0)
		var safety_duration: float = maxf(anim_duration + 0.15, 0.4)

		var tree: SceneTree = parent.get_tree() if parent.is_inside_tree() else Engine.get_main_loop() as SceneTree
		if tree != null:
			var safety_timer: SceneTreeTimer = tree.create_timer(safety_duration)
			safety_timer.timeout.connect(func():
				if spr_ref == null:
					return
				var spr: AnimatedSprite2D = spr_ref.get_ref() as AnimatedSprite2D
				var pool: Node = pool_ref.get_ref() as Node if pool_ref != null else null
				if spr != null and is_instance_valid(spr) and spr.is_playing():
					if pool != null and is_instance_valid(pool) and pool.has_method("release"):
						pool.call("release", spr)
					else:
						spr.queue_free()
			)

	# 2. Partículas direcionais de alta velocidade via ObjectPool
	var part_pool := ObjectPoolClass.get_or_create(
		scene_root,
		"_Pool_HitParticles",
		null,
		func():
			var p := CPUParticles2D.new()
			p.name = "ImpactSpark"
			p.top_level = true
			p.emitting = false
			p.one_shot = true
			p.lifetime = SPARK_LIFETIME
			p.explosiveness = 0.95
			return p,
		6
	)

	var particles: CPUParticles2D = null
	if part_pool != null and part_pool.has_method("acquire"):
		particles = part_pool.call("acquire") as CPUParticles2D

	if particles == null:
		particles = CPUParticles2D.new()
		particles.name = "ImpactSpark"
		particles.top_level = true
		particles.emitting = false
		particles.one_shot = true
		particles.lifetime = SPARK_LIFETIME
		particles.explosiveness = 0.95
		parent.add_child(particles)

	particles.global_position = pos
	particles.set_meta("impact_region", region)
	particles.set_meta("impact_position", pos)

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

	if not particles.is_inside_tree():
		parent.add_child(particles)

	particles.restart()
	particles.emitting = true

	# Reciclagem limpa no pool após emissão
	var part_ref: WeakRef = weakref(particles)
	var part_pool_ref: WeakRef = weakref(part_pool)
	var part_tree: SceneTree = parent.get_tree() if parent.is_inside_tree() else Engine.get_main_loop() as SceneTree
	if part_tree != null:
		var cleanup_timer: SceneTreeTimer = part_tree.create_timer(SPARK_LIFETIME + 0.1)
		cleanup_timer.timeout.connect(func():
			if part_ref == null:
				return
			var p: CPUParticles2D = part_ref.get_ref() as CPUParticles2D
			var pp: Node = part_pool_ref.get_ref() as Node if part_pool_ref != null else null
			if p != null and is_instance_valid(p):
				p.emitting = false
				if pp != null and is_instance_valid(pp) and pp.has_method("release"):
					pp.call("release", p)
				else:
					p.queue_free()
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
