extends SceneTree

## Teste unitário e de integração dos novos efeitos sonoros:
## 1. garrafa_quebrando.mp3 (Map 5 - obstáculo e quebra de chão)
## 2. abrir latinha.mp3 (Map 2 e Map 3 - item de cura)
## 3. arroto.mp3 (Impacto de garrafa no Bêbado)

const CombatFeedbackClass = preload("res://scripts/combat/combat_feedback.gd")
const GasBottleProjectileScene = preload("res://scenes/actors/projectiles/gas_bottle_projectile.tscn")
const BebadoEnemyScene = preload("res://scenes/actors/enemies/bebado_enemy.tscn")
const CocaPickupScene = preload("res://scenes/items/coca_pickup.tscn")
const GuaranaPickupScene = preload("res://scenes/items/guarana_pickup.tscn")

var _total: int = 0
var _passed: int = 0
var _failed: int = 0


func _assert(condition: bool, message: String) -> void:
	_total += 1
	if condition:
		_passed += 1
		print("  [OK] %s" % message)
	else:
		_failed += 1
		printerr("  [FALHA] %s" % message)


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	print("\n=== INICIANDO TESTES: NOVOS EFEITOS SONOROS (SFX) ===")

	# 1. Integridade dos arquivos de áudio
	print("\n--- 1. Integridade dos Arquivos no Disco e ResourceLoader ---")
	var paths: Array[String] = [
		CombatFeedbackClass.SFX_GARRAFA_QUEBRANDO,
		CombatFeedbackClass.SFX_ABRIR_LATINHA,
		CombatFeedbackClass.SFX_BEBADO_ARROTO
	]
	for p: String in paths:
		_assert(ResourceLoader.exists(p), "Arquivo existe no res://: %s" % p.get_file())
		var stream := load(p) as AudioStream
		_assert(stream != null, "Carrega como AudioStream válido: %s" % p.get_file())
		if stream != null and stream.has_method("get_length"):
			_assert(stream.get_length() > 0.05, "Duração do áudio é válida (>0.05s): %.2fs" % stream.get_length())

	# 2. Resolução do CombatFeedback
	print("\n--- 2. Resolução de Mapeamento em CombatFeedback ---")
	var world := Node2D.new()
	world.name = "TestWorld"
	root.add_child(world)
	await process_frame

	var p_bottle := CombatFeedbackClass.play_bottle_break(world)
	_assert(p_bottle != null and p_bottle.stream != null, "play_bottle_break retorna AudioStreamPlayer")
	if p_bottle != null and p_bottle.stream != null:
		_assert(p_bottle.stream.resource_path.ends_with("garrafa_quebrando.mp3"), "play_bottle_break usa garrafa_quebrando.mp3")

	var p_can := CombatFeedbackClass.play_can_open(world)
	_assert(p_can != null and p_can.stream != null, "play_can_open retorna AudioStreamPlayer")
	if p_can != null and p_can.stream != null:
		_assert(p_can.stream.resource_path.ends_with("abrir latinha.mp3"), "play_can_open usa abrir latinha.mp3")

	var p_burp := CombatFeedbackClass.play_bebado_burp(world)
	_assert(p_burp != null and p_burp.stream != null, "play_bebado_burp retorna AudioStreamPlayer")
	if p_burp != null and p_burp.stream != null:
		_assert(p_burp.stream.resource_path.ends_with("arroto.mp3"), "play_bebado_burp usa arroto.mp3")

	var p_pickup_coca := CombatFeedbackClass.play_pickup_sound(world, "coca")
	_assert(p_pickup_coca != null and p_pickup_coca.stream != null and p_pickup_coca.stream.resource_path.ends_with("abrir latinha.mp3"), "play_pickup_sound('coca') toca abrir latinha.mp3")

	var p_pickup_latinha := CombatFeedbackClass.play_pickup_sound(world, "latinha")
	_assert(p_pickup_latinha != null and p_pickup_latinha.stream != null and p_pickup_latinha.stream.resource_path.ends_with("abrir latinha.mp3"), "play_pickup_sound('latinha') toca abrir latinha.mp3")

	var p_impact_glass := CombatFeedbackClass.play_sound(world, CombatFeedbackClass.SFX_GARRAFA_QUEBRANDO)
	_assert(p_impact_glass != null and p_impact_glass.stream != null and p_impact_glass.stream.resource_path.ends_with("garrafa_quebrando.mp3"), "play_sound com SFX_GARRAFA_QUEBRANDO toca garrafa_quebrando.mp3")

	# 3. Item de cura (latinhas - Map 2 e Map 3)
	print("\n--- 3. Consumo de Latinhas de Cura (Coca e Guaraná) ---")
	var dummy_player := CharacterBody2D.new()
	dummy_player.name = "Player"
	dummy_player.add_to_group("player")
	var health_comp_script := load("res://scripts/components/health_component.gd") as Script
	var health_comp: Node = health_comp_script.new()
	health_comp.name = "HealthComponent"
	dummy_player.add_child(health_comp)
	world.add_child(dummy_player)
	health_comp.set("max_health", 100.0)
	health_comp.set("current_health", 50.0)

	var coca_pickup := CocaPickupScene.instantiate() as Node2D
	world.add_child(coca_pickup)
	coca_pickup.global_position = dummy_player.global_position
	await process_frame

	var consumed_coca: bool = bool(coca_pickup.call("try_consume", dummy_player))
	_assert(consumed_coca, "CocaPickup consumido pelo jogador com vida reduzida")

	# Guaraná (Map 3)
	health_comp.set("current_health", 60.0)
	var guarana_pickup := GuaranaPickupScene.instantiate() as Node2D
	world.add_child(guarana_pickup)
	guarana_pickup.global_position = dummy_player.global_position
	await process_frame

	var consumed_guarana: bool = bool(guarana_pickup.call("try_consume", dummy_player))
	_assert(consumed_guarana, "GuaranaPickup consumido com sucesso pelo jogador")

	# 4. Projétil da garrafa (Map 5): quebra em obstáculo sólido do mapa
	print("\n--- 4. Garrafa Quebrando no Mapa (Map 5) ---")
	var bottle_obstacle := GasBottleProjectileScene.instantiate() as GasBottleProjectile
	world.add_child(bottle_obstacle)
	bottle_obstacle.launch(dummy_player, 1.0, Vector2.RIGHT)
	await process_frame

	var obstacle_body := StaticBody2D.new()
	obstacle_body.name = "MapWall"
	world.add_child(obstacle_body)

	bottle_obstacle.call("_hit_map_obstacle", obstacle_body)
	_assert(bool(bottle_obstacle.get("_has_hit")), "Garrafa colidindo em obstáculo marca _has_hit = true")

	# Quebra por limite de distância / chão
	var bottle_ground := GasBottleProjectileScene.instantiate() as GasBottleProjectile
	world.add_child(bottle_ground)
	bottle_ground.launch(dummy_player, 1.0, Vector2.RIGHT)
	await process_frame
	bottle_ground.call("_break_bottle")
	_assert(bool(bottle_ground.get("_has_hit")), "Garrafa aterrissando no chão quebra e marca _has_hit = true")

	# 5. Garrafa arremessada no Bêbado (arroto.mp3)
	print("\n--- 5. Garrafa Arremessada no Bêbado (Arroto) ---")
	var bebado: Node = BebadoEnemyScene.instantiate()
	world.add_child(bebado)
	bebado.global_position = dummy_player.global_position + Vector2(60.0, 0.0)
	await process_frame
	_assert(bebado.is_in_group("bebado"), "BebadoEnemy adicionado ao grupo 'bebado'")

	var bottle_at_bebado := GasBottleProjectileScene.instantiate() as GasBottleProjectile
	world.add_child(bottle_at_bebado)
	bottle_at_bebado.launch(dummy_player, 1.0, Vector2.RIGHT)
	await process_frame

	var hit_applied: bool = bool(bottle_at_bebado.call("_try_hit", bebado))
	_assert(hit_applied, "Garrafa atinge com sucesso o Bêbado e aplica dano")

	# Finalização
	print("\n==================================================")
	print("RESULTADO DOS TESTES SFX: %d PASSARAM (Falhas: %d)" % [_passed, _failed])
	print("==================================================")

	world.queue_free()
	quit(0 if _failed == 0 else 1)
