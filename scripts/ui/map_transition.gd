class_name MapTransition
extends Control

## Controlador de transição cinemática de mapa e desbloqueio da Fase 2.
## Suporta os modos:
## 0 (POINT1_TO_BONUS): Seta vai do Ponto 1 ao Bônus 1 (após concluir mapa 1-4).
## 1 (BONUS_TO_POINT2): Seta vai do Bônus 1 ao Ponto 2 e desbloqueia o cadeado (após concluir bonus_garage).
## 2 (FULL_PREVIEW): Demonstração de todo o percurso do Ponto 1 ao Ponto 2.

enum TransitionMode {
	POINT1_TO_BONUS = 0,
	BONUS_TO_POINT2 = 1,
	FULL_PREVIEW = 2
}

const MAP_IMAGE_PATH: String = "res://assets/backgrounds/Mapa.webp"
const FALLBACK_MAP_IMAGE_PATH: String = "res://assets/backgrounds/mapa.webp"
const DEFAULT_BONUS_SCENE: String = "res://scenes/levels/bonus_garage.tscn"
const DEFAULT_CREDITS_SCENE: String = "res://scenes/ui/credits.tscn"

## Waypoints exatos ao longo do traçado vermelho (resolução 1920x1080)
const TRAIL_WAYPOINTS: Array[Vector2] = [
	Vector2(240, 348), # 0: Ponto 1 (centro de repouso)
	Vector2(255, 375), # 1: Curva contornando o círculo 1
	Vector2(280, 405), # 2: Descida ao longo da linha vermelha
	Vector2(340, 430), # 3: Curva inferior próxima à rua
	Vector2(400, 425), # 4: Subida em direção à direita
	Vector2(460, 400), # 5: Continuação diagonal
	Vector2(515, 365), # 6: Aproximação ao Bônus 1
	Vector2(578, 282), # 7: Bônus 1 (acima do círculo do ponto bônus, sem cobrir o presente)
	Vector2(635, 335), # 8: Saída do Bônus 1
	Vector2(700, 340), # 9: Trajeto vermelho central
	Vector2(760, 335), # 10: Curva suave
	Vector2(815, 320), # 11: Subida em direção ao Ponto 2
	Vector2(850, 305), # 12: Entrada na aproximação do Ponto 2
	Vector2(870, 265)  # 13: Ponto 2 (posição final de repouso sobre o círculo 2)
]

const POINT_1_PATCH_RECT := Rect2i(223, 334, 34, 31)
const POINT_2_PADLOCK_RECT := Rect2i(856, 255, 29, 44)

@export var transition_mode: TransitionMode = TransitionMode.POINT1_TO_BONUS
@export var target_scene_path: String = ""
@export var auto_start: bool = true

@onready var map_container: Control = %MapContainer
@onready var background_texture: TextureRect = %BackgroundTexture
@onready var point1_cover: TextureRect = %Point1Cover
@onready var point2_cover: TextureRect = %Point2Cover
@onready var unlock_vfx: Node2D = %UnlockVFX
@onready var trail_path: Path2D = %TrailPath
@onready var path_follow: PathFollow2D = %PathFollow
@onready var moving_arrow: Node2D = %MovingArrow
@onready var resting_arrow_p1: Node2D = %RestingArrowP1
@onready var resting_arrow_bonus: Node2D = get_node_or_null("%RestingArrowBonus") as Node2D
@onready var resting_arrow_p2: Node2D = %RestingArrowP2
@onready var fade_overlay: ColorRect = %FadeOverlay
@onready var audio_player: AudioStreamPlayer = %AudioPlayer

var _sfx_travel: AudioStreamWAV
var _sfx_unlock: AudioStreamWAV
var _is_animating: bool = false
var _bob_tween: Tween


func _ready() -> void:
	# Bloqueio de entrada estrito para garantir execução cinemática ininterrupta
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_process_unhandled_input(true)

	_resolve_target_scene()
	_setup_scaling()
	_load_background_and_patches()
	_setup_path()
	_generate_sound_effects()

	# Estado inicial dos elementos visuais conforme o modo de transição
	fade_overlay.visible = true
	fade_overlay.modulate.a = 1.0
	moving_arrow.visible = false
	path_follow.progress_ratio = 0.0

	if transition_mode == TransitionMode.POINT1_TO_BONUS:
		point1_cover.visible = false
		point2_cover.visible = false
		resting_arrow_p1.visible = true
		if resting_arrow_bonus != null:
			resting_arrow_bonus.visible = false
		resting_arrow_p2.visible = false
	elif transition_mode == TransitionMode.BONUS_TO_POINT2:
		point1_cover.visible = true
		point2_cover.visible = false
		resting_arrow_p1.visible = false
		if resting_arrow_bonus != null:
			resting_arrow_bonus.visible = true
		resting_arrow_p2.visible = false
	else:
		point1_cover.visible = false
		point2_cover.visible = false
		resting_arrow_p1.visible = true
		if resting_arrow_bonus != null:
			resting_arrow_bonus.visible = false
		resting_arrow_p2.visible = false

	get_tree().root.size_changed.connect(_setup_scaling)

	if auto_start:
		call_deferred("_start_transition_sequence")


func _resolve_target_scene() -> void:
	var session = get_node_or_null("/root/GameSession")
	if session != null:
		if "pending_map_transition_mode" in session:
			transition_mode = session.pending_map_transition_mode as TransitionMode
		if "pending_transition_target" in session:
			var pending: String = str(session.pending_transition_target)
			if not pending.is_empty() and ResourceLoader.exists(pending):
				target_scene_path = pending
				session.pending_transition_target = ""

	if target_scene_path.is_empty():
		if transition_mode == TransitionMode.POINT1_TO_BONUS:
			target_scene_path = DEFAULT_BONUS_SCENE
		else:
			target_scene_path = DEFAULT_CREDITS_SCENE


func _setup_scaling() -> void:
	if map_container == null:
		return

	var vp_size: Vector2 = get_viewport_rect().size
	if vp_size.x <= 0.0 or vp_size.y <= 0.0:
		vp_size = Vector2(1280.0, 720.0)

	var scale_factor: float = minf(vp_size.x / 1920.0, vp_size.y / 1080.0)
	if scale_factor <= 0.0:
		scale_factor = 1.0

	map_container.custom_minimum_size = Vector2(1920.0, 1080.0)
	map_container.size = Vector2(1920.0, 1080.0)
	map_container.scale = Vector2(scale_factor, scale_factor)

	var scaled_width: float = 1920.0 * scale_factor
	var scaled_height: float = 1080.0 * scale_factor
	map_container.position = Vector2(
		(vp_size.x - scaled_width) * 0.5,
		(vp_size.y - scaled_height) * 0.5
	)


func _load_background_and_patches() -> void:
	var tex: Texture2D = null
	if ResourceLoader.exists(MAP_IMAGE_PATH):
		tex = load(MAP_IMAGE_PATH) as Texture2D
	elif ResourceLoader.exists(FALLBACK_MAP_IMAGE_PATH):
		tex = load(FALLBACK_MAP_IMAGE_PATH) as Texture2D

	var map_img: Image = null
	if tex != null:
		map_img = tex.get_image()
	else:
		for p in [MAP_IMAGE_PATH, FALLBACK_MAP_IMAGE_PATH]:
			var gp := ProjectSettings.globalize_path(p)
			if FileAccess.file_exists(gp):
				map_img = Image.load_from_file(gp)
				if map_img != null:
					tex = ImageTexture.create_from_image(map_img)
					break

	if tex != null and background_texture != null:
		background_texture.texture = tex

	if map_img != null:
		if point1_cover != null:
			point1_cover.texture = _generate_patch_texture(map_img, POINT_1_PATCH_RECT)
		if point2_cover != null:
			point2_cover.texture = _generate_patch_texture(map_img, POINT_2_PADLOCK_RECT)


func _generate_patch_texture(source_img: Image, rect: Rect2i) -> ImageTexture:
	var w: int = rect.size.x
	var h: int = rect.size.y
	var patch := Image.create(w, h, false, Image.FORMAT_RGBA8)

	for y in range(h):
		var src_y: int = clampi(rect.position.y + y, 0, source_img.get_height() - 1)
		var left_x: int = clampi(rect.position.x - 1, 0, source_img.get_width() - 1)
		var right_x: int = clampi(rect.position.x + w, 0, source_img.get_width() - 1)
		var c_left: Color = source_img.get_pixel(left_x, src_y)
		var c_right: Color = source_img.get_pixel(right_x, src_y)

		for x in range(w):
			var t: float = float(x) / float(maxi(1, w - 1))
			var col: Color = c_left.lerp(c_right, t)
			patch.set_pixel(x, y, col)

	return ImageTexture.create_from_image(patch)


func _setup_path() -> void:
	if trail_path == null:
		return

	var curve := Curve2D.new()
	var points: Array[Vector2] = []
	match transition_mode:
		TransitionMode.POINT1_TO_BONUS:
			points = TRAIL_WAYPOINTS.slice(0, 8)
		TransitionMode.BONUS_TO_POINT2:
			points = TRAIL_WAYPOINTS.slice(7, 14)
		TransitionMode.FULL_PREVIEW:
			points = TRAIL_WAYPOINTS.duplicate()

	for pt in points:
		curve.add_point(pt)
	trail_path.curve = curve


func _start_transition_sequence() -> void:
	if _is_animating:
		return
	_is_animating = true

	# 1. Fade In suave da tela inteira (0% a 100% visibilidade)
	var tween_in := create_tween()
	tween_in.tween_property(fade_overlay, "modulate:a", 0.0, 0.8).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	await tween_in.finished

	# 2. Aguarda aproximadamente 0.7s conforme especificação técnica
	await get_tree().create_timer(0.7).timeout

	# 3. Animação conforme o modo
	if transition_mode == TransitionMode.POINT1_TO_BONUS:
		await _execute_point1_to_bonus()
	elif transition_mode == TransitionMode.BONUS_TO_POINT2:
		await _execute_bonus_to_point2()
	else:
		await _execute_full_preview()

	# 4. Fade Out suave para preto
	var tween_out := create_tween()
	tween_out.tween_property(fade_overlay, "modulate:a", 1.0, 0.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	await tween_out.finished

	# 5. Troca de cena para o próximo destino da campanha
	_is_animating = false
	if _bob_tween != null and _bob_tween.is_valid():
		_bob_tween.kill()
	var err := get_tree().change_scene_to_file(target_scene_path)
	if err != OK:
		printerr("Erro ao transicionar após animação do mapa para: ", target_scene_path)


func _execute_point1_to_bonus() -> void:
	resting_arrow_p1.visible = false
	point1_cover.visible = true
	moving_arrow.visible = true
	path_follow.progress_ratio = 0.0

	_play_sound(_sfx_travel)

	var tween_move := create_tween()
	tween_move.tween_property(path_follow, "progress_ratio", 1.0, 1.8).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	await tween_move.finished

	moving_arrow.visible = false
	if resting_arrow_bonus != null:
		resting_arrow_bonus.visible = true
		_start_arrow_bobbing(resting_arrow_bonus)

	# Efeito de destaque no Bônus 1
	if unlock_vfx != null:
		unlock_vfx.position = Vector2(578, 282)
		if unlock_vfx.has_method("play_burst"):
			unlock_vfx.play_burst()

	var session = get_node_or_null("/root/GameSession")
	if session != null and session.has_method("unlock_bonus_stage"):
		session.unlock_bonus_stage()

	await get_tree().create_timer(1.0).timeout


func _execute_bonus_to_point2() -> void:
	if resting_arrow_bonus != null:
		resting_arrow_bonus.visible = false
	point1_cover.visible = true
	moving_arrow.visible = true
	path_follow.progress_ratio = 0.0

	_play_sound(_sfx_travel)

	var tween_move := create_tween()
	tween_move.tween_property(path_follow, "progress_ratio", 1.0, 1.8).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	await tween_move.finished

	moving_arrow.visible = false
	resting_arrow_p2.visible = true
	_start_arrow_bobbing(resting_arrow_p2)

	# Desbloqueio da Fase 2
	point2_cover.visible = true
	_play_sound(_sfx_unlock)
	if unlock_vfx != null:
		unlock_vfx.position = Vector2(870, 290)
		if unlock_vfx.has_method("play_burst"):
			unlock_vfx.play_burst()

	var session = get_node_or_null("/root/GameSession")
	if session != null and session.has_method("unlock_stage_2"):
		session.unlock_stage_2()

	await get_tree().create_timer(1.2).timeout


func _execute_full_preview() -> void:
	resting_arrow_p1.visible = false
	point1_cover.visible = true
	moving_arrow.visible = true
	path_follow.progress_ratio = 0.0

	_play_sound(_sfx_travel)

	var tween_move := create_tween()
	tween_move.tween_property(path_follow, "progress_ratio", 1.0, 2.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	await tween_move.finished

	moving_arrow.visible = false
	resting_arrow_p2.visible = true
	_start_arrow_bobbing(resting_arrow_p2)

	point2_cover.visible = true
	_play_sound(_sfx_unlock)
	if unlock_vfx != null:
		unlock_vfx.position = Vector2(870, 290)
		if unlock_vfx.has_method("play_burst"):
			unlock_vfx.play_burst()

	var session = get_node_or_null("/root/GameSession")
	if session != null and session.has_method("unlock_stage_2"):
		session.unlock_stage_2()

	await get_tree().create_timer(1.0).timeout


func _start_arrow_bobbing(arrow_node: Node2D) -> void:
	if _bob_tween != null and _bob_tween.is_valid():
		_bob_tween.kill()

	var base_y: float = arrow_node.position.y
	_bob_tween = create_tween().set_loops()
	_bob_tween.tween_property(arrow_node, "position:y", base_y - 4.0, 0.35).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_bob_tween.tween_property(arrow_node, "position:y", base_y + 2.0, 0.35).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)


func _gui_input(event: InputEvent) -> void:
	if get_viewport() != null:
		get_viewport().set_input_as_handled()


func _unhandled_input(event: InputEvent) -> void:
	if get_viewport() != null:
		get_viewport().set_input_as_handled()


func _play_sound(stream: AudioStreamWAV) -> void:
	if audio_player != null and stream != null:
		audio_player.stream = stream
		audio_player.play()


func _generate_sound_effects() -> void:
	_sfx_travel = _create_whoosh_wav(240.0, 480.0, 0.45, 0.35)
	_sfx_unlock = _create_chime_wav(0.70, 0.50)


func _create_whoosh_wav(freq_start: float, freq_end: float, duration: float, volume: float) -> AudioStreamWAV:
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_8_BITS
	wav.mix_rate = 22050
	var sample_count: int = int(22050.0 * duration)
	var data := PackedByteArray()
	data.resize(sample_count)

	for i in range(sample_count):
		var t: float = float(i) / float(sample_count)
		var cur_freq: float = lerpf(freq_start, freq_end, t)
		var envelope: float = sin(t * PI)
		var sample: float = sin(float(i) / 22050.0 * cur_freq * TAU) * volume * envelope
		data[i] = clampi(int(sample * 127.0 + 128.0), 0, 255)

	wav.data = data
	return wav


func _create_chime_wav(duration: float, volume: float) -> AudioStreamWAV:
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_8_BITS
	wav.mix_rate = 22050
	var sample_count: int = int(22050.0 * duration)
	var data := PackedByteArray()
	data.resize(sample_count)

	var f1: float = 880.0
	var f2: float = 1108.7
	var f3: float = 1318.5

	for i in range(sample_count):
		var t: float = float(i) / 22050.0
		var env: float = exp(-4.5 * (float(i) / float(sample_count)))
		var s1: float = sin(t * f1 * TAU) * 0.45
		var s2: float = sin(t * f2 * TAU) * 0.35
		var s3: float = sin(t * f3 * TAU) * 0.25
		var sample: float = (s1 + s2 + s3) * volume * env
		data[i] = clampi(int(sample * 127.0 + 128.0), 0, 255)

	wav.data = data
	return wav
