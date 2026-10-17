class_name BossAlessandro
extends EnemyAI

## Controlador Especial do Chefe Alessandro (Fase 1 - O Gerente da Locadora).
## Utiliza os sprites oficiais em 250x330, inteligência artificial aprimorada com
## alternância entre socos, chutes e combos pesados, e barra de vida de Chefe.

@onready var anim_sprite: AnimatedSprite2D = $Visual/AnimatedSprite2D
@onready var boss_name_label: Label = $Visual/BossNameLabel

var _attack_variant: int = 0
var _anim_locked: bool = false


func _ready() -> void:
	# Configurações de Chefe (atributos superiores aos capangas normais)
	speed_x = 160.0
	speed_y = 110.0
	attack_horizontal_distance = 85.0
	attack_depth_tolerance = 22.0
	attack_cooldown = 0.65
	recoil_distance = 35.0
	recovery_duration = 0.35

	super._ready()

	if health_component != null:
		health_component.max_health = 200.0
		health_component.current_health = 200.0
		if health_bar != null:
			health_bar.max_value = 200.0
			health_bar.value = 200.0

	if melee_attack != null:
		melee_attack.damage = 25.0
		melee_attack.horizontal_range = 95.0
		melee_attack.depth_tolerance = 28.0

	if anim_sprite != null:
		anim_sprite.play("idle")


func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	_update_boss_visuals()


func _update_boss_visuals() -> void:
	if visual_root == null:
		return

	# Orientação horizontal da face
	if facing_direction != 0.0:
		visual_root.scale.x = abs(visual_root.scale.x) * facing_direction

	if anim_sprite == null or _anim_locked:
		return

	match current_state:
		State.IDLE, State.WAITING:
			if anim_sprite.animation != &"idle":
				anim_sprite.play("idle")
		State.FLANKING, State.ALIGNING_DEPTH, State.APPROACHING:
			if anim_sprite.animation != &"walk":
				anim_sprite.play("walk")
		State.TELEGRAPH:
			if anim_sprite.animation != &"idle" and anim_sprite.animation != &"guard":
				anim_sprite.play("idle")


func _trigger_attack() -> void:
	if melee_attack == null:
		return

	current_state = State.ATTACKING

	# Alterna variantes de ataque arcade (Soco -> Chute -> Combo -> Aéreo)
	_attack_variant = (_attack_variant + 1) % 4
	var anim_name: StringName = &"punch"
	match _attack_variant:
		0:
			anim_name = &"punch"
			if melee_attack != null:
				melee_attack.damage = 20.0
		1:
			anim_name = &"kick"
			if melee_attack != null:
				melee_attack.damage = 25.0
		2:
			anim_name = &"combo"
			if melee_attack != null:
				melee_attack.damage = 30.0
		3:
			anim_name = &"jump_atk"
			if melee_attack != null:
				melee_attack.damage = 28.0

	if anim_sprite != null and anim_sprite.sprite_frames.has_animation(anim_name):
		anim_sprite.play(anim_name)

	melee_attack.execute_attack(facing_direction)


func _on_attack_ended() -> void:
	super._on_attack_ended()
	if current_state != State.DEAD and current_state != State.HURT:
		if anim_sprite != null:
			anim_sprite.play("idle")


func _on_damaged(amount: float) -> void:
	super._on_damaged(amount)
	if current_state == State.DEAD:
		return

	if anim_sprite != null and anim_sprite.sprite_frames.has_animation("hurt"):
		anim_sprite.play("hurt")


func _on_died() -> void:
	super._on_died()
	_anim_locked = true

	# Restaura rotação para que a animação nativa de morte (deitado) seja exibida perfeitamente
	if visual_root != null:
		visual_root.rotation_degrees = 0.0
		visual_root.position.y = 0.0

	if anim_sprite != null and anim_sprite.sprite_frames.has_animation("death"):
		anim_sprite.play("death")
		anim_sprite.position = Vector2(0, -50) # Alinha o corpo deitado ao piso
