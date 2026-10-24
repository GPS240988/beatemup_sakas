class_name SergioNPC
extends BaseNPC

## Controlador do NPC Sérgio (O Dono da Locadora Invadida).
## Herda de BaseNPC, implementando navegação contínua em ritmo acelerado
## por todo o mapa navegável e exibição periódica das 4 imagens de fala pré-renderizadas.
##
## Estética visual: Dark Premium Medieval / Cyber-Arcade (GAME_RULES.md).
## Grupos canônicos: 'actors', 'npcs', 'damageable'.

const SERGIO_TEXTURE: Texture2D = preload("res://assets/sprites/characters/sergio/walk_sergio.webp")

@export_group("Falas em Imagem do Sérgio")
## Lista de texturas com as falas pré-renderizadas do Sérgio
@export var speech_textures: Array[Texture2D] = [
	preload("res://assets/sprites/falas/fala_sergio1.webp"),
	preload("res://assets/sprites/falas/fala_sergio2.webp"),
	preload("res://assets/sprites/falas/fala_sergio3.webp"),
	preload("res://assets/sprites/falas/fala_sergio4.webp")
]
@export var dialogue_display_duration: float = 3.8
@export var dialogue_interval: float = 3.5
@export var auto_dialogue: bool = true

# Propriedades mantidas para retrocompatibilidade
@export var dialogue_text: String = "Socorro, minha locadora foi invadida. Me ajudem"
@export var dialogue_phrases: Array[String] = [
	"Socorro, minha locadora foi invadida. Me ajudem",
	"Minha mulher está grávida, nos ajude",
	"Minha veia está entupida, acho que vou infartar"
]

var current_phrase_index: int = 0

@export_group("Patrulha Acelerada no Mapa")
@export var accelerated_speed: float = 230.0
@export var waypoint_tolerance: float = 30.0
@export var waypoint_stuck_timeout: float = 5.5

## Waypoints canônicos cobrindo toda a malha navegável do Mapa 1 (Entrada, Corredor Superior, Balcão, Fundo)
@export var map_patrol_points: Array[Vector2] = [
	Vector2(260, 680),   # Entrada esquerda / início do mapa
	Vector2(550, 520),   # Corredor superior esquerdo (atrás das estantes de TV)
	Vector2(1070, 530),  # Corredor superior central (atrás das gôndolas)
	Vector2(1440, 530),  # Corredor superior direito (balcão da locadora)
	Vector2(1880, 680),  # Fundo direito / área da saída
	Vector2(1450, 680),  # Corredor inferior direito
	Vector2(1070, 680),  # Centro inferior (entre gôndolas e corredor)
	Vector2(620, 680),   # Corredor inferior esquerdo
	Vector2(400, 620)    # Retorno à área inicial da loja
]

var current_waypoint_index: int = 0
var _dialogue_timer: float = 0.0
var _is_dialogue_visible: bool = false
var _waypoint_timer: float = 0.0
var _anim_time: float = 0.0
var _bubble_tween: Tween = null

@onready var speech_bubble: Node2D = get_node_or_null("SpeechBubble") as Node2D
@onready var speech_sprite: Sprite2D = _resolve_speech_sprite()
@onready var sprite_node: Sprite2D = get_node_or_null("Visual/Sprite2D") as Sprite2D
@onready var animated_sprite: AnimatedSprite2D = get_node_or_null("Visual/AnimatedSprite2D") as AnimatedSprite2D


func _ready() -> void:
	npc_name = "Sérgio"
	run_speed = accelerated_speed
	walk_speed = accelerated_speed * 0.75
	default_state = NPCState.MOVE_TO

	super._ready()

	# Configura textura do Sérgio se nó Sprite2D existir
	if sprite_node != null and sprite_node.texture == null:
		sprite_node.texture = SERGIO_TEXTURE

	# Inicia animação de caminhada se nó AnimatedSprite2D existir
	if animated_sprite != null:
		animated_sprite.play("walk")

	# Inicializa temporizador da fala
	_dialogue_timer = dialogue_interval * 0.5
	if speech_bubble != null:
		speech_bubble.visible = false

	# Garante resolução do nó e texturas de fala
	speech_sprite = _resolve_speech_sprite()
	_ensure_speech_textures()
	if speech_sprite != null and not speech_textures.is_empty():
		speech_sprite.texture = speech_textures[0]

	# Posiciona Sérgio no waypoint mais próximo ou no primeiro
	if not map_patrol_points.is_empty():
		_select_closest_or_next_waypoint()


func _physics_process(delta: float) -> void:
	if current_state == NPCState.DISABLED:
		velocity = Vector2.ZERO
		return

	# Atualiza ciclo de fala em imagem alternando de tempos em tempos
	_update_dialogue_cycle(delta)

	# Atualiza patrulha acelerada por todo o mapa
	_update_accelerated_patrol(delta)

	# Processa movimentação física
	super._physics_process(delta)

	# Animação dinâmica de corrida (squash & stretch / bobbing do sprite)
	_update_run_animation(delta)

	# Mantém a imagem de fala sempre desespelhada e orientada para leitura correta
	if speech_bubble != null:
		speech_bubble.scale.x = 1.0


func _resolve_speech_sprite() -> Sprite2D:
	if speech_bubble == null:
		speech_bubble = get_node_or_null("SpeechBubble") as Node2D
	if speech_bubble == null:
		return null
	var s: Sprite2D = speech_bubble.get_node_or_null("SpeechSprite") as Sprite2D
	if s == null:
		s = speech_bubble.get_node_or_null("Sprite2D") as Sprite2D
	if s == null:
		for child in speech_bubble.get_children():
			if child is Sprite2D:
				return child as Sprite2D
	return s


func _ensure_speech_textures() -> void:
	if speech_textures.is_empty():
		var paths: Array[String] = [
			"res://assets/sprites/falas/fala_sergio1.webp",
			"res://assets/sprites/falas/fala_sergio2.webp",
			"res://assets/sprites/falas/fala_sergio3.webp",
			"res://assets/sprites/falas/fala_sergio4.webp"
		]
		for p in paths:
			if ResourceLoader.exists(p):
				var tex: Texture2D = load(p) as Texture2D
				if tex != null:
					speech_textures.append(tex)


## Gerencia o ciclo periódico das falas em imagem alternando entre as 4 imagens
func _update_dialogue_cycle(delta: float) -> void:
	if not auto_dialogue or speech_bubble == null:
		return

	_dialogue_timer -= delta
	if _is_dialogue_visible:
		# Imagem de fala está ativa na tela
		if _dialogue_timer <= 0.0:
			hide_speech_bubble()
			_dialogue_timer = dialogue_interval
	else:
		# Aguardando intervalo para reaparecer de tempos em tempos com a próxima imagem
		if _dialogue_timer <= 0.0:
			if not speech_textures.is_empty():
				show_speech_bubble(current_phrase_index)
				current_phrase_index = (current_phrase_index + 1) % speech_textures.size()
			else:
				show_speech_bubble()
			_dialogue_timer = dialogue_display_duration


## Exibe a imagem de fala com animação pop dinâmica
func show_speech_bubble(phrase_input: Variant = null) -> void:
	if speech_bubble == null:
		return

	speech_sprite = _resolve_speech_sprite()
	_ensure_speech_textures()

	var selected_tex: Texture2D = null

	if phrase_input is Texture2D:
		selected_tex = phrase_input as Texture2D
	elif phrase_input is int:
		var idx: int = int(phrase_input)
		if not speech_textures.is_empty():
			selected_tex = speech_textures[idx % speech_textures.size()]
	elif phrase_input is String:
		var s: String = phrase_input as String
		if s.find("mulher") != -1 or s.find("grávida") != -1 or s.find("gravida") != -1:
			if speech_textures.size() > 1:
				selected_tex = speech_textures[1]
		elif s.find("veia") != -1 or s.find("infartar") != -1:
			if speech_textures.size() > 2:
				selected_tex = speech_textures[2]
		elif not speech_textures.is_empty():
			selected_tex = speech_textures[0]
	elif not speech_textures.is_empty():
		selected_tex = speech_textures[current_phrase_index % speech_textures.size()]

	if speech_sprite != null and selected_tex != null:
		speech_sprite.texture = selected_tex

	speech_bubble.visible = true
	_is_dialogue_visible = true

	if _bubble_tween != null and _bubble_tween.is_valid():
		_bubble_tween.kill()

	# Micro-animação pop retrô de escala (0.7 -> 1.0)
	speech_bubble.scale = Vector2(0.7, 0.7)
	_bubble_tween = create_tween()
	if _bubble_tween != null:
		_bubble_tween.tween_property(speech_bubble, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## Oculta a imagem de fala com transição suave
func hide_speech_bubble() -> void:
	if speech_bubble == null:
		return

	if _bubble_tween != null and _bubble_tween.is_valid():
		_bubble_tween.kill()

	_bubble_tween = create_tween()
	if _bubble_tween != null:
		_bubble_tween.tween_property(speech_bubble, "scale", Vector2(0.7, 0.7), 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		_bubble_tween.tween_callback(func() -> void:
			if speech_bubble != null:
				speech_bubble.visible = false
				speech_bubble.scale = Vector2.ONE
				_is_dialogue_visible = false
		)
	else:
		speech_bubble.visible = false
		_is_dialogue_visible = false


## Lógica de patrulha acelerada contínua pelos waypoints do mapa navegável
func _update_accelerated_patrol(delta: float) -> void:
	if map_patrol_points.is_empty():
		return

	var current_target: Vector2 = map_patrol_points[current_waypoint_index]
	target_position = current_target
	_waypoint_timer += delta

	# Verifica se alcançou o waypoint atual ou se estourou o tempo de segurança
	var dist_to_target: float = global_position.distance_to(current_target)
	if dist_to_target <= waypoint_tolerance or _waypoint_timer >= waypoint_stuck_timeout:
		_advance_to_next_waypoint()

	# Garante que o NPC continue em estado MOVE_TO com velocidade acelerada
	if current_state != NPCState.MOVE_TO and current_state != NPCState.FLEE:
		change_state(NPCState.MOVE_TO)


func _advance_to_next_waypoint() -> void:
	_waypoint_timer = 0.0
	current_waypoint_index = (current_waypoint_index + 1) % map_patrol_points.size()
	target_position = map_patrol_points[current_waypoint_index]


func _select_closest_or_next_waypoint() -> void:
	var closest_idx: int = 0
	var min_dist: float = INF
	for i in range(map_patrol_points.size()):
		var d: float = global_position.distance_to(map_patrol_points[i])
		if d < min_dist:
			min_dist = d
			closest_idx = i
	current_waypoint_index = (closest_idx + 1) % map_patrol_points.size()
	target_position = map_patrol_points[current_waypoint_index]


## Animação orgânica de corrida acelerada (pausa automaticamente se bloqueado em colisores)
func _update_run_animation(delta: float) -> void:
	if visual_root == null:
		return

	# Verifica velocidade pretendida e deslocamento físico real no mundo (pós move_and_slide)
	var intended_speed_sq: float = velocity.length_squared()
	var real_speed_sq: float = get_real_velocity().length_squared()
	var is_blocked: bool = is_on_wall() and real_speed_sq < 100.0

	if intended_speed_sq > 400.0 and not is_blocked:
		if animated_sprite != null and not animated_sprite.is_playing():
			animated_sprite.play("walk")

		_anim_time += delta * 18.0
		# Pulo/trote dinâmico nos passos
		visual_root.position.y = -absf(sin(_anim_time)) * 4.0
		# Leve flutuação suave na imagem de fala
		if speech_bubble != null and _is_dialogue_visible:
			speech_bubble.position.y = -200.0 + sin(_anim_time * 0.8) * 3.0
	else:
		# Bloqueado em uma parede/colisor ou parado: pausa a caminhada e apoia pés no solo
		if animated_sprite != null and animated_sprite.is_playing():
			animated_sprite.pause()
			animated_sprite.set_frame_and_progress(0, 0.0)

		visual_root.position.y = move_toward(visual_root.position.y, 0.0, delta * 30.0)
		visual_root.rotation = move_toward(visual_root.rotation, 0.0, delta * 2.0)
		if speech_bubble != null:
			speech_bubble.position.y = -200.0


## Reação ao sofrer dano (além do flee padrão, exibe imediatamente fala de pânico)
func take_damage(damage_input: Variant) -> bool:
	var accepted: bool = super.take_damage(damage_input)
	if accepted:
		show_speech_bubble(0)
		_dialogue_timer = dialogue_display_duration * 1.5
	return accepted
