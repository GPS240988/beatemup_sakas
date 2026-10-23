class_name SergioNPC
extends BaseNPC

## Controlador do NPC Sérgio (O Dono da Locadora Invadida).
## Herda de BaseNPC, implementando navegação contínua em ritmo acelerado
## por todo o mapa navegável e balão de diálogo retrô arcade periódico.
##
## Estética visual: Dark Premium Medieval / Cyber-Arcade (GAME_RULES.md).
## Grupos canônicos: 'actors', 'npcs', 'damageable'.

const ARCADE_FONT: FontFile = preload("res://assets/fonts/arcade_bold.ttf")
const SERGIO_TEXTURE: Texture2D = preload("res://assets/sprites/characters/sergio.webp")

@export_group("Diálogo Arcade")
@export var dialogue_text: String = "Socorro, minha locadora foi invadida. Me ajudem"
@export var dialogue_display_duration: float = 3.8
@export var dialogue_interval: float = 4.2
@export var auto_dialogue: bool = true

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

@onready var speech_bubble: Node2D = get_node_or_null("SpeechBubble") as Node2D
@onready var dialogue_label: Label = get_node_or_null("SpeechBubble/PanelContainer/MarginContainer/Label") as Label
@onready var sprite_node: Sprite2D = get_node_or_null("Visual/Sprite2D") as Sprite2D


func _ready() -> void:
	npc_name = "Sérgio"
	run_speed = accelerated_speed
	walk_speed = accelerated_speed * 0.75
	default_state = NPCState.MOVE_TO

	super._ready()

	# Configura textura do Sérgio se nó Sprite2D existir
	if sprite_node != null and sprite_node.texture == null:
		sprite_node.texture = SERGIO_TEXTURE

	# Inicializa temporizador do balão de fala
	_dialogue_timer = dialogue_interval * 0.5
	if speech_bubble != null:
		speech_bubble.visible = false

	# Garante que o texto oficial esteja atribuído
	if dialogue_label != null:
		dialogue_label.text = dialogue_text

	# Posiciona Sérgio no waypoint mais próximo ou no primeiro
	if not map_patrol_points.is_empty():
		_select_closest_or_next_waypoint()


func _physics_process(delta: float) -> void:
	if current_state == NPCState.DISABLED:
		velocity = Vector2.ZERO
		return

	# Atualiza ciclo de diálogo retrô de tempos em tempos
	_update_dialogue_cycle(delta)

	# Atualiza patrulha acelerada por todo o mapa
	_update_accelerated_patrol(delta)

	# Processa movimentação física
	super._physics_process(delta)

	# Animação dinâmica de corrida (squash & stretch / bobbing do sprite)
	_update_run_animation(delta)

	# Mantém o balão de diálogo sempre desespelhado e orientado para leitura correta
	if speech_bubble != null:
		speech_bubble.scale.x = 1.0


## Gerencia o ciclo periódico do balão de fala retrô
func _update_dialogue_cycle(delta: float) -> void:
	if not auto_dialogue or speech_bubble == null:
		return

	_dialogue_timer -= delta
	if _is_dialogue_visible:
		# Balão está ativo na tela
		if _dialogue_timer <= 0.0:
			hide_speech_bubble()
			_dialogue_timer = dialogue_interval
	else:
		# Aguardando intervalo para reaparecer de tempos em tempos
		if _dialogue_timer <= 0.0:
			show_speech_bubble()
			_dialogue_timer = dialogue_display_duration


## Exibe a caixa de diálogo retrô com animação pop e efeito visual
func show_speech_bubble(text_to_show: String = "") -> void:
	if speech_bubble == null:
		return

	if text_to_show != "":
		dialogue_text = text_to_show

	if dialogue_label != null:
		dialogue_label.text = dialogue_text

	speech_bubble.visible = true
	_is_dialogue_visible = true

	# Micro-animação pop retrô de escala (0.7 -> 1.0)
	speech_bubble.scale = Vector2(0.7, 0.7)
	var tween: Tween = create_tween()
	if tween != null:
		tween.tween_property(speech_bubble, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## Oculta a caixa de diálogo retrô
func hide_speech_bubble() -> void:
	if speech_bubble == null:
		return

	var tween: Tween = create_tween()
	if tween != null:
		tween.tween_property(speech_bubble, "scale", Vector2(0.7, 0.7), 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tween.tween_callback(func() -> void:
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


## Animação orgânica de corrida acelerada
func _update_run_animation(delta: float) -> void:
	if visual_root == null:
		return

	var speed_sq: float = velocity.length_squared()
	if speed_sq > 400.0:
		_anim_time += delta * 18.0
		# Pulo/trote dinâmico nos passos
		visual_root.position.y = -absf(sin(_anim_time)) * 6.0
		# Leve inclinação lateral de quem corre em desespero
		visual_root.rotation = sin(_anim_time * 0.5) * 0.05
		# Leve flutuação suave no balão
		if speech_bubble != null and _is_dialogue_visible:
			speech_bubble.position.y = -255.0 + sin(_anim_time * 0.8) * 3.0
	else:
		visual_root.position.y = move_toward(visual_root.position.y, 0.0, delta * 30.0)
		visual_root.rotation = move_toward(visual_root.rotation, 0.0, delta * 2.0)
		if speech_bubble != null:
			speech_bubble.position.y = -255.0


## Reação ao sofrer dano (além do flee padrão, pede socorro com urgência imediata)
func take_damage(damage_input: Variant) -> bool:
	var accepted: bool = super.take_damage(damage_input)
	if accepted:
		show_speech_bubble("SOCORRO!! NÃO ME BATA, MINHA LOCADORA FOI INVASÃO!")
		_dialogue_timer = dialogue_display_duration * 1.5
	return accepted
