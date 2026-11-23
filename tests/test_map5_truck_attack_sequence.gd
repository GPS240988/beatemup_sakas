extends SceneTree

const LEVEL_PATH: String = "res://scenes/levels/map_5.tscn"
const MAP5_SCRIPT_PATH: String = "res://scripts/levels/map_5_stage2.gd"
const SEQUENCE_SCRIPT_PATH: String = "res://scripts/events/map5_truck_attack_sequence.gd"
const PUNK_SCRIPT_PATH: String = "res://scripts/events/map5_truck_attack_punk.gd"
const STONE_SCRIPT_PATH: String = "res://scripts/events/map5_truck_attack_stone.gd"
const BOTTLE_SCRIPT_PATH: String = "res://scripts/actors/projectiles/gas_bottle_projectile.gd"

const PUNK_SHEETS: Array[String] = [
	"res://assets/sprites/stage2/truck_attack_sequence/punks/punk_01_spritesheet.png",
	"res://assets/sprites/stage2/truck_attack_sequence/punks/punk_02_spritesheet.png",
	"res://assets/sprites/stage2/truck_attack_sequence/punks/punk_03_spritesheet.png",
]
const TRUCK_SHEET: String = "res://assets/sprites/stage2/truck_attack_sequence/truck/truck_spritesheet.png"
const STONE_TEXTURE: String = "res://assets/sprites/stage2/truck_attack_sequence/stone.png"


func _initialize() -> void:
	call_deferred("_run_tests")


func _run_tests() -> void:
	_assert(ResourceLoader.exists(LEVEL_PATH), "Map 5 continua disponível")
	_assert(ResourceLoader.exists(MAP5_SCRIPT_PATH), "Script do Map 5 continua disponível")
	_assert(ResourceLoader.exists(SEQUENCE_SCRIPT_PATH), "Script da set piece existe")
	_assert(ResourceLoader.exists(PUNK_SCRIPT_PATH), "Script dos punks existe")
	_assert(ResourceLoader.exists(STONE_SCRIPT_PATH), "Script das pedras existe")
	_assert(ResourceLoader.exists(BOTTLE_SCRIPT_PATH), "Projétil de garrafa existe")

	for path in PUNK_SHEETS:
		var texture := load(path) as Texture2D
		_assert(texture != null, "Spritesheet de punk carrega: %s" % path)
		if texture != null:
			_assert(texture.get_width() == 880 and texture.get_height() == 600, "Punk usa grade normalizada 4x2 de 220x300")

	var truck_texture := load(TRUCK_SHEET) as Texture2D
	_assert(truck_texture != null, "Spritesheet da caminhonete carrega")
	if truck_texture != null:
		_assert(truck_texture.get_width() == 2048 and truck_texture.get_height() == 768, "Caminhonete usa grade normalizada 4x2 de 512x384")

	var stone_texture := load(STONE_TEXTURE) as Texture2D
	_assert(stone_texture != null, "Asset da pedra existe")

	var sequence_source := FileAccess.get_file_as_string(SEQUENCE_SCRIPT_PATH)
	_assert(sequence_source.contains("MAX_BOTTLE_THROWS: int = 6"), "Sequência limita a seis lançamentos")
	_assert(sequence_source.contains("func start_debug(skip_intro: bool = false)"), "Sequência possui entrada de teste sem o boss")
	_assert(sequence_source.contains("OS.is_debug_build()"), "Atalho de teste fica restrito ao build de desenvolvimento")
	_assert(sequence_source.contains("REQUIRED_HITS: int = 3"), "Sequência exige três acertos")
	_assert(sequence_source.contains("StandardDialogueBoxClass"), "Sequência usa diálogo canônico")
	_assert(not sequence_source.contains("PrototypeHud"), "Sequência não usa PrototypeHud")
	_assert(sequence_source.contains("SIDEWALK_BARRIER_LAYER: int = 16"), "Barreira da rua usa camada física dedicada")

	var bottle_source := FileAccess.get_file_as_string(BOTTLE_SCRIPT_PATH)
	_assert(bottle_source.contains('add_to_group("gas_bottle_projectile")'), "Garrafas são rastreáveis pela set piece")
	_assert(bottle_source.contains('"setpiece_punk"'), "Garrafas reconhecem os punks da set piece")
	_assert(bottle_source.contains("if actor != null and actor.is_in_group(\"setpiece_punk\")"), "Punks não são tratados como voadores pelo projétil")

	var map5_source := FileAccess.get_file_as_string(MAP5_SCRIPT_PATH)
	_assert(map5_source.contains("_start_truck_attack_sequence()"), "Map 5 inicia a set piece após a derrota do boss")
	_assert(map5_source.contains("func _on_encounter_cleared()"), "Map 5 segura a saída até a set piece terminar")
	_assert(map5_source.contains("func _unhandled_input(event: InputEvent) -> void"), "Map 5 possui atalho de debug por teclado")
	_assert(map5_source.contains("KEY_F9"), "F9 inicia a sequência completa em debug")
	_assert(map5_source.contains("KEY_F10"), "F10 inicia a sequência jogável em debug")
	_assert(map5_source.contains("start_debug"), "Map 5 chama a entrada de debug da mesma set piece")

	var packed_level := load(LEVEL_PATH) as PackedScene
	_assert(packed_level != null, "Cena do Map 5 pode ser carregada")

	print("TESTES DA SET PIECE PÓS-BÊBADO CONCLUÍDOS")
	quit(0)


func _assert(condition: bool, message: String) -> void:
	if condition:
		print("[OK] %s" % message)
	else:
		push_error("[FALHA] %s" % message)
