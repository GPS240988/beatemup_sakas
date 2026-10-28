class_name AttackData
extends Resource

## Estrutura de dados formal para definição de ataques arcade (FASE COMBATE ARCADE)
## Parametriza cada golpe individualmente sem espalhar valores mágicos no controlador.

@export var attack_id: String = "punch_1"
@export var animation: StringName = &"punch"
@export var startup: float = 0.05
@export var active: float = 0.12
@export var recovery: float = 0.15
@export var damage: float = 20.0
@export var horizontal_range: float = 85.0
@export var depth_tolerance: float = 26.0
@export var hitstun: float = 0.22
@export var knockback: float = 40.0
@export var hitstop_frames: int = 3
@export var combo_index: int = 0
@export var combo_window: float = 0.45
@export var can_knockdown: bool = false
@export var can_launch: bool = false
@export var cancel_window: float = 0.10
@export var impact_profile: String = "punch"
@export var preferred_regions: Array[String] = []
@export var hitbox_offset_y: float = 0.0

## Retorna a duração em segundos correspondente aos frames de hitstop (base 60 FPS)
func get_hitstop_duration() -> float:
	return float(hitstop_frames) / 60.0

## Duração total do ciclo de animação e física do ataque
func get_total_duration() -> float:
	return startup + active + recovery
