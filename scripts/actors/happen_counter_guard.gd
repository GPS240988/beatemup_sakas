extends "res://scripts/actors/pizza_brawler.gd"

## Pizza Brawler em espera ao lado do colega no balcão.
## Mantém a pose em pé durante a conversa ambiental e NÃO se torna inimigo
## ao se aproximar (só reage se for atacado diretamente).

var _ambient_standby: bool = true


func _ready() -> void:
	super._ready()
	_ambient_standby = true
	current_state = State.WAITING
	velocity = Vector2.ZERO
	set_collision_mask_value(2, false)
	facing_direction = -1.0 if initial_facing < 0.0 else 1.0
	if visual_root != null:
		visual_root.scale.x = absf(visual_root.scale.y) * facing_direction
	_play_anim("idle")
	if anim_sprite != null and anim_sprite.is_playing():
		anim_sprite.stop()
		anim_sprite.frame = 0


func _physics_process(delta: float) -> void:
	if _ambient_standby:
		if wake_on_proximity:
			if player_target == null or not is_instance_valid(player_target):
				_find_player_target()
			if player_target != null and is_instance_valid(player_target):
				if global_position.distance_to(player_target.global_position) <= wake_trigger_radius:
					_leave_ambient_standby()

		if _ambient_standby:
			velocity = Vector2.ZERO
			if anim_sprite != null and anim_sprite.is_playing():
				anim_sprite.stop()
				anim_sprite.frame = 0
			return

	super._physics_process(delta)


func is_in_ambient_standby() -> bool:
	return _ambient_standby


func _leave_ambient_standby() -> void:
	if not _ambient_standby:
		return
	_ambient_standby = false
	_become_hostile_on_attack()
	set_collision_mask_value(2, true)
	current_state = State.FLANKING


func _on_damaged(amount: float) -> void:
	_leave_ambient_standby()
	super._on_damaged(amount)


func _on_damaged_info(info: RefCounted) -> void:
	_leave_ambient_standby()
	super._on_damaged_info(info)
