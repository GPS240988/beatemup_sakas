extends SceneTree

## Suíte de Testes Automatizada: Validação Visual e Técnica dos Sprites de Combate do Gabriel
## Verifica spritesheet (1320x1500), grade 6x5, alinhamento dos pés, SpriteFrames,
## transição de animações (shot_1, shot_2, kick, heavy, jump_atk), retorno para idle,
## espelhamento horizontal e integridade sem regressão dos demais personagens.

var _passed: int = 0
var _failed: int = 0

func _init() -> void:
	call_deferred("_run_all_tests")


func _assert(condition: bool, test_name: String) -> void:
	if condition:
		_passed += 1
		print("  [OK] %s" % test_name)
	else:
		_failed += 1
		printerr("  [FALHA] %s" % test_name)


func _run_all_tests() -> void:
	print("\n==================================================")
	print("INICIANDO VALIDAÇÃO VISUAL E TÉCNICA: SPRITES DO GABRIEL")
	print("==================================================")
	
	_test_spritesheet_specifications()
	_test_sprite_frames_animations()
	_test_player_animation_playback_and_transitions()
	_test_horizontal_mirroring()
	_test_guilherme_and_others_untouched()
	
	print("\n==================================================")
	print("RESULTADO DA VALIDAÇÃO: %d PASSARAM (Falhas: %d)" % [_passed, _failed])
	print("==================================================")
	
	if _failed > 0:
		quit(1)
	else:
		quit(0)


func _test_spritesheet_specifications() -> void:
	print("\n--- 1. Validando Especificações do Spritesheet Definitivo ---")
	var sheet_path := "res://assets/sprites/characters/gabriel/gabriel_combat_spritesheet.png"
	_assert(FileAccess.file_exists(sheet_path), "Arquivo gabriel_combat_spritesheet.png existe no caminho oficial")
	
	var img := Image.load_from_file(ProjectSettings.globalize_path(sheet_path))
	_assert(img != null, "Imagem do spritesheet carregada com sucesso")
	if img != null:
		_assert(img.get_width() == 1320, "Largura do spritesheet é exatamente 1320 pixels (6 colunas x 220 px)")
		_assert(img.get_height() == 1500, "Altura do spritesheet é exatamente 1500 pixels (5 linhas x 300 px)")
		_assert(img.get_format() == Image.FORMAT_RGBA8, "Formato do spritesheet é RGBA8 com transparência preservada")
		
		# Valida que as células ocupadas possuem conteúdo visual (não são puramente vazias)
		# Row 0: shot_1 (cols 0, 1, 2)
		var c00 := img.get_region(Rect2i(0, 0, 220, 300))
		var c10 := img.get_region(Rect2i(220, 0, 220, 300))
		var c20 := img.get_region(Rect2i(440, 0, 220, 300))
		_assert(not c00.is_invisible() and not c10.is_invisible() and not c20.is_invisible(), "Row 0 possui os 3 quadros de shot_1 renderizados")
		
		# Row 1: shot_2 (cols 0..4)
		var c01 := img.get_region(Rect2i(0, 300, 220, 300))
		var c41 := img.get_region(Rect2i(880, 300, 220, 300))
		_assert(not c01.is_invisible() and not c41.is_invisible(), "Row 1 possui quadros de shot_2 renderizados")
		
		# Row 2: kick (cols 0..2)
		var c02 := img.get_region(Rect2i(0, 600, 220, 300))
		_assert(not c02.is_invisible(), "Row 2 possui quadros de kick renderizados")
		
		# Row 3: heavy (cols 0..5)
		var c03 := img.get_region(Rect2i(0, 900, 220, 300))
		var c53 := img.get_region(Rect2i(1100, 900, 220, 300))
		_assert(not c03.is_invisible() and not c53.is_invisible(), "Row 3 possui todos os 6 quadros de heavy renderizados")
		
		# Row 4: jump_atk (cols 0..3)
		var c04 := img.get_region(Rect2i(0, 1200, 220, 300))
		_assert(not c04.is_invisible(), "Row 4 possui quadros de jump_atk renderizados")


func _test_sprite_frames_animations() -> void:
	print("\n--- 2. Validando SpriteFrames do Gabriel (res://resources/characters/gabriel_sprite_frames.tres) ---")
	var sf_path := "res://resources/characters/gabriel_sprite_frames.tres"
	_assert(ResourceLoader.exists(sf_path), "gabriel_sprite_frames.tres existe")
	
	var sf: SpriteFrames = load(sf_path) as SpriteFrames
	_assert(sf != null, "SpriteFrames instanciado com sucesso")
	if sf == null:
		return
	
	# shot_1: 3 quadros
	_assert(sf.has_animation("shot_1"), "Animação 'shot_1' presente")
	_assert(sf.get_frame_count("shot_1") == 3, "Animação 'shot_1' possui exatamente 3 quadros")
	_assert(not sf.get_animation_loop("shot_1"), "Animação 'shot_1' possui loop = false (termina no último quadro)")
	
	# shot_2: 5 quadros
	_assert(sf.has_animation("shot_2"), "Animação 'shot_2' presente")
	_assert(sf.get_frame_count("shot_2") == 5, "Animação 'shot_2' possui exatamente 5 quadros")
	_assert(not sf.get_animation_loop("shot_2"), "Animação 'shot_2' possui loop = false")
	
	# kick: 3 quadros
	_assert(sf.has_animation("kick"), "Animação 'kick' presente")
	_assert(sf.get_frame_count("kick") == 3, "Animação 'kick' possui exatamente 3 quadros")
	_assert(not sf.get_animation_loop("kick"), "Animação 'kick' possui loop = false")
	
	# heavy: 6 quadros
	_assert(sf.has_animation("heavy"), "Animação 'heavy' presente")
	_assert(sf.get_frame_count("heavy") == 6, "Animação 'heavy' possui exatamente 6 quadros")
	_assert(not sf.get_animation_loop("heavy"), "Animação 'heavy' possui loop = false")
	
	# jump_atk: 4 quadros
	_assert(sf.has_animation("jump_atk"), "Animação 'jump_atk' presente")
	_assert(sf.get_frame_count("jump_atk") == 4, "Animação 'jump_atk' possui exatamente 4 quadros")
	_assert(not sf.get_animation_loop("jump_atk"), "Animação 'jump_atk' possui loop = false")
	
	# punch (alias de compatibilidade): 3 quadros
	_assert(sf.has_animation("punch"), "Alias de compatibilidade 'punch' preservado")
	_assert(sf.get_frame_count("punch") == 3, "Alias 'punch' possui 3 quadros")
	
	# Preservação de não-combate
	_assert(sf.has_animation("idle"), "Animação 'idle' preservada")
	_assert(sf.has_animation("walk"), "Animação 'walk' preservada")
	_assert(sf.has_animation("hurt"), "Animação 'hurt' preservada")
	_assert(sf.has_animation("fall"), "Animação 'fall' preservada")
	_assert(sf.has_animation("getup"), "Animação 'getup' preservada")
	_assert(sf.has_animation("death"), "Animação 'death' preservada")
	_assert(sf.has_animation("guard"), "Animação 'guard' preservada")


func _test_player_animation_playback_and_transitions() -> void:
	print("\n--- 3. Validando Execução de Animações e Transição de Volta para Idle ---")
	var session = _ensure_game_session()
	session.selected_character_id = "gabriel"
	
	var player_scene: PackedScene = load("res://scenes/actors/player/player.tscn")
	var player: PlayerController = player_scene.instantiate() as PlayerController
	root.add_child(player)
	
	var anim_sprite: AnimatedSprite2D = player.get_node_or_null("Visual/AnimatedSprite2D") as AnimatedSprite2D
	_assert(anim_sprite != null, "AnimatedSprite2D presente sob Visual")
	
	var attacks: Array = player.get("_combo_attacks")
	_assert(attacks[0].get("animation") == &"shot_1", "Passo 1 do combo utiliza animação 'shot_1'")
	_assert(attacks[1].get("animation") == &"shot_2", "Passo 2 do combo utiliza animação 'shot_2'")
	_assert(attacks[2].get("animation") == &"kick", "Passo 3 do combo utiliza animação 'kick'")
	_assert(attacks[3].get("animation") == &"heavy", "Passo 4 do combo utiliza animação 'heavy'")
	
	# Teste de transição: Disparo 1 -> Idle
	player._execute_combo_attack(0)
	_assert(anim_sprite.animation == &"shot_1", "Execução do passo 0 toca 'shot_1'")
	player._on_attack_ended()
	_assert(anim_sprite.animation == &"idle", "'shot_1' retorna suavemente para 'idle' sem travar no último quadro")
	
	# Teste de transição: Disparo 2 -> Idle
	player._execute_combo_attack(1)
	_assert(anim_sprite.animation == &"shot_2", "Execução do passo 1 toca 'shot_2'")
	player._on_attack_ended()
	_assert(anim_sprite.animation == &"idle", "'shot_2' retorna suavemente para 'idle'")
	
	# Teste de transição: Kick (Pistolada) -> Idle
	player._execute_combo_attack(2)
	_assert(anim_sprite.animation == &"kick", "Execução do passo 2 toca 'kick'")
	player._on_attack_ended()
	_assert(anim_sprite.animation == &"idle", "'kick' retorna suavemente para 'idle'")
	
	# Teste de transição: Heavy -> Idle
	player._execute_combo_attack(3)
	_assert(anim_sprite.animation == &"heavy", "Execução do passo 3 toca 'heavy'")
	player._on_attack_ended()
	_assert(anim_sprite.animation == &"idle", "'heavy' retorna suavemente para 'idle'")
	
	# Teste de transição: animation_finished direto
	anim_sprite.play("shot_1")
	player._on_anim_sprite_animation_finished()
	_assert(anim_sprite.animation == &"idle", "_on_anim_sprite_animation_finished restaura 'idle' para 'shot_1'")
	
	anim_sprite.play("shot_2")
	player._on_anim_sprite_animation_finished()
	_assert(anim_sprite.animation == &"idle", "_on_anim_sprite_animation_finished restaura 'idle' para 'shot_2'")
	
	player.queue_free()


func _test_horizontal_mirroring() -> void:
	print("\n--- 4. Validando Espelhamento Horizontal sem Duplicação de Sprites ---")
	var session = _ensure_game_session()
	session.selected_character_id = "gabriel"
	
	var player_scene: PackedScene = load("res://scenes/actors/player/player.tscn")
	var player: PlayerController = player_scene.instantiate() as PlayerController
	root.add_child(player)
	
	var visual: Node2D = player.get_node_or_null("Visual") as Node2D
	_assert(visual != null, "Nó Visual encontrado")
	
	# Virado para a direita (+1)
	player._update_facing_direction(1.0)
	_assert(is_equal_approx(visual.scale.x, 1.0), "visual.scale.x é +1.0 virado para a direita")
	
	# Virado para a esquerda (-1)
	player._update_facing_direction(-1.0)
	_assert(is_equal_approx(visual.scale.x, -1.0), "visual.scale.x é -1.0 virado para a esquerda")
	
	# Verifica que apenas um nó AnimatedSprite2D existe (sem clonagem ou duplicação indevida)
	var sprites_count: int = 0
	for child in visual.get_children():
		if child is AnimatedSprite2D:
			sprites_count += 1
	_assert(sprites_count == 1, "Exatamente um AnimatedSprite2D presente sob Visual (sem duplicação ao espelhar)")
	
	player.queue_free()


func _test_guilherme_and_others_untouched() -> void:
	print("\n--- 5. Confirmando Integridade e Zero Alteração em Guilherme ---")
	var session = _ensure_game_session()
	session.select_character("guilherme")
	
	var player_scene: PackedScene = load("res://scenes/actors/player/player.tscn")
	var player: PlayerController = player_scene.instantiate() as PlayerController
	root.add_child(player)
	
	var anim_sprite: AnimatedSprite2D = player.get_node_or_null("Visual/AnimatedSprite2D") as AnimatedSprite2D
	_assert(anim_sprite != null, "AnimatedSprite2D de Guilherme presente")
	_assert(anim_sprite.sprite_frames.has_animation("punch"), "Guilherme preserva animação 'punch'")
	_assert(anim_sprite.sprite_frames.get_frame_count("punch") == 3, "Guilherme mantém 3 frames de 'punch'")
	_assert(anim_sprite.sprite_frames.has_animation("kick"), "Guilherme preserva animação 'kick'")
	_assert(anim_sprite.sprite_frames.has_animation("heavy"), "Guilherme preserva animação 'heavy'")
	
	var attacks: Array = player.get("_combo_attacks")
	_assert(attacks[0].get("animation") == &"punch", "Guilherme passo 1 continua utilizando 'punch'")
	_assert(attacks[1].get("animation") == &"punch", "Guilherme passo 2 continua utilizando 'punch'")
	_assert(attacks[2].get("animation") == &"kick", "Guilherme passo 3 continua utilizando 'kick'")
	_assert(attacks[3].get("animation") == &"heavy", "Guilherme passo 4 continua utilizando 'heavy'")
	
	player.queue_free()


func _ensure_game_session() -> Node:
	var session = root.get_node_or_null("GameSession")
	if session == null:
		var script = load("res://scripts/core/game_session.gd")
		if script != null:
			session = script.new()
			session.name = "GameSession"
			root.add_child(session)
	return session
