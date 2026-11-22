class_name HeldItemProfile
extends Resource

## Fonte de verdade declarativa para um item equipável.
## Offsets deste recurso são exclusivos do item e sempre se somam ao socket
## anatômico do personagem; nunca alteram a configuração global do jogador.

enum GripMode {
	SINGLE_HAND,
	TWO_HANDS
}

@export var item_id: StringName = &""
@export var display_name: String = "Item"
@export var texture: Texture2D
@export var visual_scale: Vector2 = Vector2.ONE
@export var hand_offset: Vector2 = Vector2.ZERO
@export_range(-180.0, 180.0, 0.5) var rotation_degrees: float = 0.0
@export var grip_mode: GripMode = GripMode.SINGLE_HAND
@export var secondary_hand_offset: Vector2 = Vector2.ZERO
@export var secondary_hand_texture: Texture2D
@export var secondary_hand_scale: Vector2 = Vector2.ONE
@export var hold_animation: StringName = &""

## Combate reutiliza o MeleeAttack oficial do PlayerController.
@export_group("Combate")
@export var attack_enabled: bool = false
@export var attack_animation: StringName = &"punch"
@export var override_attack_timing: bool = false
@export_range(0.0, 1.0, 0.01) var attack_startup: float = 0.05
@export_range(0.01, 1.0, 0.01) var attack_active: float = 0.12
@export_range(0.0, 1.0, 0.01) var attack_recovery: float = 0.22
@export_range(0.0, 200.0, 1.0) var attack_damage: float = 20.0
@export_range(20.0, 500.0, 1.0) var attack_range: float = 90.0
@export_range(8.0, 100.0, 1.0) var attack_depth_tolerance: float = 28.0
@export_range(20.0, 180.0, 1.0) var attack_hitbox_height: float = 70.0
@export_range(-240.0, 40.0, 1.0) var attack_hitbox_offset_y: float = -100.0
@export_range(0.0, 400.0, 1.0) var attack_knockback: float = 70.0
@export_range(0.0, 2.0, 0.01) var attack_hitstun: float = 0.22
@export_range(0.0, 0.5, 0.001) var attack_hitstop: float = 0.05
@export var attack_can_knockdown: bool = false
@export var attack_impact_profile: String = "heavy"
@export var attack_preferred_regions: Array[String] = ["upper_torso", "head"]
@export var attack_can_hit_props: bool = true
@export var attack_check_obstacles: bool = true
@export_flags_2d_physics var attack_obstacle_collision_mask: int = 2

@export_group("Durabilidade")
## Número de acertos confirmados antes de quebrar. -1 = indestrutível.
@export var max_durability: int = -1
## Se verdadeiro, o item quebra no primeiro acerto que conecta.
@export var breaks_on_hit: bool = false
## Perfil de som/VFX da quebra (reutiliza CombatFeedback).
@export var break_sfx_profile: String = "glass_shatter"

@export_group("Arco de Ataque Visual")
## Se verdadeiro, o sprite gira durante a fase ativa do golpe.
@export var swing_arc_enabled: bool = false
## Ângulo de início da rotação do item no ataque (relativo à rotação neutra).
@export_range(-180.0, 180.0, 1.0) var swing_start_angle: float = -45.0
## Ângulo de fim da rotação do item no ataque.
@export_range(-180.0, 180.0, 1.0) var swing_end_angle: float = 45.0

@export_group("Reação a Dano")
## Se verdadeiro, o item cai no chão quando o jogador sofre knockdown (FALL).
@export var drop_on_knockdown: bool = true
## Cena de pickup instanciada no chão quando o item é derrubado. Se null, desaparece.
@export var ground_pickup_scene: PackedScene = null

func is_valid() -> bool:
	return item_id != &"" and texture != null and visual_scale.x > 0.0 and visual_scale.y > 0.0
