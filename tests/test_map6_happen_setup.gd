extends SceneTree

const MAP5_SCENE_PATH: String = "res://scenes/levels/map_5.tscn"
const MAP6_SCENE_PATH: String = "res://scenes/levels/map_6.tscn"
const PELE_SCENE_PATH: String = "res://scenes/actors/map6_pele_npc.tscn"
const MAP6_SCRIPT_PATH: String = "res://scripts/levels/map_6.gd"
const DIALOGUE_SCRIPT_PATH: String = "res://scripts/events/map6_dialogue_sequence.gd"
const STORY_BACKGROUND_PATH: String = "res://assets/backgrounds/maps/fase2/story_happen.webp"
const REQUIRED_ASSETS: Array[String] = [
	"res://assets/backgrounds/maps/fase2/Fase2_2.webp",
	STORY_BACKGROUND_PATH,
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
		if (int(pele_instance.collision_layer) & 2) == 0:
			failures.append("Pelé não está na Layer 2 para bloquear o jogador.")
		if (int(pele_instance.collision_mask) & 1) == 0 or (int(pele_instance.collision_mask) & 2) == 0:
			failures.append("Pelé não consulta as camadas do jogador e do cenário sólido.")
		var bark_bubble := pele_instance.get("_contact_bubble") as PanelContainer
		var bark_label := pele_instance.get("_contact_bubble_label") as Label
		if bark_bubble == null or bark_label == null:
			failures.append("Balão de fala espontânea do Pelé não foi construído.")
		else:
			var bark_style: StyleBox = bark_bubble.get_theme_stylebox("panel")
			if not bark_style is StyleBoxTexture:
				failures.append("Balão espontâneo não utiliza StyleBoxTexture oficial.")
			elif (bark_style as StyleBoxTexture).texture.resource_path != "res://assets/ui/hud/dialog_frame_9patch.png":
				failures.append("Balão espontâneo não usa dialog_frame_9patch.png.")
			if bark_label.label_settings == null or bark_label.label_settings.font_size != 20:
				failures.append("Fonte do balão espontâneo não está em 20px.")
			if bark_bubble.custom_minimum_size != Vector2(420.0, 104.0):
				failures.append("Balão espontâneo não reserva área suficiente para frases longas.")
		var contact_area := pele_instance.get_node_or_null("ContactArea") as Area2D
		if contact_area == null or contact_area.collision_mask != 1:
			failures.append("Área de contato físico para as falas espontâneas ausente.")
		else:
			var contact_shape := contact_area.get_node_or_null("CollisionShape2D") as CollisionShape2D
			if contact_shape == null or contact_shape.shape == null:
				failures.append("Shape da área de contato espontâneo ausente.")
			elif contact_shape.shape is RectangleShape2D and (contact_shape.shape as RectangleShape2D).size.x > 30.0:
				failures.append("Área de fala espontânea está grande demais; deve disparar apenas no contato próximo.")
			if not contact_area.body_entered.is_connected(Callable(pele_instance, "_on_contact_body_entered")):
				failures.append("Sinal de entrada do contato não está conectado ao evento de falas espontâneas.")
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
	if not dialogue_source.contains(STORY_BACKGROUND_PATH):
		failures.append("A negociação não utiliza a arte narrativa story_happen.webp.")
	if not dialogue_source.contains("_play_restaurant_entry_transition"):
		failures.append("A transição cinematográfica de entrada na pizzaria está ausente.")
	if dialogue_source.contains("STRETCH_KEEP_ASPECT_COVERED") or not dialogue_source.contains("STRETCH_KEEP_ASPECT_CENTERED"):
		failures.append("A arte da HAPPEN não está configurada para exibição integral sem corte.")
	if not dialogue_source.contains("STORY_ART_BOTTOM_DESKTOP") or not dialogue_source.contains("STORY_DIALOGUE_TOP_DESKTOP"):
		failures.append("O palco da imagem e a área de diálogo não estão separados.")
	var pele_source: String = FileAccess.get_file_as_string("res://scripts/actors/map6_pele_npc.gd")
	if not dialogue_source.contains("StandardDialogueBoxClass.build_dialogue_ui"):
		failures.append("Diálogo principal não utiliza a fábrica oficial StandardDialogueBox.")
	if not dialogue_source.contains("STORY_DIALOGUE_TOP_DESKTOP: float = 0.67") or not dialogue_source.contains("STORY_DIALOGUE_TOP_MOBILE: float = 0.64"):
		failures.append("Área vertical do diálogo narrativo diverge da área segura canônica.")
	if not dialogue_source.contains("STORY_DIALOGUE_BOTTOM: float = 0.98") or not dialogue_source.contains("custom_minimum_size = Vector2(0.0, 216.0 if not is_mobile else 232.0)"):
		failures.append("Moldura não reserva altura suficiente para falas quebradas em múltiplas linhas.")
	if not pele_source.contains("StandardDialogueBoxClass.create_dialogue_stylebox()"):
		failures.append("Balão espontâneo do Pelé não utiliza a moldura oficial 9-patch.")
	if not pele_source.contains("CONTACT_BARK_FONT_SIZE: int = 20"):
		failures.append("Fonte das falas espontâneas não foi ampliada para 20px.")
	for bark in ["Encosta não, florzinha!", "Pega no charuto aqui na minha calça!", "Na verdade eu sou um velho gordo.", "Preconceituoso!"]:
		if not pele_source.contains(bark):
			failures.append("Fala espontânea de contato ausente: " + bark)
	if not pele_source.contains("_on_contact_body_entered") or not pele_source.contains("_show_contact_bark_after_interaction_window"):
		failures.append("Evento de fala espontânea por contato físico ausente.")
	if not map6_source.contains("_actors_layer.visible = false"):
		failures.append("Os atores vivos não são ocultados durante a arte estática da negociação.")

	if failures.is_empty():
		print("PASS: Map 5 → Map 6, Pelé, ausência de acompanhantes e fluxo de diálogos validados.")
		quit(0)
		return

	for failure in failures:
		push_error(failure)
	quit(1)
