class_name HeldItemCombatComponent
extends Node

## Aplica o perfil da arma ao MeleeAttack canônico do jogador.
## Não cria hitbox, busca de alvos, DamageInfo ou dano paralelo.

const CombatFeedbackClass = preload("res://scripts/combat/combat_feedback.gd")

var current_profile: HeldItemProfile = null
var current_durability: int = -1
var _pending_profile: HeldItemProfile = null
var _has_pending_profile_change: bool = false
var _owner_player: Node2D = null
var _melee_attack: MeleeAttack = null
var _anim_sprite: AnimatedSprite2D = null
var _saved_attack_values: Dictionary = {}
var _has_saved_values: bool = false


static func attach_to_player(player: Node) -> HeldItemCombatComponent:
	if player == null or not is_instance_valid(player):
		return null
	var existing := player.get_node_or_null("HeldItemCombatComponent") as HeldItemCombatComponent
	if existing != null:
		return existing
	var component := HeldItemCombatComponent.new()
	component.name = "HeldItemCombatComponent"
	player.add_child(component)
	return component


func _ready() -> void:
	_owner_player = get_parent() as Node2D
	if _owner_player == null:
		return
	_melee_attack = _owner_player.get_node_or_null("MeleeAttack") as MeleeAttack
	_anim_sprite = _owner_player.get_node_or_null("Visual/AnimatedSprite2D") as AnimatedSprite2D
	if _melee_attack == null:
		return
	if not _melee_attack.attack_started.is_connected(_on_attack_started):
		_melee_attack.attack_started.connect(_on_attack_started)
	if not _melee_attack.attack_phase_changed.is_connected(_on_attack_phase_changed):
		_melee_attack.attack_phase_changed.connect(_on_attack_phase_changed)
	if not _melee_attack.attack_ended.is_connected(_on_attack_ended):
		_melee_attack.attack_ended.connect(_on_attack_ended)
	if not _melee_attack.target_hit.is_connected(_on_target_hit):
		_melee_attack.target_hit.connect(_on_target_hit)


func set_profile(profile: HeldItemProfile) -> void:
	if _melee_attack != null and _melee_attack.is_attacking:
		_pending_profile = profile if profile != null and profile.attack_enabled else null
		_has_pending_profile_change = true
		return
	current_profile = profile if profile != null and profile.attack_enabled else null
	current_durability = profile.max_durability if current_profile != null else -1
	_pending_profile = null
	_has_pending_profile_change = false


func clear_profile(expected_item_id: StringName = &"") -> void:
	var candidate: HeldItemProfile = current_profile
	if candidate == null and _has_pending_profile_change:
		candidate = _pending_profile
	if candidate == null:
		return
	if expected_item_id != &"" and candidate.item_id != expected_item_id:
		return
	if _melee_attack != null and _melee_attack.is_attacking:
		_pending_profile = null
		_has_pending_profile_change = true
		return
	current_profile = null
	_pending_profile = null
	_has_pending_profile_change = false
	_restore_attack_values()


func is_item_combat_enabled() -> bool:
	return current_profile != null and current_profile.attack_enabled


func _on_attack_phase_changed(new_phase: int) -> void:
	if new_phase == MeleeAttack.Phase.INACTIVE:
		_reset_swing_arc()
		_restore_attack_values()
		_apply_pending_profile()
		return
	if not _can_apply_item_profile_to_current_attack():
		return
	_save_attack_values()
	_apply_profile_attack()
	_apply_phase_timing(new_phase)
	if new_phase == MeleeAttack.Phase.ACTIVE:
		_start_swing_arc()
	elif new_phase == MeleeAttack.Phase.RECOVERY:
		_reset_swing_arc()


func _on_attack_started() -> void:
	if not _can_apply_item_profile_to_current_attack():
		return
	_save_attack_values()
	_apply_profile_attack()
	_apply_phase_timing(_melee_attack.current_phase)
	if _anim_sprite != null and current_profile.attack_animation != &"":
		if _anim_sprite.sprite_frames != null and _anim_sprite.sprite_frames.has_animation(current_profile.attack_animation):
			_anim_sprite.play(current_profile.attack_animation)


func _on_attack_ended() -> void:
	_reset_swing_arc()
	_restore_attack_values()
	_apply_pending_profile()


func _can_apply_item_profile_to_current_attack() -> bool:
	if not is_item_combat_enabled() or _melee_attack == null:
		return false
	# A voadora tem dados e hitbox próprios no PlayerController. O perfil da arma
	# não pode sobrescrever dano, alcance ou temporização do ataque aéreo.
	if _owner_player != null and "_current_attack_anim" in _owner_player:
		if StringName(str(_owner_player.get("_current_attack_anim"))) == &"jump_atk":
			return false
	return true


func _apply_pending_profile() -> void:
	if not _has_pending_profile_change:
		return
	current_profile = _pending_profile
	current_durability = current_profile.max_durability if current_profile != null else -1
	_pending_profile = null
	_has_pending_profile_change = false


func _on_target_hit(_target: Node, _damage: float) -> void:
	if current_profile == null or not current_profile.attack_enabled:
		return
	if current_profile.breaks_on_hit:
		_break_item()
		return
	if current_durability > 0:
		current_durability -= 1
		if current_durability <= 0:
			_break_item()


func _break_item() -> void:
	if current_profile == null:
		return
	var item_id: StringName = current_profile.item_id
	var sfx: String = current_profile.break_sfx_profile
	if sfx != "":
		CombatFeedbackClass.play_impact_sound(_owner_player if _owner_player != null else self, sfx)
	if _owner_player != null:
		var held: HeldItemComponent = _owner_player.get_node_or_null("Visual/HeldItemComponent") as HeldItemComponent
		if held != null:
			held.unequip_item(item_id)
	clear_profile(item_id)


func _start_swing_arc() -> void:
	if current_profile == null or not current_profile.swing_arc_enabled or _owner_player == null:
		return
	var held: HeldItemComponent = _owner_player.get_node_or_null("Visual/HeldItemComponent") as HeldItemComponent
	if held == null:
		return
	var spr: Sprite2D = held.get_item_sprite()
	if spr == null:
		return
	var start_rot: float = current_profile.rotation_degrees + current_profile.swing_start_angle
	var end_rot: float = current_profile.rotation_degrees + current_profile.swing_end_angle
	spr.rotation_degrees = start_rot
	var dur: float = current_profile.attack_active if current_profile.override_attack_timing else (_melee_attack.active_duration if _melee_attack != null else 0.12)
	var tween: Tween = create_tween()
	if tween != null:
		tween.tween_property(spr, "rotation_degrees", end_rot, maxf(0.01, dur))


func _reset_swing_arc() -> void:
	if _owner_player == null:
		return
	var held: HeldItemComponent = _owner_player.get_node_or_null("Visual/HeldItemComponent") as HeldItemComponent
	if held == null:
		return
	var spr: Sprite2D = held.get_item_sprite()
	if spr != null and current_profile != null:
		spr.rotation_degrees = current_profile.rotation_degrees


func _save_attack_values() -> void:
	if _has_saved_values or _melee_attack == null:
		return
	var hitbox_size: Vector2 = Vector2.ZERO
	if _melee_attack.hitbox_shape != null and _melee_attack.hitbox_shape.shape is RectangleShape2D:
		hitbox_size = (_melee_attack.hitbox_shape.shape as RectangleShape2D).size
	_saved_attack_values = {
		"damage": _melee_attack.damage,
		"horizontal_range": _melee_attack.horizontal_range,
		"depth_tolerance": _melee_attack.depth_tolerance,
		"startup_duration": _melee_attack.startup_duration,
		"active_duration": _melee_attack.active_duration,
		"recovery_duration": _melee_attack.recovery_duration,
		"attack_cooldown": _melee_attack.attack_cooldown,
		"knockback_force": _melee_attack.knockback_force,
		"hitstun_duration": _melee_attack.hitstun_duration,
		"hitstop_duration": _melee_attack.hitstop_duration,
		"can_knockdown": _melee_attack.can_knockdown,
		"impact_profile": _melee_attack.impact_profile,
		"preferred_regions": _melee_attack.preferred_regions.duplicate(),
		"hitbox_offset_y": _melee_attack.hitbox_offset_y,
		"can_hit_props": _melee_attack.can_hit_props,
		"check_obstacles": _melee_attack.check_obstacles,
		"obstacle_collision_mask": _melee_attack.obstacle_collision_mask,
		"hitbox_size": hitbox_size
	}
	_has_saved_values = true


func _apply_profile_attack() -> void:
	if _melee_attack == null or current_profile == null:
		return
	_melee_attack.damage = current_profile.attack_damage
	_melee_attack.horizontal_range = current_profile.attack_range
	_melee_attack.depth_tolerance = current_profile.attack_depth_tolerance
	_melee_attack.knockback_force = current_profile.attack_knockback
	_melee_attack.hitstun_duration = current_profile.attack_hitstun
	_melee_attack.hitstop_duration = current_profile.attack_hitstop
	_melee_attack.can_knockdown = current_profile.attack_can_knockdown
	_melee_attack.impact_profile = current_profile.attack_impact_profile
	_melee_attack.preferred_regions = current_profile.attack_preferred_regions.duplicate()
	_melee_attack.hitbox_offset_y = current_profile.attack_hitbox_offset_y
	_melee_attack.can_hit_props = current_profile.attack_can_hit_props
	_melee_attack.check_obstacles = current_profile.attack_check_obstacles
	_melee_attack.obstacle_collision_mask = current_profile.attack_obstacle_collision_mask
	if _melee_attack.hitbox_shape != null and _melee_attack.hitbox_shape.shape is RectangleShape2D:
		(_melee_attack.hitbox_shape.shape as RectangleShape2D).size = Vector2(
			current_profile.attack_range,
			current_profile.attack_hitbox_height
		)
	_melee_attack._update_hitbox_transform()


func _apply_phase_timing(new_phase: int) -> void:
	if current_profile == null or not current_profile.override_attack_timing or _melee_attack == null:
		return
	_melee_attack.startup_duration = current_profile.attack_startup
	_melee_attack.active_duration = current_profile.attack_active
	_melee_attack.recovery_duration = current_profile.attack_recovery
	_melee_attack.attack_cooldown = current_profile.attack_startup + current_profile.attack_active + current_profile.attack_recovery
	match new_phase:
		MeleeAttack.Phase.STARTUP:
			_melee_attack._phase_timer = current_profile.attack_startup
		MeleeAttack.Phase.ACTIVE:
			_melee_attack._phase_timer = current_profile.attack_active
		MeleeAttack.Phase.RECOVERY:
			_melee_attack._phase_timer = current_profile.attack_recovery


func _restore_attack_values() -> void:
	if not _has_saved_values or _melee_attack == null:
		_saved_attack_values.clear()
		_has_saved_values = false
		return
	_melee_attack.damage = float(_saved_attack_values.get("damage", _melee_attack.damage))
	_melee_attack.horizontal_range = float(_saved_attack_values.get("horizontal_range", _melee_attack.horizontal_range))
	_melee_attack.depth_tolerance = float(_saved_attack_values.get("depth_tolerance", _melee_attack.depth_tolerance))
	_melee_attack.startup_duration = float(_saved_attack_values.get("startup_duration", _melee_attack.startup_duration))
	_melee_attack.active_duration = float(_saved_attack_values.get("active_duration", _melee_attack.active_duration))
	_melee_attack.recovery_duration = float(_saved_attack_values.get("recovery_duration", _melee_attack.recovery_duration))
	_melee_attack.attack_cooldown = float(_saved_attack_values.get("attack_cooldown", _melee_attack.attack_cooldown))
	_melee_attack.knockback_force = float(_saved_attack_values.get("knockback_force", _melee_attack.knockback_force))
	_melee_attack.hitstun_duration = float(_saved_attack_values.get("hitstun_duration", _melee_attack.hitstun_duration))
	_melee_attack.hitstop_duration = float(_saved_attack_values.get("hitstop_duration", _melee_attack.hitstop_duration))
	_melee_attack.can_knockdown = bool(_saved_attack_values.get("can_knockdown", _melee_attack.can_knockdown))
	_melee_attack.impact_profile = str(_saved_attack_values.get("impact_profile", _melee_attack.impact_profile))
	var regions: Variant = _saved_attack_values.get("preferred_regions", [])
	_melee_attack.preferred_regions = regions.duplicate() if regions is Array else []
	_melee_attack.hitbox_offset_y = float(_saved_attack_values.get("hitbox_offset_y", _melee_attack.hitbox_offset_y))
	_melee_attack.can_hit_props = bool(_saved_attack_values.get("can_hit_props", _melee_attack.can_hit_props))
	_melee_attack.check_obstacles = bool(_saved_attack_values.get("check_obstacles", _melee_attack.check_obstacles))
	_melee_attack.obstacle_collision_mask = int(_saved_attack_values.get("obstacle_collision_mask", _melee_attack.obstacle_collision_mask))
	var old_size: Variant = _saved_attack_values.get("hitbox_size", Vector2.ZERO)
	if _melee_attack.hitbox_shape != null and _melee_attack.hitbox_shape.shape is RectangleShape2D and old_size is Vector2 and old_size != Vector2.ZERO:
		(_melee_attack.hitbox_shape.shape as RectangleShape2D).size = old_size
	_melee_attack._update_hitbox_transform()
	_saved_attack_values.clear()
	_has_saved_values = false
