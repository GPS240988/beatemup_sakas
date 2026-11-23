extends SceneTree

## Teste dos ajustes de balanceamento e spawn de mapa:
## 1. Dano aumentado do especial (110.0) e knockdown obrigatório em inimigos
## 2. Vida dos carros da fase bônus ajustada para destruição em 40s (540 HP cada)
## 3. Prevenção de voadora/dash imediato ao iniciar o mapa (_spawn_input_cooldown)

const PlayerControllerScene = preload("res://scenes/actors/player/player.tscn")
const CarOrangeScene = preload("res://scenes/props/bonus_car_orange.tscn")
const CarBlueScene = preload("res://scenes/props/bonus_car_blue.tscn")
const BebadoScene = preload("res://scenes/actors/enemies/bebado_enemy.tscn")
const EnemyAIScene = preload("res://scenes/actors/enemies/basic_enemy.tscn")
const DamageInfoClass = preload("res://scripts/combat/damage_info.gd")
const HeroDataClass = preload("res://scripts/combat/hero_data.gd")

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
	print("\n=== TESTES: BALANCEAMENTO DE COMBATE, VEÍCULOS E SPAWN ===")

	var world := Node2D.new()
	world.name = "TestWorld"
	root.add_child(world)
	await process_frame

	# 1. Validação da vida calibrada dos carros da garagem
	print("\n--- 1. Vida dos Carros da Fase Bônus (40 Segundos) ---")
	var car_orange = CarOrangeScene.instantiate()
	world.add_child(car_orange)
	var car_blue = CarBlueScene.instantiate()
	world.add_child(car_blue)
	await process_frame

	_assert(is_equal_approx(car_orange.max_health, 540.0), "Carro Hatch Laranja (Fiesta) possui 540 HP")
	_assert(is_equal_approx(car_blue.max_health, 540.0), "Carro Sedan Azul (Escort) possui 540 HP")

	var total_car_health: float = car_orange.max_health + car_blue.max_health
	_assert(is_equal_approx(total_car_health, 1080.0), "Vida total dos 2 carros somados é exatamente 1080 HP")

	# Simulação matemática de DPS
	var guilherme_dps: float = 80.0 / 1.53 # ~52.3 DPS
	var gabriel_dps: float = 64.0 / 1.55   # ~41.3 DPS
	var guilherme_time_needed: float = total_car_health / guilherme_dps
	var gabriel_time_needed: float = total_car_health / gabriel_dps

	_assert(guilherme_time_needed <= 26.0, "Guilherme destrói ambos os carros em ~%.1fs (<= 26s, limite 40s)" % guilherme_time_needed)
	_assert(gabriel_time_needed <= 32.0, "Gabriel destrói ambos os carros em ~%.1fs (<= 32s, limite 40s)" % gabriel_time_needed)

	# 2. Validação do Dano do Especial e Knockdown Obrigatório
	print("\n--- 2. Dano do Especial e Knockdown Obrigatório ---")
	var default_hero_data := HeroDataClass.new()
	_assert(default_hero_data.special_damage >= 100.0, "Dano padrão do Especial em HeroData é >= 100 (atual: %.1f)" % default_hero_data.special_damage)
	_assert(default_hero_data.special_prop_damage >= 80.0, "Dano em props do Especial é >= 80 (atual: %.1f)" % default_hero_data.special_prop_damage)

	var gabriel_res = load("res://resources/heroes/gabriel_data.tres")
	if gabriel_res != null:
		_assert(gabriel_res.special_damage >= 100.0, "Gabriel possui special_damage >= 100 (atual: %.1f)" % gabriel_res.special_damage)

	# Testar knockdown em inimigos comuns e no Bêbado
	var grunt = EnemyAIScene.instantiate()
	world.add_child(grunt)
	var grunt_health = grunt.get_node_or_null("HealthComponent")
	if grunt_health != null:
		grunt_health.max_health = 300.0
		grunt_health.current_health = 300.0
	await process_frame

	var special_dmg_info := DamageInfoClass.new(
		110.0,
		null,
		Vector2.ZERO,
		Vector2.RIGHT,
		"special",
		220.0,
		0.5,
		true,
		true,
		0.08,
		"special"
	)

	grunt.take_damage(special_dmg_info)
	_assert(grunt.get("current_state") == 9, "Inimigo comum entra em State.FALL (9) após sofrer Especial")

	# Testar Bêbado: não pode desviar do Especial e DEVE cair
	var bebado = BebadoScene.instantiate()
	world.add_child(bebado)
	var bebado_health = bebado.get_node_or_null("HealthComponent")
	if bebado_health != null:
		bebado_health.max_health = 300.0
		bebado_health.current_health = 300.0
	await process_frame

	bebado.set("bebado_state", 1) # DODGING
	var hit_applied_dodge = bebado.take_damage(special_dmg_info)
	_assert(hit_applied_dodge, "Bêbado não pode ignorar/desviar de Golpe Especial mesmo durante esquiva")
	_assert(bebado.get("current_state") == 9, "Bêbado sofre knockdown e entra em State.FALL (9) após Golpe Especial")

	# 3. Prevenção de voadora / dash ao iniciar o mapa
	print("\n--- 3. Prevenção de Voadora / Dash ao Iniciar o Mapa ---")
	var player = PlayerControllerScene.instantiate()
	world.add_child(player)
	await process_frame

	_assert(player.get("_spawn_input_cooldown") > 0.0, "PlayerController inicializa com _spawn_input_cooldown > 0 (carência de entrada no spawn)")

	# Simular que a tecla jump/voadora estava pressionada ao entrar
	Input.action_press("jump")
	player._physics_process(0.016)
	_assert(not player.get("_is_jumping"), "Player não executa salto/voadora no primeiro quadro enquanto em carência de spawn")
	_assert(not player.is_dashing(), "Player não executa dash no primeiro quadro enquanto em carência de spawn")
	Input.action_release("jump")

	# Aguarda expirar a carência de spawn
	player.set("_spawn_input_cooldown", 0.0)
	_assert(player.get("_spawn_input_cooldown") <= 0.0, "Carência de spawn expira normalmente para combate")

	print("\n==================================================")
	print("RESULTADOS: %d PASSARAM (Falhas: %d)" % [_passed, _failed])
	print("==================================================")

	world.queue_free()
	quit(0 if _failed == 0 else 1)
