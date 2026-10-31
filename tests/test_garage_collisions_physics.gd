extends SceneTree

## Teste Dinâmico e Físico de Colisões: Bonus Garage Perímetro e Cantos
## Simula movimentação física real do Player com move_and_slide()
## contra os 4 limites, os 4 cantos e a circulação livre ao redor dos veículos.

var _total: int = 0
var _passed: int = 0
var _failed: int = 0


func _init() -> void:
	call_deferred("_run_simulation")


func _assert(cond: bool, msg: String) -> void:
	_total += 1
	if cond:
		_passed += 1
		print("  [OK] %s" % msg)
	else:
		_failed += 1
		printerr("  [FAIL] %s" % msg)


func _run_simulation() -> void:
	print("==================================================")
	print("INICIANDO SIMULAÇÃO FÍSICA: LIMITES DA GARAGEM")
	print("==================================================")

	var garage_scene: PackedScene = load("res://scenes/levels/bonus_garage.tscn")
	var garage = garage_scene.instantiate()
	root.add_child(garage)

	# Aguarda 2 frames para registro completo no PhysicsServer2D
	await process_frame
	await process_frame

	var player = garage.get_node_or_null("World/Actors/Player") as CharacterBody2D
	_assert(player != null, "Player instanciado e presente na árvore")
	if player == null:
		garage.free()
		quit(1)
		return

	# Teste 1: Limite Superior (Pressionando continuamente para CIMA)
	print("\n--- Teste 1: Pressionando contra Limite Superior ---")
	player.global_position = Vector2(820, 600)
	for i in range(40):
		player.velocity = Vector2(0, -350)
		player.move_and_slide()
	
	_assert(player.global_position.y >= 535.0, "Player é barrado no topo (Y=%f >= 535.0, não entra na parede)" % player.global_position.y)
	_assert(player.global_position.y <= 610.0, "Player alcançou o limite do fundo da garagem (Y=%f)" % player.global_position.y)

	# Teste 2: Deslize horizontal junto ao Limite Superior
	print("\n--- Teste 2: Movimento horizontal encostado no Limite Superior ---")
	var pos_before_x = player.global_position.x
	for i in range(20):
		player.velocity = Vector2(250, -50) # Tenta subir mas caminha para a direita
		player.move_and_slide()
	_assert(player.global_position.x > pos_before_x + 30.0, "Player caminha livremente para a direita junto à parede")
	_assert(player.global_position.y >= 535.0, "Player permanece impedido de subir na parede durante o deslize")

	# Teste 3: Retorno normal para baixo
	print("\n--- Teste 3: Retorno para baixo afastando-se da parede ---")
	for i in range(20):
		player.velocity = Vector2(0, 300)
		player.move_and_slide()
	_assert(player.global_position.y > 650.0, "Player desce livremente retornando ao centro da garagem (Y=%f)" % player.global_position.y)

	# Teste 4: Limite Inferior (Pressionando continuamente para BAIXO)
	print("\n--- Teste 4: Pressionando contra Limite Inferior ---")
	player.global_position = Vector2(820, 750)
	for i in range(40):
		player.velocity = Vector2(0, 350)
		player.move_and_slide()
	_assert(player.global_position.y <= 835.0, "Player é barrado na base (Y=%f <= 835.0, não sai da tela)" % player.global_position.y)
	_assert(player.global_position.y >= 815.0, "Player alcançou a borda inferior do piso jogável (Y=%f)" % player.global_position.y)

	# Teste 5: Limite Esquerdo (Pressionando continuamente para a ESQUERDA)
	print("\n--- Teste 5: Pressionando contra Limite Esquerdo ---")
	player.global_position = Vector2(250, 750)
	for i in range(40):
		player.velocity = Vector2(-350, 0)
		player.move_and_slide()
	_assert(player.global_position.x >= 85.0, "Player é barrado na lateral esquerda (X=%f >= 85.0)" % player.global_position.x)
	_assert(player.global_position.x <= 105.0, "Player encostou no limite esquerdo (X=%f)" % player.global_position.x)

	# Teste 6: Limite Direito (Pressionando continuamente para a DIREITA)
	print("\n--- Teste 6: Pressionando contra Limite Direito ---")
	player.global_position = Vector2(1400, 750)
	for i in range(40):
		player.velocity = Vector2(350, 0)
		player.move_and_slide()
	_assert(player.global_position.x <= 1585.0, "Player é barrado na lateral direita (X=%f <= 1585.0)" % player.global_position.x)
	_assert(player.global_position.x >= 1440.0, "Player encostou no limite direito (X=%f)" % player.global_position.x)

	# Teste 7: Quatro Cantos da Garagem (Sem escape em diagonais)
	print("\n--- Teste 7: Quatro Cantos da Garagem ---")
	# 7.1 Canto Superior Esquerdo
	player.global_position = Vector2(200, 600)
	for i in range(40):
		player.velocity = Vector2(-350, -350)
		player.move_and_slide()
	_assert(player.global_position.x >= 85.0 and player.global_position.y >= 535.0, "Canto Superior Esquerdo vedado: X=%f, Y=%f" % [player.global_position.x, player.global_position.y])

	# 7.2 Canto Superior Direito
	player.global_position = Vector2(1450, 600)
	for i in range(40):
		player.velocity = Vector2(350, -350)
		player.move_and_slide()
	_assert(player.global_position.x <= 1585.0 and player.global_position.y >= 535.0, "Canto Superior Direito vedado: X=%f, Y=%f" % [player.global_position.x, player.global_position.y])

	# 7.3 Canto Inferior Esquerdo
	player.global_position = Vector2(200, 750)
	for i in range(40):
		player.velocity = Vector2(-350, 350)
		player.move_and_slide()
	_assert(player.global_position.x >= 85.0 and player.global_position.y <= 835.0, "Canto Inferior Esquerdo vedado: X=%f, Y=%f" % [player.global_position.x, player.global_position.y])

	# 7.4 Canto Inferior Direito
	player.global_position = Vector2(1450, 750)
	for i in range(40):
		player.velocity = Vector2(350, 350)
		player.move_and_slide()
	_assert(player.global_position.x <= 1585.0 and player.global_position.y <= 835.0, "Canto Inferior Direito vedado: X=%f, Y=%f" % [player.global_position.x, player.global_position.y])

	# Teste 8: Circulação Livre ao Redor dos Dois Veículos
	print("\n--- Teste 8: Circulação ao Redor dos Veículos ---")
	# 8.1 Atrás do Carro Laranja (Fiesta)
	player.global_position = Vector2(480, 560)
	for i in range(15):
		player.velocity = Vector2(150, 0)
		player.move_and_slide()
	_assert(player.global_position.x > 500.0, "Player caminha livremente ATRÁS do Carro Laranja (Y=560)")

	# 8.2 Na Frente do Carro Laranja
	player.global_position = Vector2(480, 750)
	for i in range(15):
		player.velocity = Vector2(150, 0)
		player.move_and_slide()
	_assert(player.global_position.x > 500.0, "Player caminha livremente NA FRENTE do Carro Laranja (Y=750)")

	# 8.3 Atrás do Carro Azul (Escort)
	player.global_position = Vector2(1160, 560)
	for i in range(15):
		player.velocity = Vector2(150, 0)
		player.move_and_slide()
	_assert(player.global_position.x > 1180.0, "Player caminha livremente ATRÁS do Carro Azul (Y=560)")

	# 8.4 Na Frente do Carro Azul
	player.global_position = Vector2(1160, 750)
	for i in range(15):
		player.velocity = Vector2(150, 0)
		player.move_and_slide()
	_assert(player.global_position.x > 1180.0, "Player caminha livremente NA FRENTE do Carro Azul (Y=750)")

	garage.free()

	print("==================================================")
	print("RESULTADO FINAL: %d/%d PASSARAM (Falhas: %d)" % [_passed, _total, _failed])
	print("==================================================")

	if _failed > 0:
		quit(1)
	else:
		quit(0)

