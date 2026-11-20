class_name CreditsMenu
extends Control

## Reproduz o vídeo de encerramento da fase bônus e, ao terminar,
## apresenta a transição cinematográfica no mapa-base até o Estágio 02.

const CREDITS_BG_PATH: String = "res://assets/backgrounds/creditos.webp"
const CREDITS_VIDEO_PATH: String = "res://assets/videos/creditos/video_creditos_demo.ogv"
const MAP_TRANSITION_SCENE: String = "res://scenes/ui/map_transition.tscn"
const STAGE2_INTRO_SCENE: String = "res://scenes/story/story_stage2_intro.tscn"
const MAIN_MENU_SCENE: String = "res://scenes/ui/main_menu.tscn"
const BGM_CREDITS_PATH: String = "res://assets/audio/bgm/Menu.mp3"

@onready var background_image: TextureRect = %BackgroundImage
@onready var video_player: VideoStreamPlayer = get_node_or_null("%VideoPlayer") as VideoStreamPlayer
@onready var fade_overlay: ColorRect = %FadeOverlay
@onready var audio_player: AudioStreamPlayer = %AudioPlayer

var _transition_started: bool = false


func _ready() -> void:
	if background_image != null and ResourceLoader.exists(CREDITS_BG_PATH):
		background_image.texture = load(CREDITS_BG_PATH) as Texture2D

	# O vídeo e seus recursos pertencem ao pacote stage1.
	var pack_mgr = get_node_or_null("/root/PackManager")
	if pack_mgr != null and pack_mgr.has_method("ensure_pack_loaded_async"):
		if not pack_mgr.is_pack_mounted("stage1"):
			await pack_mgr.ensure_pack_loaded_async("stage1")

	# O vídeo é a única apresentação desta tela: sem botão, toque ou atalho de saída.
	if fade_overlay != null:
		fade_overlay.modulate.a = 1.0
		var fade_in := create_tween()
		fade_in.tween_property(fade_overlay, "modulate:a", 0.0, 0.8)
		fade_in.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

	_setup_video_credits()


func _setup_video_credits() -> void:
	if video_player != null and ResourceLoader.exists(CREDITS_VIDEO_PATH):
		var stream: VideoStream = ResourceLoader.load(CREDITS_VIDEO_PATH) as VideoStream
		if stream == null:
			var theora_stream := VideoStreamTheora.new()
			theora_stream.file = CREDITS_VIDEO_PATH
			stream = theora_stream

		if stream != null:
			video_player.stream = stream
			video_player.expand = true
			video_player.loop = false
			video_player.visible = true
			if not video_player.finished.is_connected(_on_video_finished):
				video_player.finished.connect(_on_video_finished, CONNECT_ONE_SHOT)
			video_player.play()

			# O vídeo possui trilha Vorbis própria; interrompe a BGM externa.
			var session = get_node_or_null("/root/GameSession")
			if session != null and session.has_method("stop_bgm"):
				session.stop_bgm()
			return

	# Se o vídeo não estiver disponível, não deixa a progressão da campanha travada.
	push_warning("CreditsMenu: vídeo de créditos indisponível; seguindo para o Estágio 02.")
	if video_player != null:
		video_player.visible = false
	call_deferred("_on_video_finished")


func _on_video_finished() -> void:
	if _transition_started:
		return
	_transition_started = true

	# Mantém o último quadro por um breve instante antes da transição para o mapa.
	await get_tree().create_timer(0.45).timeout
	if fade_overlay != null:
		var fade_out := create_tween()
		fade_out.tween_property(fade_overlay, "modulate:a", 1.0, 0.55)
		fade_out.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		await fade_out.finished

	# O fluxo do Estágio 02 é deliberadamente restrito a builds de depuração.
	# Em release, os créditos encerram a campanha sem expor o mapa ainda não publicado.
	var target_scene: String = MAIN_MENU_SCENE
	if OS.is_debug_build():
		var session = get_node_or_null("/root/GameSession")
		if session != null:
			session.pending_map_transition_mode = 1
			session.pending_transition_target = STAGE2_INTRO_SCENE
			session.has_seen_stage_2_transition = true
		target_scene = MAP_TRANSITION_SCENE

	var err := get_tree().change_scene_to_file(target_scene)
	if err != OK:
		_transition_started = false
		printerr("CreditsMenu: falha ao continuar após os créditos para ", target_scene, ": ", err)
