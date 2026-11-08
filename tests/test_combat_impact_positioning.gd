extends SceneTree

## Suíte Automatizada de Validação do Posicionamento e Bidirecionalidade dos Impactos de Combate
## Valida rigorosamente os 9 cenários mandatórios do Prompt de Auditoria de Impactos (Projeto Sakas).

const PlayerScene: PackedScene = preload("res://scenes/actors/player/player.tscn")
const BasicEnemyScene: PackedScene = preload("res://scenes/actors/enemies/basic_enemy.tscn")
const BossAlessandroScene: PackedScene = preload("res://scenes/actors/enemies/boss_alessandro.tscn")
const ImpactZonesClass = preload("res://scripts/combat/impact_zones.gd")
const CombatFeedbackClass = preload("res://scripts/combat/combat_feedback.gd")
const DamageInfoClass = preload("res://scripts/combat/damage_info.gd")

var _total: int = 0
var _passed: int = 0
var _failed: int = 0


func assert_test(cond: bool, msg: String) -> void:
	_total += 1
	if cond:
		_passed += 1
		print("  [OK] %s" % msg)
	else:
		_failed += 1
		printerr("  [FALHA] %s" % msg)


func _init() -> void:
	print("\n" + "=".repeat(75))
	print("SUÍTE DE TESTES: AUDITORIA E POSICIONAMENTO REAL DE IMPACTOS (SAKAS)")
	print("=".repeat(75))
	call_deferred("_run_suite")


func _run_suite() -> void:
	# -------------------------------------------------------------
	# Instanciação dos atores de teste
	# -------------------------------------------------------------
	var player: PlayerController = PlayerScene.instantiate() as PlayerController
	var enemy: EnemyAI = BasicEnemyScene.instantiate() as EnemyAI
	root.add_child(player)
	root.add_child(enemy)

	# -------------------------------------------------------------
	# Cenário 1: Jogador acerta inimigo com soco alto (Jab) -> Efeito na cabeça do inimigo
	# -------------------------------------------------------------
	print("\n--- Cenário 1: Jogador Acerta Inimigo com Soco Alto (Cabeça) ---")
	player.global_position = Vector2(200, 300)
	enemy.global_position = Vector2(270, 300) # Inimigo à direita do jogador

	var jab_res: Dictionary = ImpactZonesClass.resolve_impact_on_target(
		enemy,
		player.global_position + Vector2(40.0, -125.0), # Hitbox do Jab (-125px)
		Vector2(85.0, 60.0),
		["head", "upper_torso"],
		1.0,
		"punch",
		player.global_position
	)

	assert_test(jab_res.region == "head", "C1: Soco alto (Jab) identifica região anatômica 'head'")
	# Para Jogador de Magic: head_bottom_y = -125.0, logo Y <= 300 - 125 = 175
	assert_test(jab_res.position.y <= enemy.global_position.y - 125.0, "C1: Coordenada Y do efeito está na cabeça do inimigo (Y <= -125px)")
	# Inset de contato no lado voltado para o jogador (lado esquerdo do inimigo: base_x - 16px)
	assert_test(is_equal_approx(jab_res.position.x, enemy.global_position.x - 16.0), "C1: Coordenada X posicionada na face de contato esquerda do inimigo (270 - 16 = 254)")
	assert_test(jab_res.position.x > player.global_position.x, "C1: Efeito posicionado no corpo do inimigo, NÃO próximo ao atacante")

	# -------------------------------------------------------------
	# Cenário 2: Jogador acerta inimigo com soco médio (Cross) -> Efeito no tórax do inimigo
	# -------------------------------------------------------------
	print("\n--- Cenário 2: Jogador Acerta Inimigo com Soco Médio (Tórax) ---")
	var cross_res: Dictionary = ImpactZonesClass.resolve_impact_on_target(
		enemy,
		player.global_position + Vector2(40.0, -110.0), # Hitbox do Cross (-110px)
		Vector2(90.0, 50.0),
		["upper_torso", "head"],
		1.0,
		"punch",
		player.global_position
	)

	assert_test(cross_res.region == "upper_torso", "C2: Soco médio (Cross) identifica região 'upper_torso'")
	assert_test(cross_res.position.y > enemy.global_position.y - 125.0 and cross_res.position.y <= enemy.global_position.y - 85.0, "C2: Coordenada Y está na faixa do tórax superior [-125, -85]")
	assert_test(cross_res.position.y != jab_res.position.y, "C2: Coordenada Y de soco médio é geometricamente distinta do soco alto")

	# -------------------------------------------------------------
	# Cenário 3: Jogador acerta inimigo com chute (Kick) -> Efeito no tronco inferior / cintura
	# -------------------------------------------------------------
	print("\n--- Cenário 3: Jogador Acerta Inimigo com Chute (Cintura/Tronco Inferior) ---")
	var kick_res: Dictionary = ImpactZonesClass.resolve_impact_on_target(
		enemy,
		player.global_position + Vector2(40.0, -70.0), # Hitbox do Kick (-70px)
		Vector2(105.0, 55.0),
		["lower_torso"],
		1.0,
		"kick",
		player.global_position
	)

	assert_test(kick_res.region == "lower_torso", "C3: Chute identifica região 'lower_torso'")
	assert_test(kick_res.position.y > enemy.global_position.y - 85.0 and kick_res.position.y <= enemy.global_position.y - 45.0, "C3: Coordenada Y está na faixa do tronco inferior [-85, -45]")
	assert_test(kick_res.position.y > cross_res.position.y, "C3: Efeito do chute é verticalmente mais baixo que o soco no tórax")

	# -------------------------------------------------------------
	# Cenário 4: Jogador acerta golpe pesado (Finisher) -> Efeito de alto impacto na região correta
	# -------------------------------------------------------------
	print("\n--- Cenário 4: Jogador Acerta Golpe Pesado / Finisher ---")
	var finisher_res: Dictionary = ImpactZonesClass.resolve_impact_on_target(
		enemy,
		player.global_position + Vector2(40.0, -120.0), # Hitbox do Finisher (-120px)
		Vector2(115.0, 65.0),
		["upper_torso", "head"],
		1.0,
		"finisher",
		player.global_position
	)

	assert_test(finisher_res.region in ["upper_torso", "head"], "C4: Finisher identifica região de alto impacto (upper_torso ou head)")
	assert_test(finisher_res.position.y <= enemy.global_position.y - 95.0, "C4: Coordenada Y respeita centro de massa superior do impacto")

	# -------------------------------------------------------------
	# Cenário 5: Inimigo acerta jogador (alto) -> Efeito na cabeça do jogador
	# -------------------------------------------------------------
	print("\n--- Cenário 5: Inimigo Acerta Jogador (Alto / Cabeça) ---")
	# Inimigo ataca jogador posicionado à esquerda
	enemy.global_position = Vector2(400, 300)
	player.global_position = Vector2(330, 300) # Jogador à esquerda do inimigo

	var enemy_hit_head: Dictionary = ImpactZonesClass.resolve_impact_on_target(
		player,
		enemy.global_position + Vector2(-35.0, -170.0), # Golpe alto do inimigo direcionado à cabeça
		Vector2(80.0, 50.0),
		["head", "upper_torso"],
		-1.0,
		"punch",
		enemy.global_position
	)

	assert_test(enemy_hit_head.region == "head", "C5: Inimigo acertando alto identifica cabeça do jogador ('head')")
	# Player é perfil STANDARD_220_300: head_bottom_y = -155.0
	assert_test(enemy_hit_head.position.y <= player.global_position.y - 155.0, "C5: Coordenada Y do efeito está na cabeça do jogador (Y <= -155px)")
	# Inimigo está à direita (X=400 > X=330), logo o contato é na face DIREITA do jogador (330 + 18 = 348)
	assert_test(is_equal_approx(enemy_hit_head.position.x, player.global_position.x + 18.0), "C5: Coordenada X na face de contato correta do jogador voltada para o inimigo (330 + 18 = 348)")
	assert_test(enemy_hit_head.position.x < enemy.global_position.x, "C5: Efeito no corpo do jogador, NÃO próximo ao atacante")

	# -------------------------------------------------------------
	# Cenário 6: Inimigo acerta jogador (médio/baixo) -> Efeito no tronco do jogador
	# -------------------------------------------------------------
	print("\n--- Cenário 6: Inimigo Acerta Jogador (Médio/Baixo / Tronco) ---")
	var enemy_hit_torso: Dictionary = ImpactZonesClass.resolve_impact_on_target(
		player,
		enemy.global_position + Vector2(-35.0, -80.0), # Golpe baixo/médio do inimigo
		Vector2(80.0, 50.0),
		["lower_torso"],
		-1.0,
		"kick",
		enemy.global_position
	)

	assert_test(enemy_hit_torso.region == "lower_torso", "C6: Golpe baixo do inimigo identifica tronco inferior/cintura do jogador ('lower_torso')")
	# Player standard: lower_torso faixa [-105, -55]
	assert_test(enemy_hit_torso.position.y > player.global_position.y - 105.0 and enemy_hit_torso.position.y <= player.global_position.y - 55.0, "C6: Coordenada Y na cintura do jogador [-105, -55]")
	assert_test(is_equal_approx(enemy_hit_torso.position.x, player.global_position.x + 18.0), "C6: Posição horizontal na borda direita do jogador voltada para o atacante")

	# -------------------------------------------------------------
	# Cenário 7: Golpes com lado invertido (atacante à direita) -> Posição e espelhamento corretos
	# -------------------------------------------------------------
	print("\n--- Cenário 7: Golpes com Lado Invertido (Simetria Bidirecional) ---")
	# Jogador à direita do inimigo (atacando para a esquerda)
	player.global_position = Vector2(500, 300)
	enemy.global_position = Vector2(430, 300)

	var inverted_res: Dictionary = ImpactZonesClass.resolve_impact_on_target(
		enemy,
		player.global_position + Vector2(-40.0, -110.0),
		Vector2(85.0, 60.0),
		["upper_torso"],
		-1.0,
		"punch",
		player.global_position
	)

	# Inimigo está à esquerda do jogador (430 < 500), logo o lado atingido é a face DIREITA do inimigo (430 + 16 = 446)
	assert_test(is_equal_approx(inverted_res.position.x, enemy.global_position.x + 16.0), "C7: Impacto invertido gerado na borda direita do inimigo (430 + 16 = 446)")
	assert_test(inverted_res.position.x < player.global_position.x, "C7: Efeito posicionado no inimigo, NÃO próximo ao jogador atacante")

	# Testa instanciação com espelhamento visual correto
	var vfx_holder := Node2D.new()
	root.add_child(vfx_holder)

	var dir_left := Vector2(-1.0, 0.0)
	var dir_right := Vector2(1.0, 0.0)
	CombatFeedbackClass.spawn_hit_spark(vfx_holder, inverted_res.position, dir_left, "punch")
	await process_frame

	var pool_node: Node = root.find_child("_Pool_HitSparks", true, false)
	var spark_inverted: AnimatedSprite2D = null
	if pool_node != null:
		for child in pool_node.get_children():
			var spr := child as AnimatedSprite2D
			if spr != null and spr.visible:
				spark_inverted = spr
				break

	assert_test(spark_inverted != null, "C7: Faísca de impacto instanciada via ObjectPool")
	if spark_inverted != null:
		assert_test(spark_inverted.scale.x < 0.0, "C7: Escala X invertida (negativa) para golpe desferido para a esquerda")
		assert_test(spark_inverted.global_position == inverted_res.position, "C7: Posição global da faísca exatamente coincidente com ponto de contato anatômico")
		# Verifica que a compensação horizontal offset não causa desvio falso
		assert_test(spark_inverted.offset.x == 0.0 or is_equal_approx(absf(spark_inverted.offset.x), 0.0), "C7: Efeito blunt_hit possui offset.x nulo, garantindo centro perfeito em ambas as direções")

	vfx_holder.queue_free()

	# -------------------------------------------------------------
	# Cenário 8: Whiff (golpe sem contato) -> Nenhum efeito instanciado
	# -------------------------------------------------------------
	print("\n--- Cenário 8: Isolamento de Whiff (Golpe Sem Contato) ---")
	# Posiciona o jogador a 1000px de distância de qualquer inimigo
	player.global_position = Vector2(1500, 300)
	enemy.global_position = Vector2(100, 300)

	var target_hit_occurred: bool = false
	var on_target_hit := func(_target: Node, _dmg: float):
		target_hit_occurred = true
	player.melee_attack.target_hit.connect(on_target_hit)

	# Executa soco no ar (whiff)
	player.melee_attack.cancel_attack()
	var attack_executed: bool = player.melee_attack.execute_attack(1.0)
	assert_test(attack_executed, "C8: Ataque no ar disparado")
	await process_frame

	assert_test(not target_hit_occurred, "C8: Sinal target_hit NÃO emitido durante ataque no ar")
	assert_test(player.melee_attack.hit_targets.is_empty(), "C8: Lista de alvos atingidos vazia (Whiff estrito)")

	player.melee_attack.target_hit.disconnect(on_target_hit)

	# -------------------------------------------------------------
	# Cenário 9: Ataque em área (Especial) -> Efeitos em cada inimigo atingido
	# -------------------------------------------------------------
	print("\n--- Cenário 9: Ataque em Área (Golpe Especial) ---")
	var enemy2: EnemyAI = BasicEnemyScene.instantiate() as EnemyAI
	root.add_child(enemy2)

	player.global_position = Vector2(500, 300)
	enemy.global_position = Vector2(400, 300) # Inimigo 1 à esquerda do player
	enemy2.global_position = Vector2(600, 300) # Inimigo 2 à direita do player

	# Resolve o especial para cada inimigo atingido
	var spec1: Dictionary = ImpactZonesClass.resolve_impact_on_target(
		enemy,
		enemy.global_position + Vector2(0, -110),
		Vector2(100, 100),
		["upper_torso", "head"],
		-1.0,
		"special",
		player.global_position
	)
	var spec2: Dictionary = ImpactZonesClass.resolve_impact_on_target(
		enemy2,
		enemy2.global_position + Vector2(0, -110),
		Vector2(100, 100),
		["upper_torso", "head"],
		1.0,
		"special",
		player.global_position
	)

	assert_test(spec1.region in ["upper_torso", "head"], "C9: Inimigo 1 (à esquerda) resolve região anatômica correta")
	assert_test(spec2.region in ["upper_torso", "head"], "C9: Inimigo 2 (à direita) resolve região anatômica correta")
	assert_test(spec1.position.x < player.global_position.x, "C9: Efeito no Inimigo 1 posicionado no corpo do Inimigo 1 (< Player.X)")
	assert_test(spec2.position.x > player.global_position.x, "C9: Efeito no Inimigo 2 posicionado no corpo do Inimigo 2 (> Player.X)")
	# Inimigo 1 está à esquerda do player, logo recebe impacto na borda direita voltada para o player (400 + 16 = 416)
	assert_test(is_equal_approx(spec1.position.x, enemy.global_position.x + 16.0), "C9: Inimigo 1 recebe impacto na borda voltada para o herói (400 + 16 = 416)")
	# Inimigo 2 está à direita do player, logo recebe impacto na borda esquerda voltada para o herói (600 - 16 = 584)
	assert_test(is_equal_approx(spec2.position.x, enemy2.global_position.x - 16.0), "C9: Inimigo 2 recebe impacto na borda voltada para o herói (600 - 16 = 584)")

	# Limpeza
	player.queue_free()
	enemy.queue_free()
	enemy2.queue_free()

	print("\n" + "=".repeat(75))
	print("RESULTADO DOS TESTES DE IMPACTO: %d/%d PASSARAM (Falhas: %d)" % [_passed, _total, _failed])
	print("=".repeat(75) + "\n")

	quit(0 if _failed == 0 else 1)
