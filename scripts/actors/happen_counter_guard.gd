extends "res://scripts/actors/pizza_brawler.gd"

## Pizza Brawler em espera ao lado do colega no balcão.
## Mantém a pose em pé durante a conversa ambiental e entra no combate
## somente quando o jogador se aproxima da área de atendimento.

var _ambient_standby: bool = true


func _ready() -> void:
	super._ready()
	_ambient_standby = true
	current_state = State.WAITING
	velocity = Vector2.ZERO
	set_collision_mask_value(2, false)
	_play_anim("idle")


func _physics_process(delta: float) -> void:
	if _ambient_standby:
		if player_target == null or not is_instance_valid(player_target):
			_find_player_target()

		if player_target != null and is_instance_valid(player_target):
			if global_position.distance_to(player_target.global_position) <= wake_trigger_radius:
				_leave_ambient_standby()
			else:
				_update_facing(player_target.global_position.x)

		if _ambient_standby:
			velocity = Vector2.ZERO
			_play_anim("idle")
			return

	super._physics_process(delta)


func is_in_ambient_standby() -> bool:
	return _ambient_standby


func _leave_ambient_standby() -> void:
	if not _ambient_standby:
		return
	_ambient_standby = false
	set_collision_mask_value(2, true)
	current_state = State.FLANKING


func _on_damaged(amount: float) -> void:
	_leave_ambient_standby()
	super._on_damaged(amount)


func _on_damaged_info(info: RefCounted) -> void:
	_leave_ambient_standby()
	super._on_damaged_info(info)
