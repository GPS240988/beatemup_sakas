extends SceneTree

## Suíte de Testes Automatizados Headless: Contrato Visual e de Animação do Jogador
## Projeto Sakas — Beat 'em Up 2.5D (Godot 4.x)
##
## Valida rigorosamente:
## 1. Resolução e formato de todos os sprites PNG do herói (220×300 px, RGBA, fundo transparente)
## 2. Linha de base de contato dos pés (tolerância declarada de contato com solo Y=300)
## 3. Configuração canônica do SpriteFrames (nomes, contagem de quadros, loop e FPS)
## 4. Estabilidade geométrica e de escala da cena do jogador durante locomoção e combate

const PlayerScene: PackedScene = preload("res://scenes/actors/player/player.tscn")

var passed: int = 0
var failed: int = 0


func _init() -> void:
	call_deferred("_run_animation_contract_tests")


func assert_test(condition: bool, message: String) -> void:
	if condition:
		passed += 1
		print("  [OK] %s" % message)
	else:
		failed += 1
		printerr("  [FALHA] %s" % message)


func _run_animation_contract_tests() -> void:
	print("==================================================")
	print("INICIANDO SUITE DE TESTES: CONTRATO DE ANIMAÇÃO DO JOGADOR")
	print("==================================================")

	test_sprite_dimensions_and_channels()
	test_ground_baseline_consistency()
	test_sprite_frames_configuration()
	test_player_scene_transforms_and_scale()

	print("==================================================")
	print("RESULTADO DO CONTRATO DE ANIMAÇÃO: %d PASSARAM (Falhas: %d)" % [passed, failed])
	print("==================================================")

	if failed > 0:
		quit(1)
	else:
		quit(0)


## 1. Validação de Dimensões, Resolução e Canal Alfa dos Sprites PNG
func test_sprite_dimensions_and_channels() -> void:
	print("\n--- 1. Validando Resolução e Formato dos Sprites (assets/sprites/characters/guilherme/) ---")
	var base_path: String = "res://assets/sprites/characters/guilherme/"
	var dir := DirAccess.open(base_path)
	if dir == null:
		printerr("  [FALHA] Não foi possível acessar o diretório de sprites: %s" % base_path)
		failed += 1
		return

	dir.list_dir_begin()
	var file_name: String = dir.get_next()
	var png_count: int = 0

	# Exceções declaradas de largura para poses deitadas no chão (chassi horizontal)
	var horizontal_exceptions: Array[String] = ["death.png", "fall_03.png"]

	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".png") and not file_name.ends_with(".import"):
			png_count += 1
			var file_path: String = base_path + file_name
			var img := Image.load_from_file(ProjectSettings.globalize_path(file_path))

			if img != null:
				var width: int = img.get_width()
				var height: int = img.get_height()

				# Altura deve ser estritamente 300 px
				var height_ok: bool = (height == 300)
				# Largura: 220 px para poses de pé, ou 260 px para exceções de chão deitadas
				var width_ok: bool = false
				if file_name in horizontal_exceptions:
					width_ok = (width == 260 or width == 220)
				else:
					width_ok = (width == 220)

				var has_alpha: bool = (img.detect_alpha() != Image.ALPHA_NONE)

				assert_test(
					height_ok and width_ok and has_alpha,
					"Sprite '%s': dimensões=(%d×%d px), alfa=%s" % [file_name, width, height, str(has_alpha)]
				)
			else:
				printerr("  [FALHA] Falha ao ler imagem: %s" % file_name)
				failed += 1

		file_name = dir.get_next()

	dir.list_dir_end()
	assert_test(png_count >= 30, "Total de sprites PNG verificados: %d (mínimo esperado: 30)" % png_count)


## 2. Linha de Base dos Pés de Apoio (Piso Y = 0 no Mundo)
func test_ground_baseline_consistency() -> void:
	print("\n--- 2. Validando Linha de Base dos Pés de Apoio (Piso Y = 300 no Canvas) ---")
	var base_path: String = "res://assets/sprites/characters/guilherme/"
	var ground_sprites: Array[String] = [
		"idle.png",
		"walk1.png", "walk2.png", "walk3.png", "walk4.png",
		"punch_01.png", "punch_02.png", "punch_03.png",
		"kick_01.png",
		"heavy_01.png", "heavy_02.png", "heavy_03.png", "heavy_04.png", "heavy_05.png", "heavy_06.png",
		"guard.png",
		"hurt_01.png", "hurt_02.png"
	]

	# Tolerância pequena declarada de até 20 pixels na base do canvas para contato no solo
	const MAX_BASELINE_GAP: int = 20

	for sprite_name: String in ground_sprites:
		var file_path: String = base_path + sprite_name
		var img := Image.load_from_file(ProjectSettings.globalize_path(file_path))
		if img == null:
			printerr("  [FALHA] Falha ao carregar imagem para teste de base: %s" % sprite_name)
			failed += 1
			continue

		var used_rect: Rect2i = img.get_used_rect()
		var bottom_y: int = used_rect.position.y + used_rect.size.y
		var gap: int = 300 - bottom_y

		assert_test(
			gap >= 0 and gap <= MAX_BASELINE_GAP,
			"Sprite '%s': pixel mais baixo Y=%d (gap da base=%d px <= %d px)" % [sprite_name, bottom_y, gap, MAX_BASELINE_GAP]
		)


## 3. Configuração Aprovada do SpriteFrames do Player
func test_sprite_frames_configuration() -> void:
	print("\n--- 3. Validando SpriteFrames do Jogador (Contagem de Quadros e Nomes) ---")
	var player_instance := PlayerScene.instantiate() as PlayerController
	root.add_child(player_instance)

	var anim_sprite: AnimatedSprite2D = player_instance.get_node_or_null("Visual/AnimatedSprite2D") as AnimatedSprite2D
	assert_test(anim_sprite != null and anim_sprite.sprite_frames != null, "AnimatedSprite2D e SpriteFrames carregados")

	if anim_sprite != null and anim_sprite.sprite_frames != null:
		var sf: SpriteFrames = anim_sprite.sprite_frames

		var expected_animations: Dictionary = {
			"idle": 1,
			"walk": 4,
			"punch": 3,
			"kick": 3,
			"heavy": 6,   # Novo conjunto aprovado com 6 sprites!
			"guard": 1,
			"hurt": 2,
			"fall": 3,
			"getup": 2,
			"death": 1,
			"jump": 3,
			"jump_atk": 2
		}

		for anim_name: String in expected_animations.keys():
			var expected_count: int = expected_animations[anim_name]
			if sf.has_animation(anim_name):
				var actual_count: int = sf.get_frame_count(anim_name)
				assert_test(
					actual_count == expected_count,
					"Animação '%s': quadros=%d (esperado=%d)" % [anim_name, actual_count, expected_count]
				)
			else:
				printerr("  [FALHA] Animação ausente no SpriteFrames: %s" % anim_name)
				failed += 1

		# Valida loop da animação heavy (deve ser false para ataque de impacto único)
		assert_test(not sf.get_animation_loop("heavy"), "Animação 'heavy' não deve repetir em loop")
		assert_test(sf.get_animation_speed("heavy") >= 9.0, "Animação 'heavy' velocidade >= 9.0 FPS")

	player_instance.queue_free()


## 4. Estabilidade Geométrica e Escala da Cena do Jogador
func test_player_scene_transforms_and_scale() -> void:
	print("\n--- 4. Validando Posição, Escala Fixa e Estabilidade Durante Ataques ---")
	var player_instance := PlayerScene.instantiate() as PlayerController
	root.add_child(player_instance)

	var visual_root: Node2D = player_instance.get_node_or_null("Visual") as Node2D
	assert_test(visual_root != null, "Nó Visual existe na cena do Player")

	if visual_root != null:
		# Escala padrão do nó Visual não deve ter compressões distorcidas no eixo Y
		assert_test(
			is_equal_approx(absf(visual_root.scale.y), 1.0),
			"Escala vertical do nó Visual é 1.0 (sem compressão estática)"
		)

		# Posição vertical inicial do visual no solo
		assert_test(
			is_equal_approx(visual_root.position.y, 0.0),
			"Posição Y do nó Visual inicia em 0.0 (contato dos pés com chão)"
		)

		# Executa golpe pesado (heavy) e verifica estabilidade da escala
		player_instance._execute_combo_attack(3) # Heavy / Finisher
		assert_test(
			is_equal_approx(absf(visual_root.scale.y), 1.0),
			"Escala vertical mantida em 1.0 durante a execução do golpe pesado"
		)
		assert_test(
			is_equal_approx(visual_root.position.y, 0.0),
			"Posição Y do nó Visual mantida em 0.0 durante golpe pesado no solo"
		)

		# Verifica que a virada de lado (flip) altera apenas o sinal de scale.x
		player_instance._update_facing_direction(-1.0)
		assert_test(visual_root.scale.x < 0.0, "Virar para a esquerda inverte apenas scale.x")
		assert_test(
			is_equal_approx(visual_root.scale.y, 1.0),
			"scale.y permanece estritamente 1.0 ao virar para a esquerda"
		)

	player_instance.queue_free()
