class_name HeroData
extends Resource

## Dados e atributos oficiais de um herói jogável (Beat 'em Up 2.5D)
## Permite criar novos heróis diretamente pelo Inspector via arquivos .tres.

@export_group("Identidade")
@export var hero_id: String = "guilherme"
@export var display_name: String = "Guilherme"

@export_group("Locomoção 2.5D")
@export var speed_x: float = 260.0
@export var speed_y: float = 190.0

@export_group("Física de Salto")
@export var jump_force: float = 460.0
@export var jump_gravity: float = 1350.0

@export_group("Ataque Aéreo")
@export var aerial_jump_v_velocity: float = -340.0
@export var aerial_damage: float = 35.0
@export var aerial_range: float = 110.0
@export var aerial_startup: float = 0.04
@export var aerial_active: float = 0.22
@export var aerial_recovery: float = 0.23
@export var aerial_forward_velocity: float = 240.0
@export var aerial_hitbox_offset_y: float = -130.0

@export_group("Golpe Especial")
@export var special_max_charge: float = 100.0
@export var special_initial_charge: float = 0.0
@export var special_charge_per_hit: float = 3.5
@export var special_damage: float = 60.0
@export var special_prop_damage: float = 50.0
@export var special_knockback: float = 180.0
@export var special_hitstun: float = 0.50
@export var special_presentation_texture: Texture2D = null
@export var special_title: String = ""
@export var special_theme_color: Color = Color(0.95, 0.78, 0.15, 0.90) # Ouro nobre e branco
@export var special_presentation_duration: float = 2.5

@export_group("Combo 1 - Jab / Soco")
@export var punch1_damage: float = 20.0
@export var punch1_range: float = 85.0
@export var punch1_depth_tolerance: float = 26.0
@export var punch1_startup: float = 0.04
@export var punch1_active: float = 0.12
@export var punch1_recovery: float = 0.22
@export var punch1_hitstun: float = 0.22
@export var punch1_knockback: float = 40.0
@export var punch1_hitstop_frames: int = 3
@export var punch1_combo_window: float = 0.42
@export var punch1_hitbox_offset_y: float = -125.0

@export_group("Combo 2 - Cruzado / Soco 2")
@export var punch2_damage: float = 25.0
@export var punch2_range: float = 90.0
@export var punch2_depth_tolerance: float = 26.0
@export var punch2_startup: float = 0.04
@export var punch2_active: float = 0.12
@export var punch2_recovery: float = 0.22
@export var punch2_hitstun: float = 0.25
@export var punch2_knockback: float = 55.0
@export var punch2_hitstop_frames: int = 3
@export var punch2_combo_window: float = 0.45
@export var punch2_hitbox_offset_y: float = -110.0

@export_group("Combo 3 - Chute no Tronco")
@export var kick3_damage: float = 32.0
@export var kick3_range: float = 105.0
@export var kick3_depth_tolerance: float = 28.0
@export var kick3_startup: float = 0.05
@export var kick3_active: float = 0.15
@export var kick3_recovery: float = 0.25
@export var kick3_hitstun: float = 0.30
@export var kick3_knockback: float = 85.0
@export var kick3_hitstop_frames: int = 4
@export var kick3_combo_window: float = 0.48
@export var kick3_hitbox_offset_y: float = -70.0

@export_group("Combo 4 - Finisher / Gancho Pesado")
@export var heavy4_damage: float = 48.0
@export var heavy4_range: float = 115.0
@export var heavy4_depth_tolerance: float = 30.0
@export var heavy4_startup: float = 0.06
@export var heavy4_active: float = 0.20
@export var heavy4_recovery: float = 0.40
@export var heavy4_hitstun: float = 0.40
@export var heavy4_knockback: float = 160.0
@export var heavy4_hitstop_frames: int = 6
@export var heavy4_hitbox_offset_y: float = -120.0

