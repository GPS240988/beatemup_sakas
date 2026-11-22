class_name HeldItemComponent
extends Node2D

## Composição visual global de itens equipados.
## O item e a mão em primeiro plano compartilham a hierarquia Y-Sort do ator:
## não usam Z absoluto nem offsets negativos de Z que possam separá-los dos pés.
## A mão é recortada dinamicamente do frame atual do AnimatedSprite2D, portanto
## acompanha idle/walk e não exige um spritesheet corporal duplicado por item.

const DEFAULT_HAND_OFFSETS: Dictionary = {
	&"guilherme": Vector2(38.0, -104.0),
	&"gabriel": Vector2(45.0, -136.0)
}
const FALLBACK_HAND_OFFSET: Vector2 = Vector2(38.0, -104.0)

## Região da mão/antebraço na textura-fonte 220x300. A região é extraída do frame
## ativo, preservando exatamente os pixels, a paleta e a animação oficial.
const CHARACTER_GRIP_REGIONS: Dictionary = {
	&"guilherme": Rect2i(128, 148, 76, 94),
	&"gabriel": Rect2i(112, 76, 102, 108)
}
const FALLBACK_GRIP_REGION: Rect2i = Rect2i(128, 148, 76, 94)

var character_id: StringName = &"guilherme"
var equipped_item_id: StringName = &""
var _anim_sprite: AnimatedSprite2D = null
var _item_sprite: Sprite2D = null
var _hand_overlay: Sprite2D = null
var _cached_frame_texture: Texture2D = null
var _cached_region: Rect2i = Rect2i()


## Garante uma única instância sob Player/Visual. Todos os pickups devem reutilizá-la.
static func attach_to_player(player: Node) -> HeldItemComponent:
	if player == null or not is_instance_valid(player):
		return null

	var visual_root: Node2D = player.get_node_or_null("Visual") as Node2D
	if visual_root == null:
		return null

	var existing: HeldItemComponent = visual_root.get_node_or_null("HeldItemComponent") as HeldItemComponent
	if existing != null:
		return existing

	var component := HeldItemComponent.new()
	component.name = "HeldItemComponent"
	component.character_id = _resolve_character_id(player)
	visual_root.add_child(component)
	return component


static func _resolve_character_id(player: Node) -> StringName:
	var hero_data: Resource = null
	if "hero_data" in player:
		hero_data = player.get("hero_data") as Resource
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
	_anim_sprite = get_parent().get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D

	_item_sprite = Sprite2D.new()
	_item_sprite.name = "HeldItemSprite"
	_item_sprite.centered = true
	_item_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_item_sprite.region_enabled = false
	# Z relativo 0 é intencional: herda a posição Y-Sort do Player.
	# O componente é adicionado depois de AnimatedSprite2D, então o item é desenhado
	# sobre o corpo; a recorte de mão é o filho seguinte e o sobrepõe visualmente.
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
	set_process(false)
	_refresh_hand_anchor()


## Atualiza o perfil visual quando o jogador/personagem for trocado em runtime.
func set_character_id(value: StringName) -> void:
	character_id = StringName(String(value).strip_edges().to_lower())
	_cached_frame_texture = null
	_refresh_hand_anchor()
	_sync_hand_overlay()


## Equipa qualquer textura transportável. item_offset é relativo ao socket da mão.
## Não existe parâmetro de Z: item e mão devem preservar o Y-Sort do ator.
func equip_item(
	item_id: StringName,
	texture: Texture2D,
	item_scale: Vector2 = Vector2.ONE,
	item_offset: Vector2 = Vector2.ZERO,
	rotation_degrees: float = 0.0
) -> bool:
	if item_id == &"" or texture == null or item_scale.x <= 0.0 or item_scale.y <= 0.0:
		return false
	if _item_sprite == null:
		return false

	_item_sprite.texture = texture
	_item_sprite.scale = item_scale
	_item_sprite.position = _get_hand_offset() + item_offset
	_item_sprite.rotation_degrees = rotation_degrees
	_item_sprite.z_index = 0
	_item_sprite.z_as_relative = true
	_item_sprite.visible = true
	equipped_item_id = item_id
	_cached_frame_texture = null
	_sync_hand_overlay()
	set_process(true)
	return true


## Remove somente o item solicitado, sem interferir em outro equipamento.
func unequip_item(expected_item_id: StringName = &"") -> bool:
	if equipped_item_id == &"":
		return false
	if expected_item_id != &"" and equipped_item_id != expected_item_id:
		return false

	_item_sprite.visible = false
	_item_sprite.texture = null
	_hand_overlay.visible = false
	_hand_overlay.texture = null
	_item_sprite.position = Vector2.ZERO
	_item_sprite.rotation = 0.0
	_cached_frame_texture = null
	equipped_item_id = &""
	set_process(false)
	return true


func is_holding_item(expected_item_id: StringName = &"") -> bool:
	if equipped_item_id == &"" or _item_sprite == null or not _item_sprite.visible:
		return false
	return expected_item_id == &"" or equipped_item_id == expected_item_id


func get_item_sprite() -> Sprite2D:
	return _item_sprite


func get_hand_overlay_sprite() -> Sprite2D:
	return _hand_overlay


func get_hand_anchor_offset() -> Vector2:
	return _get_hand_offset()


func get_grip_region() -> Rect2i:
	var region: Rect2i = CHARACTER_GRIP_REGIONS.get(character_id, FALLBACK_GRIP_REGION)
	return region


func _process(_delta: float) -> void:
	if is_holding_item():
		_sync_hand_overlay()


func _refresh_hand_anchor() -> void:
	if _item_sprite == null:
		return
	if equipped_item_id != &"":
		_item_sprite.position = _get_hand_offset()


func _get_hand_offset() -> Vector2:
	return DEFAULT_HAND_OFFSETS.get(character_id, FALLBACK_HAND_OFFSET)


func _sync_hand_overlay() -> void:
	if _hand_overlay == null or _anim_sprite == null:
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

	# Reconstrói a posição do recorte no mesmo espaço local do AnimatedSprite2D.
	# Assim o antebraço/mão acompanha cada frame, escala, offset e rotação do ator.
	var region_center: Vector2 = Vector2(safe_region.position) + Vector2(safe_region.size) * 0.5
	var sprite_origin: Vector2 = -texture_size * 0.5 if _anim_sprite.centered else Vector2.ZERO
	var region_local_center: Vector2 = sprite_origin + region_center
	var transformed_region_center: Vector2 = (region_local_center * _anim_sprite.scale).rotated(_anim_sprite.rotation)
	_hand_overlay.position = _anim_sprite.position + _anim_sprite.offset + transformed_region_center
	_hand_overlay.scale = _anim_sprite.scale
	_hand_overlay.rotation = _anim_sprite.rotation
	_hand_overlay.flip_h = _anim_sprite.flip_h
	_hand_overlay.z_index = 0
	_hand_overlay.z_as_relative = true
	_hand_overlay.visible = is_holding_item()
