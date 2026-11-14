extends SceneTree

const MainMenuScene: PackedScene = preload("res://scenes/ui/main_menu.tscn")
const MenuCharacterShowcaseScript: Script = preload("res://scripts/ui/components/menu_character_showcase.gd")

var _total: int = 0
var _passed: int = 0
var _failed: int = 0


func _assert(cond: bool, msg: String) -> void:
	_total += 1
	if cond:
		_passed += 1
		print("  [OK] %s" % msg)
	else:
		_failed += 1
		printerr("  [FALHA] %s" % msg)


func _init() -> void:
	call_deferred("_run_suite")


func _run_suite() -> void:
	print("\n========================================================")
	print("TESTE: APRESENTAÇÃO CÍCLICA DOS PERSONAGENS (MENU)")
	print("========================================================")

	var menu: Control = MainMenuScene.instantiate() as Control
	root.add_child(menu)
	await process_frame
	await process_frame

	print("\n--- Teste 1: Presença e Posicionamento no Canto Esquerdo ---")
	var showcase = menu.find_child("CharacterShowcase", true, false)
	_assert(showcase != null, "CharacterShowcase encontrado na hierarquia do MainMenu")

	var brand_column: Control = menu.find_child("BrandColumn", true, false) as Control
	_assert(brand_column != null, "BrandColumn (coluna esquerda) existe")
	if showcase != null and brand_column != null:
		_assert(showcase.get_parent() == brand_column, "CharacterShowcase reside na coluna esquerda (canto esquerdo do menu)")
		_assert(showcase.visible, "CharacterShowcase está visível")

	print("\n--- Teste 2: Relação dos 5 Personagens e Sprites de Menu ---")
	_assert(showcase.get_character_count() == 5, "Total de exatamente 5 personagens no showcase")

	var expected_characters := [
		{"index": 0, "id": "guilherme", "name": "GUILHERME", "file": "guilherme_menu.png"},
		{"index": 1, "id": "gabriel", "name": "GABRIEL", "file": "gabriel_menu.png"},
		{"index": 2, "id": "andre", "name": "ANDRÉ", "file": "andre_menu.png"},
		{"index": 3, "id": "juliana", "name": "JULIANA", "file": "juliana_menu.png"},
		{"index": 4, "id": "alessandro", "name": "ALESSANDRO", "file": "alessandro_menu.png"}
	]

	var sprite: TextureRect = showcase.get_node_or_null("SpriteContainer/CharacterSprite") as TextureRect
	var name_lbl: Label = showcase.get_node_or_null("NameBadge/CharacterNameLabel") as Label

	_assert(sprite != null, "CharacterSprite (TextureRect) existe")
	_assert(name_lbl != null, "CharacterNameLabel (Label) existe")

	if sprite != null:
		_assert(sprite.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST, "Filtro de textura é CanvasItem.TEXTURE_FILTER_NEAREST (Pixel Art HD)")

	print("\n--- Teste 3: Elementos PixelFX (Sombra, Aura Neon e Poeira) ---")
	var ground_shadow: Polygon2D = showcase.get_node_or_null("VFXContainer/GroundShadow") as Polygon2D
	var ground_aura: Polygon2D = showcase.get_node_or_null("VFXContainer/GroundAura") as Polygon2D
	var dust: CPUParticles2D = showcase.get_node_or_null("VFXContainer/DustParticles") as CPUParticles2D

	_assert(ground_shadow != null, "GroundShadow de solo PixelFX existe")
	_assert(ground_aura != null, "GroundAura de reflexo neon PixelFX existe")
	if ground_aura != null and ground_aura.material != null:
		var canvas_mat := ground_aura.material as CanvasItemMaterial
		_assert(canvas_mat != null and canvas_mat.blend_mode == CanvasItemMaterial.BLEND_MODE_ADD, "GroundAura utiliza blend_mode ADD para reflexo luminoso")
	_assert(dust != null, "DustParticles (CPUParticles2D) para impacto de aterrissagem existe")

	print("\n--- Teste 4: Ciclagem 1 a 1 e Repetição Infinita ---")
	for expected in expected_characters:
		var idx: int = expected["index"]
		var exp_id: String = expected["id"]
		var exp_name: String = expected["name"]
		var exp_file: String = expected["file"]

		_assert(showcase.get_current_character_index() == idx, "Personagem [%d] ativo: %s" % [idx, exp_name])
		_assert(showcase.get_current_character_id() == exp_id, "ID do personagem: %s" % exp_id)
		_assert(showcase.get_current_character_name() == exp_name, "Nome exibido: %s" % exp_name)

		if name_lbl != null:
			_assert(name_lbl.text == exp_name, "Label de texto exibe somente o nome: '%s'" % name_lbl.text)

		if sprite != null and sprite.texture != null:
			var path: String = sprite.texture.resource_path
			_assert(path.ends_with(exp_file), "Sprite carrega asset oficial '%s' (caminho: %s)" % [exp_file, path])

		# Avança para o próximo personagem
		showcase.next_character()
		await process_frame

	# Verifica se após o 5º personagem (Alessandro), voltou ao 1º (Guilherme)
	_assert(showcase.get_current_character_index() == 0, "Ao chegar ao último (Alessandro), o ciclo reinicia no 1º (Guilherme)")
	_assert(showcase.get_current_character_name() == "GUILHERME", "Nome do primeiro personagem reexibido: GUILHERME")
	_assert(showcase.is_cycling(), "Apresentação em loop cíclico contínuo ativo")

	print("\n========================================================")
	print("RESULTADO: %d/%d PASSARAM (Falhas: %d)" % [_passed, _total, _failed])
	print("========================================================")

	menu.queue_free()
	await process_frame
	quit(0 if _failed == 0 else 1)
