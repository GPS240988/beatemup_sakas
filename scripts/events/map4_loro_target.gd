class_name Map4LoroTarget
extends Node2D

## Alvo de combate invisível alinhado ao ponto caminhável sob o Loro do Mapa 4.
## O sprite original permanece intacto; o alvo só aceita golpes durante o grito.

signal hit_by_player

const DamageInfoClass = preload("res://scripts/combat/damage_info.gd")

var _loro_sprite: AnimatedSprite2D = null
var _loro_anchor: Node2D = null
var _is_shouting: bool = false
var _speech_bubble: Label = null
var _connected_player_attacks: Array[Node] = []
var _shout_blink_tween: Tween = null
var _loro_original_modulate: Color = Color.WHITE


func _ready() -> void:
	add_to_group("map4_loro_target")
	call_deferred("_connect_player_attacks")


func configure(loro_sprite: AnimatedSprite2D, loro_anchor: Node2D) -> void:
	_loro_sprite = loro_sprite
	_loro_anchor = loro_anchor
	if _loro_sprite != null:
		_loro_original_modulate = _loro_sprite.modulate
	_sync_target_position()


func _process(_delta: float) -> void:
	_sync_target_position()
	_connect_player_attacks()


func _connect_player_attacks() -> void:
	if not is_inside_tree():
		return
	for player: Node in get_tree().get_nodes_in_group("player"):
		if player in _connected_player_attacks:
			continue
		var melee_attack: Node = player.get_node_or_null("MeleeAttack")
		if melee_attack == null or not melee_attack.has_signal("attack_phase_changed"):
			continue
		var callback := Callable(self, "_on_player_attack_phase_changed").bind(player)
		if not melee_attack.is_connected("attack_phase_changed", callback):
			melee_attack.connect("attack_phase_changed", callback)
		_connected_player_attacks.append(player)


func _on_player_attack_phase_changed(new_phase: int, attacker: Node) -> void:
	if not _is_shouting or new_phase != 2 or attacker == null or not is_instance_valid(attacker):
		return
	var melee_attack: Node = attacker.get_node_or_null("MeleeAttack")
	if melee_attack == null:
		return
	var facing: float = float(melee_attack.get("facing_direction"))
	var attack_range: float = float(melee_attack.get("horizontal_range"))
	var depth_tolerance: float = float(melee_attack.get("depth_tolerance"))
	var attacker_body: Node2D = attacker as Node2D
	if attacker_body == null:
		return
	var offset: Vector2 = global_position - attacker_body.global_position
	var forward_distance: float = offset.x * facing
	if forward_distance < -10.0 or forward_distance > attack_range:
		return
	if absf(offset.y) > depth_tolerance:
		return

	var hit_direction: float = signf(offset.x)
	if hit_direction == 0.0:
		hit_direction = facing
	var damage_info: RefCounted = DamageInfoClass.new(
		0.0, attacker, attacker_body.global_position,
		Vector2(hit_direction, 0.0), "melee", 0.0, 0.0,
		false, false, 0.0, "punch", "upper_torso", global_position
	)
	if take_damage(damage_info):
		# Preserva o feedback de combo/medidor do PlayerController sem inserir
		# o civil nos grupos de inimigos ou no CombatDirector.
		melee_attack.emit_signal("target_hit", self, 0.0)


func _sync_target_position() -> void:
	if _loro_anchor == null or not is_instance_valid(_loro_anchor):
		return
	# O Loro fica visualmente empoleirado. O ponto de acerto fica na faixa
	# caminhável imediatamente abaixo dele, respeitando o combate 2.5D.
	global_position = Vector2(
		_loro_anchor.global_position.x,
		clampf(_loro_anchor.global_position.y + 124.0, 545.0, 735.0)
	)


func start_shouting() -> void:
	_is_shouting = true
	if _loro_sprite != null and is_instance_valid(_loro_sprite):
		_loro_sprite.process_mode = Node.PROCESS_MODE_ALWAYS
		_loro_sprite.speed_scale = 1.5
		if _loro_sprite.sprite_frames != null and _loro_sprite.sprite_frames.has_animation("idle"):
			_loro_sprite.play("idle")
		_start_shout_blink()
	_show_speech_bubble()


func stop_shouting() -> void:
	_is_shouting = false
	if _loro_sprite != null and is_instance_valid(_loro_sprite):
		if _shout_blink_tween != null and _shout_blink_tween.is_valid():
			_shout_blink_tween.kill()
		_shout_blink_tween = null
		_loro_sprite.modulate = _loro_original_modulate
		_loro_sprite.speed_scale = 1.0
		_loro_sprite.process_mode = Node.PROCESS_MODE_INHERIT
	if _speech_bubble != null and is_instance_valid(_speech_bubble):
		_speech_bubble.queue_free()
	_speech_bubble = null


func _start_shout_blink() -> void:
	if _loro_sprite == null or not is_instance_valid(_loro_sprite):
		return
	if _shout_blink_tween != null and _shout_blink_tween.is_valid():
		_shout_blink_tween.kill()
	_loro_sprite.modulate = _loro_original_modulate
	_shout_blink_tween = _loro_sprite.create_tween().set_loops()
	_shout_blink_tween.set_trans(Tween.TRANS_SINE)
	_shout_blink_tween.tween_property(_loro_sprite, "modulate:a", 0.28, 0.12)
	_shout_blink_tween.tween_property(_loro_sprite, "modulate:a", _loro_original_modulate.a, 0.12)


func is_shouting() -> bool:
	return _is_shouting


func take_damage(damage_input: Variant) -> bool:
	if not _is_shouting or not (damage_input is RefCounted):
		return false
	var attacker: Node = damage_input.get("attacker") as Node
	if attacker == null or not attacker.is_in_group("player"):
		return false

	stop_shouting()
	hit_by_player.emit()
	return true


func _show_speech_bubble() -> void:
	if _speech_bubble != null and is_instance_valid(_speech_bubble):
		_speech_bubble.queue_free()

	_speech_bubble = Label.new()
	_speech_bubble.name = "LoroShoutBubble"
	var sprite_head_position: Vector2 = to_local(_loro_sprite.global_position) if _loro_sprite != null and is_instance_valid(_loro_sprite) else Vector2(0.0, -124.0)
	_speech_bubble.position = sprite_head_position + Vector2(-180.0, -142.0)
	_speech_bubble.size = Vector2(360.0, 72.0)
	_speech_bubble.text = "ALEHANDRO! ALEHANDRO!\nMULHERES PELADAS! MULHERES PELADAS!"
	_speech_bubble.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_speech_bubble.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_speech_bubble.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_speech_bubble.add_theme_font_size_override("font_size", 16)
	_speech_bubble.add_theme_color_override("font_color", Color(1.0, 0.91, 0.62, 1.0))
	_speech_bubble.add_theme_color_override("font_outline_color", Color(0.08, 0.04, 0.08, 1.0))
	_speech_bubble.add_theme_constant_override("outline_size", 4)
	_speech_bubble.z_index = 140

	var bubble_style := StyleBoxFlat.new()
	bubble_style.bg_color = Color(0.055, 0.035, 0.09, 0.94)
	bubble_style.border_color = Color(1.0, 0.68, 0.22, 1.0)
	bubble_style.set_border_width_all(3)
	bubble_style.set_corner_radius_all(8)
	bubble_style.content_margin_left = 10.0
	bubble_style.content_margin_right = 10.0
	bubble_style.content_margin_top = 7.0
	bubble_style.content_margin_bottom = 7.0
	_speech_bubble.add_theme_stylebox_override("normal", bubble_style)
	add_child(_speech_bubble)
