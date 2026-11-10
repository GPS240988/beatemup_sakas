extends SceneTree

const MenuCharacterSlotClass = preload("res://scripts/ui/components/menu_character_slot.gd")
const MenuCharacterDataClass = preload("res://scripts/ui/menu_character_data.gd")

func _init() -> void:
	print("\n========================================================")
	print(" TESTE: MENU_CHARACTER_SLOT E MENU_CHARACTER_DATA")
	print("========================================================")

	var scn = load("res://scenes/ui/components/menu_character_slot.tscn") as PackedScene
	assert(scn != null, "A cena menu_character_slot.tscn deve carregar sem erros")
	print("  [OK] Cena menu_character_slot.tscn carregada com sucesso")

	var slot = scn.instantiate()
	assert(slot != null, "A cena deve instanciar como MenuCharacterSlot")
	print("  [OK] Instanciado como MenuCharacterSlot")

	var data = MenuCharacterDataClass.create_guilherme()
	assert(data.id == "guilherme", "ID do Guilherme deve ser guilherme")
	assert(data.is_active == true, "Guilherme deve ser ativo")
	print("  [OK] MenuCharacterData.create_guilherme() validado")

	var gabriel = MenuCharacterDataClass.create_gabriel()
	assert(gabriel.is_active == false, "Gabriel deve iniciar inativo para expansão futura")
	var andre = MenuCharacterDataClass.create_andre()
	assert(andre.is_active == false, "André deve iniciar inativo para expansão futura")
	var juliana = MenuCharacterDataClass.create_juliana()
	assert(juliana.is_active == false, "Juliana deve iniciar inativo para expansão futura")
	print("  [OK] Os outros 3 slots (Gabriel, André, Juliana) configurados e inativos")

	root.add_child(slot)
	slot.apply_character_data(data)
	assert(slot.visible == true, "Slot do Guilherme deve estar visível")
	assert(slot.character_texture.texture != null, "Textura de Guilherme deve estar carregada")
	print("  [OK] apply_character_data() aplicou Guilherme com sucesso")

	slot.start_presentation(true)
	print("  [OK] start_presentation() executado com sucesso")

	slot.queue_free()
	print("\n>> TODOS OS TESTES DO SLOT PASSARAM COM SUCESSO! <<\n")
	quit(0)
