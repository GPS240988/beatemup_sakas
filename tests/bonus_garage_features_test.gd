extends SceneTree

## Suíte de Testes Automatizados Headless:
## 1. WallTop e Limites Físicos da Garagem Bônus (Testes A a G)
## 2. Detecção de Golpes e Hurtbox nos Carros (Testes A a H)
## 3. Sistema de Continues e Recompensas Idempotentes
## 4. Cronômetro Global de 40 Segundos e Encerramento
## 5. EnemyHUD Visibilidade (Visível apenas próximo, vivo ou sofrendo dano)
## 6. Remoção de referências a siga.webp

const BonusStageManagerClass = preload("res://scripts/levels/bonus_stage_manager.gd")
const DestructiblePropClass = preload("res://scripts/props/destructible_prop.gd")
const DamageInfoClass = preload("res://scripts/combat/damage_info.gd")
const EnemyHUDClass = preload("res://scripts/ui/enemy_hud.gd")

var _total: int = 0
var _passed: int = 0
var _failed: int = 0


func _init() -> void:
	call_deferred("_run_all_tests")


func _assert(cond: bool, msg: String) -> void:
	_total += 1
	if cond:
		_passed += 1
		print("  [OK] %s" % msg)
	else:
		_failed += 1
		printerr("  [FAIL] %s" % msg)


func _run_all_tests() -> void:
	print("==================================================")
	print("INICIANDO SUITE DE TESTES: CORREÇÃO WALLTOP E FASE BÔNUS")
	print("==================================================")

	test_walltop_geometry()
	test_vehicle_hurtbox_detection()
	test_continue_reward_and_timer()
	test_enemy_hud_visibility_rules()
	test_siga_cleanup()

	print("==================================================")
	print("RESULTADOS: %d/%d PASSARAM (Falhas: %d)" % [_passed, _total, _failed])
	print("==================================================")

	if _failed > 0:
		quit(1)
	else:
		quit(0)


func test_walltop_geometry() -> void:
	print("\n--- 1. Validando Geometria e Limites de WallTop e Perímetro ---")
	var garage_scene: PackedScene = load("res://scenes/levels/bonus_garage.tscn")
	var garage = garage_scene.instantiate()
	root.add_child(garage)

	var wall_top = garage.get_node_or_null("StaticWorld/WorldBoundaries/WallTop") as CollisionShape2D
	_assert(wall_top != null, "WallTop existe em StaticWorld/WorldBoundaries")
	if wall_top != null:
		var rect := wall_top.shape as RectangleShape2D
		_assert(rect != null, "WallTop possui RectangleShape2D")
		_assert(rect.size.y >= 500.0, "Espessura de WallTop é de meio-espaço robusto (>= 500px)")
		_assert(wall_top.position.y <= 300.0, "Centro de WallTop cobre toda a área superior exterior")
		
		# Teste A: Limite superior da barreira alinha com início do piso caminhável
		var bottom_edge = wall_top.position.y + (rect.size.y * 0.5)
		_assert(bottom_edge >= 510.0 and bottom_edge <= 525.0, "Borda inferior de WallTop delimita o topo da garagem (510..525px)")
		
		# Teste D: Largura cobre com folga toda a extensão da garagem
		_assert(rect.size.x >= 2000.0, "WallTop cobre amplamente toda a largura da garagem (>= 2000px)")

	# Teste E: Outros limites e vedação dos cantos
	var wall_bottom = garage.get_node_or_null("StaticWorld/WorldBoundaries/WallBottom") as CollisionShape2D
	var wall_left = garage.get_node_or_null("StaticWorld/WorldBoundaries/WallLeft") as CollisionShape2D
	var wall_right = garage.get_node_or_null("StaticWorld/WorldBoundaries/WallRight") as CollisionShape2D
	_assert(wall_bottom != null, "WallBottom preservado")
	_assert(wall_left != null, "WallLeft preservado")
	_assert(wall_right != null, "WallRight preservado")

	if wall_bottom != null:
		var r_bot := wall_bottom.shape as RectangleShape2D
		var top_edge = wall_bottom.position.y - (r_bot.size.y * 0.5)
		_assert(top_edge >= 820.0 and top_edge <= 840.0, "Borda superior de WallBottom delimita a base jogável (820..840px)")

	if wall_left != null:
		var r_left := wall_left.shape as RectangleShape2D
		var right_edge = wall_left.position.x + (r_left.size.x * 0.5)
		_assert(right_edge >= 50.0 and right_edge <= 70.0, "Borda direita de WallLeft delimita o lado esquerdo jogável (50..70px)")

	if wall_right != null:
		var r_right := wall_right.shape as RectangleShape2D
		var left_edge = wall_right.position.x - (r_right.size.x * 0.5)
		_assert(left_edge >= 1600.0 and left_edge <= 1620.0, "Borda esquerda de WallRight delimita o lado direito jogável (1600..1620px)")

	garage.queue_free()


func test_vehicle_hurtbox_detection() -> void:
	print("\n--- 2. Validando Detecção Ampliada e Hurtbox dos Veículos ---")
	var orange_scene: PackedScene = load("res://scenes/props/bonus_car_orange.tscn")
	var car_orange = orange_scene.instantiate() as DestructibleProp
	root.add_child(car_orange)
	car_orange.global_position = Vector2(480, 660)

	var blue_scene: PackedScene = load("res://scenes/props/bonus_car_blue.tscn")
	var car_blue = blue_scene.instantiate() as DestructibleProp
	root.add_child(car_blue)
	car_blue.global_position = Vector2(1160, 680)

	# Validação da geometria Hurtbox segmentada (Center, Front, Rear)
	var orange_hurtbox = car_orange.get_node_or_null("Hurtbox") as Area2D
	_assert(orange_hurtbox != null, "Hurtbox presente no carro laranja")
	_assert(orange_hurtbox.get_node_or_null("CollisionShape2D_Center") != null, "Carro laranja possui CollisionShape2D_Center")
	_assert(orange_hurtbox.get_node_or_null("CollisionShape2D_Front") != null, "Carro laranja possui CollisionShape2D_Front")
	_assert(orange_hurtbox.get_node_or_null("CollisionShape2D_Rear") != null, "Carro laranja possui CollisionShape2D_Rear")

	var blue_hurtbox = car_blue.get_node_or_null("Hurtbox") as Area2D
	_assert(blue_hurtbox != null, "Hurtbox presente no carro azul")
	_assert(blue_hurtbox.get_node_or_null("CollisionShape2D_Center") != null, "Carro azul possui CollisionShape2D_Center")
	_assert(blue_hurtbox.get_node_or_null("CollisionShape2D_Front") != null, "Carro azul possui CollisionShape2D_Front")
	_assert(blue_hurtbox.get_node_or_null("CollisionShape2D_Rear") != null, "Carro azul possui CollisionShape2D_Rear")

	# Teste de get_closest_contact_point em diferentes ângulos de aproximação
	# A: Frente (lado direito)
	var pt_front = car_orange.get_closest_contact_point(Vector2(700, 660))
	_assert(pt_front.x > 480.0, "Ponto de contato frontal é mapeado para a extremidade frontal")
	
	# B: Traseira (lado esquerdo)
	var pt_rear = car_orange.get_closest_contact_point(Vector2(200, 660))
	_assert(pt_rear.x < 480.0, "Ponto de contato traseiro é mapeado para a extremidade traseira")

	# C: Laterais superior e inferior
	var pt_top = car_orange.get_closest_contact_point(Vector2(480, 580))
	var pt_bottom = car_orange.get_closest_contact_point(Vector2(480, 720))
	_assert(pt_top.y <= 660.0, "Ponto superior mapeado corretamente")
	_assert(pt_bottom.y >= 640.0, "Ponto inferior mapeado corretamente")

	# Teste de recepção de dano
	var initial_hp = car_orange.current_health
	var dmg_info = DamageInfoClass.new(50.0, null, Vector2(500, 660), Vector2.LEFT, "melee", 0.0, 0.0, true)
	var hit_ok = car_orange.take_damage(dmg_info)
	_assert(hit_ok, "Carro aceita dano de ataque melee")
	_assert(car_orange.current_health == initial_hp - 50.0, "Vida do carro reduz exatamente pelo valor de dano")

	car_orange.queue_free()
	car_blue.queue_free()


func test_continue_reward_and_timer() -> void:
	print("\n--- 3. Validando Cronômetro de 40s e Recompensa de Continues ---")
	var garage_scene: PackedScene = load("res://scenes/levels/bonus_garage.tscn")
	var garage = garage_scene.instantiate()
	root.add_child(garage)

	var manager = garage.get_node_or_null("BonusStageManager")
	_assert(manager != null, "BonusStageManager presente na cena da garagem")
	_assert(manager.get("round_duration") == 40.0, "Cronômetro configurado com 40 segundos")
	_assert(manager.get("time_left") == 40.0, "Tempo inicial é 40 segundos")

	var car_orange = garage.get_node_or_null("World/Props/Vehicles/CarOrange") as DestructibleProp
	var car_blue = garage.get_node_or_null("World/Props/Vehicles/CarBlue") as DestructibleProp
	_assert(car_orange != null and car_blue != null, "Ambos os carros presentes para gerenciamento")

	# Simula destruição do carro laranja -> +1 continue
	manager._on_orange_car_destroyed()
	_assert(manager.orange_car_destroyed == true, "orange_car_destroyed registrado")
	_assert(manager.orange_continue_awarded == true, "orange_continue_awarded registrado")
	_assert(manager.total_continues_awarded == 1, "+1 continue concedido pelo carro laranja")

	# Teste de Idempotência: emitir sinal novamente NÃO deve conceder continue adicional
	manager._on_orange_car_destroyed()
	_assert(manager.total_continues_awarded == 1, "Idempotência mantida: segundo evento do mesmo carro não duplica recompensa")

	# Simula destruição do carro azul -> +1 continue (total 2)
	manager._on_blue_car_destroyed()
	_assert(manager.blue_car_destroyed == true, "blue_car_destroyed registrado")
	_assert(manager.blue_continue_awarded == true, "blue_continue_awarded registrado")
	_assert(manager.total_continues_awarded == 2, "+2 continues totais concedidos pela destruição de ambos os carros")
	_assert(manager.is_completed == true, "Rodada finalizada automaticamente após destruição de ambos os carros")

	garage.queue_free()


func test_enemy_hud_visibility_rules() -> void:
	print("\n--- 4. Validando Regras de Visibilidade da EnemyHUD ---")
	var hud_scene: PackedScene = load("res://scenes/ui/prototype_hud.tscn")
	var hud = hud_scene.instantiate()
	root.add_child(hud)

	var enemy_hud = hud.get_node_or_null("%EnemyHUD") as EnemyHUD
	_assert(enemy_hud != null, "EnemyHUD presente em PrototypeHud")
	_assert(enemy_hud.visible == false, "EnemyHUD inicia oculta quando nenhum inimigo está próximo ou em combate")

	# Cria nó mock de inimigo
	var mock_enemy = Node2D.new()
	mock_enemy.name = "MockEnemy"
	mock_enemy.set("current_health", 100.0)
	mock_enemy.set("max_health", 100.0)
	mock_enemy.global_position = Vector2(1000, 500)
	root.add_child(mock_enemy)

	enemy_hud.target_enemy(mock_enemy, false)
	# Sem jogador próximo e sem dano recente: permanece oculta ou faz fade_out
	enemy_hud._check_visibility_rules()
	_assert(enemy_hud.visible == false or enemy_hud.modulate.a == 0.0, "EnemyHUD oculta quando inimigo está longe")

	# Ao tomar dano: deve ficar visível imediatamente
	enemy_hud.set_enemy_health(80.0, 100.0, false)
	_assert(enemy_hud.visible == true, "EnemyHUD torna-se visível ao receber dano")

	mock_enemy.queue_free()
	hud.queue_free()


func test_siga_cleanup() -> void:
	print("\n--- 5. Validando Limpeza de siga.webp ---")
	var siga_scene: PackedScene = load("res://scenes/ui/siga_indicator.tscn")
	var siga_node = siga_scene.instantiate()
	_assert(siga_node != null, "siga_indicator.tscn carrega sem erros de dependência")
	_assert(siga_node.get_node_or_null("%ExitSignSprite") == null, "ExitSignSprite de siga.webp foi removido de siga_indicator.tscn")
	_assert(not FileAccess.file_exists("res://assets/backgrounds/siga.webp"), "Arquivo legado siga.webp não existe no repositório")
	siga_node.free()
