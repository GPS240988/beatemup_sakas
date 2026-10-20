class_name HealthComponent
extends Node

const DamageInfoRef = preload("res://scripts/combat/damage_info.gd")

## Sinal emitido quando a vida atual é modificada
signal health_changed(current: float, max_health: float)

## Sinal emitido quando recebe dano com sucesso
signal damaged(amount: float)

## Sinal emitido acompanhado do objeto descritor de dano (FASE 6)
signal damaged_info(info: RefCounted)

## Sinal emitido uma única vez quando a vida atinge zero
signal died()

## Vida máxima do personagem
@export var max_health: float = 100.0:
	set(value):
		max_health = maxf(1.0, value)
		if current_health > max_health:
			current_health = max_health
			health_changed.emit(current_health, max_health)

## Vida atual do personagem
@export var current_health: float = 100.0

## Indica se o personagem foi derrotado
var is_dead: bool = false


func _ready() -> void:
	current_health = max_health
	health_changed.emit(current_health, max_health)


## Aplica dano à vida. Aceita tanto float/int quanto instâncias de DamageInfo (Damage Contract).
## Retorna true se o dano foi aplicado com sucesso.
func take_damage(damage_input: Variant) -> bool:
	if is_dead:
		return false

	var amount: float = 0.0
	var info: RefCounted = null

	if damage_input is float or damage_input is int:
		amount = float(damage_input)
	elif damage_input != null and damage_input.get("amount") != null:
		amount = float(damage_input.get("amount"))
		info = damage_input as RefCounted
	else:
		return false

	if amount <= 0.0:
		return false

	current_health = maxf(0.0, current_health - amount)
	damaged.emit(amount)
	if info != null:
		damaged_info.emit(info)
	health_changed.emit(current_health, max_health)

	if current_health <= 0.0 and not is_dead:
		is_dead = true
		died.emit()

	return true


## Restaura a vida para o valor máximo e reseta o estado de derrota
func reset() -> void:
	is_dead = false
	current_health = max_health
	health_changed.emit(current_health, max_health)
