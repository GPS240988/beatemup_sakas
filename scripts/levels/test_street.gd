class_name TestStreet
extends BaseLevel

## Nível da Fase 1 - Seção 1 (Test Street).
## Herda de BaseLevel, integrando CombatDirector, indicador "SIGA →",
## e transição sequencial para o Mapa 2.

@onready var enemy: EnemyAI = get_node_or_null("World/Entities/BasicEnemy") as EnemyAI


func _ready() -> void:
	map_name = "Fase 1 - Seção 1: Entrada da Rua"
	map_index = 1
	next_map_scene_path = "res://scenes/levels/map_2.tscn"
	is_final_map = false

	super._ready()

	# Conecta barra de vida do primeiro inimigo na HUD se existir
	if enemy != null and hud != null and enemy.health_component != null:
		enemy.health_component.health_changed.connect(hud.update_enemy_health)
		hud.update_enemy_health(enemy.health_component.current_health, enemy.health_component.max_health)
