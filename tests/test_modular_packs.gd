# tests/test_modular_packs.gd
extends SceneTree

## Suíte de Testes Automatizados da Arquitetura Modular Multi-PCK.
## Valida montagem em runtime, integridade de streams de áudio, texturas HD
## e respeito aos orçamentos de tamanho do projeto.

const PackManagerScript = preload("res://scripts/core/pack_manager.gd")

var passed: int = 0
var failed: int = 0


func _init() -> void:
	print("\n" + "=" . repeat(70))
	print(" BATERIA DE TESTES: ARQUITETURA MODULAR MULTI-PCK")
	print("=" . repeat(70))

	test_manifest_integrity()
	test_mount_audio_bgm_pack()
	test_mount_story_cinematics_pack()
	test_mount_stage1_pack()
	test_pack_manager_api()

	print("\n" + "=" . repeat(70))
	print(" RESULTADO DOS TESTES MULTI-PCK:")
	print("  Passaram: %d | Falharam: %d" % [passed, failed])
	print("=" . repeat(70) + "\n")

	quit(0 if failed == 0 else 1)


func assert_true(condition: bool, test_name: String) -> void:
	if condition:
		passed += 1
		print("  [PASS] %s" % test_name)
	else:
		failed += 1
		push_error("  [FAIL] %s" % test_name)


func test_manifest_integrity() -> void:
	print("\n--- 1. Validando Manifesto de Pacotes (public/packs/manifest.json) ---")
	var manifest_path = "public/packs/manifest.json"
	assert_true(FileAccess.file_exists(manifest_path), "manifest.json deve existir em public/packs/")

	var file = FileAccess.open(manifest_path, FileAccess.READ)
	assert_true(file != null, "Arquivo manifest.json deve ser legível")
	if not file:
		return

	var text = file.get_as_text()
	file.close()

	var json = JSON.new()
	var err = json.parse(text)
	assert_true(err == OK, "manifest.json deve conter JSON válido")
	if err != OK:
		return

	var data = json.get_data()
	assert_true(data is Dictionary and data.has("packs"), "Manifesto deve conter dicionário de packs")
	var packs: Dictionary = data.get("packs", {})

	assert_true(packs.has("audio_bgm"), "Manifesto deve catalogar audio_bgm")
	assert_true(packs.has("story_cinematics"), "Manifesto deve catalogar story_cinematics")
	assert_true(packs.has("stage1"), "Manifesto deve catalogar stage1")

	for pack_id in packs.keys():
		var pinfo = packs[pack_id]
		var sz_mb = pinfo.get("size_mb", 999.0)
		assert_true(sz_mb <= 45.0, "Pacote %s deve respeitar o teto de 45 MB (Atual: %.2f MB)" % [pack_id, sz_mb])


func test_mount_audio_bgm_pack() -> void:
	print("\n--- 2. Validando Pacote de Áudio (pack_audio_bgm.pck) ---")
	var pack_path = "public/packs/pack_audio_bgm.pck"
	assert_true(FileAccess.file_exists(pack_path), "Arquivo pack_audio_bgm.pck deve existir")

	var mount_ok = ProjectSettings.load_resource_pack(pack_path, false)
	assert_true(mount_ok, "Montagem de pack_audio_bgm.pck deve ser bem-sucedida")

	var bgm_1 = load("res://assets/audio/bgm/M_1_2 - Estágio 1.mp3")
	assert_true(bgm_1 is AudioStreamMP3, "M_1_2 deve ser carregável como AudioStreamMP3")
	if bgm_1 is AudioStreamMP3:
		assert_true(bgm_1.get_length() > 60.0, "Duração de M_1_2 deve ser superior a 60s (Atual: %.1fs)" % bgm_1.get_length())

	var bgm_2 = load("res://assets/audio/bgm/M_3_4 - Estágio 1.mp3")
	assert_true(bgm_2 is AudioStreamMP3, "M_3_4 deve ser carregável como AudioStreamMP3")
	if bgm_2 is AudioStreamMP3:
		assert_true(bgm_2.get_length() > 60.0, "Duração de M_3_4 deve ser superior a 60s (Atual: %.1fs)" % bgm_2.get_length())


func test_mount_story_cinematics_pack() -> void:
	print("\n--- 3. Validando Pacote de Cinemáticas (pack_story_cinematics.pck) ---")
	var pack_path = "public/packs/pack_story_cinematics.pck"
	assert_true(FileAccess.file_exists(pack_path), "Arquivo pack_story_cinematics.pck deve existir")

	var mount_ok = ProjectSettings.load_resource_pack(pack_path, false)
	assert_true(mount_ok, "Montagem de pack_story_cinematics.pck deve ser bem-sucedida")

	var intro_tex = load("res://assets/story/map_1/intro_group.webp")
	assert_true(intro_tex is Texture2D, "intro_group.webp deve ser carregável como Texture2D")
	if intro_tex is Texture2D:
		assert_true(intro_tex.get_width() == 1920 and intro_tex.get_height() == 1080, "intro_group.webp deve ter resolução Full HD 1920x1080 (Atual: %s)" % intro_tex.get_size())

	var cena02 = load("res://assets/backgrounds/intro_cena02.webp")
	assert_true(cena02 is Texture2D, "intro_cena02.webp deve ser carregável como Texture2D")


func test_mount_stage1_pack() -> void:
	print("\n--- 4. Validando Pacote do Estágio 1 (pack_stage1.pck) ---")
	var pack_path = "public/packs/pack_stage1.pck"
	assert_true(FileAccess.file_exists(pack_path), "Arquivo pack_stage1.pck deve existir")

	var mount_ok = ProjectSettings.load_resource_pack(pack_path, false)
	assert_true(mount_ok, "Montagem de pack_stage1.pck deve ser bem-sucedida")

	var fase1_1 = load("res://assets/backgrounds/maps/fase1/Fase1_1.webp")
	assert_true(fase1_1 is Texture2D, "Fase1_1.webp deve ser carregável como Texture2D")

	var garagem = load("res://assets/backgrounds/maps/bonus1/garagem.webp")
	assert_true(garagem is Texture2D, "garagem.webp deve ser carregável como Texture2D")


func test_pack_manager_api() -> void:
	print("\n--- 5. Validando API do Autoload PackManager ---")
	var mgr = PackManagerScript.new()
	assert_true(mgr != null, "Instância de PackManager deve ser criada com sucesso")

	var known = PackManagerScript.KNOWN_PACKS
	assert_true(known.has("audio_bgm") and known.has("story_cinematics") and known.has("stage1"), "PackManager deve conter os 3 pacotes conhecidos")

	assert_true(mgr.is_resource_available("res://assets/audio/bgm/M_1_2 - Estágio 1.mp3"), "Recurso M_1_2 deve ser reportado como disponível após montagem")
	assert_true(mgr.is_resource_available("res://assets/story/map_1/intro_group.webp"), "Recurso intro_group deve ser reportado como disponível após montagem")
	assert_true(mgr.is_resource_available("res://assets/backgrounds/maps/fase1/Fase1_1.webp"), "Recurso Fase1_1 deve ser reportado como disponível após montagem")

	mgr.free()
