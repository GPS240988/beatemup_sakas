extends SceneTree

## Suíte de Testes Automatizados Headless para a Transição de Mapa e Desbloqueio da Fase 2.

const MapTransitionClass = preload("res://scripts/ui/map_transition.gd")
const MapMenuClass = preload("res://scripts/ui/map_menu.gd")
const MapArrowRendererClass = preload("res://scripts/ui/map_arrow_renderer.gd")
const MapUnlockVFXClass = preload("res://scripts/ui/map_unlock_vfx.gd")
const GameSessionClassRef = preload("res://scripts/core/game_session.gd")

var total_tests: int = 0
var passed_tests: int = 0
var failed_tests: int = 0


func _init() -> void:
	call_deferred("_run_all_tests")


func assert_test(condition: bool, test_name: String) -> void:
	total_tests += 1
	if condition:
		passed_tests += 1
		print("  [OK] %s" % test_name)
	else:
		failed_tests += 1
		printerr("  [FALHA] %s" % test_name)


func _run_all_tests() -> void:
	print("==================================================")
	print("INICIANDO TESTES DA TRANSIÇÃO DE MAPA E DESBLOQUEIO (GODOT 4.x)")
	print("==================================================")

	test_map_transition_scene_structure()
	test_trail_waypoints_and_modes()
	test_arrow_and_vfx_nodes()
	test_game_session_bonus_and_stage2_persistence()
	test_map_menu_dynamic_progression()
	test_base_level_map_4_and_bonus_interception()

	print("==================================================")
	print("RESULTADO DOS TESTES MAP TRANSITION: %d/%d PASSARAM (Falhas: %d)" % [passed_tests, total_tests, failed_tests])
	print("==================================================")

	if failed_tests == 0:
		quit(0)
	else:
		quit(1)


func test_map_transition_scene_structure() -> void:
	print("\n--- Testando Estrutura da Cena MapTransition ---")
	var scene: PackedScene = load("res://scenes/ui/map_transition.tscn")
	assert_test(scene != null, "Cena map_transition.tscn carregada com sucesso")

	var instance: Node = scene.instantiate()
	assert_test(instance != null and instance.get_script() == MapTransitionClass, "Instância é da classe MapTransition")
	assert_test(instance is Control and (instance as Control).mouse_filter == Control.MOUSE_FILTER_STOP, "MouseFilter está configurado como STOP para bloquear entradas")

	instance.set("auto_start", false)
	root.add_child(instance)

	var bg: TextureRect = instance.get_node_or_null("%BackgroundTexture") as TextureRect
	assert_test(bg != null, "BackgroundTexture existe na cena")
	if bg != null:
		assert_test(bg.texture != null, "BackgroundTexture possui a imagem oficial do mapa")

	var p1_cover: TextureRect = instance.get_node_or_null("%Point1Cover") as TextureRect
	assert_test(p1_cover != null, "Point1Cover existe na cena")
	if p1_cover != null:
		assert_test(p1_cover.texture != null, "Point1Cover possui textura de cobertura procedural")
		assert_test(p1_cover.position.x >= 220.0 and p1_cover.position.x <= 230.0, "Point1Cover posicionado sobre a seta do Ponto 1")

	var p2_cover: TextureRect = instance.get_node_or_null("%Point2Cover") as TextureRect
	assert_test(p2_cover != null, "Point2Cover existe na cena")
	if p2_cover != null:
		assert_test(p2_cover.texture != null, "Point2Cover possui textura de cobertura procedural")
		assert_test(p2_cover.position.x >= 850.0 and p2_cover.position.x <= 865.0, "Point2Cover posicionado sobre o cadeado do Ponto 2")

	var resting_p1 = instance.get_node_or_null("%RestingArrowP1")
	var resting_bonus = instance.get_node_or_null("%RestingArrowBonus")
	var resting_p2 = instance.get_node_or_null("%RestingArrowP2")
	assert_test(resting_p1 != null, "RestingArrowP1 existe para repouso no Ponto 1")
	assert_test(resting_bonus != null, "RestingArrowBonus existe para repouso no Bônus 1")
	assert_test(resting_p2 != null, "RestingArrowP2 existe para repouso no Ponto 2")

	var fade: ColorRect = instance.get_node_or_null("%FadeOverlay") as ColorRect
	assert_test(fade != null, "FadeOverlay existe para controle de Fade In / Fade Out")

	var audio: AudioStreamPlayer = instance.get_node_or_null("%AudioPlayer") as AudioStreamPlayer
	assert_test(audio != null, "AudioStreamPlayer existe para efeitos sonoros")

	instance.queue_free()


func test_trail_waypoints_and_modes() -> void:
	print("\n--- Testando Trajeto da Seta e Modos de Transição ---")
	var waypoints: Array[Vector2] = MapTransitionClass.TRAIL_WAYPOINTS
	assert_test(waypoints.size() == 14, "Waypoints completos definidos (total: 14)")

	# Ponto 1 de partida
	var start_pt: Vector2 = waypoints[0]
	assert_test(start_pt.distance_to(Vector2(240, 348)) < 2.0, "Ponto 1 de partida está em (240, 348)")

	# Bônus 1 intermediário (acima do círculo do ponto bônus, sem cobrir o presente)
	var bonus_pt: Vector2 = waypoints[7]
	assert_test(bonus_pt.distance_to(Vector2(578, 282)) < 2.0, "Bônus 1 está em (578, 282) acima do círculo")

	# Ponto 2 de chegada
	var end_pt: Vector2 = waypoints[13]
	assert_test(end_pt.distance_to(Vector2(870, 265)) < 2.0, "Ponto 2 de chegada está em (870, 265)")

	# Leg 1: Ponto 1 -> Bônus 1 (waypoints 0..7)
	var leg1 = waypoints.slice(0, 8)
	var curve1 := Curve2D.new()
	for pt in leg1: curve1.add_point(pt)
	assert_test(curve1.get_baked_length() >= 360.0 and curve1.get_baked_length() <= 440.0, "Leg 1 (Ponto 1 -> Bônus 1) comprimento adequado (%.1f px)" % curve1.get_baked_length())

	# Leg 2: Bônus 1 -> Ponto 2 (waypoints 7..13)
	var leg2 = waypoints.slice(7, 14)
	var curve2 := Curve2D.new()
	for pt in leg2: curve2.add_point(pt)
	assert_test(curve2.get_baked_length() >= 310.0 and curve2.get_baked_length() <= 370.0, "Leg 2 (Bônus 1 -> Ponto 2) comprimento adequado (%.1f px)" % curve2.get_baked_length())


func test_arrow_and_vfx_nodes() -> void:
	print("\n--- Testando Renderizadores de Seta e Feedback Visual ---")
	var arrow: Node2D = MapArrowRendererClass.new()
	assert_test(arrow != null, "MapArrowRenderer instanciado com sucesso")
	assert_test(arrow.get("arrow_color") == Color(1, 1, 1, 1), "Cor interna da seta é branco puro arcade")
	arrow.free()

	var vfx: Node2D = MapUnlockVFXClass.new()
	assert_test(vfx != null, "MapUnlockVFX instanciado com sucesso")
	assert_test(vfx.has_method("play_burst"), "MapUnlockVFX possui método play_burst()")
	vfx.free()


func test_game_session_bonus_and_stage2_persistence() -> void:
	print("\n--- Testando Desbloqueio e Persistência no GameSession ---")
	var session = GameSessionClassRef.new()
	session._ready()

	# Limpa estado anterior de teste se houver
	session.bonus_stage_unlocked = false
	session.stage_2_unlocked = false
	session.max_unlocked_stage = 1
	session._save_campaign_progression()

	assert_test(not session.is_bonus_unlocked(), "Bônus inicialmente bloqueado")
	assert_test(not session.is_stage_2_unlocked(), "Fase 2 inicialmente bloqueada")

	# Desbloqueio do Bônus 1
	session.unlock_bonus_stage()
	assert_test(session.is_bonus_unlocked(), "Bônus desbloqueado após unlock_bonus_stage()")
	assert_test(not session.is_stage_2_unlocked(), "Fase 2 continua bloqueada ao desbloquear apenas o bônus")

	# Desbloqueio da Fase 2
	session.unlock_stage_2()
	assert_test(session.is_stage_2_unlocked(), "Fase 2 desbloqueada após unlock_stage_2()")
	assert_test(session.max_unlocked_stage >= 2, "max_unlocked_stage atualizado para >= 2")

	# Restauração em nova instância
	var session_restored = GameSessionClassRef.new()
	session_restored._ready()
	assert_test(session_restored.is_bonus_unlocked(), "Bônus permanece desbloqueado após recarregamento")
	assert_test(session_restored.is_stage_2_unlocked(), "Fase 2 permanece desbloqueada após recarregamento")

	session.free()
	session_restored.free()


func test_map_menu_dynamic_progression() -> void:
	print("\n--- Testando Atualização Dinâmica do Menu de Mapa com Progresso ---")
	var menu_scene: PackedScene = load("res://scenes/ui/map_menu.tscn")
	assert_test(menu_scene != null, "map_menu.tscn carregada com sucesso")

	var active_session = root.get_node_or_null("GameSession")
	var created_session: bool = false
	if active_session == null:
		active_session = GameSessionClassRef.new()
		active_session.name = "GameSession"
		root.add_child(active_session)
		created_session = true

	# Caso 1: Início de Jogo (Fase 2 bloqueada)
	active_session.bonus_stage_unlocked = false
	active_session.stage_2_unlocked = false
	active_session._save_campaign_progression()

	var menu_initial = menu_scene.instantiate()
	root.add_child(menu_initial)
	var arrow_p1 = menu_initial.get_node_or_null("%ArrowP1")
	var arrow_p2 = menu_initial.get_node_or_null("%ArrowP2")
	var p2_cover = menu_initial.get_node_or_null("%Point2Cover")
	assert_test(arrow_p1 != null and arrow_p1.visible, "No início do jogo: seta é exibida sobre o Ponto 1")
	assert_test(arrow_p2 != null and not arrow_p2.visible, "No início do jogo: seta do Ponto 2 está oculta")
	assert_test(p2_cover != null and not p2_cover.visible, "No início do jogo: cadeado do Ponto 2 permanece visível")
	menu_initial.queue_free()

	# Caso 2: Fase 2 Desbloqueada e Salva
	active_session.unlock_stage_2()
	var menu_unlocked = menu_scene.instantiate()
	root.add_child(menu_unlocked)
	var u_arrow_p1 = menu_unlocked.get_node_or_null("%ArrowP1")
	var u_arrow_p2 = menu_unlocked.get_node_or_null("%ArrowP2")
	var u_p2_cover = menu_unlocked.get_node_or_null("%Point2Cover")
	assert_test(u_arrow_p1 != null and not u_arrow_p1.visible, "Após desbloqueio: seta do Ponto 1 fica oculta")
	assert_test(u_arrow_p2 != null and u_arrow_p2.visible, "Após desbloqueio: seta é exibida sobre o Ponto 2")
	assert_test(u_p2_cover != null and u_p2_cover.visible, "Após desbloqueio: cadeado do Ponto 2 é removido/coberto")
	menu_unlocked.queue_free()

	if created_session:
		active_session.queue_free()


func test_base_level_map_4_and_bonus_interception() -> void:
	print("\n--- Testando Intercepções de Transição em map_4 e bonus_garage ---")
	var map4_scene: PackedScene = load("res://scenes/levels/map_4.tscn")
	assert_test(map4_scene != null, "map_4.tscn carregada com sucesso")
	var map4 = map4_scene.instantiate()
	assert_test(map4.get("next_map_scene_path") == "res://scenes/levels/bonus_garage.tscn", "map_4 aponta para bonus_garage.tscn")
	assert_test(map4.get_node_or_null("SigaIndicator") != null, "SigaIndicator restaurado na cena do Mapa 4")
	map4.free()

	var garage_scene: PackedScene = load("res://scenes/levels/bonus_garage.tscn")
	assert_test(garage_scene != null, "bonus_garage.tscn carregada com sucesso")
	var garage = garage_scene.instantiate()
	assert_test(garage.get("map_group") == "bonus1", "bonus_garage pertence ao grupo 'bonus1'")
	assert_test(garage.get_node_or_null("SigaIndicator") != null, "SigaIndicator restaurado na cena da Garagem Bônus")
	garage.free()
