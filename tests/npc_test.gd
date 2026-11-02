extends SceneTree

## Suíte de Testes do Sistema de NPCs Móveis e FSM (Godot 4.x) — FASE 7
## Valida formalmente:
## 1. NPC aparece e instanciação completa com nós obrigatórios.
## 2. Locomoção do NPC (MOVE_TO, WANDER, FLEE, velocidade e direção).
## 3. Isolamento: NPC não é registrado como enemy.
## 4. Não interferência no combate e contabilidade do CombatDirector.
## 5. Respeito a colisões físicas de mundo (Layer 1 e Mask 2).
## 6. Segurança da câmera (NPC não possui nem sequestra a câmera).
## 7. Prevenção de spam de pathfinding (throttling de 0.25s).
## 8. Ciclo de vida da FSM (IDLE, WANDER, MOVE_TO, WAIT, FLEE, EVENT, DISABLED).

const BaseNPCClass = preload("res://scripts/actors/npc.gd")
const CombatDirectorClass = preload("res://scripts/combat/combat_director.gd")
const HealthComponentClass = preload("res://scripts/components/health_component.gd")

var total_tests: int = 0
var passed_tests: int = 0
var failed_tests: int = 0


func _init() -> void:
	call_deferred("_run_npc_tests")


func assert_test(condition: bool, test_name: String) -> void:
	total_tests += 1
	if condition:
		passed_tests += 1
		print("  [OK] %s" % test_name)
	else:
		failed_tests += 1
		printerr("  [FALHA] %s" % test_name)


func _run_npc_tests() -> void:
	print("==================================================")
	print("INICIANDO SUITE DE TESTES: NPCS MÓVEIS (FASE 7)")
	print("==================================================")

	var npc_scene: PackedScene = load("res://scenes/actors/npc.tscn")
	assert_test(npc_scene != null, "Cena npc.tscn carregada com sucesso")
	if npc_scene == null:
		_finish()
		return

	# PARTE 1: NPC aparece e nós obrigatórios
	print("\n--- 1. Validando Estrutura e Instanciação do NPC ---")
	var npc_inst: Node = npc_scene.instantiate()
	assert_test(npc_inst != null, "Instância de NPC criada com sucesso")
	assert_test(npc_inst is CharacterBody2D, "NPC herda de CharacterBody2D")
	assert_test(npc_inst.is_in_group("actors"), "NPC pertence ao grupo 'actors'")
	assert_test(npc_inst.is_in_group("npcs"), "NPC pertence ao grupo 'npcs'")
	assert_test(npc_inst.is_in_group("damageable"), "NPC pertence ao grupo 'damageable'")
	assert_test(not npc_inst.is_in_group("enemies"), "NPC NÃO pertence ao grupo 'enemies'")
	assert_test(not npc_inst.is_in_group("player"), "NPC NÃO pertence ao grupo 'player'")

	var visual: Node2D = npc_inst.get_node_or_null("Visual") as Node2D
	var collision_shape: CollisionShape2D = npc_inst.get_node_or_null("CollisionShape2D") as CollisionShape2D
	var hurtbox: Area2D = npc_inst.get_node_or_null("Hurtbox") as Area2D
	var health_comp: Node = npc_inst.get_node_or_null("HealthComponent")
	var nav_agent: NavigationAgent2D = npc_inst.get_node_or_null("NavigationAgent2D") as NavigationAgent2D

	assert_test(visual != null, "Nó Visual presente")
	assert_test(collision_shape != null, "Nó CollisionShape2D presente")
	assert_test(hurtbox != null, "Nó Hurtbox presente")
	assert_test(health_comp != null, "Nó HealthComponent presente")
	assert_test(nav_agent != null, "Nó NavigationAgent2D presente")

	root.add_child(npc_inst)
	await process_frame

	var base_npc: Node = npc_inst
	assert_test(base_npc.get_current_state() == BaseNPCClass.NPCState.IDLE, "Estado inicial é IDLE")
	assert_test(not base_npc.is_moving(), "NPC inicia parado (velocity zero)")

	# PARTE 2: Locomoção e movimentação (MOVE_TO)
	print("\n--- 2. Validando Locomoção e Navegação ---")
	(base_npc as Node2D).global_position = Vector2(100, 100)
	var target_pos := Vector2(250, 100)
	var tracker := {"reached": false}
	base_npc.destination_reached.connect(func() -> void: tracker["reached"] = true)

	base_npc.move_to(target_pos)
	assert_test(base_npc.get_current_state() == BaseNPCClass.NPCState.MOVE_TO, "Estado transicionou para MOVE_TO")

	# Simula steps de física
	for i in range(15):
		base_npc._physics_process(0.1)

	assert_test(base_npc.is_moving(), "NPC adquire velocidade de deslocamento")
	assert_test((base_npc as Node2D).global_position.x > 100.0, "NPC deslocou-se na direção do alvo X")
	assert_test(base_npc.facing_direction == 1.0, "NPC virou para a direita (facing_direction == 1.0)")

	# Teleporta próximo para validar chegada
	(base_npc as Node2D).global_position = target_pos - Vector2(4, 0)
	base_npc._physics_process(0.05)
	assert_test(tracker["reached"], "Sinal destination_reached emitido ao alcançar o alvo")
	assert_test(base_npc.get_current_state() == BaseNPCClass.NPCState.IDLE, "Retorna para IDLE após alcançar destino")

	# PARTE 3: Isolamento contra o CombatDirector
	print("\n--- 3. Validando Isolamento contra CombatDirector ---")
	var director: Node = CombatDirectorClass.new()
	root.add_child(director)
	await process_frame

	director.register_enemy(base_npc)
	assert_test(not director.alive_enemies.has(base_npc), "CombatDirector rejeitou registro do NPC como enemy")
	assert_test(not director.registered_enemies.has(base_npc), "NPC NÃO está na lista registered_enemies")

	# PARTE 4: Não interferência na vitória do combate
	print("\n--- 4. Validando Não-Interferência no Combate ---")
	var enemy_dummy := CharacterBody2D.new()
	enemy_dummy.add_to_group("actors")
	enemy_dummy.add_to_group("enemies")
	var enemy_hc: Node = HealthComponentClass.new()
	enemy_dummy.add_child(enemy_hc)
	root.add_child(enemy_dummy)
	await process_frame

	director.register_enemy(enemy_dummy)
	assert_test(director.alive_enemies.size() == 1, "Apenas o inimigo genuíno foi registrado")

	# Derrota o inimigo
	enemy_hc.take_damage(100.0)
	director.notify_enemy_defeated(enemy_dummy)
	assert_test(director.is_cleared, "Encontro declarado concluído com sucesso mesmo com NPC ativo")

	root.remove_child(enemy_dummy)
	enemy_dummy.free()
	root.remove_child(director)
	director.free()

	# PARTE 5: Respeito a Colisões de Mundo
	print("\n--- 5. Validando Respeito a Colisões Físicas ---")
	var cb_npc: CharacterBody2D = base_npc as CharacterBody2D
	assert_test(cb_npc.collision_layer == 1, "NPC colide na Layer 1 (Atores)")
	assert_test(cb_npc.collision_mask == 2, "NPC detecta barreiras na Layer 2 (Mundo Físico / Mobílias)")

	# PARTE 6: Segurança de Câmera
	print("\n--- 6. Validando Ausência de Interferência na Câmera ---")
	var cam: Camera2D = base_npc.get_node_or_null("Camera2D") as Camera2D
	assert_test(cam == null, "NPC não possui Camera2D interna (câmera do player protegida)")

	# PARTE 7: Prevenção de Spam de Pathfinding
	print("\n--- 7. Validando Prevenção de Spam de Pathfinding ---")
	base_npc.move_to(Vector2(500, 500))
	base_npc._physics_process(0.016)
	var cooldown_active: bool = base_npc._pathfind_cooldown > 0.0
	assert_test(cooldown_active, "Throttling de pathfinding ativado após solicitação de rota")
	assert_test(base_npc._pathfind_cooldown <= BaseNPCClass.PATHFIND_MIN_INTERVAL, "Cooldown respeita o limite mínimo de 0.25s")

	# PARTE 8: Máquina de Estados Completa (FSM)
	print("\n--- 8. Validando Estados da FSM (WANDER, WAIT, FLEE, EVENT, DISABLED) ---")
	# WANDER
	base_npc.wander()
	assert_test(base_npc.get_current_state() == BaseNPCClass.NPCState.WANDER, "Transição para WANDER bem-sucedida")

	# WAIT
	base_npc.wait(1.5)
	assert_test(base_npc.get_current_state() == BaseNPCClass.NPCState.WAIT, "Transição para WAIT bem-sucedida")
	assert_test(base_npc._state_timer == 1.5, "Timer de espera configurado em 1.5s")

	# FLEE
	base_npc.flee_from(Vector2(100, 100))
	assert_test(base_npc.get_current_state() == BaseNPCClass.NPCState.FLEE, "Transição para FLEE bem-sucedida")
	assert_test(base_npc.is_fleeing, "Flag is_fleeing ativada")

	# EVENT
	base_npc.enter_event()
	assert_test(base_npc.get_current_state() == BaseNPCClass.NPCState.EVENT, "Transição para EVENT bem-sucedida")
	assert_test(not base_npc.is_moving(), "NPC para movimentação autônoma no modo EVENT")

	# DISABLED
	base_npc.disable_npc()
	assert_test(base_npc.get_current_state() == BaseNPCClass.NPCState.DISABLED, "Transição para DISABLED bem-sucedida")

	# Re-enable
	base_npc.enable_npc()
	assert_test(base_npc.get_current_state() == BaseNPCClass.NPCState.IDLE, "Reativação retorna para IDLE")

	root.remove_child(npc_inst)
	npc_inst.free()

	_finish()


func _finish() -> void:
	print("==================================================")
	print("RESULTADO DOS TESTES DE NPCS MÓVEIS (FASE 7): %d/%d PASSARAM (Falhas: %d)" % [passed_tests, total_tests, failed_tests])
	print("==================================================")

	if failed_tests == 0:
		quit(0)
	else:
		quit(1)
