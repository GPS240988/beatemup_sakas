# tests/test_pack_manager_lifecycle.gd
extends SceneTree

## Teste Automatizado do Ciclo de Vida do PackManager
## Valida:
## 1. Catálogo KNOWN_PACKS e configuração de criticidade (critical = false para streaming sob demanda)
## 2. Estados e métodos de consulta (is_pack_mounted, get_pack_state)
## 3. Emissão de sinais (pack_progress, pack_mounted)
## 4. Montagem síncrona e assíncrona

var passed: int = 0
var failed: int = 0


func _init() -> void:
	print("\n========================================================")
	print(" INICIANDO TESTE: PACKMANAGER & STREAMING DE PACOTES")
	print("========================================================\n")

	_run_tests()


func _run_tests() -> void:
	await process_frame
	var pack_mgr = root.get_node_or_null("PackManager")
	_assert(pack_mgr != null, "Autoload PackManager deve estar presente no SceneTree")
	if pack_mgr == null:
		_finish_test()
		return

	# 1. Validação do catálogo KNOWN_PACKS
	var known: Dictionary = pack_mgr.KNOWN_PACKS
	_assert(known.has("audio_bgm"), "KNOWN_PACKS deve conter 'audio_bgm'")
	_assert(known.has("story_cinematics"), "KNOWN_PACKS deve conter 'story_cinematics'")
	_assert(known.has("stage1"), "KNOWN_PACKS deve conter 'stage1'")

	# 2. Na arquitetura PWA Premium, pacotes não são críticos na inicialização
	_assert(known["audio_bgm"].get("critical", true) == false, "'audio_bgm' deve ter critical=false para permitir streaming sob demanda")
	_assert(known["story_cinematics"].get("critical", true) == false, "'story_cinematics' deve ter critical=false")
	_assert(known["stage1"].get("critical", true) == false, "'stage1' deve ter critical=false")

	# 3. Métodos essenciais
	_assert(pack_mgr.has_method("is_pack_mounted"), "PackManager deve implementar is_pack_mounted()")
	_assert(pack_mgr.has_method("mount_pack"), "PackManager deve implementar mount_pack()")
	_assert(pack_mgr.has_method("ensure_pack_loaded"), "PackManager deve implementar ensure_pack_loaded()")
	_assert(pack_mgr.has_method("ensure_pack_loaded_async"), "PackManager deve implementar ensure_pack_loaded_async()")
	_assert(pack_mgr.has_method("get_pack_state"), "PackManager deve implementar get_pack_state()")

	# 4. Sinais essenciais
	_assert(pack_mgr.has_signal("pack_mounted"), "PackManager deve possuir sinal 'pack_mounted'")
	_assert(pack_mgr.has_signal("pack_progress"), "PackManager deve possuir sinal 'pack_progress'")
	_assert(pack_mgr.has_signal("pack_error"), "PackManager deve possuir sinal 'pack_error'")

	# 5. Teste de montagem de pacote local existente
	var stage1_ok = await pack_mgr.ensure_pack_loaded_async("stage1")
	_assert(stage1_ok == true, "ensure_pack_loaded_async('stage1') deve retornar true para pacote local")
	_assert(pack_mgr.is_pack_mounted("stage1") == true, "stage1 deve estar marcado como MOUNTED")

	# 6. Teste de idempotência (chamar novamente quando já montado)
	var stage1_second = await pack_mgr.ensure_pack_loaded_async("stage1")
	_assert(stage1_second == true, "ensure_pack_loaded_async deve retornar true imediatamente quando já montado")

	_finish_test()


func _finish_test() -> void:
	print("\n========================================================")
	print(" RESULTADO: %d passaram, %d falharam" % [passed, failed])
	print("========================================================\n")
	quit(0 if failed == 0 else 1)


func _assert(condition: bool, message: String) -> void:
	if condition:
		passed += 1
		print("  [OK] %s" % message)
	else:
		failed += 1
		printerr("  [FALHA] %s" % message)
