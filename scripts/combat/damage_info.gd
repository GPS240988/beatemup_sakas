class_name DamageInfo
extends RefCounted

## Contrato de Informação de Dano (FASE 6 — INTEGRAÇÃO COM COMBATE).
## O atacante empacota todas as propriedades do dano e transfere para o receptor.
## O receptor é a autoridade máxima sobre como receber, mitigar, reagir ou ignorar.

var amount: float = 10.0
var attacker: Node = null
var source_position: Vector2 = Vector2.ZERO
var direction: Vector2 = Vector2.RIGHT
var damage_type: String = "melee" # "melee", "projectile", "hazard", "special"
var knockback_force: float = 0.0
var hitstun_duration: float = 0.0
var can_destroy_props: bool = true
var can_knockdown: bool = false
var hitstop_duration: float = 0.05
var impact_profile: String = "punch"


func _init(
	p_amount: float = 10.0,
	p_attacker: Node = null,
	p_source_pos: Vector2 = Vector2.ZERO,
	p_direction: Vector2 = Vector2.RIGHT,
	p_type: String = "melee",
	p_knockback: float = 0.0,
	p_hitstun: float = 0.0,
	p_can_destroy_props: bool = true,
	p_can_knockdown: bool = false,
	p_hitstop: float = 0.05,
	p_impact_profile: String = "punch"
) -> void:
	amount = p_amount
	attacker = p_attacker
	source_position = p_source_pos
	direction = p_direction
	damage_type = p_type
	knockback_force = p_knockback
	hitstun_duration = p_hitstun
	can_destroy_props = p_can_destroy_props
	can_knockdown = p_can_knockdown
	hitstop_duration = p_hitstop
	impact_profile = p_impact_profile

