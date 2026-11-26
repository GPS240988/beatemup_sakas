class_name PizzaBrawler
extends EnemyAI

## Inimigo Pizza Brawler (Fase 2-3 / Map 7 — HAPPEN).
## Suporta rotina inicial sentado na cadeira (sit_idle -> getup -> EnemyAI) ou
## de costas no balcão pegando comida (counter_eat -> alerta -> EnemyAI),
## com efeito de gordura/suor na pele e suporte completo a paletas e arquétipos.

enum IdleRoutine {
	NONE,
	SITTING,
	COUNTER_EATING
}

enum BrawlerPhase {
	SITTING,
	COUNTER_EATING,
	GETTING_UP,
	COMBAT
}

@export var initial_routine: IdleRoutine = IdleRoutine.SITTING
@export var start_sitting: bool = true
@export var wake_on_proximity: bool = true
@export var peaceful_until_attacked: bool = false
@export var wake_trigger_radius: float = 200.0
@export var initial_facing: float = -1.0
@export var getup_fallback_duration: float = 0.68
@export var counter_turn_duration: float = 0.24
@export var step_out_offset: Vector2 = Vector2.ZERO
@export_range(0.0, 0.5, 0.01) var skin_oil_sheen: float = 0.26

@onready var wake_trigger: Area2D = get_node_or_null("WakeTrigger") as Area2D

var _brawler_phase: BrawlerPhase = BrawlerPhase.COMBAT
var _getup_timer: float = 0.0
var _waking_from_counter: bool = false
var _grease_drip: CPUParticles2D = null
var _grease_burst: CPUParticles2D = null

const BANHA_HURT_SFX: String = "res://assets/audio/sfx/banha_gorducho.mp3"

static var _grease_pixel_tex: Texture2D = null


func _ready() -> void:
	if display_name == "JOGADOR DE MAGIC" or display_name.is_empty():
		display_name = "PIZZA BRAWLER"

	# Preserva archetype e palette_variant configurados por instância na cena (não sobrescrever!)
	super._ready()
	_apply_skin_oil_shader()
	_setup_grease_particles()

	if anim_sprite != null and not anim_sprite.animation_finished.is_connected(_on_brawler_animation_finished):
		anim_sprite.animation_finished.connect(_on_brawler_animation_finished)

	if wake_trigger != null:
		var wake_shape := wake_trigger.get_node_or_null("CollisionShape2D") as CollisionShape2D
		if wake_shape != null and wake_shape.shape is CircleShape2D:
			var dup_shape := (wake_shape.shape as CircleShape2D).duplicate() as CircleShape2D
			dup_shape.radius = wake_trigger_radius
			wake_shape.shape = dup_shape
		if not wake_trigger.body_entered.is_connected(_on_wake_trigger_body_entered):
			wake_trigger.body_entered.connect(_on_wake_trigger_body_entered)

	var effective_routine: IdleRoutine = initial_routine
	if not start_sitting and effective_routine == IdleRoutine.SITTING:
		effective_routine = IdleRoutine.NONE

	match effective_routine:
		IdleRoutine.SITTING:
			_enter_sitting_phase()
		IdleRoutine.COUNTER_EATING:
			_enter_counter_eating_phase()
		_:
			_brawler_phase = BrawlerPhase.COMBAT
			set_collision_mask_value(2, true)

	if peaceful_until_attacked:
		remove_from_group("enemies")
		if combat_director != null and is_instance_valid(combat_director) and combat_director.has_method("unregister_enemy"):
			combat_director.call("unregister_enemy", self)
		if effective_routine != IdleRoutine.SITTING and effective_routine != IdleRoutine.COUNTER_EATING:
			current_state = State.WAITING
			facing_direction = -1.0 if initial_facing < 0.0 else 1.0
			if visual_root != null:
				visual_root.scale.x = absf(visual_root.scale.y) * facing_direction
			_play_anim("idle")
			if anim_sprite != null and anim_sprite.is_playing():
				anim_sprite.stop()
				anim_sprite.frame = 0


func is_sitting() -> bool:
	return _brawler_phase == BrawlerPhase.SITTING


func is_counter_eating() -> bool:
	return _brawler_phase == BrawlerPhase.COUNTER_EATING


func is_getting_up() -> bool:
	return _brawler_phase == BrawlerPhase.GETTING_UP


func is_in_combat() -> bool:
	return _brawler_phase == BrawlerPhase.COMBAT


func _enter_sitting_phase() -> void:
	_brawler_phase = BrawlerPhase.SITTING
	current_state = State.WAITING
	velocity = Vector2.ZERO
	# Relaxa colisão contra mobília enquanto sentado para não ser empurrado para fora da cadeira
	set_collision_mask_value(2, false)
	facing_direction = -1.0 if initial_facing < 0.0 else 1.0
	if visual_root != null:
		visual_root.scale.x = absf(visual_root.scale.y) * facing_direction
	_play_anim("sit_idle")


func _enter_counter_eating_phase() -> void:
	_brawler_phase = BrawlerPhase.COUNTER_EATING
	current_state = State.WAITING
	velocity = Vector2.ZERO
	set_collision_mask_value(2, false)
	facing_direction = -1.0 if initial_facing < 0.0 else 1.0
	if visual_root != null:
		visual_root.scale.x = absf(visual_root.scale.y) * facing_direction
	_play_anim("counter_eat")


func trigger_wake_up() -> void:
	if _brawler_phase != BrawlerPhase.SITTING and _brawler_phase != BrawlerPhase.COUNTER_EATING:
		return
	if current_state == State.DEAD:
		return

	var was_counter: bool = (_brawler_phase == BrawlerPhase.COUNTER_EATING)
	_waking_from_counter = was_counter
	_brawler_phase = BrawlerPhase.GETTING_UP
	velocity = Vector2.ZERO
	emit_grease_burst(10)

	if was_counter:
		_getup_timer = counter_turn_duration
		if player_target != null and is_instance_valid(player_target):
			_update_facing(player_target.global_position.x)
		CombatFeedback.spawn_floating_text(self, global_position + Vector2(0.0, -195.0), "!", Color(1.0, 0.84, 0.24, 1.0))
		_play_anim("guard")
		return

	_getup_timer = getup_fallback_duration
	if anim_sprite != null and anim_sprite.sprite_frames != null and anim_sprite.sprite_frames.has_animation("getup"):
		anim_sprite.play("getup")
	else:
		_finish_wake_up()


func _finish_wake_up() -> void:
	if _brawler_phase != BrawlerPhase.GETTING_UP:
		return
	_brawler_phase = BrawlerPhase.COMBAT
	_waking_from_counter = false
	if step_out_offset != Vector2.ZERO:
		global_position += step_out_offset
	set_collision_mask_value(2, true)
	if current_state != State.DEAD:
		current_state = State.FLANKING
		_play_anim("idle")


func _physics_process(delta: float) -> void:
	if not peaceful_until_attacked and (combat_director == null or not is_instance_valid(combat_director)):
		_find_combat_director()

	if current_state == State.DEAD:
		if _grease_drip != null:
			_grease_drip.emitting = false
		super._physics_process(delta)
		return

	if _brawler_phase == BrawlerPhase.SITTING or _brawler_phase == BrawlerPhase.COUNTER_EATING:
		velocity = Vector2.ZERO
		_play_anim("sit_idle" if _brawler_phase == BrawlerPhase.SITTING else "counter_eat")
		if wake_on_proximity:
			if player_target == null or not is_instance_valid(player_target):
				_find_player_target()
			if player_target != null and is_instance_valid(player_target):
				if global_position.distance_to(player_target.global_position) <= wake_trigger_radius:
					trigger_wake_up()
		return

	if _brawler_phase == BrawlerPhase.GETTING_UP:
		velocity = Vector2.ZERO
		_getup_timer -= delta
		if _getup_timer <= 0.0:
			_finish_wake_up()
		return

	if peaceful_until_attacked:
		velocity = Vector2.ZERO
		current_state = State.WAITING
		if anim_sprite != null and anim_sprite.is_playing():
			anim_sprite.stop()
			anim_sprite.frame = 0
		return

	super._physics_process(delta)


func _on_wake_trigger_body_entered(body: Node2D) -> void:
	if not wake_on_proximity:
		return
	if _brawler_phase != BrawlerPhase.SITTING and _brawler_phase != BrawlerPhase.COUNTER_EATING:
		return
	if body != null and body.is_in_group("player"):
		trigger_wake_up()


func _on_brawler_animation_finished() -> void:
	if _brawler_phase == BrawlerPhase.GETTING_UP and not _waking_from_counter and anim_sprite != null and anim_sprite.animation == &"getup":
		_finish_wake_up()


func _trigger_attack() -> void:
	emit_grease_burst(8)
	super._trigger_attack()


func _become_hostile_on_attack() -> void:
	if not is_in_group("enemies"):
		add_to_group("enemies")
	if combat_director != null and is_instance_valid(combat_director):
		combat_director.register_enemy(self)


func _play_banha_hurt_sound() -> void:
	CombatFeedback.play_sound(self, BANHA_HURT_SFX, 1.5, 0.08)


func _on_damaged(amount: float) -> void:
	_become_hostile_on_attack()
	if _brawler_phase != BrawlerPhase.COMBAT:
		_brawler_phase = BrawlerPhase.COMBAT
		_waking_from_counter = false
		if step_out_offset != Vector2.ZERO:
			global_position += step_out_offset
		set_collision_mask_value(2, true)
	emit_grease_burst(12)
	_play_banha_hurt_sound()
	super._on_damaged(amount)


func _on_damaged_info(info: RefCounted) -> void:
	_become_hostile_on_attack()
	if _brawler_phase != BrawlerPhase.COMBAT:
		_brawler_phase = BrawlerPhase.COMBAT
		_waking_from_counter = false
		if step_out_offset != Vector2.ZERO:
			global_position += step_out_offset
		set_collision_mask_value(2, true)
	emit_grease_burst(12)
	_play_banha_hurt_sound()
	super._on_damaged_info(info)


func _on_died() -> void:
	if not peaceful_until_attacked and (combat_director == null or not is_instance_valid(combat_director)):
		_find_combat_director()
	if _grease_drip != null:
		_grease_drip.emitting = false
	super._on_died()


func _apply_skin_oil_shader() -> void:
	if anim_sprite == null or anim_sprite.material == null:
		return
	var mat := anim_sprite.material as ShaderMaterial
	if mat == null:
		return
	mat.set_shader_parameter("oil_sheen_strength", skin_oil_sheen)
	mat.set_shader_parameter("skin_source_hue", 24.0)
	mat.set_shader_parameter("skin_hue_tolerance", 12.0)


func _get_grease_pixel_texture() -> Texture2D:
	if _grease_pixel_tex == null:
		var img := Image.create(3, 3, false, Image.FORMAT_RGBA8)
		img.fill(Color(0, 0, 0, 0))
		# Pequeno cluster pixel-art de gota oleosa (núcleo claro + borda âmbar)
		img.set_pixel(1, 0, Color(1.0, 0.92, 0.58, 1.0))
		img.set_pixel(0, 1, Color(0.95, 0.72, 0.25, 0.95))
		img.set_pixel(1, 1, Color(1.0, 0.96, 0.78, 1.0))
		img.set_pixel(2, 1, Color(0.95, 0.72, 0.25, 0.95))
		img.set_pixel(1, 2, Color(0.88, 0.58, 0.18, 0.90))
		_grease_pixel_tex = ImageTexture.create_from_image(img)
	return _grease_pixel_tex


func _create_grease_ramp() -> Gradient:
	var grad := Gradient.new()
	grad.set_color(0, Color(1.0, 0.95, 0.72, 0.92))
	grad.set_color(1, Color(0.88, 0.55, 0.14, 0.0))
	return grad


func _setup_grease_particles() -> void:
	if visual_root == null:
		return
	var tex: Texture2D = _get_grease_pixel_texture()
	var ramp: Gradient = _create_grease_ramp()

	if visual_root.get_node_or_null("GreaseParticles") == null:
		_grease_drip = CPUParticles2D.new()
		_grease_drip.name = "GreaseParticles"
		_grease_drip.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		_grease_drip.texture = tex
		_grease_drip.position = Vector2(0.0, -96.0)
		_grease_drip.amount = 10
		_grease_drip.lifetime = 0.75
		_grease_drip.randomness = 0.35
		_grease_drip.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
		_grease_drip.emission_rect_extents = Vector2(36.0, 44.0)
		_grease_drip.direction = Vector2(0.0, 1.0)
		_grease_drip.spread = 22.0
		_grease_drip.gravity = Vector2(0.0, 145.0)
		_grease_drip.initial_velocity_min = 6.0
		_grease_drip.initial_velocity_max = 22.0
		_grease_drip.scale_amount_min = 0.9
		_grease_drip.scale_amount_max = 1.35
		_grease_drip.color_ramp = ramp
		_grease_drip.emitting = true
		visual_root.add_child(_grease_drip)
	else:
		_grease_drip = visual_root.get_node_or_null("GreaseParticles") as CPUParticles2D

	if visual_root.get_node_or_null("GreaseBurstParticles") == null:
		_grease_burst = CPUParticles2D.new()
		_grease_burst.name = "GreaseBurstParticles"
		_grease_burst.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		_grease_burst.texture = tex
		_grease_burst.position = Vector2(0.0, -96.0)
		_grease_burst.amount = 12
		_grease_burst.lifetime = 0.48
		_grease_burst.one_shot = true
		_grease_burst.explosiveness = 0.92
		_grease_burst.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
		_grease_burst.emission_rect_extents = Vector2(32.0, 38.0)
		_grease_burst.direction = Vector2(0.0, -0.5)
		_grease_burst.spread = 160.0
		_grease_burst.gravity = Vector2(0.0, 360.0)
		_grease_burst.initial_velocity_min = 45.0
		_grease_burst.initial_velocity_max = 115.0
		_grease_burst.scale_amount_min = 1.0
		_grease_burst.scale_amount_max = 1.6
		_grease_burst.color_ramp = ramp
		_grease_burst.emitting = false
		visual_root.add_child(_grease_burst)
	else:
		_grease_burst = visual_root.get_node_or_null("GreaseBurstParticles") as CPUParticles2D


func emit_grease_burst(burst_amount: int = 10) -> void:
	if _grease_burst == null or not is_instance_valid(_grease_burst):
		return
	if current_state == State.DEAD:
		return
	_grease_burst.amount = clampi(burst_amount, 4, 20)
	_grease_burst.restart()
	_grease_burst.emitting = true
