class_name DestructibleProp
extends StaticBody2D

## Contrato Arquitetural para Objetos Dinâmicos e Destrutíveis (FASE 5).
## Representa elementos de cenário que sofrem impacto, mudam de estado e podem ser destruídos:
## caixas, barris, lixeiras, mesas, máquinas de fliperama, portas e barricadas.
##
## MÁQUINA DE ESTADOS:
## ACTIVE     -> Íntegro, vida cheia, colisão sólida ativa, desvio de navegação ativo.
## DAMAGED    -> Sofreu dano sub-letal, exibe avaria/impacto visual, permanece sólido.
## DESTROYING -> Recebeu dano fatal, aciona efeitos/sons/drops, desativa colisões.
## DESTROYED  -> Inerte, passagem liberada, colisores desabilitados, recusa dano adicional.
##
## CONTRATO DE DANO:
## Qualquer entidade causadora de dano -> Damage -> Damageable -> DestructibleProp
##
## CONTRATO DE NÓS (DESACOPLADO E OPCIONAL):
## DestructibleProp (StaticBody2D, layer 2, mask 1, y_sort_enabled = true)
## ├── Visual (Node2D, Y < 0)
## │   ├── Intact (Node2D, opcional)
## │   └── Broken (Node2D, opcional, escombros no chão)
## ├── CollisionShape2D (Base de colisão física no solo, Layer 2)
## ├── Hurtbox (Area2D receptora de dano, Layer 3 [bitmask 4], Mask 0)
## ├── HealthComponent (Node opcional para gerenciamento de vida)
## ├── Effects (Node2D para partículas e sons de impacto/destruição)
## └── NavigationIntegration (NavigationObstacle2D para desvio dinâmico)

enum PropState {
	ACTIVE,
	DAMAGED,
	DESTROYING,
	DESTROYED
}

signal state_changed(new_state: PropState)
signal prop_damaged(amount: float, current_health: float)
signal prop_destroying()
signal prop_destroyed()

@export_group("Atributos do Prop")
@export var prop_name: String = "Caixa de Madeira"
@export var max_health: float = 50.0
@export var is_destructible: bool = true
@export var drops_item: bool = false
@export var drop_item_scene: PackedScene = null

@export_group("Texturas de Dano por Estágio (Opcional)")
## Lista de texturas em ordem sequencial de avaria (ex: games1, games2, games3, games4)
@export var damage_stage_textures: Array[Texture2D] = []

var current_state: PropState = PropState.ACTIVE
var current_health: float = 50.0
var is_broken: bool = false
var is_destroyed: bool = false

@onready var visual_root: Node2D = get_node_or_null("Visual") as Node2D
@onready var visual_intact: Node2D = get_node_or_null("Visual/Intact") as Node2D
@onready var visual_broken: Node2D = get_node_or_null("Visual/Broken") as Node2D
@onready var collision_shape: CollisionShape2D = get_node_or_null("CollisionShape2D") as CollisionShape2D
@onready var hurtbox: Area2D = get_node_or_null("Hurtbox") as Area2D
@onready var health_component: Node = get_node_or_null("HealthComponent")
@onready var effects: Node2D = get_node_or_null("Effects") as Node2D
@onready var nav_obstacle: NavigationObstacle2D = get_node_or_null("NavigationIntegration") as NavigationObstacle2D


func _ready() -> void:
	_resolve_internal_nodes()
	add_to_group("props")
	add_to_group("destructibles")
	add_to_group("destructible_props")
	add_to_group("damageable")
	y_sort_enabled = true
	current_health = max_health

	# Camada física padrão: Layer 2 (Mundo sólido / Obstáculos), Mask 1 (Atores)
	collision_layer = 2
	collision_mask = 1

	if hurtbox != null:
		# Layer 3 (Hurtbox), Mask 0
		hurtbox.collision_layer = 4 # Bitmask 4 = Layer 3
		hurtbox.collision_mask = 0
		hurtbox.monitoring = false
		hurtbox.monitorable = true

	if nav_obstacle != null:
		nav_obstacle.avoidance_enabled = true

	if visual_intact != null:
		visual_intact.visible = true
	if visual_broken != null:
		visual_broken.visible = false

	if not damage_stage_textures.is_empty():
		_update_damage_stage_visual()

	_setup_health_component()

	current_state = PropState.ACTIVE
	is_broken = false
	is_destroyed = false


func _resolve_internal_nodes() -> void:
	if visual_root == null:
		visual_root = get_node_or_null("Visual") as Node2D
	if visual_intact == null and visual_root != null:
		visual_intact = visual_root.get_node_or_null("Intact") as Node2D
	if visual_broken == null and visual_root != null:
		visual_broken = visual_root.get_node_or_null("Broken") as Node2D
	if collision_shape == null:
		collision_shape = get_node_or_null("CollisionShape2D") as CollisionShape2D
	if hurtbox == null:
		hurtbox = get_node_or_null("Hurtbox") as Area2D
	if health_component == null:
		health_component = get_node_or_null("HealthComponent")
	if effects == null:
		effects = get_node_or_null("Effects") as Node2D
	if nav_obstacle == null:
		nav_obstacle = get_node_or_null("NavigationIntegration") as NavigationObstacle2D


func _setup_health_component() -> void:
	if health_component == null:
		return

	health_component.set("max_health", max_health)
	health_component.set("current_health", current_health)

	if health_component.has_signal("damaged") and not health_component.is_connected("damaged", _on_health_damaged):
		health_component.connect("damaged", _on_health_damaged)
	if health_component.has_signal("health_changed") and not health_component.is_connected("health_changed", _on_health_changed):
		health_component.connect("health_changed", _on_health_changed)
	if health_component.has_signal("died") and not health_component.is_connected("died", _on_health_died):
		health_component.connect("died", _on_health_died)


func _on_health_damaged(amount: float) -> void:
	if health_component != null:
		current_health = health_component.get("current_health")
	prop_damaged.emit(amount, current_health)
	if current_health > 0.0:
		_transition_to_damaged()


func _on_health_changed(new_hp: float, _max_hp: float) -> void:
	current_health = new_hp


func _on_health_died() -> void:
	_transition_to_destroying()


## Ponto de entrada canônico para recebimento de dano (Damage Contract)
func take_damage(damage_input: Variant) -> bool:
	# Recusa dano se não for destrutível ou se já estiver em destruição/destruído
	if not is_destructible or current_state == PropState.DESTROYING or current_state == PropState.DESTROYED or is_destroyed:
		return false

	var amount: float = 0.0
	if damage_input is float or damage_input is int:
		amount = float(damage_input)
	elif damage_input != null and damage_input.get("amount") != null:
		if damage_input.get("can_destroy_props") == false:
			return false
		amount = float(damage_input.get("amount"))
	else:
		return false

	if amount <= 0.0:
		return false

	_resolve_internal_nodes()

	# Se possuir HealthComponent, delega para manter sincronia bidirecional
	if health_component != null:
		if health_component.get("is_dead") == true:
			return false
		var accepted: bool = health_component.take_damage(damage_input)
		return accepted

	# Caso contrário, aplica localmente
	current_health = maxf(0.0, current_health - amount)
	prop_damaged.emit(amount, current_health)

	if current_health <= 0.0:
		_transition_to_destroying()
	else:
		_transition_to_damaged()

	return true


## Transição para estado DAMAGED
func _transition_to_damaged() -> void:
	if current_state == PropState.DESTROYING or current_state == PropState.DESTROYED:
		return
	current_state = PropState.DAMAGED
	state_changed.emit(current_state)
	if not damage_stage_textures.is_empty():
		_update_damage_stage_visual()
	_play_impact_effect()


## Transição para estado DESTROYING
func _transition_to_destroying() -> void:
	if current_state == PropState.DESTROYING or current_state == PropState.DESTROYED:
		return

	current_state = PropState.DESTROYING
	is_broken = true
	state_changed.emit(current_state)
	prop_destroying.emit()

	destroy_prop()


## Execução da destruição (Desacoplada e livre de rebuild global de NavigationRegion2D)
func destroy_prop() -> void:
	if current_state == PropState.DESTROYED and is_destroyed:
		return

	_resolve_internal_nodes()
	is_broken = true
	current_health = 0.0
	if health_component != null:
		health_component.set("current_health", 0.0)
		health_component.set("is_dead", true)

	# 1. Desativa colisão física para permitir passagem imediata de atores
	if collision_shape != null:
		collision_shape.set_deferred("disabled", true)

	# 2. Desativa Hurtbox para não receber mais ataques nem emitir detecções
	if hurtbox != null:
		hurtbox.set_deferred("monitorable", false)

	# 3. Desativa obstáculo no NavigationServer2D via avoidance (SEM bake global de polígono!)
	if nav_obstacle != null:
		nav_obstacle.avoidance_enabled = false

	# 4. Aciona efeitos e sons desacoplados
	_play_destruction_effect()

	# 5. Dropar itens configurados
	_spawn_drop()

	# 6. Atualização visual desacoplada
	if not damage_stage_textures.is_empty():
		_update_damage_stage_visual()
	elif visual_intact != null and visual_broken != null:
		visual_intact.visible = false
		visual_broken.visible = true
	elif visual_root != null:
		visual_root.visible = false

	# 7. Finaliza estado DESTROYED
	current_state = PropState.DESTROYED
	is_destroyed = true
	state_changed.emit(current_state)
	prop_destroyed.emit()


## Toca efeitos visuais e sonoros de impacto (se disponíveis)
func _play_impact_effect() -> void:
	if effects != null:
		var sound: AudioStreamPlayer2D = effects.get_node_or_null("ImpactSound") as AudioStreamPlayer2D
		if sound != null and not sound.playing:
			sound.play()
		var particles: CPUParticles2D = effects.get_node_or_null("ImpactParticles") as CPUParticles2D
		if particles != null:
			particles.restart()
			particles.emitting = true

	# Micro tremor visual ao sofrer impacto (Dark Premium Medieval / Arcade feel)
	if visual_root != null and is_inside_tree():
		var orig_pos := visual_root.position
		var tween := create_tween()
		if tween != null:
			tween.tween_property(visual_root, "position", orig_pos + Vector2(randf_range(-2.5, 2.5), randf_range(-1.5, 1.5)), 0.04)
			tween.tween_property(visual_root, "position", orig_pos, 0.04)


## Toca efeitos visuais e sonoros de destruição (se disponíveis)
func _play_destruction_effect() -> void:
	if effects == null:
		return
	var sound: AudioStreamPlayer2D = effects.get_node_or_null("BreakSound") as AudioStreamPlayer2D
	if sound != null:
		sound.play()
	var particles: CPUParticles2D = effects.get_node_or_null("BreakParticles") as CPUParticles2D
	if particles != null:
		particles.restart()
		particles.emitting = true


## Instancia drop configurado
func _spawn_drop() -> void:
	if not drops_item or drop_item_scene == null:
		return
	var drop_inst := drop_item_scene.instantiate() as Node2D
	if drop_inst == null:
		return
	drop_inst.global_position = global_position
	var parent := get_parent()
	if parent != null:
		parent.add_child.call_deferred(drop_inst)


## Reinicia o estado do prop (suporte a resets e object pooling)
func reset_prop() -> void:
	_resolve_internal_nodes()
	current_health = max_health
	is_broken = false
	is_destroyed = false
	current_state = PropState.ACTIVE

	if collision_shape != null:
		collision_shape.set_deferred("disabled", false)
	if hurtbox != null:
		hurtbox.set_deferred("monitorable", true)
	if nav_obstacle != null:
		nav_obstacle.avoidance_enabled = true
	if visual_intact != null:
		visual_intact.visible = true
	if visual_broken != null:
		visual_broken.visible = false
	elif visual_root != null:
		visual_root.visible = true

	if not damage_stage_textures.is_empty():
		_update_damage_stage_visual()

	if health_component != null and health_component.has_method("reset"):
		health_component.reset()

	state_changed.emit(current_state)


func _resolve_stage_sprite() -> Sprite2D:
	if visual_root == null:
		return null
	var sprite := visual_root.get_node_or_null("Sprite2D") as Sprite2D
	if sprite != null:
		return sprite
	for child in visual_root.get_children():
		if child is Sprite2D:
			return child as Sprite2D
		if child is Node2D:
			for subchild in child.get_children():
				if subchild is Sprite2D:
					return subchild as Sprite2D
	return null


func _update_damage_stage_visual() -> void:
	if damage_stage_textures.is_empty():
		return
	var sprite := _resolve_stage_sprite()
	if sprite == null:
		return

	var total_stages := damage_stage_textures.size()
	var target_index := 0

	if current_state == PropState.DESTROYED or current_state == PropState.DESTROYING or is_destroyed or current_health <= 0.0:
		target_index = total_stages - 1
	elif current_state == PropState.ACTIVE or current_health >= max_health:
		target_index = 0
	else:
		var damage_ratio: float = clampf(1.0 - (current_health / maxf(1.0, max_health)), 0.0, 1.0)
		target_index = clampi(int(floor(damage_ratio * float(total_stages - 1))), 0, total_stages - 1)
		if target_index == 0 and total_stages > 1:
			target_index = 1

	if target_index >= 0 and target_index < total_stages and damage_stage_textures[target_index] != null:
		sprite.texture = damage_stage_textures[target_index]

	var shadow := visual_root.get_node_or_null("Shadow") as CanvasItem
	if shadow != null:
		shadow.visible = (target_index < total_stages - 1)


## Consultas de estado
func is_active() -> bool:
	return current_state == PropState.ACTIVE

func is_damaged() -> bool:
	return current_state == PropState.DAMAGED

func is_destroying() -> bool:
	return current_state == PropState.DESTROYING

func is_prop_destroyed() -> bool:
	return current_state == PropState.DESTROYED or is_destroyed

func get_current_state() -> PropState:
	return current_state
