class_name HealthComponent
extends Node

## Sinal emitido quando a vida atual é modificada
signal health_changed(current: float, max_health: float)

## Sinal emitido quando recebe dano com sucesso
signal damaged(amount: float)

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


## Aplica dano à vida. Retorna true se o dano foi aplicado com sucesso.
func take_damage(amount: float) -> bool:
	if is_dead or amount <= 0.0:
		return false

	current_health = maxf(0.0, current_health - amount)
	damaged.emit(amount)
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
