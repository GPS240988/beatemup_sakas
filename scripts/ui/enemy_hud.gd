class_name EnemyHUD
extends Control

## Componente Oficial de HUD do Inimigo Arcade (Projeto Sakas | Godot 4.x)
## Em estrita conformidade com a imagem de referência 2 (referência 2.webp).
## Posicionado no Canto Superior Direito (~320-340px por ~72-80px):
## - Nome alinhado à direita ("INIMIGO" ou nome do Boss/Capanga)
## - Barra de Vida Vermelha Segmentada com animação fluida de Damage Buffer
## - Retrato compacto do Inimigo com moldura azul arcade espelhado à direita

@export var damage_buffer_delay: float = 0.35
@export var damage_buffer_duration: float = 0.40

@onready var enemy_name_label: Label = %EnemyNameLabel
@onready var hp_bar: SegmentedBar = %HpBar
@onready var portrait_texture: TextureRect = %PortraitTexture
@onready var portrait_frame: TextureRect = %PortraitFrame

var current_hp: float = 100.0
var max_hp: float = 100.0
var _buffer_hp_val: float = 100.0
var _damage_buffer_tween: Tween = null
var _fade_tween: Tween = null
var _auto_hide_timer: float = 0.0

var _current_target: Node = null
var _bound_health_component: Node = null


func _ready() -> void:
	if hp_bar != null:
		# Barra vermelha arcade vibrante oficial da referência 2
		hp_bar.filled_color = Color(0.95, 0.12, 0.12, 1.0)
		hp_bar.filled_highlight = Color(1.0, 0.55, 0.55, 0.85)
		hp_bar.filled_shadow = Color(0.55, 0.04, 0.04, 0.75)
		hp_bar.buffer_color = Color(1.0, 0.72, 0.15, 1.0)
		hp_bar.frame_color = Color(0.0, 0.65, 1.0, 1.0)
		hp_bar.queue_redraw()
	
	set_enemy_name("JOGADOR DE MAGIC")
	set_enemy_health(100.0, 100.0, true)


func _process(delta: float) -> void:
	if _auto_hide_timer > 0.0:
		_auto_hide_timer -= delta
		if _auto_hide_timer <= 0.0 and current_hp <= 0.0:
			fade_out()


func set_enemy_name(value: String) -> void:
	if enemy_name_label != null:
		enemy_name_label.text = value.to_upper()


func set_enemy_portrait(texture: Texture2D) -> void:
	if portrait_texture != null and texture != null:
		portrait_texture.texture = texture


func set_enemy_health(new_current: float, new_max: float, immediate: bool = false) -> void:
	new_max = maxf(new_max, 1.0)
	new_current = clampf(new_current, 0.0, new_max)
	
	var is_damage: bool = not immediate and new_current < current_hp
	current_hp = new_current
	max_hp = new_max
	
	if hp_bar == null:
		return
	
	hp_bar.max_value = max_hp
	
	if immediate:
		if _damage_buffer_tween != null and _damage_buffer_tween.is_valid():
			_damage_buffer_tween.kill()
		_buffer_hp_val = current_hp
		hp_bar.value = current_hp
		hp_bar.buffer_value = current_hp
	elif is_damage:
		# 1. Segmentos principais caem imediatamente
		hp_bar.value = current_hp
		
		# 2. Interrompe animação anterior
		if _damage_buffer_tween != null and _damage_buffer_tween.is_valid():
			_damage_buffer_tween.kill()
		
		# 3. Buffer aguarda delay e depois reduz suavemente
		_damage_buffer_tween = create_tween()
		_damage_buffer_tween.tween_interval(damage_buffer_delay)
		_damage_buffer_tween.tween_method(
			func(val: float):
				_buffer_hp_val = val
				hp_bar.buffer_value = val,
			_buffer_hp_val,
			current_hp,
			damage_buffer_duration
		).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	else:
		_buffer_hp_val = current_hp
		hp_bar.value = current_hp
		hp_bar.buffer_value = current_hp
	
	# Exibe com animação de fade caso estivesse oculto
	fade_in()
	
	if current_hp <= 0.0:
		_auto_hide_timer = 2.0


func is_current_target_alive() -> bool:
	if _current_target == null or not is_instance_valid(_current_target):
		return false
	var h_comp = _current_target.get_node_or_null("HealthComponent")
	if h_comp != null and "current_health" in h_comp:
		return float(h_comp.current_health) > 0.0
	if "current_health" in _current_target:
		return float(_current_target.current_health) > 0.0
	return true


func target_enemy(enemy_node: Node, from_player_hit: bool = false) -> void:
	if enemy_node == null or not is_instance_valid(enemy_node):
		return
	
	if _current_target == enemy_node:
		return
	
	# Late enemy_registered não pode sobrescrever o alvo ativo sendo golpeado pelo jogador
	if not from_player_hit and is_current_target_alive():
		return
	
	unbind_target()
	_current_target = enemy_node
	
	# Determina nome do alvo
	var name_text: String = "JOGADOR DE MAGIC"
	if "display_name" in enemy_node and not str(enemy_node.display_name).is_empty():
		name_text = str(enemy_node.display_name)
	elif enemy_node.is_in_group("boss") or enemy_node.name.to_lower().contains("boss"):
		name_text = "ALESSANDRO"
	elif "enemy_name" in enemy_node and not str(enemy_node.enemy_name).is_empty():
		name_text = str(enemy_node.enemy_name)
	elif "character_name" in enemy_node:
		name_text = str(enemy_node.character_name)
	set_enemy_name(name_text)
	
	# Extrai e enquadra o retrato dinâmico
	_update_enemy_portrait_from_target(enemy_node)
	
	# Conecta vida
	var health_comp = enemy_node.get_node_or_null("HealthComponent")
	if health_comp != null:
		_bound_health_component = health_comp
		if not health_comp.health_changed.is_connected(_on_target_health_changed):
			health_comp.health_changed.connect(_on_target_health_changed)
		if health_comp.has_signal("died") and not health_comp.died.is_connected(_on_target_died):
			health_comp.died.connect(_on_target_died)
		set_enemy_health(health_comp.current_health, health_comp.max_health, true)
	elif "current_health" in enemy_node and "max_health" in enemy_node:
		set_enemy_health(float(enemy_node.current_health), float(enemy_node.max_health), true)
	
	if not enemy_node.tree_exited.is_connected(_on_target_tree_exited):
		enemy_node.tree_exited.connect(_on_target_tree_exited)


func _update_enemy_portrait_from_target(enemy_node: Node) -> void:
	if portrait_texture == null:
		return
	
	var anim_sprite: AnimatedSprite2D = enemy_node.get_node_or_null("Visual/AnimatedSprite2D") as AnimatedSprite2D
	if anim_sprite == null:
		anim_sprite = enemy_node.find_child("AnimatedSprite2D") as AnimatedSprite2D
	
	if anim_sprite != null and anim_sprite.sprite_frames != null:
		var frame_tex: Texture2D = null
		if anim_sprite.sprite_frames.has_animation("idle"):
			frame_tex = anim_sprite.sprite_frames.get_frame_texture("idle", 0)
		elif anim_sprite.sprite_frames.has_animation("default"):
			frame_tex = anim_sprite.sprite_frames.get_frame_texture("default", 0)
		
		if frame_tex != null:
			var atlas: AtlasTexture = AtlasTexture.new()
			atlas.atlas = frame_tex
			# Recorte do busto/rosto do Jogador de Magic
			atlas.region = Rect2(45, 0, 185, 185)
			set_enemy_portrait(atlas)
		
		# Preserva o shader de paleta de cores da jaqueta
		if anim_sprite.material != null:
			portrait_texture.material = anim_sprite.material.duplicate()
		else:
			portrait_texture.material = null
	else:
		portrait_texture.material = null
		var default_tex: Texture2D = null
		if ResourceLoader.exists("res://assets/ui/hud/portraits/portrait_jogador_de_magic.png"):
			default_tex = load("res://assets/ui/hud/portraits/portrait_jogador_de_magic.png") as Texture2D
		if default_tex == null:
			default_tex = load("res://assets/ui/hud/portraits/portrait_enemy.png") as Texture2D
		if default_tex != null:
			set_enemy_portrait(default_tex)


func unbind_target() -> void:
	if _bound_health_component != null and is_instance_valid(_bound_health_component):
		if _bound_health_component.is_connected("health_changed", _on_target_health_changed):
			_bound_health_component.disconnect("health_changed", _on_target_health_changed)
		if _bound_health_component.has_signal("died") and _bound_health_component.is_connected("died", _on_target_died):
			_bound_health_component.disconnect("died", _on_target_died)
	_bound_health_component = null
	
	if _current_target != null and is_instance_valid(_current_target):
		if _current_target.is_connected("tree_exited", _on_target_tree_exited):
			_current_target.disconnect("tree_exited", _on_target_tree_exited)
	_current_target = null


func _on_target_health_changed(cur: float, max_v: float) -> void:
	set_enemy_health(cur, max_v)
	if cur <= 0.0:
		_on_target_died()


func _on_target_died() -> void:
	# Ao morrer, seleciona o próximo alvo vivo mais próximo
	call_deferred("_select_next_living_target")


func _on_target_tree_exited() -> void:
	unbind_target()
	call_deferred("_select_next_living_target")


func _select_next_living_target() -> void:
	if get_tree() == null:
		return
	
	var living_enemies = get_tree().get_nodes_in_group("enemies")
	var best_target: Node = null
	var min_dist: float = 999999.0
	var ref_pos: Vector2 = Vector2.ZERO
	
	var player = get_tree().get_first_node_in_group("player")
	if player != null and is_instance_valid(player):
		ref_pos = player.global_position
	
	for enemy in living_enemies:
		if enemy == null or not is_instance_valid(enemy):
			continue
		if enemy == _current_target:
			continue
		var h_comp = enemy.get_node_or_null("HealthComponent")
		if h_comp != null and h_comp.current_health <= 0.0:
			continue
		if "current_health" in enemy and float(enemy.current_health) <= 0.0:
			continue
		var dist = ref_pos.distance_to(enemy.global_position)
		if dist < min_dist:
			min_dist = dist
			best_target = enemy
	
	if best_target != null:
		target_enemy(best_target, true)
	else:
		fade_out()


func fade_in() -> void:
	visible = true
	if _fade_tween != null and _fade_tween.is_valid():
		_fade_tween.kill()
	_fade_tween = create_tween()
	_fade_tween.tween_property(self, "modulate:a", 1.0, 0.15)


func fade_out() -> void:
	if _fade_tween != null and _fade_tween.is_valid():
		_fade_tween.kill()
	_fade_tween = create_tween()
	_fade_tween.tween_property(self, "modulate:a", 0.0, 0.40)
	_fade_tween.tween_callback(func(): visible = false)
