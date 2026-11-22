class_name HeldItemComponent
extends Node2D

## Componente visual global de itens equipados.
## Socket anatômico pertence ao personagem; ajuste de pixel, escala e rotação
## pertencem exclusivamente ao HeldItemProfile do objeto.

const DEFAULT_HAND_OFFSETS: Dictionary = {
	&"guilherme": Vector2(38.0, -104.0),
	&"gabriel": Vector2(45.0, -136.0)
}
const FALLBACK_HAND_OFFSET: Vector2 = Vector2(38.0, -104.0)
const CHARACTER_GRIP_REGIONS: Dictionary = {
	&"guilherme": Rect2i(128, 148, 76, 94),
	&"gabriel": Rect2i(112, 76, 102, 108)
}
const FALLBACK_GRIP_REGION: Rect2i = Rect2i(128, 148, 76, 94)

var character_id: StringName = &"guilherme"
var equipped_item_id: StringName = &""
var active_profile: HeldItemProfile = null
var _owner_player: Node = null
var _hero_data: HeroData = null
var _anim_sprite: AnimatedSprite2D = null
var _item_sprite: Sprite2D = null
var _hand_overlay: Sprite2D = null
var _secondary_hand_sprite: Sprite2D = null
var _combat_component: HeldItemCombatComponent = null
var _cached_frame_texture: Texture2D = null
var _cached_region: Rect2i = Rect2i()
var _previous_animation: StringName = &""

static func attach_to_player(player: Node) -> HeldItemComponent:
	if player == null or not is_instance_valid(player):
		return null
	var visual_root: Node2D = player.get_node_or_null("Visual") as Node2D
	if visual_root == null:
		return null
	var existing := visual_root.get_node_or_null("HeldItemComponent") as HeldItemComponent
	if existing != null:
		existing._owner_player = player
		existing._hero_data = player.get("hero_data") as HeroData if "hero_data" in player else null
		existing._combat_component = HeldItemCombatComponent.attach_to_player(player)
		existing._connect_player_signals()
		return existing
	var component := HeldItemComponent.new()
	component.name = "HeldItemComponent"
	component.character_id = _resolve_character_id(player)
	component._owner_player = player
	component._hero_data = player.get("hero_data") as HeroData if "hero_data" in player else null
	visual_root.add_child(component)
	component._combat_component = HeldItemCombatComponent.attach_to_player(player)
	component._connect_player_signals()
	return component

static func _resolve_character_id(player: Node) -> StringName:
	var hero_data: Resource = player.get("hero_data") as Resource if "hero_data" in player else null
	if hero_data != null and "hero_id" in hero_data:
		var hero_id: String = str(hero_data.get("hero_id")).strip_edges().to_lower()
		if not hero_id.is_empty():
			return StringName(hero_id)
	var session: Node = player.get_node_or_null("/root/GameSession")
	if session != null and "selected_character_id" in session:
		var selected_id: String = str(session.get("selected_character_id")).strip_edges().to_lower()
		if not selected_id.is_empty():
			return StringName(selected_id)
	return &"guilherme"

func _ready() -> void:
	if _owner_player == null and get_parent() != null and get_parent().get_parent() != null:
		_owner_player = get_parent().get_parent()
		if _hero_data == null and "hero_data" in _owner_player:
			_hero_data = _owner_player.get("hero_data") as HeroData
	_connect_player_signals()
	_anim_sprite = get_parent().get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	_item_sprite = Sprite2D.new()
	_item_sprite.name = "HeldItemSprite"
	_item_sprite.centered = true
	_item_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_item_sprite.z_index = 0
	_item_sprite.z_as_relative = true
	_item_sprite.visible = false
	add_child(_item_sprite)

	_hand_overlay = Sprite2D.new()
	_hand_overlay.name = "HeldItemHandOverlay"
	_hand_overlay.centered = true
	_hand_overlay.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_hand_overlay.region_enabled = true
	_hand_overlay.region_filter_clip_enabled = true
	_hand_overlay.z_index = 0
	_hand_overlay.z_as_relative = true
	_hand_overlay.visible = false
	add_child(_hand_overlay)

	_secondary_hand_sprite = Sprite2D.new()
	_secondary_hand_sprite.name = "HeldItemSecondaryHand"
	_secondary_hand_sprite.centered = true
	_secondary_hand_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_secondary_hand_sprite.z_index = 0
	_secondary_hand_sprite.z_as_relative = true
	_secondary_hand_sprite.visible = false
	add_child(_secondary_hand_sprite)
	set_process(false)

func set_character_id(value: StringName) -> void:
	character_id = StringName(String(value).strip_edges().to_lower())
	_cached_frame_texture = null
	_refresh_profile_transform()
	_sync_hand_overlay()

## API preferencial: cada item fornece seu próprio HeldItemProfile.
func equip_profile(profile: HeldItemProfile) -> bool:
	if profile == null or not profile.is_valid() or _item_sprite == null:
		return false
	if active_profile != null:
		unequip_item(active_profile.item_id)
	active_profile = profile
	equipped_item_id = profile.item_id
	_item_sprite.texture = profile.texture
	_item_sprite.scale = profile.visual_scale
	_item_sprite.position = _get_hand_offset() + profile.hand_offset
	_item_sprite.rotation_degrees = profile.rotation_degrees
	_item_sprite.visible = true
	_cached_frame_texture = null
	if profile.secondary_hand_texture != null and profile.grip_mode == HeldItemProfile.GripMode.TWO_HANDS:
		_secondary_hand_sprite.texture = profile.secondary_hand_texture
		_secondary_hand_sprite.scale = profile.secondary_hand_scale
		_secondary_hand_sprite.position = _get_hand_offset() + profile.secondary_hand_offset
		_secondary_hand_sprite.visible = true
	else:
		_secondary_hand_sprite.texture = null
		_secondary_hand_sprite.visible = false
	if profile.hold_animation != &"" and _anim_sprite != null and _anim_sprite.sprite_frames != null:
		if _anim_sprite.sprite_frames.has_animation(profile.hold_animation):
			_previous_animation = _anim_sprite.animation
			_anim_sprite.play(profile.hold_animation)
	if _combat_component == null:
		_combat_component = HeldItemCombatComponent.attach_to_player(get_parent().get_parent())
	if _combat_component != null:
		_combat_component.set_profile(profile)
	_sync_hand_overlay()
	set_process(true)
	return true

## Compatibilidade com pickups antigos. Os parâmetros são transformados em perfil
## transitório do item e não escrevem nos offsets anatômicos do personagem.
func equip_item(
	item_id: StringName,
	texture: Texture2D,
	item_scale: Vector2 = Vector2.ONE,
	item_offset: Vector2 = Vector2.ZERO,
	rotation_degrees: float = 0.0
) -> bool:
	var profile := HeldItemProfile.new()
	profile.item_id = item_id
	profile.display_name = String(item_id)
	profile.texture = texture
	profile.visual_scale = item_scale
	profile.hand_offset = item_offset
	profile.rotation_degrees = rotation_degrees
	return equip_profile(profile)

func unequip_item(expected_item_id: StringName = &"") -> bool:
	if equipped_item_id == &"":
		return false
	if expected_item_id != &"" and equipped_item_id != expected_item_id:
		return false
	var removed_id: StringName = equipped_item_id
	if _combat_component != null:
		_combat_component.clear_profile(removed_id)
	if active_profile != null and active_profile.hold_animation != &"" and _anim_sprite != null:
		if _previous_animation != &"" and _anim_sprite.sprite_frames != null and _anim_sprite.sprite_frames.has_animation(_previous_animation):
			_anim_sprite.play(_previous_animation)
	_item_sprite.visible = false
	_item_sprite.texture = null
	_hand_overlay.visible = false
	_hand_overlay.texture = null
	_secondary_hand_sprite.visible = false
	_secondary_hand_sprite.texture = null
	_item_sprite.position = Vector2.ZERO
	_item_sprite.rotation = 0.0
	_cached_frame_texture = null
	active_profile = null
	equipped_item_id = &""
	_previous_animation = &""
	set_process(false)
	return true

func is_holding_item(expected_item_id: StringName = &"") -> bool:
	if equipped_item_id == &"" or _item_sprite == null or active_profile == null:
		return false
	return expected_item_id == &"" or equipped_item_id == expected_item_id

func get_item_sprite() -> Sprite2D:
	return _item_sprite

func get_hand_overlay_sprite() -> Sprite2D:
	return _hand_overlay

func get_hand_anchor_offset() -> Vector2:
	return _get_hand_offset()

func get_grip_region() -> Rect2i:
	if _hero_data != null and _hero_data.get("grip_rect") != null and _hero_data.grip_rect != Rect2i():
		return _hero_data.grip_rect
	return CHARACTER_GRIP_REGIONS.get(character_id, FALLBACK_GRIP_REGION)

func _process(_delta: float) -> void:
	if is_holding_item():
		_update_item_pose_and_visibility()
		_sync_hand_overlay()

func _update_item_pose_and_visibility() -> void:
	if _anim_sprite == null or not is_instance_valid(_anim_sprite) or active_profile == null or _item_sprite == null:
		return

	# Na voadora (jump_atk), oculta temporariamente o item para manter a silhueta límpida do chute clássico
	if _anim_sprite.animation == &"jump_atk":
		_item_sprite.visible = false
		if _hand_overlay != null:
			_hand_overlay.visible = false
		if _secondary_hand_sprite != null:
			_secondary_hand_sprite.visible = false
		return

	_item_sprite.visible = true
	if _secondary_hand_sprite != null and active_profile.grip_mode == HeldItemProfile.GripMode.TWO_HANDS and active_profile.secondary_hand_texture != null:
		_secondary_hand_sprite.visible = true

	# Oscilação dinâmica por frame da animação (walk, punch, heavy, kick, shot, etc.)
	var motion: Vector2 = _get_animation_motion_offset()
	_item_sprite.position = _get_hand_offset() + active_profile.hand_offset + motion
	if _secondary_hand_sprite != null and active_profile.grip_mode == HeldItemProfile.GripMode.TWO_HANDS:
		_secondary_hand_sprite.position = _get_hand_offset() + active_profile.secondary_hand_offset + motion

func _get_animation_motion_offset() -> Vector2:
	if _anim_sprite == null or not is_instance_valid(_anim_sprite):
		return Vector2.ZERO
	var anim_name: StringName = _anim_sprite.animation
	var frame_idx: int = _anim_sprite.frame
	match anim_name:
		&"walk":
			# Ciclo clássico de 4 frames de caminhada (vaivém do braço + bobbing dos passos)
			match frame_idx % 4:
				0: return Vector2(-4.0, 0.0)
				1: return Vector2(0.0, -3.0)
				2: return Vector2(6.0, 0.0)
				3: return Vector2(0.0, -2.0)
				_: return Vector2.ZERO
		&"punch":
			# Avanço e recuo sincronizados ao soco
			match frame_idx:
				0: return Vector2(-6.0, 2.0)
				1: return Vector2(18.0, -4.0)
				2: return Vector2(6.0, 0.0)
				_: return Vector2.ZERO
		&"heavy":
			# Preparação e golpe pesado
			match frame_idx:
				0, 1: return Vector2(-10.0, 4.0)
				2, 3: return Vector2(22.0, -8.0)
				4, 5: return Vector2(8.0, 0.0)
				_: return Vector2.ZERO
		&"kick":
			# Rotação/torção do tronco no chute
			match frame_idx:
				0: return Vector2(-8.0, 2.0)
				1: return Vector2(-12.0, 0.0)
				2: return Vector2(-4.0, 0.0)
				_: return Vector2.ZERO
		&"shot_1", &"shot_2":
			# Recuo e disparo do tiro (Gabriel)
			match frame_idx:
				0: return Vector2(14.0, -6.0)
				1: return Vector2(4.0, -2.0)
				_: return Vector2.ZERO
		_:
			return Vector2.ZERO
	return Vector2.ZERO

func _refresh_profile_transform() -> void:
	if active_profile == null or _item_sprite == null:
		return
	var motion: Vector2 = _get_animation_motion_offset()
	_item_sprite.position = _get_hand_offset() + active_profile.hand_offset + motion
	if _secondary_hand_sprite != null and active_profile.grip_mode == HeldItemProfile.GripMode.TWO_HANDS:
		_secondary_hand_sprite.position = _get_hand_offset() + active_profile.secondary_hand_offset + motion

func _get_hand_offset() -> Vector2:
	if _hero_data != null and _hero_data.get("hand_socket_offset") != null and _hero_data.hand_socket_offset != Vector2.ZERO:
		return _hero_data.hand_socket_offset
	return DEFAULT_HAND_OFFSETS.get(character_id, FALLBACK_HAND_OFFSET)

## Desequipa o item e, se configurado, gera o pickup correspondente no solo.
func drop_item(impulse_dir: Vector2 = Vector2.ZERO) -> bool:
	if active_profile == null or equipped_item_id == &"":
		return false
	var profile: HeldItemProfile = active_profile
	var current_id: StringName = equipped_item_id
	unequip_item(current_id)
	if profile.ground_pickup_scene != null and _owner_player != null and is_instance_valid(_owner_player):
		var pickup := profile.ground_pickup_scene.instantiate() as Node2D
		if pickup != null:
			var spawn_pos: Vector2 = _owner_player.global_position
			if impulse_dir != Vector2.ZERO:
				spawn_pos += impulse_dir * 24.0
			pickup.global_position = spawn_pos
			var target_parent: Node = _owner_player.get_parent()
			if target_parent != null:
				target_parent.add_child(pickup)
	return true

func _connect_player_signals() -> void:
	if _owner_player == null or not is_instance_valid(_owner_player):
		return
	if _owner_player.has_signal("state_changed"):
		if not _owner_player.is_connected("state_changed", _on_player_state_changed):
			_owner_player.connect("state_changed", _on_player_state_changed)

func _on_player_state_changed(new_state_name: String) -> void:
	if active_profile != null and active_profile.drop_on_knockdown:
		if new_state_name in ["Fall", "Dead"]:
			var facing: float = float(_owner_player.get("facing_direction")) if "facing_direction" in _owner_player else 1.0
			drop_item(Vector2(-facing, 0.0))

func _sync_hand_overlay() -> void:
	if _hand_overlay == null or _anim_sprite == null:
		return
	if _anim_sprite.animation == &"jump_atk" or (_item_sprite != null and not _item_sprite.visible):
		_hand_overlay.visible = false
		return
	if _anim_sprite.sprite_frames == null or not _anim_sprite.sprite_frames.has_animation(_anim_sprite.animation):
		_hand_overlay.visible = false
		return
	var frame_count: int = _anim_sprite.sprite_frames.get_frame_count(_anim_sprite.animation)
	if frame_count <= 0:
		_hand_overlay.visible = false
		return
	var frame_index: int = clampi(_anim_sprite.frame, 0, frame_count - 1)
	var frame_texture: Texture2D = _anim_sprite.sprite_frames.get_frame_texture(_anim_sprite.animation, frame_index)
	if frame_texture == null:
		_hand_overlay.visible = false
		return
	var texture_size: Vector2 = frame_texture.get_size()
	var requested_region: Rect2i = get_grip_region()
	var region_x: int = clampi(requested_region.position.x, 0, maxi(0, int(texture_size.x) - 1))
	var region_y: int = clampi(requested_region.position.y, 0, maxi(0, int(texture_size.y) - 1))
	var region_width: int = mini(requested_region.size.x, maxi(1, int(texture_size.x) - region_x))
	var region_height: int = mini(requested_region.size.y, maxi(1, int(texture_size.y) - region_y))
	var safe_region := Rect2i(region_x, region_y, region_width, region_height)
	if _cached_frame_texture != frame_texture or _cached_region != safe_region:
		_hand_overlay.texture = frame_texture
		_hand_overlay.region_rect = Rect2(Vector2(safe_region.position), Vector2(safe_region.size))
		_cached_frame_texture = frame_texture
		_cached_region = safe_region
	var region_center: Vector2 = Vector2(safe_region.position) + Vector2(safe_region.size) * 0.5
	var sprite_origin: Vector2 = -texture_size * 0.5 if _anim_sprite.centered else Vector2.ZERO
	var local_center: Vector2 = sprite_origin + region_center
	var transformed_center: Vector2 = (local_center * _anim_sprite.scale).rotated(_anim_sprite.rotation)
	var motion: Vector2 = _get_animation_motion_offset()
	_hand_overlay.position = _anim_sprite.position + _anim_sprite.offset + transformed_center + motion
	_hand_overlay.scale = _anim_sprite.scale
	_hand_overlay.rotation = _anim_sprite.rotation
	_hand_overlay.flip_h = _anim_sprite.flip_h
	_hand_overlay.visible = is_holding_item() and _item_sprite != null and _item_sprite.visible
