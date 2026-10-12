class_name TestStreet
extends Node2D

@onready var player: PlayerController = $World/Entities/Player
@onready var enemy: EnemyAI = $World/Entities/BasicEnemy
@onready var hud: PrototypeHud = $PrototypeHud


func _ready() -> void:
	if player != null and hud != null:
		player.player_moved.connect(hud.on_player_moved)
		player.state_changed.connect(hud.update_player_state)
		
		if player.health_component != null:
			player.health_component.health_changed.connect(hud.update_player_health)
			player.health_component.died.connect(hud.show_game_over)
			hud.update_player_health(player.health_component.current_health, player.health_component.max_health)

		hud.on_player_moved(player.global_position, Vector2.ZERO)

	if enemy != null and hud != null:
		if enemy.health_component != null:
			enemy.health_component.health_changed.connect(hud.update_enemy_health)
			enemy.enemy_defeated.connect(hud.show_victory)
			hud.update_enemy_health(enemy.health_component.current_health, enemy.health_component.max_health)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("restart"):
		get_tree().reload_current_scene()
