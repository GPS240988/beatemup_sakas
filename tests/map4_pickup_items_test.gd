extends SceneTree

## Regressão focada dos pickups novos do Mapa 4: alcance real, prompt e cura do ovo.

const PlayerControllerClass = preload("res://scripts/actors/player_controller.gd")
const EggScene: PackedScene = preload("res://scenes/items/ovo_pickup.tscn")
const DiceScene: PackedScene = preload("res://scenes/items/dado_continue_pickup.tscn")

var total_tests: int = 0
var failed_tests: int = 0


func _initialize() -> void:
	call_deferred("_run_tests")


func _run_tests() -> void:
	var world := Node2D.new()
	world.name = "PickupTestWorld"
	root.add_child(world)
	current_scene = world

	var player_scene: PackedScene = load("res://scenes/actors/player/player.tscn") as PackedScene
	_assert(player_scene != null, "Cena do jogador carrega")
	if player_scene == null:
		quit(1)
		return
	var player := player_scene.instantiate() as PlayerControllerClass
	world.add_child(player)
	player.global_position = Vector2(426.0, 580.0)

	var egg := EggScene.instantiate() as Node2D
	egg.position = Vector2(426.0, 521.0)
	world.add_child(egg)
	await process_frame

	_assert(is_equal_approx(egg.global_position.y, 580.0), "Ovo é reposicionado para dentro da faixa caminhável do Mapa 4")
	var egg_sprite: Sprite2D = egg.get("item_sprite") as Sprite2D
	_assert(egg_sprite != null and egg_sprite.texture != null, "Ovo carrega a textura real com a capitalização correta")
	_assert(egg_sprite != null and is_equal_approx(egg_sprite.position.y, -72.5), "Base do sprite do ovo fica alinhada ao chão")
	var health: HealthComponent = player.get_node_or_null("HealthComponent") as HealthComponent
	_assert(health != null, "Jogador possui HealthComponent")
	if health != null:
		health.current_health = maxf(0.0, health.max_health - 60.0)
		egg.call("_process", 0.016)
		_assert(bool(egg.call("can_offer_hint_to", player)), "Ovo reconhece o jogador dentro do alcance 2.5D")
		var hint: Button = egg.get("_hint_button") as Button
		_assert(hint != null and hint.visible and hint.text == "Pegar", "Prompt Pegar aparece sobre o ovo")
		_assert(hint != null and is_equal_approx(hint.position.y, -250.0), "Prompt fica acima da silhueta do ovo")
		var health_before: float = health.current_health
		_assert(bool(egg.call("try_consume", player)), "Ovo pode ser coletado pelo contrato interact/try_consume")
		_assert(is_equal_approx(health.current_health, minf(health.max_health, health_before + 50.0)), "Ovo recupera até 50 HP")

	var dice := DiceScene.instantiate()
	world.add_child(dice)
	await process_frame
	_assert(str(dice.get("item_texture_path")) == "res://assets/sprites/Itens/dado_continue.png", "Dado aponta para o caminho de textura com capitalização correta")
	var dice_sprite: Sprite2D = dice.get_node("Visual/Sprite") as Sprite2D
	_assert(dice_sprite != null and dice_sprite.texture != null, "Dado carrega sua textura real")

	world.free()
	print("RESULTADO: %d testes, %d falhas" % [total_tests, failed_tests])
	quit(0 if failed_tests == 0 else 1)


func _assert(condition: bool, description: String) -> void:
	total_tests += 1
	if condition:
		print("[OK] ", description)
	else:
		failed_tests += 1
		printerr("[FALHA] ", description)
