class_name StoryIntroFase1_2
extends Control

## Apresenta a arte narrativa entre map_1 e map_2 (Fase 1: Entrada da Locadora).
## A interferência CRT é aplicada exclusivamente à região do vidro do fliperama.
## A apresentação termina automaticamente e transiciona para map_2.tscn.

const MAP_2_SCENE_PATH: String = "res://scenes/levels/map_2.tscn"
const CRT_SHADER: Shader = preload("res://shaders/crt_screen_flicker.gdshader")
const STORY_IMAGE_PATH: String = "res://assets/backgrounds/maps/fase1/story_intro_fase1_2.webp"
const MobileScreenAction = preload("res://scripts/mobile/mobile_screen_action.gd")

@export_range(1.0, 12.0, 0.1) var presentation_duration: float = 4.4
@export_range(0.1, 2.0, 0.05) var fade_duration: float = 0.55
## Região UV aproximada do vidro do CRT na imagem 16:9.
## Valores: x, y, largura e altura, normalizados entre 0 e 1.
@export var crt_screen_uv_rect: Vector4 = Vector4(0.174, 0.165, 0.651, 0.535)

var _fade_overlay: ColorRect
var _transition_started: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_presentation()
	call_deferred("_play_presentation")


func _is_mobile_runtime() -> bool:
	return MobileScreenAction.is_mobile_runtime()


## A apresentação é obrigatória: entradas do usuário não podem antecipar a transição.
## Consome teclado, mouse e toque para impedir que o comando chegue ao gameplay.
func _input(_event: InputEvent) -> void:
	var viewport: Viewport = get_viewport()
	if viewport != null:
		viewport.set_input_as_handled()


func _build_presentation() -> void:
	var background := ColorRect.new()
	background.name = "Background"
	background.color = Color(0.004, 0.005, 0.009, 1.0)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)

	var artwork := TextureRect.new()
	artwork.name = "StoryArtwork"
	artwork.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	artwork.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	artwork.stretch_mode = TextureRect.STRETCH_SCALE if _is_mobile_runtime() else TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	artwork.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	artwork.mouse_filter = Control.MOUSE_FILTER_IGNORE
	artwork.texture = _load_story_texture()

	if artwork.texture != null:
		var shader_material := ShaderMaterial.new()
		shader_material.shader = CRT_SHADER
		shader_material.set_shader_parameter("screen_rect", crt_screen_uv_rect)
		artwork.material = shader_material
	else:
		push_error("Não foi possível carregar a arte: " + STORY_IMAGE_PATH)

	add_child(artwork)

	_fade_overlay = ColorRect.new()
	_fade_overlay.name = "FadeOverlay"
	_fade_overlay.color = Color.BLACK
	_fade_overlay.modulate.a = 1.0
	_fade_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fade_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_fade_overlay)


func _load_story_texture() -> Texture2D:
	if not ResourceLoader.exists(STORY_IMAGE_PATH):
		return null
	return ResourceLoader.load(STORY_IMAGE_PATH) as Texture2D


func _play_presentation() -> void:
	if _transition_started or _fade_overlay == null:
		return

	var fade_in := create_tween()
	fade_in.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	var fade_in_tweener: PropertyTweener = fade_in.tween_property(
		_fade_overlay, "modulate:a", 0.0, fade_duration
	)
	fade_in_tweener.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	await fade_in.finished

	if not is_inside_tree() or _transition_started:
		return

	await get_tree().create_timer(presentation_duration, true).timeout
	if not is_inside_tree() or _transition_started:
		return

	_transition_to_map_2()


func _transition_to_map_2() -> void:
	if _transition_started:
		return
	_transition_started = true

	# Limpa inputs antes da troca de cena para evitar ataques acidentais no início do mapa
	Input.action_release("attack")
	Input.action_release("jump")
	Input.action_release("ui_accept")

	var fade_out := create_tween()
	fade_out.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	var fade_out_tweener: PropertyTweener = fade_out.tween_property(
		_fade_overlay, "modulate:a", 1.0, fade_duration
	)
	fade_out_tweener.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	await fade_out.finished

	if not is_inside_tree():
		return

	if not ResourceLoader.exists(MAP_2_SCENE_PATH):
		push_error("Mapa de destino não encontrado: " + MAP_2_SCENE_PATH)
		_transition_started = false
		_reveal_artwork_again()
		return

	var error: Error = get_tree().change_scene_to_file(MAP_2_SCENE_PATH)
	if error != OK:
		push_error("Falha ao solicitar carregamento de map_2.tscn. Código: %d" % error)
		_transition_started = false
		_reveal_artwork_again()


func _reveal_artwork_again() -> void:
	if _fade_overlay == null or not is_instance_valid(_fade_overlay):
		return
	var recovery_tween := create_tween()
	recovery_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	var recovery_tweener: PropertyTweener = recovery_tween.tween_property(
		_fade_overlay, "modulate:a", 0.0, fade_duration
	)
	recovery_tweener.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
