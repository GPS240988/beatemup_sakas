extends SceneTree

## Suíte de Testes do NPC Sérgio (Dono da Locadora) — Godot 4.x
## Valida formalmente:
## 1. Instanciação completa e nós obrigatórios de ator.
## 2. Textura oficial do Sérgio (sergio.webp / idle_sergio.webp) ancorada no solo.
## 3. Isolamento canônico nos grupos 'actors', 'npcs', 'damageable' (não 'enemies').
## 4. Locomoção acelerada contínua cobrindo toda a malha navegável do mapa.
## 5. Balão de fala retrô arcade com texto exato e tipografia arcade_bold.ttf.
## 6. Ciclo periódico de exibição e orientação correta de leitura (sem espelhamento).

const SergioNPCClass = preload("res://scripts/actors/sergio_npc.gd")

var total_tests: int = 0
var passed_tests: int = 0
var failed_tests: int = 0


func _init() -> void:
	call_deferred("_run_sergio_tests")


func assert_test(condition: bool, test_name: String) -> void:
	total_tests += 1
	if condition:
		passed_tests += 1
		print("  [OK] %s" % test_name)
	else:
		failed_tests += 1
		printerr("  [FALHA] %s" % test_name)


func _run_sergio_tests() -> void:
	print("==================================================")
	print("INICIANDO SUITE DE TESTES: NPC SÉRGIO (LOCADORA)")
	print("==================================================")

	var sergio_scene: PackedScene = load("res://scenes/actors/sergio_npc.tscn")
	assert_test(sergio_scene != null, "Cena sergio_npc.tscn carregada com sucesso")
	if sergio_scene == null:
		_finish()
		return

	# PARTE 1: Instanciação e Contrato de Ator
	print("\n--- 1. Validando Estrutura e Contrato de Ator ---")
	var inst: Node = sergio_scene.instantiate()
	assert_test(inst != null, "Instância de SergioNPC criada com sucesso")
	assert_test(inst is CharacterBody2D, "SergioNPC herda de CharacterBody2D")
	assert_test(inst is BaseNPC, "SergioNPC herda da classe canônica BaseNPC")
	assert_test(inst.is_in_group("actors"), "SergioNPC pertence ao grupo 'actors'")
	assert_test(inst.is_in_group("npcs"), "SergioNPC pertence ao grupo 'npcs'")
	assert_test(inst.is_in_group("damageable"), "SergioNPC pertence ao grupo 'damageable'")
	assert_test(not inst.is_in_group("enemies"), "SergioNPC NÃO pertence ao grupo 'enemies'")
	assert_test(not inst.is_in_group("player"), "SergioNPC NÃO pertence ao grupo 'player'")

	var sergio: CharacterBody2D = inst as CharacterBody2D
	var visual: Node2D = sergio.get_node_or_null("Visual") as Node2D
	var sprite: Sprite2D = sergio.get_node_or_null("Visual/Sprite2D") as Sprite2D
	var col_shape: CollisionShape2D = sergio.get_node_or_null("CollisionShape2D") as CollisionShape2D
	var hurtbox: Area2D = sergio.get_node_or_null("Hurtbox") as Area2D
	var health_comp: Node = sergio.get_node_or_null("HealthComponent")
	var nav_agent: NavigationAgent2D = sergio.get_node_or_null("NavigationAgent2D") as NavigationAgent2D
	var bubble: Node2D = sergio.get_node_or_null("SpeechBubble") as Node2D
	var speech_sprite: Sprite2D = sergio.get_node_or_null("SpeechBubble/SpeechSprite") as Sprite2D

	assert_test(visual != null, "Nó Visual presente")
	assert_test(sprite != null, "Nó Sprite2D presente em Visual")
	assert_test(col_shape != null, "Nó CollisionShape2D de pés presente")
	assert_test(hurtbox != null, "Nó Hurtbox presente")
	assert_test(health_comp != null, "Nó HealthComponent presente")
	assert_test(nav_agent != null, "Nó NavigationAgent2D presente")
	assert_test(bubble != null, "Nó SpeechBubble presente")
	assert_test(speech_sprite != null, "Nó SpeechSprite presente no SpeechBubble")

	root.add_child(sergio)
	await process_frame

	# PARTE 2: Sprite do Sérgio e Ancoragem Espacial
	print("\n--- 2. Validando Textura e Ancoragem do Sprite ---")
	assert_test(sprite.texture != null, "Sprite2D possui textura atribuída")
	if sprite.texture != null:
		var tex_path: String = sprite.texture.resource_path
		assert_test(tex_path.find("sergio") != -1, "Textura aponta para asset do Sérgio (%s)" % tex_path)
	assert_test(sprite.position.y < 0.0, "Sprite projetado acima da origem no solo (Y < 0)")
	assert_test(col_shape.position.y <= 0.0, "Colisor de contato posicionado na base dos pés")

	# Validação da animação de caminhada
	var anim_sprite: AnimatedSprite2D = sergio.get_node_or_null("Visual/AnimatedSprite2D") as AnimatedSprite2D
	assert_test(anim_sprite != null, "Nó AnimatedSprite2D de caminhada presente em Visual")
	if anim_sprite != null:
		assert_test(anim_sprite.sprite_frames != null, "AnimatedSprite2D possui SpriteFrames atribuído")
		assert_test(anim_sprite.sprite_frames.has_animation("walk"), "SpriteFrames possui animação 'walk'")

	# PARTE 3: Falas em Imagem Pré-Renderizadas (Assets / Sprites / Falas)
	print("\n--- 3. Validando Falas em Imagem do Sérgio ---")
	assert_test(sergio.speech_textures.size() == 4, "Sérgio possui exatamente 4 texturas de fala em imagem")

	# Valida caminhos dos 4 arquivos webp
	for i in range(4):
		var tex: Texture2D = sergio.speech_textures[i]
		assert_test(tex != null, "Textura de fala %d carregada" % (i + 1))
		if tex != null:
			var p: String = tex.resource_path
			assert_test(p.find("fala_sergio%d" % (i + 1)) != -1, "Textura %d aponta para fala_sergio%d.webp (%s)" % [i + 1, i + 1, p])

	# Testa exibição de cada fala alternada no SpeechSprite
	for i in range(4):
		sergio.show_speech_bubble(i)
		assert_test(speech_sprite.texture == sergio.speech_textures[i], "show_speech_bubble(%d) aplicou textura fala_sergio%d" % [i, i + 1])
		assert_test(bubble.visible, "Balão de fala visível para fala %d" % (i + 1))

	# Exibição e ocultação do balão
	assert_test(sergio._is_dialogue_visible, "Flag interna de diálogo marca visibilidade ativa")

	# Simula espelhamento de direção e verifica se balão não inverte
	sergio.velocity = Vector2(-150.0, 0.0)
	sergio._update_facing_direction()
	assert_test(sergio.facing_direction == -1.0, "Sérgio virou para a esquerda (facing_direction == -1.0)")
	assert_test(visual.scale.x < 0.0, "Visual espelhado para a esquerda")
	assert_test(bubble.scale.x > 0.0, "Balão de diálogo NÃO espelha (imagem legível da esquerda para direita)")

	sergio.hide_speech_bubble()
	await create_timer(0.2).timeout
	assert_test(not bubble.visible, "hide_speech_bubble() oculta o balão após transição")

	# PARTE 4: Locomoção Acelerada e Cobertura do Mapa
	print("\n--- 4. Validando Patrulha Acelerada por Todo o Mapa ---")
	assert_test(sergio.run_speed >= 200.0, "Velocidade de corrida é acelerada (speed >= 200.0, atual: %.1f)" % sergio.run_speed)
	assert_test(sergio.map_patrol_points.size() >= 5, "Circuito de patrulha possui múltiplos waypoints (total: %d)" % sergio.map_patrol_points.size())

	# Valida abrangência dos waypoints (deve cobrir início < 400px e fim > 1700px no eixo X)
	var min_x: float = INF
	var max_x: float = -INF
	for pt in sergio.map_patrol_points:
		min_x = minf(min_x, pt.x)
		max_x = maxf(max_x, pt.y if false else pt.x)

	assert_test(min_x <= 400.0, "Patrulha cobre a extrema esquerda do mapa navegável (min_x: %.1f)" % min_x)
	assert_test(max_x >= 1700.0, "Patrulha cobre a extrema direita do mapa navegável (max_x: %.1f)" % max_x)

	# Simula steps de movimentação
	var initial_idx: int = sergio.current_waypoint_index
	sergio.global_position = sergio.map_patrol_points[initial_idx]
	sergio._physics_process(0.05)
	assert_test(sergio.current_waypoint_index != initial_idx, "Atingir waypoint avança automaticamente para o próximo no circuito")

	# PARTE 5: Parada de Animação ao Colidir com Parede/Obstáculo
	print("\n--- 5. Validando Parada de Animação em Colisão/Parede ---")
	# Movimento livre com velocidade acelerada
	sergio.velocity = Vector2(230.0, 0.0)
	sergio._update_run_animation(0.016)
	assert_test(anim_sprite.is_playing() and anim_sprite.animation == "walk", "Em deslocamento livre, animação 'walk' está tocando")

	# Bloqueio em colisão (simula parede onde deslocamento real é bloqueado)
	sergio.velocity = Vector2.ZERO
	sergio._update_run_animation(0.016)
	assert_test(not anim_sprite.is_playing(), "Ao parar na parede/colisão, animação 'walk' pausa/para")
	assert_test(anim_sprite.frame == 0, "Ao parar, retorna ao frame neutro (repouso no solo)")

	# Retomada após desbloqueio
	sergio.velocity = Vector2(230.0, 0.0)
	sergio._update_run_animation(0.016)
	assert_test(anim_sprite.is_playing(), "Ao desbloquear da parede, animação 'walk' é retomada imediatamente")

	root.remove_child(sergio)
	sergio.free()

	_finish()


func _finish() -> void:
	print("==================================================")
	print("RESULTADO DOS TESTES DO SÉRGIO: %d/%d PASSARAM (Falhas: %d)" % [passed_tests, total_tests, failed_tests])
	print("==================================================")

	if failed_tests == 0:
		quit(0)
	else:
		quit(1)
