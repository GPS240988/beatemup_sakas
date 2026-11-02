class_name TestStreet
extends BaseLevel

## Nível da Fase 1 - Seção 1 (Test Street).
## Herda de BaseLevel, integrando CombatDirector, indicador "SIGA →",
## e transição sequencial para o Mapa 2.

var enemy: EnemyAI = null


func _get_first_enemy() -> EnemyAI:
	var e = get_node_or_null("World/Actors/Enemies/BasicEnemy") as EnemyAI
	if e == null:
		e = get_node_or_null("World/Actors/BasicEnemy") as EnemyAI
	if e == null:
		e = get_node_or_null("World/Entities/BasicEnemy") as EnemyAI
	if e == null and get_tree() != null:
		var found = get_tree().get_first_node_in_group("enemies")
		if found is EnemyAI:
			e = found as EnemyAI
	return e


func _ready() -> void:
	map_name = "Fase 1 - Seção 1: Entrada da Rua"
	map_index = 1
	next_map_scene_path = "res://scenes/levels/map_2.tscn"
	is_final_map = false

	super._ready()

	enemy = _get_first_enemy()

	# Conecta barra de vida do primeiro inimigo na HUD se existir
	if enemy != null and hud != null and enemy.health_component != null:
		enemy.health_component.health_changed.connect(hud.update_enemy_health)
		hud.update_enemy_health(enemy.health_component.current_health, enemy.health_component.max_health)
		if hud.has_method("set_enemy_target"):
			hud.set_enemy_target(enemy)
