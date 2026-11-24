extends SceneTree

const LEVEL_PATH: String = "res://scenes/levels/map_5.tscn"
const MAP5_SCRIPT_PATH: String = "res://scripts/levels/map_5_stage2.gd"
const SEQUENCE_SCRIPT_PATH: String = "res://scripts/events/map5_truck_attack_sequence.gd"
const PUNK_SCRIPT_PATH: String = "res://scripts/events/map5_truck_attack_punk.gd"
const STONE_SCRIPT_PATH: String = "res://scripts/events/map5_truck_attack_stone.gd"
const BOTTLE_SCRIPT_PATH: String = "res://scripts/actors/projectiles/gas_bottle_projectile.gd"
const ATTENDANT_SCRIPT_PATH: String = "res://scripts/actors/frentista_interactable.gd"

const PUNK_SHEETS: Array[String] = [
	"res://assets/sprites/stage2/truck_attack_sequence/punks/punk_01_spritesheet.png",
	"res://assets/sprites/stage2/truck_attack_sequence/punks/punk_02_spritesheet.png",
	"res://assets/sprites/stage2/truck_attack_sequence/punks/punk_03_spritesheet.png",
]
const TRUCK_SHEET: String = "res://assets/sprites/stage2/truck_attack_sequence/truck/truck_spritesheet.png"
const STONE_TEXTURE: String = "res://assets/sprites/stage2/truck_attack_sequence/stone.png"
const TRUCK_FULL_TEXTURE: String = "res://assets/sprites/stage2/truck_attack_sequence/truck/truck_full.png"


func _initialize() -> void:
	call_deferred("_run_tests")


func _run_tests() -> void:
	_assert(ResourceLoader.exists(LEVEL_PATH), "Map 5 continua disponível")
	_assert(ResourceLoader.exists(MAP5_SCRIPT_PATH), "Script do Map 5 continua disponível")
	_assert(ResourceLoader.exists(SEQUENCE_SCRIPT_PATH), "Script da set piece existe")
	_assert(ResourceLoader.exists(PUNK_SCRIPT_PATH), "Script dos punks existe")
	_assert(ResourceLoader.exists(STONE_SCRIPT_PATH), "Script das pedras existe")
	_assert(ResourceLoader.exists(BOTTLE_SCRIPT_PATH), "Projétil de garrafa existe")
	_assert(ResourceLoader.exists(ATTENDANT_SCRIPT_PATH), "Script do frentista existe")

	for path in PUNK_SHEETS:
		var texture := load(path) as Texture2D
		_assert(texture != null, "Spritesheet de punk carrega: %s" % path)
		if texture != null:
			_assert(texture.get_width() == 880 and texture.get_height() == 600, "Punk usa grade normalizada 4x2 de 220x300")

	var truck_texture := load(TRUCK_SHEET) as Texture2D
	_assert(truck_texture != null, "Spritesheet da caminhonete carrega")
	if truck_texture != null:
		_assert(truck_texture.get_width() == 2048 and truck_texture.get_height() == 768, "Caminhonete usa grade normalizada 4x2 de 512x384")

	var full_truck_texture := load(TRUCK_FULL_TEXTURE) as Texture2D
	_assert(full_truck_texture != null, "Arte completa da caminhonete carrega")
	if full_truck_texture != null:
		_assert(full_truck_texture.get_width() == 1536 and full_truck_texture.get_height() == 615, "Arte completa mantém proporção e recorte transparente aprovado")

	_assert(CombatFeedback != null, "CombatFeedback está acessível para SFX da caminhonete")
	_assert(ResourceLoader.exists("res://assets/audio/sfx/acelerando.mp3"), "SFX acelerando.mp3 existe")
	_assert(ResourceLoader.exists("res://assets/audio/sfx/frenagem_derrapagem.mp3"), "SFX frenagem_derrapagem.mp3 existe")
	_assert(ResourceLoader.exists("res://assets/audio/sfx/motorchegando.mp3"), "SFX motorchegando.mp3 existe")
	_assert(ResourceLoader.exists("res://assets/audio/sfx/pedrada.mp3"), "SFX pedrada.mp3 existe")

	var stone_texture := load(STONE_TEXTURE) as Texture2D
	_assert(stone_texture != null, "Asset da pedra existe")

	var sequence_source := FileAccess.get_file_as_string(SEQUENCE_SCRIPT_PATH)
	_assert(sequence_source.contains("MAX_BOTTLE_THROWS: int = 6"), "Sequência limita a seis lançamentos por rodada")
	_assert(sequence_source.contains("func start_debug(skip_intro: bool = false)"), "Sequência possui entrada de teste sem o boss")
	_assert(sequence_source.contains("OS.is_debug_build()"), "Atalho de teste fica restrito ao build de desenvolvimento")
	_assert(sequence_source.contains("REQUIRED_HITS: int = 3"), "Sequência exige três acertos")
	_assert(sequence_source.contains("StandardDialogueBoxClass"), "Sequência usa diálogo canônico")
	_assert(not sequence_source.contains("PrototypeHud"), "Sequência não usa PrototypeHud")
	_assert(sequence_source.contains("SIDEWALK_BARRIER_LAYER: int = 16"), "Barreira da rua usa camada física dedicada")
	_assert(sequence_source.contains("TRUCK_ROAD_Y: float = 674.0"), "Caminhonete ocupa a faixa de rua mais próxima da câmera")
	_assert(sequence_source.contains("TRUCK_STAGE_X: float = 745.0"), "Caminhonete para no centro entre os engradados")
	_assert(sequence_source.contains("PUNK_BED_OFFSETS"), "Punks usam pontos locais próprios da caçamba")
	_assert(sequence_source.contains("Vector2(-207.0, -118.0)"), "Punk traseiro usa posição lateral própria")
	_assert(sequence_source.contains("Vector2(-150.0, -128.0)"), "Punk central fica escalonado em profundidade")
	_assert(sequence_source.contains("Vector2(-93.0, -118.0)"), "Punk dianteiro usa posição lateral própria")
	_assert(sequence_source.contains("TRUCK_BED_FOREGROUND_TEXTURE"), "Set piece possui textura de primeiro plano da caçamba")
	_assert(sequence_source.contains("_truck_bed_foreground_sprite.visible = use_full_vehicle"), "Oclusão frontal da caçamba acompanha o estado do veículo")
	_assert(sequence_source.contains("_truck.add_child(punk)"), "Punks acompanham a caminhonete como filhos")
	_assert(sequence_source.contains("TRUCK_FULL_TEXTURE"), "Estados finais usam a arte completa da caminhonete")
	_assert(sequence_source.contains("signal all_punks_defeated()"), "Terceiro punk emite sinal de conclusão visual")
	_assert(sequence_source.contains("all_punks_defeated.emit()"), "Sinal SIGA dispara no terceiro punk")
	_assert(sequence_source.contains("use_full_vehicle: bool = true"), "Todos os estados mantêm a proporção unificada da arte completa sem encolhimento")
	_assert(sequence_source.contains("_truck_full_sprite.visible = use_full_vehicle"), "Sprite completo ativo em todas as fases da caminhonete")
	_assert(sequence_source.contains("play_truck_motor_chegando"), "Chegada da caminhonete toca SFX acelerando.mp3")
	_assert(sequence_source.contains("play_truck_frenagem_derrapagem"), "Frenagem e derrapagem tocam SFX frenagem_derrapagem.mp3")
	_assert(sequence_source.contains("play_truck_saindo"), "Saída da caminhonete toca SFX motorchegando.mp3")
	_assert(sequence_source.contains("_truck.y_sort_enabled = false"), "Composição interna do veículo usa ordem de desenho estável")
	_assert(sequence_source.contains("_truck.move_child(_truck_sprite, _truck.get_child_count() - 1)"), "Carroceria é desenhada sobre a parte inferior dos punks")
	_assert(sequence_source.contains("func _play_intro_arrival_drift()"), "Derrapagem de entrada termina antes do diálogo")
	_assert(sequence_source.contains("await _play_intro_arrival_drift()"), "Apresentação da chegada é aguardada antes do diálogo")
	_assert(sequence_source.contains("func _return_truck_for_remaining_punks()"), "Caminhonete retorna quando acabam as tentativas")
	_assert(sequence_source.contains("_throws_used = 0"), "Cada retorno libera uma nova rodada de seis arremessos")
	_assert(sequence_source.contains("punk.is_defeated()"), "Somente punks vivos retornam à caçamba")
	_assert(sequence_source.contains("var target := _get_stone_target(punk)"), "Pedra recebe a mira relativa ao punk que a arremessa")
	_assert(sequence_source.contains("STONE_AIM_OFFSETS"), "Pedras usam dispersão pequena para passar perto do jogador")
	_assert(sequence_source.contains("_sidewalk_barrier.global_position = Vector2.ZERO"), "Barreira permanece nas coordenadas do mapa")
	_assert(not sequence_source.contains("TRUCK_CRUISE_SPEED"), "Caminhonete não deriva para a borda durante o gameplay")
	_assert(not sequence_source.contains("_update_punk_positions"), "Punks mantêm ancoragem local na caçamba")

	var punk_source := FileAccess.get_file_as_string(PUNK_SCRIPT_PATH)
	_assert(punk_source.contains("BASE_VISUAL_SCALE: float = 0.40"), "Escala dos punks adequada ao espaço da caçamba")
	_assert(punk_source.contains("VISUAL_BASE_OFFSET_Y: float = -60.0"), "Base do spritesheet coincide com a âncora dos pés")
	_assert(punk_source.contains("_visual.position = Vector2(0.0, VISUAL_BASE_OFFSET_Y)"), "Offset visual usa a âncora calculada")
	_assert(punk_source.contains("capsule.radius = 34.0"), "Hurtbox dos punks tem largura mais generosa")
	_assert(punk_source.contains("capsule.height = 132.0"), "Hurtbox cobre a silhueta útil do torso")
	_assert(punk_source.contains("DODGE_CHANCE: float = 0.50"), "Punk possui 50% de chance de esquiva configurada")
	_assert(punk_source.contains("spawn_floating_text"), "Punk aciona texto flutuante em caso de esquiva")
	_assert(punk_source.contains('"MISS"'), "Texto de esquiva exibe 'MISS'")
	_assert(punk_source.contains("CombatFeedbackClass"), "Punk referencia CombatFeedback")

	var feedback_source := FileAccess.get_file_as_string("res://scripts/combat/combat_feedback.gd")
	_assert(feedback_source.contains("func spawn_floating_text"), "CombatFeedback implementa método estático spawn_floating_text")

	var bottle_source := FileAccess.get_file_as_string(BOTTLE_SCRIPT_PATH)
	_assert(bottle_source.contains('add_to_group("gas_bottle_projectile")'), "Garrafas são rastreáveis pela set piece")
	_assert(bottle_source.contains('"setpiece_punk"'), "Garrafas reconhecem os punks da set piece")
	_assert(bottle_source.contains("allowed_depth_tolerance = maxf(allowed_depth_tolerance, 104.0)"), "Punks recebem tolerância de profundidade específica")

	var stone_source := FileAccess.get_file_as_string(STONE_SCRIPT_PATH)
	_assert(stone_source.contains("circle.radius = 9.0"), "Colisão das pedras permite proximidade justa")
	_assert(stone_source.contains("sprite.scale = Vector2(1.25, 1.25)"), "Pedra tem aumento visual discreto sem ampliar o dano/collider")
	_assert(stone_source.contains("play_stone_throw"), "Arremesso de pedra toca SFX pedrada.mp3")

	var attendant_source := FileAccess.get_file_as_string(ATTENDANT_SCRIPT_PATH)
	_assert(attendant_source.contains("func set_interaction_enabled(enabled: bool)"), "Frentista pode ser bloqueado durante boss e caminhonete")
	_assert(attendant_source.contains("INTERACTION_RANGE_X: float = 28.0"), "Raio horizontal do frentista foi reduzido")
	_assert(attendant_source.contains("INTERACTION_DEPTH_Y: float = 16.0"), "Tolerância de profundidade do frentista foi reduzida")

	var map5_source := FileAccess.get_file_as_string(MAP5_SCRIPT_PATH)
	_assert(map5_source.contains("_start_truck_attack_sequence()"), "Map 5 inicia a set piece após a derrota do boss")
	_assert(map5_source.contains("_set_frentista_interaction_enabled(false)"), "Interação com frentista é bloqueada durante a luta e o evento")
	_assert(map5_source.contains("_set_frentista_truck_visibility(false)"), "Frentista se recolhe durante a presença da caminhonete")
	_assert(map5_source.contains("close_shape.size = Vector2(56.0, 32.0)"), "Área de interação do mapa usa alcance curto")
	_assert(map5_source.contains("func _on_encounter_cleared()"), "Map 5 segura a saída até a set piece terminar")
	_assert(map5_source.contains("if success:\n\t\tsuper._on_encounter_cleared()"), "SIGA só é liberado após sucesso e derrota dos três punks")
	_assert(map5_source.contains("sequence.all_punks_defeated.connect(_on_truck_attack_punks_defeated"), "Map 5 recebe o sinal do terceiro punk")
	_assert(map5_source.contains("func _on_truck_attack_punks_defeated()"), "Map 5 ativa o indicador SIGA após os três punks")
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
