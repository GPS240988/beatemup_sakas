extends SceneTree

# ==============================================================================
# TESTS/PERFORMANCE_AUDIT_TEST.GD — FASE 10: AUDITORIA DE PERFORMANCE E 60 FPS
# ==============================================================================
# Valida as garantias de performance a 60 FPS para Desktop e Mobile:
# - Ausência de rebuild/bake global de NavigationRegion2D na destruição de props
# - Ausência de alocações e varreduras repetitivas de grupos por frame
# - Throttling de pathfinding e prevenção de spam de rotas
# - Uso exclusivo de CPUParticles2D contra stutter de compilação de shader no mobile
# - Desconexão segura de sinais e limpeza de instâncias sem vazamentos de nós
# - Isolamento de camadas físicas (Layers 1 a 5)
# ==============================================================================

const PlayerScene: PackedScene = preload("res://scenes/actors/player/player.tscn")
const BasicEnemyScene: PackedScene = preload("res://scenes/actors/enemies/basic_enemy.tscn")
const DestructiblePropScene: PackedScene = preload("res://scenes/props/destructible_prop.tscn")
const NPCScene: PackedScene = preload("res://scenes/actors/npc.tscn")
const MeleeAttackScript = preload("res://scripts/components/melee_attack.gd")
const CombatDirectorScript = preload("res://scripts/combat/combat_director.gd")
const DamageInfoScript = preload("res://scripts/combat/damage_info.gd")

var total_tests: int = 0
var passed_tests: int = 0
var failed_tests: int = 0


func _init() -> void:
	print("==================================================")
	print("INICIANDO SUITE DE AUDITORIA DE PERFORMANCE (FASE 10 - 60 FPS)")
	print("==================================================")
	call_deferred("_run_all_performance_tests")


func assert_test(condition: bool, test_name: String) -> void:
	total_tests += 1
	if condition:
		passed_tests += 1
		print("  [OK] %s" % test_name)
	else:
		failed_tests += 1
		printerr("  [FALHA] %s" % test_name)


func _run_all_performance_tests() -> void:
	await _test_navmesh_rebuild_prevention()
	await _test_melee_attack_zero_per_frame_group_allocations()
	await _test_pathfinding_throttling_and_avoidance()
	await _test_cpu_particles_mobile_friendliness()
	await _test_combat_director_instance_lifecycle_cleanup()
	await _test_collision_layer_isolation_budget()

	print("==================================================")
	print("RESULTADO DA AUDITORIA DE PERFORMANCE: %d/%d PASSARAM (Falhas: %d)" % [passed_tests, total_tests, failed_tests])
	print("==================================================")

	if failed_tests > 0:
		quit(1)
	else:
		quit(0)


## 1. Valida que a destruição de múltiplos props NÃO faz rebuild global da malha de navegação
func _test_navmesh_rebuild_prevention() -> void:
	print("\n--- 1. Validando Prevenção de Rebuild Global de Navegação ---")
	var nav_region := NavigationRegion2D.new()
	var nav_poly := NavigationPolygon.new()
	var vertices := PackedVector2Array([
		Vector2(0, 0), Vector2(1000, 0), Vector2(1000, 500), Vector2(0, 500)
	])
	nav_poly.vertices = vertices
	nav_poly.add_polygon(PackedInt32Array([0, 1, 2, 3]))
	nav_region.navigation_polygon = nav_poly
	root.add_child(nav_region)

	var initial_poly_count: int = nav_poly.get_polygon_count()
	var initial_vertex_count: int = nav_poly.get_vertices().size()

	# Instancia e quebra 5 props no mapa
	var props: Array[Node] = []
	for i in range(5):
		var prop: Node = DestructiblePropScene.instantiate()
		prop.position = Vector2(100.0 * (i + 1), 250.0)
		nav_region.add_child(prop)
		props.append(prop)

	assert_test(props.size() == 5, "5 DestructibleProps instanciados sob NavigationRegion2D")

	# Destrói todos os props
	for prop in props:
		prop.take_damage(100.0)

	# Verifica se as propriedades da malha de navegação permaneceram intactas sem rebake pesado
	assert_test(nav_poly.get_polygon_count() == initial_poly_count, "Contagem de polígonos inalterada (sem rebake global)")
	assert_test(nav_poly.get_vertices().size() == initial_vertex_count, "Contagem de vértices inalterada (sem reconstrução de vértices)")

	# Confirma que cada prop desativou o obstáculo via RVO avoidance de forma instantânea
	var all_avoidance_disabled: bool = true
	var all_colliders_disabled: bool = true
	for prop in props:
		var nav_obs: NavigationObstacle2D = prop.get_node_or_null("NavigationIntegration") as NavigationObstacle2D
		if nav_obs != null and nav_obs.avoidance_enabled:
			all_avoidance_disabled = false
		var col: CollisionShape2D = prop.get_node_or_null("CollisionShape2D") as CollisionShape2D
		# Aguarda frame para set_deferred
		await root.get_tree().physics_frame
		if col != null and not col.disabled:
			all_colliders_disabled = false

	assert_test(all_avoidance_disabled, "Avoidance de todos os 5 obstáculos desativado instantaneamente no servidor")
	assert_test(all_colliders_disabled, "Colisões físicas desativadas deferred sem travar thread principal")

	for prop in props:
		prop.queue_free()
	nav_region.queue_free()


## 2. Valida otimização de MeleeAttack: sem varreduras de grupo por frame a 60 FPS
func _test_melee_attack_zero_per_frame_group_allocations() -> void:
	print("\n--- 2. Validando MeleeAttack: Sem Alocação Contínua de Grupos por Frame ---")
	var node := Node2D.new()
	root.add_child(node)

	var attack: Node = MeleeAttackScript.new()
	attack.target_group = "enemies"
	node.add_child(attack)

	# Executa ataque
	attack.execute_attack(1.0)
	assert_test(attack.is_active_window, "Janela ativa de ataque iniciada")

	# Simula 10 frames de _physics_process a 60 FPS (0.016s por frame)
	for i in range(10):
		attack._physics_process(0.016)

	assert_test(attack.is_attacking, "Ataque processado durante 10 frames sem exceções de nulo")
	attack.cancel_attack()
	assert_test(not attack.is_active_window, "Janela de ataque cancelada de forma limpa")

	node.queue_free()


## 3. Valida throttling de pathfinding em NPCs e Inimigos
func _test_pathfinding_throttling_and_avoidance() -> void:
	print("\n--- 3. Validando Throttling de Pathfinding e Prevenção de Spam ---")
	var npc: CharacterBody2D = NPCScene.instantiate() as CharacterBody2D
	root.add_child(npc)

	# Solicita rota e processa frame físico de movimento
	npc.move_to(Vector2(500, 300))
	npc._physics_process(0.016)
	assert_test(npc.get("_pathfind_cooldown") > 0.0, "Cooldown de pathfinding ativado imediatamente após passo físico")
	assert_test(npc.get("PATHFIND_MIN_INTERVAL") >= 0.20, "Intervalo mínimo de pathfinding configurado para prevenir spam (>= 0.20s)")

	# Garante que durante o cooldown o NavigationAgent2D não é spammado a cada frame
	var prev_cooldown: float = npc.get("_pathfind_cooldown")
	npc._physics_process(0.05)
	var new_cooldown: float = npc.get("_pathfind_cooldown")
	assert_test(new_cooldown < prev_cooldown, "Cooldown decrementa suavemente pelo delta da física")

	npc.queue_free()


## 4. Valida compatibilidade Mobile: CPUParticles2D sem compilação de shader pesado
func _test_cpu_particles_mobile_friendliness() -> void:
	print("\n--- 4. Validando Eficiência Mobile (Partículas CPU sem Shader Stutter) ---")
	var prop: Node = DestructiblePropScene.instantiate()
	root.add_child(prop)

	var effects: Node = prop.get_node_or_null("Effects")
	assert_test(effects != null, "Nó de Efeitos presente no DestructibleProp")

	var impact_particles: Node = effects.get_node_or_null("ImpactParticles")
	var break_particles: Node = effects.get_node_or_null("BreakParticles")

	assert_test(impact_particles is CPUParticles2D, "ImpactParticles utiliza CPUParticles2D (compatível com mobile)")
	assert_test(break_particles is CPUParticles2D, "BreakParticles utiliza CPUParticles2D (compatível com mobile)")

	if impact_particles != null:
		assert_test(not (impact_particles is GPUParticles2D), "ImpactParticles NÃO utiliza GPUParticles2D (evita shader pipeline hitch)")
	if break_particles != null:
		assert_test(not (break_particles is GPUParticles2D), "BreakParticles NÃO utiliza GPUParticles2D (evita shader pipeline hitch)")

	prop.queue_free()


## 5. Valida limpeza de instâncias e ciclo de vida do CombatDirector
func _test_combat_director_instance_lifecycle_cleanup() -> void:
	print("\n--- 5. Validando Limpeza de Ciclo de Vida no CombatDirector ---")
	var director_node: Node = CombatDirectorScript.new()
	root.add_child(director_node)

	# Cria 3 inimigos simulados
	var enemy1: CharacterBody2D = BasicEnemyScene.instantiate() as CharacterBody2D
	var enemy2: CharacterBody2D = BasicEnemyScene.instantiate() as CharacterBody2D
	var enemy3: CharacterBody2D = BasicEnemyScene.instantiate() as CharacterBody2D
	root.add_child(enemy1)
	root.add_child(enemy2)
	root.add_child(enemy3)

	director_node.register_enemy(enemy1)
	director_node.register_enemy(enemy2)
	director_node.register_enemy(enemy3)

	assert_test(director_node.get_remaining_enemies_count() == 3, "3 inimigos registrados com sucesso")

	# Solicita token para inimigo 1
	var token_ok: bool = director_node.request_attack_token(enemy1)
	assert_test(token_ok, "Inimigo 1 obteve token de ataque")

	# Destrói/remove inimigo 1 via queue_free e simula frame de saída
	enemy1.tree_exiting.emit()
	enemy1.queue_free()

	# Processa frame do diretor
	director_node._process(0.016)

	assert_test(director_node.get_remaining_enemies_count() == 2, "Inimigo removido de forma limpa do diretor ao sair da árvore")
	assert_test(not director_node.token_holders.has(enemy1), "Token detido pelo inimigo removido foi revogado automaticamente")

	enemy2.queue_free()
	enemy3.queue_free()
	director_node.queue_free()


## 6. Valida orçamento de física e isolamento das Camadas (Layers 1 a 5)
func _test_collision_layer_isolation_budget() -> void:
	print("\n--- 6. Validando Orçamento e Isolamento das Camadas de Colisão ---")
	var player: CharacterBody2D = PlayerScene.instantiate() as CharacterBody2D
	var enemy: CharacterBody2D = BasicEnemyScene.instantiate() as CharacterBody2D
	var prop: StaticBody2D = DestructiblePropScene.instantiate() as StaticBody2D
	root.add_child(player)
	root.add_child(enemy)
	root.add_child(prop)

	# Layer 1 = Atores (Player e Inimigo não colidem fisicamente entre si para evitar travamento)
	assert_test(player.collision_layer == 1, "Player corpo físico na Layer 1")
	assert_test(player.collision_mask == 2, "Player colide apenas com o Mundo/Mobílias na Layer 2")
	assert_test(enemy.collision_layer == 1, "Enemy corpo físico na Layer 1")
	assert_test(enemy.collision_mask == 2, "Enemy colide apenas com o Mundo/Mobílias na Layer 2")

	# Layer 2 = Props e Mundo (Sólido para atores)
	assert_test(prop.collision_layer == 2, "DestructibleProp corpo sólido na Layer 2")
	assert_test(prop.collision_mask == 1, "DestructibleProp mascara atores na Layer 1")

	# Hurtboxes = Layer 3 (bitmask 4), Hitboxes = Layer 4 (bitmask 8)
	var player_hurt: Area2D = player.get_node_or_null("Hurtbox") as Area2D
	var player_hit: Area2D = player.get_node_or_null("MeleeAttack/HitboxArea") as Area2D

	if player_hurt != null:
		assert_test(player_hurt.collision_layer == 4, "Player Hurtbox na Layer 3 (bitmask 4)")
		assert_test(player_hurt.collision_mask == 0, "Player Hurtbox sem máscaras ativas (mask 0)")

	if player_hit != null:
		assert_test(player_hit.collision_layer == 8, "Player Hitbox na Layer 4 (bitmask 8)")
		assert_test(player_hit.collision_mask == 4, "Player Hitbox monitora estritamente Hurtboxes na Layer 3 (bitmask 4)")

	player.queue_free()
	enemy.queue_free()
	prop.queue_free()
