extends SceneTree

const MAP5_SCENE_PATH: String = "res://scenes/levels/map_5.tscn"
const MAP6_SCENE_PATH: String = "res://scenes/levels/map_6.tscn"
const PELE_SCENE_PATH: String = "res://scenes/actors/map6_pele_npc.tscn"
const MAP6_SCRIPT_PATH: String = "res://scripts/levels/map_6.gd"
const DIALOGUE_SCRIPT_PATH: String = "res://scripts/events/map6_dialogue_sequence.gd"
const REQUIRED_ASSETS: Array[String] = [
	"res://assets/backgrounds/maps/fase2/Fase2_2.webp",
	"res://assets/sprites/characters/npc/pele/pele_idle.png",
	"res://assets/sprites/characters/npc/pele/pele_expressions.png",
	"res://assets/sprites/characters/npc/pele/pele_gestures.png",
	"res://assets/ui/hud/portraits/portrait_guilherme.png",
	"res://assets/ui/hud/portraits/portrait_gabriel.png",
	"res://assets/ui/hud/portraits/portrait_andre.png",
	"res://assets/ui/hud/portraits/portrait_juliana.png",
	"res://assets/ui/hud/portraits/portrait_alessandro.png"
]


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var failures: Array[String] = []
	for asset_path in REQUIRED_ASSETS:
		if not ResourceLoader.exists(asset_path):
			failures.append("Asset ausente: " + asset_path)

	var map5 := load(MAP5_SCENE_PATH) as PackedScene
	if map5 == null:
		failures.append("Map 5 não pôde ser carregado.")
	else:
		var map5_instance := map5.instantiate()
		if str(map5_instance.get("next_map_scene_path")) != MAP6_SCENE_PATH:
			failures.append("Map 5 não aponta para o Map 6.")
		map5_instance.free()

	var pele_scene := load(PELE_SCENE_PATH) as PackedScene
	if pele_scene == null:
		failures.append("Cena do Pelé não pôde ser carregada.")
	else:
		var pele_instance := pele_scene.instantiate()
		if not pele_instance.has_method("play_animation") or not pele_instance.has_method("interact"):
			failures.append("Pelé não expõe a API de animação/interação esperada.")
		get_root().add_child(pele_instance)
		await process_frame
		var pele_sprite := pele_instance.get_node_or_null("Visual/AnimatedSprite2D") as AnimatedSprite2D
		if pele_sprite == null or pele_sprite.sprite_frames == null:
			failures.append("SpriteFrames do Pelé não foram construídos ao entrar na árvore.")
		else:
			var expected_animation_frames: Dictionary = {
				"idle_neutral": 1,
				"idle_attentive": 4,
				"reaction_skeptical": 4,
				"reaction_amused": 4,
				"gesture_stop": 4,
				"gesture_allow_entry": 4
			}
			for animation_name in expected_animation_frames:
				if not pele_sprite.sprite_frames.has_animation(animation_name):
					failures.append("Animação ausente no Pelé: " + str(animation_name))
				elif pele_sprite.sprite_frames.get_frame_count(animation_name) != int(expected_animation_frames[animation_name]):
					failures.append("Contagem incorreta de frames em: " + str(animation_name))
		pele_instance.queue_free()
		await process_frame

	var map6 := load(MAP6_SCENE_PATH) as PackedScene
	if map6 == null:
		failures.append("Map 6 não pôde ser carregado.")
	else:
		var map6_instance := map6.instantiate()
		var actors_root := map6_instance.get_node_or_null("World/Actors")
		if actors_root == null:
			failures.append("Contêiner World/Actors ausente no Map 6.")
		else:
			if actors_root.get_node_or_null("Player") == null:
				failures.append("Player ausente no Map 6.")
			if actors_root.get_node_or_null("Pele") == null:
				failures.append("Pelé ausente no Map 6.")
			for actor_node in actors_root.get_children():
				if actor_node.name not in ["Player", "Pele"]:
					failures.append("Ator não permitido no Map 6: " + actor_node.name)
		if str(map6_instance.get("next_map_scene_path")) != "res://scenes/levels/map_7.tscn":
			failures.append("Destino futuro do Map 6 não está configurado para o Map 7.")
		map6_instance.free()

	var map6_source: String = FileAccess.get_file_as_string(MAP6_SCRIPT_PATH)
	if map6_source.contains("_create_companion") or map6_source.contains("CharacterBody2D.new()"):
		failures.append("O controlador do Map 6 ainda cria acompanhantes como atores vivos.")

	var dialogue_source: String = FileAccess.get_file_as_string(DIALOGUE_SCRIPT_PATH)
	if not dialogue_source.contains("ARRIVAL_LINES") or not dialogue_source.contains("PELE_CONTACT_LINES"):
		failures.append("Separação entre diálogo de chegada e contato com Pelé ausente.")
	if not dialogue_source.contains("_selected_order.has(character_id)"):
		failures.append("A escolha sequencial não bloqueia personagens já selecionados.")

	if failures.is_empty():
		print("PASS: Map 5 → Map 6, Pelé, ausência de acompanhantes e fluxo de diálogos validados.")
		quit(0)
		return

	for failure in failures:
		push_error(failure)
	quit(1)
