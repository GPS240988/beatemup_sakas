class_name PlayerBullet
extends Area2D

## Projétil 2.5D disparado pela pistola de Gabriel.
## Respeita a tolerância de profundidade (eixo Y no chão), colide com obstáculos
## na Layer 2 (paredes/cenário) e atinge hurtboxes de inimigos na Layer 3.

const DamageInfoClass = preload("res://scripts/combat/damage_info.gd")
const CombatFeedbackClass = preload("res://scripts/combat/combat_feedback.gd")
const ARCADE_FONT: FontFile = preload("res://assets/fonts/arcade_bold.ttf")

@export var speed: float = 700.0
@export var damage: float = 14.0
@export var max_range: float = 280.0
@export var depth_tolerance: float = 24.0
@export var can_knockdown: bool = false
@export var hitstop_duration: float = 0.033 # 2 frames a 60 FPS
@export var hitstun_duration: float = 0.20
@export var knockback_force: float = 30.0
@export var impact_profile: String = "projectile"

var attacker: Node = null
var projectile_lane_y: float = 0.0
var direction: Vector2 = Vector2.RIGHT

var _distance_traveled: float = 0.0
var _has_hit: bool = false
var _frame_timer: float = 0.0
const FRAME_DURATION: float = 1.0 / 30.0

@onready var sprite: Sprite2D = get_node_or_null("Sprite2D") as Sprite2D


func _ready() -> void:
	add_to_group("projectiles")
	add_to_group("player_projectiles")
	
	collision_layer = 8 # Hitbox
	collision_mask = 6  # Layer 2 (world bodies) + Layer 3 / bit 4 (hurtboxes)
	monitoring = true
	monitorable = false
	
	area_entered.connect(_on_area_entered)
	body_entered.connect(_on_body_entered)
	
	if direction.x < 0.0:
		scale.x = -1.0


func _process(delta: float) -> void:
	if sprite != null and sprite.hframes * sprite.vframes > 1:
		_frame_timer += delta
		if _frame_timer >= FRAME_DURATION:
			_frame_timer -= FRAME_DURATION
			sprite.frame = (sprite.frame + 1) % (sprite.hframes * sprite.vframes)


func _physics_process(delta: float) -> void:
	if _has_hit:
		return
	
	var step_dist: float = speed * delta
	global_position += direction * step_dist
	_distance_traveled += step_dist
	
	if _distance_traveled >= max_range:
		queue_free()


func _on_body_entered(body: Node) -> void:
	if _has_hit or body == null:
		return
	
	# Ignora o atacante e outros atores/personagens amigáveis para não colidir como obstáculo de cenário
	if body == attacker or body.is_in_group("player") or body.is_in_group("npcs") or body.is_in_group("civilians") or body.is_in_group("allies") or body.is_in_group("actors"):
		return
	
	# Obstáculo sólido do cenário atingido (Layer 2)
	_has_hit = true
	CombatFeedbackClass.spawn_hit_spark(self, global_position, direction, "projectile", "upper_torso")
	CombatFeedbackClass.play_impact_sound(self, "light")
	queue_free()


func _on_area_entered(area: Area2D) -> void:
	if _has_hit or area == null or not is_instance_valid(area):
		return
	_try_hit(area)


func _try_hit(collider: Node) -> bool:
	if _has_hit or collider == null or not is_instance_valid(collider):
		return false
	
	var target_actor: Node = _find_target_actor(collider)
	if target_actor == null or target_actor == attacker:
		return false
	
	# Exclusões explícitas por segurança (jogador, NPCs e civis jamais sofrem dano de projétil)
	if target_actor.is_in_group("player") or target_actor.is_in_group("npcs") or target_actor.is_in_group("civilians") or target_actor.is_in_group("allies"):
		return false
	
	# Se for inimigo, valida se está vivo
	if target_actor.is_in_group("enemies"):
		var health_comp: Node = target_actor.get_node_or_null("HealthComponent")
		if health_comp != null and "is_dead" in health_comp and health_comp.is_dead:
			return false
		if "is_dead" in target_actor and target_actor.is_dead:
			return false
	
	# Se for prop destrutível, valida se não foi destruído
	if target_actor.is_in_group("destructibles") or target_actor.is_in_group("destructible_props"):
		if "is_broken" in target_actor and target_actor.is_broken:
			return false
	
	# Regra de profundidade 2.5D: compara a posição Y dos pés no chão do alvo com a linha de tiro
	var target_pos: Vector2 = target_actor.global_position if target_actor is Node2D else global_position
	var depth_diff: float = absf(target_pos.y - projectile_lane_y)
	if depth_diff > depth_tolerance:
		return false
	
	# Evasão aérea: se o alvo estiver no ar (salto), o tiro passa por baixo
	if _is_actor_jumping(target_actor):
		_show_miss_feedback(target_actor)
		_has_hit = true
		queue_free()
		return false
	
	# Projétil atinge alvo único — consome o tiro imediatamente
	_has_hit = true
	
	var damage_info := DamageInfoClass.new(
		damage,
		attacker,
		attacker.global_position if attacker != null else global_position,
		direction,
		"projectile",
		knockback_force,
		hitstun_duration,
		true, # can_hit_props
		can_knockdown,
		hitstop_duration,
		impact_profile,
		"upper_torso",
		global_position
	)
	
	var applied: bool = false
	if target_actor.has_method("take_damage"):
		applied = bool(target_actor.take_damage(damage_info))
	else:
		var health: Node = target_actor.get_node_or_null("HealthComponent")
		if health != null and health.has_method("take_damage"):
			applied = bool(health.take_damage(damage_info))
	
	if applied:
		CombatFeedbackClass.apply_hitstop(attacker, target_actor, hitstop_duration)
		var vfx_prof: String = "projectile" if impact_profile in ["punch", "projectile"] else impact_profile
		CombatFeedbackClass.spawn_hit_spark(self, global_position, direction, vfx_prof, "upper_torso")
		CombatFeedbackClass.play_impact_sound(self, impact_profile)
		if can_knockdown or impact_profile == "finisher":
			CombatFeedbackClass.trigger_screen_shake(self, 6.0, 0.22)
		if attacker != null:
			if attacker.has_method("_on_projectile_hit"):
				attacker.call("_on_projectile_hit", target_actor, damage)
			elif attacker.has_method("_on_hit_connected"):
				attacker.call("_on_hit_connected")
	
	queue_free()
	return applied


## Método público para testes pontuais e validações diretas
func test_hit_candidate(candidate: Node) -> bool:
	return _try_hit(candidate)


func _find_target_actor(start_node: Node) -> Node:
	var candidate: Node = start_node
	while candidate != null:
		# Exclusões prioritárias estritas: player, npcs, civis e aliados
		if candidate.is_in_group("player") or candidate.is_in_group("npcs") or candidate.is_in_group("civilians") or candidate.is_in_group("allies"):
			return null

		# Inimigos válidos
		if candidate.is_in_group("enemies"):
			return candidate

		# Objetos destrutíveis aprovados conforme o Damage Contract
		if candidate.is_in_group("destructibles") or candidate.is_in_group("destructible_props"):
			return candidate

		candidate = candidate.get_parent()
	return null


func _is_actor_jumping(actor: Node) -> bool:
	if actor.get("_is_jumping") == true:
		return true
	var visual: Node2D = actor.get_node_or_null("Visual") as Node2D
	return visual != null and visual.position.y <= -12.0


func _show_miss_feedback(target_actor: Node) -> void:
	var actor_2d: Node2D = target_actor as Node2D
	if actor_2d == null:
		return
	
	var feedback_parent: Node = actor_2d.get_parent()
	if feedback_parent == null:
		feedback_parent = get_tree().current_scene
	if feedback_parent == null:
		return
	
	var feedback := Node2D.new()
	feedback.name = "BulletMissFeedback"
	feedback.top_level = true
	feedback.z_index = 220
	feedback.z_as_relative = false
	feedback.process_mode = Node.PROCESS_MODE_ALWAYS
	feedback_parent.add_child(feedback)
	
	var visual_offset_y: float = 0.0
	var target_visual: Node2D = actor_2d.get_node_or_null("Visual") as Node2D
	if target_visual != null:
		visual_offset_y = target_visual.position.y
	feedback.global_position = actor_2d.global_position + Vector2(0.0, visual_offset_y - 205.0)
	
	var label := Label.new()
	label.name = "Text"
	label.text = "MISS"
	label.position = Vector2(-70.0, -22.0)
	label.size = Vector2(140.0, 44.0)
	label.add_theme_font_override("font", ARCADE_FONT)
	label.add_theme_font_size_override("font_size", 24)
	label.add_theme_color_override("font_color", Color(1.0, 0.92, 0.28, 1.0))
	label.add_theme_color_override("font_outline_color", Color(0.02, 0.02, 0.02, 1.0))
	label.add_theme_constant_override("outline_size", 6)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	feedback.add_child(label)
	
	var tween: Tween = feedback.create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.set_parallel(true)
	tween.tween_property(feedback, "position:y", feedback.position.y - 48.0, 0.62).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(feedback, "modulate:a", 0.0, 0.62).set_delay(0.14)
	tween.chain().tween_callback(feedback.queue_free)
