# tests/test_runtime_pck_mount.gd
extends SceneTree

func _init() -> void:
	print("--- TESTE DE CARREGAMENTO RUNTIME DE PCK ---")
	var pck_path = "public/packs/pack_stage1.pck"
	var test_res = "res://assets/backgrounds/maps/fase1/Fase1_1.webp"

	print("1. Antes de montar:")
	print("   ResourceLoader.exists('%s'): %s" % [test_res, ResourceLoader.exists(test_res)])

	print("2. Montando PCK: %s" % pck_path)
	var ok = ProjectSettings.load_resource_pack(pck_path, true)
	print("   Resultado de load_resource_pack: %s" % ok)

	print("3. Após montar:")
	var exists_after = ResourceLoader.exists(test_res)
	print("   ResourceLoader.exists('%s'): %s" % [test_res, exists_after])

	if ok and exists_after:
		print("--- SUCESSO: PCK MONTADO E RECURSO ACESSÍVEL EM RUNTIME ---")
		quit(0)
	else:
		printerr("--- FALHA NA MONTAGEM DE RUNTIME ---")
		quit(1)

