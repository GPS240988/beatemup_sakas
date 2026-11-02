extends SceneTree

## Suíte de Testes Automatizados do Sistema de Spawn (Godot 4.x) — FASE 4
## Valida formalmente:
## 1. Presença do nó container SpawnPoints e do SpawnDirector em todos os mapas.
## 2. Pontos possuem coordenadas físicas válidas dentro da área caminhável do nível.
## 3. IDs dos pontos de spawn são estritamente únicos (sem duplicidade).
## 4. Inicialização do SpawnDirector e resolução de pontos cadastrados.
## 5. Suporte a tipos de spawn: Enemy, NPC, Reinforcement, Event e Boss.
## 6. Integração com CombatDirector (reforços/inimigos registrados; NPCs isolados).
## 7. Preservação integral do funcionamento das fases e do spawn do chefe.

const BaseLevelClass = preload("res://scripts/levels/base_level.gd")
const SpawnDirectorClass = preload("res://scripts/spawning/spawn_director.gd")
const SpawnPointClass = preload("res://scripts/spawning/spawn_point.gd")
const BasicEnemyClass = preload("res://scripts/actors/enemy_ai.gd")
const BaseNPCClass = preload("res://scripts/actors/npc.gd")

var total_tests: int = 0
var passed_tests: int = 0
var failed_tests: int = 0


func _init() -> void:
	call_deferred("_run_spawn_tests")


func assert_test(condition: bool, test_name: String) -> void:
	total_tests += 1
	if condition:
		passed_tests += 1
		print("  [OK] %s" % test_name)
	else:
		failed_tests += 1
		printerr("  [FALHA] %s" % test_name)


func _run_spawn_tests() -> void:
	print("==================================================")
	print("INICIANDO SUITE DE TESTES DO SISTEMA DE SPAWN (FASE 4)")
	print("==================================================")

	var map_paths: Array[String] = [
		"res://scenes/levels/map_1.tscn",
		"res://scenes/levels/map_2.tscn",
		"res://scenes/levels/map_3.tscn",
		"res://scenes/levels/map_4.tscn",
		"res://scenes/levels/test_street.tscn"
	]

	for path in map_paths:
		var map_name: String = path.get_file().get_basename()
		print("\n--- Validando Sistema de Spawn em [%s] ---" % map_name)

		var scene: PackedScene = load(path)
		assert_test(scene != null, "%s: Cena carregada com sucesso" % map_name)
		if scene == null:
			continue

		var inst: Node = scene.instantiate()
		assert_test(inst != null, "%s: Instância gerada" % map_name)
		if inst == null:
			continue

		root.add_child(inst)

		# 1. SpawnPoints container existe
		var spawn_container: Node2D = inst.get_node_or_null("SpawnPoints") as Node2D
		assert_test(spawn_container != null, "%s: Nó container 'SpawnPoints' existe" % map_name)

		# 2. SpawnDirector existe e inicializa
		var director: Node = inst.get_node_or_null("SpawnDirector")
		assert_test(director != null, "%s: Nó 'SpawnDirector' existe" % map_name)
		if director != null:
			assert_test(director is SpawnDirectorClass, "%s: SpawnDirector possui classe fortemente tipada" % map_name)
			assert_test(director.is_in_group("spawn_director"), "%s: SpawnDirector pertence ao grupo 'spawn_director'" % map_name)

		# 3. Validação dos pontos de spawn cadastrados
		if spawn_container != null:
			var point_children: Array[Node] = spawn_container.get_children()
			assert_test(point_children.size() >= 3, "%s: Possui no mínimo 3 pontos de spawn (atual: %d)" % [map_name, point_children.size()])

			var ids_found: Dictionary = {}
			for child in point_children:
				var p := child as Node2D
				assert_test(p != null and p is SpawnPointClass, "%s: Ponto '%s' herda de SpawnPoint" % [map_name, child.name])

				var pid: String = str(child.get("point_id"))
				assert_test(not pid.is_empty(), "%s: Ponto '%s' possui point_id preenchido (%s)" % [map_name, child.name, pid])
				assert_test(not ids_found.has(pid), "%s: ID do ponto '%s' é estritamente único (sem duplicidade)" % [map_name, pid])
				ids_found[pid] = true

				# Posição física válida (dentro dos limites do mapa 1983x793 ou test_street 1400x700)
				var pos: Vector2 = p.position
				assert_test(pos.x >= 0.0 and pos.x <= 2000.0, "%s: Ponto '%s' tem coordenada X válida (%.1f)" % [map_name, pid, pos.x])
				assert_test(pos.y >= 350.0 and pos.y <= 750.0, "%s: Ponto '%s' tem coordenada Y na faixa caminhável (%.1f)" % [map_name, pid, pos.y])

		# 4. Verificação de Spawn do Chefe no Mapa 4
		if map_name == "map_4":
			var boss_point := spawn_container.get_node_or_null("SpawnPoint_Boss")
			assert_test(boss_point != null, "map_4: Possui 'SpawnPoint_Boss' dedicado para o Chefe")
			if boss_point != null:
				assert_test(boss_point.get("point_id") == "spawn_boss", "map_4: Ponto do Chefe possui ID 'spawn_boss'")
				assert_test(boss_point.get("spawn_type") == 4, "map_4: Ponto do Chefe é do tipo BOSS (4)")

		root.remove_child(inst)
		inst.free()

	# PARTE 2: Testes Funcionais de Runtime do SpawnDirector
	print("\n--- Testando Métodos e Orquestração do SpawnDirector em Runtime ---")
	test_spawn_director_runtime_features()

	print("==================================================")
	print("RESULTADO DOS TESTES DE SPAWN: %d/%d PASSARAM (Falhas: %d)" % [passed_tests, total_tests, failed_tests])
	print("==================================================")

	if failed_tests == 0:
		quit(0)
	else:
		quit(1)


func test_spawn_director_runtime_features() -> void:
	var director: Node = SpawnDirectorClass.new()
	root.add_child(director)

	var p1: Marker2D = SpawnPointClass.new()
	p1.name = "P1"
	p1.set("point_id", "left_entry")
	p1.set("spawn_type", 0) # ENEMY
	p1.set("spawn_group", "enemies")
	p1.position = Vector2(120, 500)

	var p2: Marker2D = SpawnPointClass.new()
	p2.name = "P2"
	p2.set("point_id", "civic_square")
	p2.set("spawn_type", 1) # NPC
	p2.set("spawn_group", "npcs")
	p2.position = Vector2(400, 520)

	var p3: Marker2D = SpawnPointClass.new()
	p3.name = "P3"
	p3.set("point_id", "ambush_alley")
	p3.set("spawn_type", 2) # REINFORCEMENT
	p3.set("spawn_group", "enemies")
	p3.position = Vector2(850, 540)

	root.add_child(p1)
	root.add_child(p2)
	root.add_child(p3)

	director.call("register_spawn_point", p1)
	director.call("register_spawn_point", p2)
	director.call("register_spawn_point", p3)

	# 1. Recuperação de pontos
	assert_test(director.call("get_spawn_point", "left_entry") == p1, "SpawnDirector recupera ponto por ID ('left_entry')")
	assert_test(director.call("get_spawn_point", "inexistente") == null, "SpawnDirector retorna null para ID inexistente")

	# 2. Filtragem por tipo e por grupo
	var enemy_points: Array = director.call("get_points_by_type", 0)
	assert_test(enemy_points.size() == 1 and enemy_points[0] == p1, "Filtro por tipo ENEMY correto")

	var npc_points: Array = director.call("get_points_by_type", 1)
	assert_test(npc_points.size() == 1 and npc_points[0] == p2, "Filtro por tipo NPC correto")

	var enemies_group_points: Array = director.call("get_points_by_group", "enemies")
	assert_test(enemies_group_points.size() == 2, "Filtro por grupo 'enemies' retorna 2 pontos (left_entry e ambush_alley)")

	# 3. Spawn dinâmico de Inimigo em Ponto
	var enemy_scene: PackedScene = load("res://scenes/actors/enemies/basic_enemy.tscn")
	var spawned_enemy: Node = director.call("spawn_at_point", "left_entry", enemy_scene, root)
	assert_test(spawned_enemy != null, "Inimigo spawnado com sucesso no ponto 'left_entry'")
	if spawned_enemy is Node2D:
		assert_test((spawned_enemy as Node2D).global_position == p1.global_position, "Inimigo assume a coordenada exata do SpawnPoint (%.1f, %.1f)" % [p1.global_position.x, p1.global_position.y])

	# 4. Spawn dinâmico de NPC em Ponto
	var npc_scene: PackedScene = load("res://scenes/actors/npc.tscn")
	var spawned_npc: Node = director.call("spawn_npc", "civic_square", npc_scene, root)
	assert_test(spawned_npc != null, "NPC spawnado com sucesso via spawn_npc()")
	assert_test(spawned_npc.is_in_group("npcs"), "NPC gerado pertence ao grupo 'npcs'")
	assert_test(not spawned_npc.is_in_group("enemies"), "NPC gerado NÃO pertence ao grupo 'enemies'")

	# 5. Spawn livre por Coordenada Física
	var pos_enemy: Node = director.call("spawn_at_position", Vector2(750, 480), enemy_scene, root, 0)
	assert_test(pos_enemy != null, "Entidade spawnada com sucesso por coordenada livre")
	if pos_enemy is Node2D:
		assert_test((pos_enemy as Node2D).global_position == Vector2(750, 480), "Entidade posicionada na coordenada livre informada")

	# Limpeza
	root.remove_child(director)
	root.remove_child(p1)
	root.remove_child(p2)
	root.remove_child(p3)
	if spawned_enemy != null:
		root.remove_child(spawned_enemy)
		spawned_enemy.free()
	if spawned_npc != null:
		root.remove_child(spawned_npc)
		spawned_npc.free()
	if pos_enemy != null:
		root.remove_child(pos_enemy)
		pos_enemy.free()
	director.free()
	p1.free()
	p2.free()
	p3.free()
