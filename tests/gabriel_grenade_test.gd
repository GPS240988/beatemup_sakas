extends SceneTree

## Smoke test de recursos/configuração para a habilidade de granada do Gabriel.
## Execução: godot --headless --path . --script tests/gabriel_grenade_test.gd

const GrenadeScene: PackedScene = preload("res://scenes/actors/projectiles/player_grenade.tscn")
const HandlerScript: Script = preload("res://scripts/actors/grenade_handler.gd")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var grenade: Node = GrenadeScene.instantiate()
	assert(grenade != null, "A cena de granada deve instanciar")
	assert(is_equal_approx(float(grenade.get("fuse_duration")), 2.0), "O pavio precisa durar 2 segundos")
	assert(int(grenade.get("blast_radius")) == 150, "O raio de explosão precisa ser 150 px")
	assert(float(grenade.get("self_damage")) > 0.0, "A explosão precisa causar dano ao lançador")
	assert(float(grenade.get("enemy_damage")) > 0.0, "A explosão precisa causar dano a inimigos")
	assert(float(grenade.get("prop_damage")) > 0.0, "A explosão precisa causar dano a props")
	var handler := Node.new()
	handler.set_script(HandlerScript)
	assert(int(handler.get("grenades_remaining")) == 2, "Gabriel começa cada mapa com duas granadas")
	handler.call("set_grenades_remaining", 1)
	assert(int(handler.get("grenades_remaining")) == 1, "O estoque do save deve poder ser restaurado")
	handler.call("set_grenades_remaining", 9)
	assert(int(handler.get("grenades_remaining")) == 2, "O estoque restaurado deve respeitar o máximo por mapa")
	grenade.free()
	handler.free()
	print("[gabriel_grenade_test] PASS")
	quit(0)
