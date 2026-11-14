class_name MenuCharacterShowcase
extends Control

## Componente de Apresentação Cíclica dos Personagens no Menu Principal (Sakas Neo-16-bit).
## Implementa a apresentação arcade digna de grandes produções dos anos 90:
## 1. Exibição individual cíclica (1 a 1) no canto esquerdo da locadora.
## 2. Somente o nome do personagem em tipografia arcade dourada de alto contraste.
## 3. Efeitos PixelFX: sombra sólida de solo, aura de neon aditiva e poeira/faísca no solo ao aterrissar.
## 4. Respiração idle orgânica com pés ancorados no chão.
## 5. Loop contínuo infinito entre os 5 personagens (Guilherme -> Gabriel -> André -> Juliana -> Alessandro).

signal character_presented(character_id: String, character_name: String)

const ARCADE_FONT: FontFile = preload("res://assets/fonts/arcade_bold.ttf")

const CHARACTERS: Array[Dictionary] = [
	{
		"id": "guilherme",
		"name": "GUILHERME",
		"texture_path": "res://assets/sprites/characters/guilherme_menu.png",
		"fallback_path": "res://assets/sprites/characters/guilherme/guilherme_menu.png",
		"accent_color": Color(0.25, 0.95, 0.65, 1.0), # Ciano Esmeralda
		"shadow_scale": Vector2(1.0, 1.0)
	},
	{
		"id": "gabriel",
		"name": "GABRIEL",
		"texture_path": "res://assets/sprites/characters/gabriel_menu.png",
		"fallback_path": "res://assets/sprites/characters/gabriel/gabriel_menu.png",
		"accent_color": Color(0.35, 0.70, 1.0, 1.0), # Azul Cobalto
		"shadow_scale": Vector2(1.0, 1.0)
	},
	{
		"id": "andre",
		"name": "ANDRÉ",
		"texture_path": "res://assets/sprites/characters/andre_menu.png",
		"fallback_path": "res://assets/sprites/characters/andre/andre_menu.png",
		"accent_color": Color(0.96, 0.35, 0.22, 1.0), # Vermelho Chamas
		"shadow_scale": Vector2(1.08, 1.0)
	},
	{
		"id": "juliana",
		"name": "JULIANA",
		"texture_path": "res://assets/sprites/characters/juliana_menu.png",
		"fallback_path": "res://assets/sprites/characters/juliana/juliana_menu.png",
		"accent_color": Color(0.98, 0.82, 0.25, 1.0), # Dourado Solar
		"shadow_scale": Vector2(0.96, 1.0)
	},
	{
		"id": "alessandro",
		"name": "ALESSANDRO",
		"texture_path": "res://assets/sprites/characters/alessandro_menu.png",
		"fallback_path": "res://assets/sprites/characters/chefes/alessandro/alessandro_menu.png",
		"accent_color": Color(0.78, 0.35, 0.95, 1.0), # Púrpura Sombrio (Chefe)
		"shadow_scale": Vector2(1.05, 1.0)
	}
]

# Tempos da coreografia arcade (em segundos)
const TIME_ENTER: float = 0.45
const TIME_HOLD: float = 3.20
const TIME_EXIT: float = 0.35
const TIME_PAUSE: float = 0.20

# Nós internos
@onready var vfx_container: Control = $VFXContainer
@onready var ground_shadow: Polygon2D = $VFXContainer/GroundShadow
@onready var ground_aura: Polygon2D = $VFXContainer/GroundAura
@onready var dust_particles: CPUParticles2D = $VFXContainer/DustParticles
@onready var sprite_container: Control = $SpriteContainer
@onready var character_sprite: TextureRect = $SpriteContainer/CharacterSprite
@onready var name_label: Label = $NameBadge/CharacterNameLabel
@onready var name_badge: Control = $NameBadge

var _loaded_textures: Dictionary = {}
var _current_index: int = 0
var _active_tween: Tween = null
var _breathe_tween: Tween = null
var _is_cycling: bool = false
var _clock: float = 0.0

var _base_sprite_pos: Vector2 = Vector2.ZERO
var _base_name_pos: Vector2 = Vector2.ZERO


func _ready() -> void:
	_preload_textures()
	_setup_visual_styles()

	if sprite_container != null:
		_base_sprite_pos = sprite_container.position
	if name_badge != null:
		_base_name_pos = name_badge.position

	start_cycle()


func _preload_textures() -> void:
	for char_info in CHARACTERS:
		var path: String = char_info["texture_path"]
		if not ResourceLoader.exists(path) and char_info.has("fallback_path"):
			path = char_info["fallback_path"]
		if ResourceLoader.exists(path):
			_loaded_textures[char_info["id"]] = load(path) as Texture2D


func _setup_visual_styles() -> void:
	# Cria elipse da sombra fixa no solo
	if ground_shadow != null:
		ground_shadow.polygon = _generate_ellipse(64.0, 16.0, 16)
		ground_shadow.color = Color(0.015, 0.02, 0.04, 0.68)
		ground_shadow.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

	# Cria elipse de reflexo neon suave no solo da locadora (PixelFX)
	if ground_aura != null:
		ground_aura.polygon = _generate_ellipse(76.0, 20.0, 16)
		ground_aura.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		var add_mat := CanvasItemMaterial.new()
		add_mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		ground_aura.material = add_mat

	# Configura partículas de poeira de aterrissagem / aterrissagem arcade
	if dust_particles != null:
		dust_particles.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		dust_particles.amount = 6
		dust_particles.lifetime = 0.45
		dust_particles.one_shot = true
		dust_particles.explosiveness = 0.85
		dust_particles.direction = Vector2(0.0, -0.6)
		dust_particles.spread = 45.0
		dust_particles.gravity = Vector2(0.0, 20.0)
		dust_particles.initial_velocity_min = 28.0
		dust_particles.initial_velocity_max = 55.0
		dust_particles.scale_amount_min = 2.0
		dust_particles.scale_amount_max = 3.5

	# Tipografia do nome do personagem: somente o nome em arcade_bold
	if name_label != null:
		name_label.add_theme_font_override("font", ARCADE_FONT)
		name_label.add_theme_font_size_override("font_size", 28)
		name_label.add_theme_color_override("font_color", Color(1.0, 0.88, 0.35, 1.0)) # Ouro Arcade
		name_label.add_theme_color_override("font_outline_color", Color(0.03, 0.02, 0.05, 1.0))
		name_label.add_theme_constant_override("outline_size", 6)
		name_label.add_theme_color_override("font_shadow_color", Color(0.85, 0.12, 0.18, 0.85)) # Sombra carmesim arcade
		name_label.add_theme_constant_override("shadow_offset_x", 3)
		name_label.add_theme_constant_override("shadow_offset_y", 3)


static func _generate_ellipse(rx: float, ry: float, count: int = 16) -> PackedVector2Array:
	var pts := PackedVector2Array()
	pts.resize(count)
	for i in range(count):
		var theta: float = (float(i) / float(count)) * TAU
		pts[i] = Vector2(cos(theta) * rx, sin(theta) * ry)
	return pts


func start_cycle() -> void:
	_is_cycling = true
	_present_character(_current_index)


func stop_cycle() -> void:
	_is_cycling = false
	if _active_tween != null and _active_tween.is_valid():
		_active_tween.kill()
	if _breathe_tween != null and _breathe_tween.is_valid():
		_breathe_tween.kill()


func _present_character(index: int) -> void:
	if not _is_cycling or not is_inside_tree():
		return

	_current_index = index % CHARACTERS.size()
	var char_info: Dictionary = CHARACTERS[_current_index]

	# 1. Aplica dados e textura
	var tex: Texture2D = _loaded_textures.get(char_info["id"], null)
	if tex == null:
		var path: String = char_info["texture_path"]
		if not ResourceLoader.exists(path) and char_info.has("fallback_path"):
			path = char_info["fallback_path"]
		if ResourceLoader.exists(path):
			tex = load(path) as Texture2D
			_loaded_textures[char_info["id"]] = tex

	if character_sprite != null and tex != null:
		character_sprite.texture = tex

	# 2. Atualiza estritamente o nome do personagem
	if name_label != null:
		name_label.text = char_info["name"]
		# Sombra do texto harmonizada com o personagem
		name_label.add_theme_color_override("font_shadow_color", char_info["accent_color"] * Color(0.65, 0.65, 0.65, 0.85))

	# 3. Cores de iluminação PixelFX no solo
	var accent: Color = char_info["accent_color"]
	if ground_aura != null:
		ground_aura.color = Color(accent.r, accent.g, accent.b, 0.22)
		ground_aura.scale = char_info.get("shadow_scale", Vector2.ONE)

	if ground_shadow != null:
		ground_shadow.scale = char_info.get("shadow_scale", Vector2.ONE)

	if dust_particles != null:
		dust_particles.color = Color(accent.r, accent.g, accent.b, 0.75)

	emit_signal("character_presented", char_info["id"], char_info["name"])

	# 4. Executa a coreografia de entrada, hold e saída
	_run_presentation_sequence()


func _run_presentation_sequence() -> void:
	if _active_tween != null and _active_tween.is_valid():
		_active_tween.kill()
	if _breathe_tween != null and _breathe_tween.is_valid():
		_breathe_tween.kill()

	# Configuração de partida invisível e recuada à esquerda
	if sprite_container != null:
		sprite_container.modulate.a = 0.0
		sprite_container.position.x = _base_sprite_pos.x - 32.0
		sprite_container.position.y = _base_sprite_pos.y

	if name_badge != null:
		name_badge.modulate.a = 0.0
		name_badge.position.y = _base_name_pos.y + 10.0

	if vfx_container != null:
		vfx_container.modulate.a = 0.0

	# Emissão de partículas de aterrissagem arcade
	if dust_particles != null:
		dust_particles.restart()

	_active_tween = create_tween()

	# --- FASE 1: ENTRADA (0.45s) ---
	# Slide elegante da esquerda para o centro + Fade In nítido
	_active_tween.set_parallel(true)
	if sprite_container != null:
		_active_tween.tween_property(sprite_container, "position:x", _base_sprite_pos.x, TIME_ENTER).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		_active_tween.tween_property(sprite_container, "modulate:a", 1.0, TIME_ENTER * 0.75)

	if name_badge != null:
		_active_tween.tween_property(name_badge, "position:y", _base_name_pos.y, TIME_ENTER).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		_active_tween.tween_property(name_badge, "modulate:a", 1.0, TIME_ENTER * 0.85)

	if vfx_container != null:
		_active_tween.tween_property(vfx_container, "modulate:a", 1.0, TIME_ENTER)

	# --- FASE 2: APRECIAÇÃO / IDLE HOLD (3.20s) ---
	_active_tween.chain().tween_interval(TIME_HOLD)

	# Inicia leve respiração do sprite durante o hold (sub-pixel de 1.5px vertical, pés no chão)
	_active_tween.chain().tween_callback(_start_subtle_breathing)

	# --- FASE 3: SAÍDA (0.35s) ---
	# Fade out suave com leve recuo
	_active_tween.chain().set_parallel(true)
	if sprite_container != null:
		_active_tween.tween_property(sprite_container, "modulate:a", 0.0, TIME_EXIT).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		_active_tween.tween_property(sprite_container, "position:x", _base_sprite_pos.x + 16.0, TIME_EXIT)

	if name_badge != null:
		_active_tween.tween_property(name_badge, "modulate:a", 0.0, TIME_EXIT * 0.8)

	if vfx_container != null:
		_active_tween.tween_property(vfx_container, "modulate:a", 0.0, TIME_EXIT)

	# --- FASE 4: INTERVALO DE TRANSIÇÃO (0.20s) ---
	_active_tween.chain().tween_interval(TIME_PAUSE)

	# --- FASE 5: REPETIÇÃO INDEFINIDA DO CICLO ---
	_active_tween.chain().tween_callback(func():
		if _is_cycling:
			_present_character(_current_index + 1)
	)


func _start_subtle_breathing() -> void:
	if not _is_cycling or sprite_container == null:
		return

	if _breathe_tween != null and _breathe_tween.is_valid():
		_breathe_tween.kill()

	_breathe_tween = create_tween().set_loops()
	_breathe_tween.tween_property(sprite_container, "position:y", _base_sprite_pos.y - 1.5, 0.95).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_breathe_tween.tween_property(sprite_container, "position:y", _base_sprite_pos.y, 0.95).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


## Avança manualmente para o próximo personagem (útil para testes unitários)
func next_character() -> void:
	_present_character(_current_index + 1)


func get_current_character_index() -> int:
	return _current_index


func get_current_character_id() -> String:
	return CHARACTERS[_current_index]["id"]


func get_current_character_name() -> String:
	return CHARACTERS[_current_index]["name"]


func get_character_count() -> int:
	return CHARACTERS.size()


func is_cycling() -> bool:
	return _is_cycling


func _exit_tree() -> void:
	stop_cycle()
