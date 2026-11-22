class_name AerialVisualPriorityComponent
extends Node

## Prioridade visual temporária para saltos/voadoras.
## A raiz física e a coordenada dos pés não mudam: somente Visual recebe Z 1
## enquanto o ator está no ar, ficando acima de props caminháveis (Z 0) e sob
## Foreground (Z 10). A sombra permanece no plano Z 0.

@export var airborne_z_index: int = 1
@export var grounded_z_index: int = 0

var _player: CharacterBody2D = null
var _visual: Node2D = null
var _shadow: CanvasItem = null

func _ready() -> void:
	_player = get_parent() as CharacterBody2D
	if _player == null:
		set_physics_process(false)
		return
	_visual = _player.get_node_or_null("Visual") as Node2D
	if _visual == null:
		set_physics_process(false)
		return
	_shadow = _visual.get_node_or_null("Shadow") as CanvasItem
	_visual.z_as_relative = true
	_visual.z_index = grounded_z_index
	if _shadow != null:
		_shadow.z_as_relative = true
		_shadow.z_index = 0
	set_physics_process(true)

func _physics_process(_delta: float) -> void:
	if _player == null or _visual == null:
		return
	var airborne: bool = bool(_player.get("_is_jumping"))
	var desired_z: int = airborne_z_index if airborne else grounded_z_index
	if _visual.z_index != desired_z:
		_visual.z_index = desired_z
		_visual.z_as_relative = true
	if _shadow != null:
		_shadow.z_index = -desired_z
		_shadow.z_as_relative = true
