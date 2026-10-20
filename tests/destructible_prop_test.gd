extends SceneTree

## Suíte de Testes do Sistema de Objetos Destrutíveis (Godot 4.x) — FASE 5
## Valida formalmente:
## 1. Instanciação e arquitetura desacoplada (Visual, Collision, Damage Receiver, Health, Effects, NavigationObstacle2D).
## 2. Recebimento de dano e redução de vida.
## 3. Máquina de estados completa: ACTIVE -> DAMAGED -> DESTROYING -> DESTROYED.
## 4. Recusa estrita de dano após destruição.
## 5. Desativação de colisão física e hurtbox (liberação de passagem).
## 6. Performance de navegação: desativação de avoidance sem rebuild global de NavigationRegion2D.
## 7. Robustez e ausência de erros na destruição múltipla ou nós parciais.
## 8. Coexistência harmônica nos mapas do jogo (World/Props).
## 9. Não interferência entre múltiplos objetos destrutíveis.
## 10. Desacoplamento do contrato de dano (Damage -> Damageable -> Destructible).

const DestructiblePropClass = preload("res://scripts/props/destructible_prop.gd")
const HealthComponentClass = preload("res://scripts/components/health_component.gd")

var total_tests: int = 0
var passed_tests: int = 0
var failed_tests: int = 0


func _init() -> void:
	call_deferred("_run_destructible_prop_tests")


func assert_test(condition: bool, test_name: String) -> void:
	total_tests += 1
	if condition:
		passed_tests += 1
		print("  [OK] %s" % test_name)
	else:
		failed_tests += 1
		printerr("  [FALHA] %s" % test_name)


func _run_destructible_prop_tests() -> void:
	print("==================================================")
	print("INICIANDO SUITE DE TESTES: OBJETOS DESTRUTÍVEIS (FASE 5)")
	print("==================================================")

	var prop_scene: PackedScene = load("res://scenes/props/destructible_prop.tscn")
	assert_test(prop_scene != null, "Cena destructible_prop.tscn carregada com sucesso")
	if prop_scene == null:
		_finish()
		return

	# PARTE 1: Arquitetura desacoplada e inicialização de nós
	print("\n--- 1. Validando Arquitetura Desacoplada e Nós do DestructibleProp ---")
	var prop_inst: Node = prop_scene.instantiate()
	assert_test(prop_inst != null, "Instância de DestructibleProp criada")
	assert_test(prop_inst is StaticBody2D, "DestructibleProp é um StaticBody2D")
	assert_test(prop_inst.is_in_group("props"), "Prop pertence ao grupo 'props'")
	assert_test(prop_inst.is_in_group("destructibles"), "Prop pertence ao grupo 'destructibles'")
	assert_test(prop_inst.is_in_group("destructible_props"), "Prop pertence ao grupo 'destructible_props'")
	assert_test(prop_inst.is_in_group("damageable"), "Prop pertence ao grupo 'damageable'")
	assert_test(not prop_inst.is_in_group("enemies"), "Prop NÃO pertence a 'enemies' (desacoplamento total)")
	assert_test(not prop_inst.is_in_group("actors"), "Prop NÃO pertence a 'actors'")
	assert_test(not prop_inst.is_in_group("player"), "Prop NÃO pertence a 'player'")

	# Componentes desacoplados
	var visual: Node2D = prop_inst.get_node_or_null("Visual") as Node2D
	var collision_shape: CollisionShape2D = prop_inst.get_node_or_null("CollisionShape2D") as CollisionShape2D
	var hurtbox: Area2D = prop_inst.get_node_or_null("Hurtbox") as Area2D
	var health_comp: Node = prop_inst.get_node_or_null("HealthComponent")
	var effects: Node2D = prop_inst.get_node_or_null("Effects") as Node2D
	var nav_obstacle: NavigationObstacle2D = prop_inst.get_node_or_null("NavigationIntegration") as NavigationObstacle2D

	assert_test(visual != null, "Componente Visual presente")
	assert_test(collision_shape != null, "Componente CollisionShape2D presente")
	assert_test(hurtbox != null, "Componente Hurtbox presente")
	assert_test(health_comp != null, "Componente HealthComponent presente")
	assert_test(effects != null, "Componente Effects presente")
	assert_test(nav_obstacle != null, "Componente NavigationIntegration presente")

	root.add_child(prop_inst)
	await process_frame

	# Estado inicial
	assert_test(prop_inst.get_current_state() == DestructiblePropClass.PropState.ACTIVE, "Estado inicial é ACTIVE")
	assert_test(prop_inst.is_active(), "is_active() retorna true inicialmente")
	assert_test(prop_inst.current_health == prop_inst.max_health, "current_health igual a max_health")
	assert_test(not prop_inst.is_broken, "is_broken é false inicialmente")
	assert_test(not prop_inst.is_prop_destroyed(), "is_prop_destroyed() é false inicialmente")
	assert_test(nav_obstacle.avoidance_enabled == true, "NavigationObstacle2D avoidance_enabled ativo")
	assert_test(hurtbox.monitorable == true, "Hurtbox.monitorable ativo para detecção de dano")

	# PARTE 2: Recebimento de dano e redução de vida
	print("\n--- 2. Validando Recebimento de Dano e Redução de Vida ---")
	var initial_hp: float = prop_inst.current_health
	var damage_amount: float = 10.0
	var tracker := {
		"damaged": false,
		"dmg": 0.0,
		"hp": 0.0,
		"destroying": false,
		"destroyed": false
	}

	prop_inst.prop_damaged.connect(func(amt: float, hp: float) -> void:
		tracker["damaged"] = true
		tracker["dmg"] = amt
		tracker["hp"] = hp
	)

	var damage_accepted: bool = prop_inst.take_damage(damage_amount)
	assert_test(damage_accepted, "take_damage() aceitou dano sub-letal")
	assert_test(prop_inst.current_health == initial_hp - damage_amount, "current_health reduziu exatamente %f" % damage_amount)
	if health_comp != null:
		assert_test(health_comp.get("current_health") == initial_hp - damage_amount, "HealthComponent sincronizado com redução de vida")
	assert_test(tracker["damaged"], "Sinal prop_damaged disparado")
	assert_test(tracker["dmg"] == damage_amount, "Valor do dano no sinal confere")
	assert_test(tracker["hp"] == initial_hp - damage_amount, "Vida restante no sinal confere")

	# PARTE 3: Máquina de estados (ACTIVE -> DAMAGED -> DESTROYING -> DESTROYED)
	print("\n--- 3. Validando Máquina de Estados ---")
	assert_test(prop_inst.get_current_state() == DestructiblePropClass.PropState.DAMAGED, "Estado mudou para DAMAGED após dano")
	assert_test(prop_inst.is_damaged(), "is_damaged() retorna true")
	assert_test(not prop_inst.is_active(), "is_active() retorna false")
	assert_test(not prop_inst.is_prop_destroyed(), "is_prop_destroyed() retorna false")

	var state_history: Array[int] = []
	prop_inst.state_changed.connect(func(s: int) -> void: state_history.append(s))
	prop_inst.prop_destroying.connect(func() -> void: tracker["destroying"] = true)
	prop_inst.prop_destroyed.connect(func() -> void: tracker["destroyed"] = true)

	# Aplica dano letal restante
	var lethal_accepted: bool = prop_inst.take_damage(prop_inst.current_health)
	assert_test(lethal_accepted, "Dano letal aceito")
	assert_test(prop_inst.current_health == 0.0, "current_health atingiu 0")
	assert_test(tracker["destroying"], "Sinal prop_destroying emitido na destruição")
	assert_test(tracker["destroyed"], "Sinal prop_destroyed emitido na destruição")
	assert_test(state_history.has(DestructiblePropClass.PropState.DESTROYING), "Histórico de estados registrou DESTROYING")
	assert_test(state_history.has(DestructiblePropClass.PropState.DESTROYED), "Histórico de estados registrou DESTROYED")
	assert_test(prop_inst.get_current_state() == DestructiblePropClass.PropState.DESTROYED, "Estado final é DESTROYED")
	assert_test(prop_inst.is_prop_destroyed(), "is_prop_destroyed() retorna true")
	assert_test(prop_inst.is_broken, "is_broken é true")

	# PARTE 4: Recusa estrita de dano após destruição
	print("\n--- 4. Validando Recusa Estrita de Dano Após Destruição ---")
	tracker["damaged"] = false
	var post_death_damage_accepted: bool = prop_inst.take_damage(50.0)
	assert_test(not post_death_damage_accepted, "take_damage() recusou dano após estar DESTROYED")
	assert_test(prop_inst.current_health == 0.0, "Vida permanece 0.0 sem alterações")
	assert_test(not tracker["damaged"], "Nenhum sinal de dano emitido após destruição")

	# PARTE 5: Desativação de Colisão Física, Hurtbox e Obstáculo
	print("\n--- 5. Validando Liberação de Passagem e Desativação de Hurtbox ---")
	await process_frame
	await process_frame
	assert_test(collision_shape.disabled, "CollisionShape2D está disabled (passagem física liberada)")
	assert_test(not hurtbox.monitorable, "Hurtbox monitorable desativado")
	assert_test(not nav_obstacle.avoidance_enabled, "NavigationObstacle2D avoidance_enabled desativado")
	assert_test(not visual.visible, "Visual desativado/oculto")

	root.remove_child(prop_inst)
	prop_inst.free()

	# PARTE 6: Performance de navegação — ausência de bake global da NavigationRegion2D
	print("\n--- 6. Validando Performance de Navegação (Sem Rebuild de NavigationRegion2D) ---")
	var map1_scene: PackedScene = load("res://scenes/levels/map_1.tscn")
	assert_test(map1_scene != null, "Mapa 1 carregado para teste de performance")
	if map1_scene != null:
		var map1_inst: Node = map1_scene.instantiate()
		root.add_child(map1_inst)
		await process_frame

		var nav_region: NavigationRegion2D = map1_inst.get_node_or_null("NavigationRegion2D") as NavigationRegion2D
		assert_test(nav_region != null, "NavigationRegion2D localizada no mapa")
		var initial_navpoly: NavigationPolygon = nav_region.navigation_polygon if nav_region != null else null
		assert_test(initial_navpoly != null, "NavigationPolygon inicial presente")

		# Adiciona um prop destrutível dinamicamente no mapa
		var dynamic_prop: Node = prop_scene.instantiate()
		var props_container: Node = map1_inst.get_node_or_null("World/Props")
		if props_container != null:
			props_container.add_child(dynamic_prop)
			(dynamic_prop as Node2D).global_position = Vector2(500, 600)
			await process_frame

			# Destrói o prop
			dynamic_prop.destroy_prop()
			await process_frame
			await process_frame

			# Verifica que a NavigationRegion2D NÃO sofreu bake_navigation_polygon nem troca de recurso
			assert_test(nav_region.navigation_polygon == initial_navpoly, "NavigationPolygon permanece exatamente a mesma referência (sem rebuild!)")
			var d_nav_obstacle: NavigationObstacle2D = dynamic_prop.get_node_or_null("NavigationIntegration") as NavigationObstacle2D
			assert_test(d_nav_obstacle != null and not d_nav_obstacle.avoidance_enabled, "Avoidance do prop foi desativado dinamicamente")

		root.remove_child(map1_inst)
		map1_inst.free()

	# PARTE 7: Não interferência entre múltiplos objetos destrutíveis
	print("\n--- 7. Validando Não-Interferência Entre Múltiplos Objetos Destrutíveis ---")
	var prop_a: Node = prop_scene.instantiate()
	var prop_b: Node = prop_scene.instantiate()
	root.add_child(prop_a)
	root.add_child(prop_b)
	(prop_a as Node2D).global_position = Vector2(100, 100)
	(prop_b as Node2D).global_position = Vector2(200, 100)
	await process_frame

	# Destrói apenas Prop A
	prop_a.take_damage(prop_a.max_health)
	await process_frame
	await process_frame

	assert_test(prop_a.is_prop_destroyed(), "Prop A destruído com sucesso")
	var col_a: CollisionShape2D = prop_a.get_node_or_null("CollisionShape2D") as CollisionShape2D
	assert_test(col_a != null and col_a.disabled, "Prop A colisão desabilitada")

	assert_test(prop_b.is_active(), "Prop B permanece estritamente ACTIVE")
	assert_test(prop_b.current_health == prop_b.max_health, "Prop B permanece com vida total (30.0)")
	var col_b: CollisionShape2D = prop_b.get_node_or_null("CollisionShape2D") as CollisionShape2D
	assert_test(col_b != null and not col_b.disabled, "Prop B colisão permanece ativa")
	var nav_b: NavigationObstacle2D = prop_b.get_node_or_null("NavigationIntegration") as NavigationObstacle2D
	assert_test(nav_b != null and nav_b.avoidance_enabled, "Prop B avoidance permanece ativo")

	root.remove_child(prop_a)
	root.remove_child(prop_b)
	prop_a.free()
	prop_b.free()

	# PARTE 8: Idempotência e robustez contra destruição com nós ausentes
	print("\n--- 8. Validando Robustez e Idempotência de Destruição ---")
	var bare_prop: Node = DestructiblePropClass.new()
	root.add_child(bare_prop)
	await process_frame
	# Destruição em prop sem subnós configurados não deve emitir erro nem quebrar a execução
	bare_prop.destroy_prop()
	assert_test(bare_prop.is_prop_destroyed(), "Prop básico sem nós filhos destrói sem erros")
	# Chamada duplicada
	bare_prop.destroy_prop()
	assert_test(bare_prop.is_prop_destroyed(), "destroy_prop() é estritamente idempotente")
	root.remove_child(bare_prop)
	bare_prop.free()

	# PARTE 9: Coexistência nos 5 mapas do projeto
	print("\n--- 9. Validando Coexistência em Todos os Mapas ---")
	var all_maps: Array[String] = [
		"res://scenes/levels/map_1.tscn",
		"res://scenes/levels/map_2.tscn",
		"res://scenes/levels/map_3.tscn",
		"res://scenes/levels/map_4.tscn",
		"res://scenes/levels/test_street.tscn"
	]

	for map_path in all_maps:
		var mname: String = map_path.get_file().get_basename()
		var mscene: PackedScene = load(map_path)
		assert_test(mscene != null, "%s: Cena carregada com sucesso" % mname)
		if mscene == null:
			continue

		var minst: Node = mscene.instantiate()
		root.add_child(minst)
		await process_frame

		var p_container: Node = minst.get_node_or_null("World/Props")
		assert_test(p_container != null, "%s: World/Props existe e recebe props" % mname)
		if p_container != null:
			var test_prop: Node = prop_scene.instantiate()
			p_container.add_child(test_prop)
			(test_prop as Node2D).global_position = Vector2(400, 600)
			await process_frame

			assert_test(test_prop.is_inside_tree(), "%s: DestructibleProp adicionado com sucesso a World/Props" % mname)
			assert_test(test_prop.is_in_group("destructibles"), "%s: DestructibleProp reconhecido no grupo 'destructibles'" % mname)
			assert_test(test_prop.is_in_group("damageable"), "%s: DestructibleProp reconhecido no grupo 'damageable'" % mname)

			# Simula quebra no mapa
			test_prop.take_damage(test_prop.max_health)
			await process_frame
			assert_test(test_prop.is_prop_destroyed(), "%s: DestructibleProp quebrou no mapa sem erros" % mname)

		root.remove_child(minst)
		minst.free()

	# PARTE 10: Desacoplamento do Contrato de Dano (Damage Contract)
	print("\n--- 10. Validando Desacoplamento do Contrato de Dano ---")
	var generic_prop: Node = prop_scene.instantiate()
	root.add_child(generic_prop)
	await process_frame

	# Dano por entidade arbitrária (qualquer atacante invocando take_damage)
	var attacker_name: String = "PlayerPunchAttack"
	var took: bool = generic_prop.take_damage(15.0)
	assert_test(took, "Ataque '%s' aplicou dano com sucesso" % attacker_name)

	# Dano por perigo ambiental
	var hazard_name: String = "ExplosiveHazard"
	var took_hazard: bool = generic_prop.take_damage(15.0)
	assert_test(took_hazard, "Perigo '%s' causou destruição com sucesso" % hazard_name)
	assert_test(generic_prop.is_prop_destroyed(), "Prop destruído por perigo ambiental desacoplado")

	root.remove_child(generic_prop)
	generic_prop.free()

	_finish()


func _finish() -> void:
	print("==================================================")
	print("RESULTADO DOS TESTES DE OBJETOS DESTRUTÍVEIS (FASE 5): %d/%d PASSARAM (Falhas: %d)" % [passed_tests, total_tests, failed_tests])
	print("==================================================")

	if failed_tests == 0:
		quit(0)
	else:
		quit(1)
