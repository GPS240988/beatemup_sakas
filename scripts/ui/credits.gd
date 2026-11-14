class_name CreditsMenu
extends Control

## Tela de Créditos Oficial — Projeto Sakas
## Exibe o vídeo de encerramento em tela cheia (assets/videos/creditos/video_creditos_demo.ogv)
## com áudio próprio integrado, preservando a imagem estática como fallback de segurança.
## Apresentada automaticamente após o término da Fase Bônus (Garagem).
## Permite retorno ao Menu Principal via botão arcade, toque na tela ou teclas arcade.

const MAIN_MENU_SCENE: String = "res://scenes/ui/main_menu.tscn"
const CREDITS_BG_PATH: String = "res://assets/backgrounds/creditos.webp"
const CREDITS_VIDEO_PATH: String = "res://assets/videos/creditos/video_creditos_demo.ogv"
const BGM_CREDITS_PATH: String = "res://assets/audio/bgm/Menu.mp3"

const MobileScreenAction = preload("res://scripts/mobile/mobile_screen_action.gd")

@onready var background_image: TextureRect = %BackgroundImage
@onready var video_player: VideoStreamPlayer = get_node_or_null("%VideoPlayer") as VideoStreamPlayer
@onready var fade_overlay: ColorRect = %FadeOverlay
@onready var btn_back: Button = %BtnBack
@onready var audio_player: AudioStreamPlayer = %AudioPlayer

var _is_returning: bool = false
var _can_interact: bool = false


func _ready() -> void:
	# 1. Carrega o background de créditos como base de fallback visual
	if background_image != null and ResourceLoader.exists(CREDITS_BG_PATH):
		background_image.texture = load(CREDITS_BG_PATH) as Texture2D

	# 2. Inicializa e reproduz o vídeo de créditos oficial
	_setup_video_credits()

	# 3. Botão de retorno
	if btn_back != null:
		btn_back.pressed.connect(_on_back_pressed)
		btn_back.grab_focus()

	# 4. Ação Mobile Primária
	MobileScreenAction.add_primary_action(
		self, "VOLTAR AO MENU", Callable(self, "_on_back_pressed"), Color(0.98, 0.82, 0.25, 1.0), btn_back
	)

	# 5. Animação de entrada suave (Fade In de 0.8s)
	if fade_overlay != null:
		fade_overlay.modulate.a = 1.0
		var tween := create_tween()
		tween.tween_property(fade_overlay, "modulate:a", 0.0, 0.8).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		tween.tween_callback(func(): _can_interact = true)
	else:
		_can_interact = true


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
			video_player.loop = true
			video_player.visible = true
			video_player.play()

			# O vídeo possui trilha sonora Vorbis própria; interrompe a BGM externa
			var session = get_node_or_null("/root/GameSession")
			if session != null and session.has_method("stop_bgm"):
				session.stop_bgm()
			return

	# Fallback caso o vídeo não possa ser carregado
	if video_player != null:
		video_player.visible = false

	var session = get_node_or_null("/root/GameSession")
	if session != null and session.has_method("play_bgm"):
		session.play_bgm(BGM_CREDITS_PATH, -4.0, 1.0)
	elif audio_player != null and ResourceLoader.exists(BGM_CREDITS_PATH):
		audio_player.stream = load(BGM_CREDITS_PATH) as AudioStream
		audio_player.play()


func _on_back_pressed() -> void:
	if _is_returning:
		return
	_is_returning = true

	if video_player != null and video_player.is_playing():
		video_player.stop()

	# Fade Out suave antes de trocar de cena
	if fade_overlay != null:
		var tween := create_tween()
		tween.tween_property(fade_overlay, "modulate:a", 1.0, 0.45).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		await tween.finished

	var err := get_tree().change_scene_to_file(MAIN_MENU_SCENE)
	if err != OK:
		printerr("Falha ao retornar ao Menu Principal: ", err)


func _gui_input(event: InputEvent) -> void:
	if not _can_interact or _is_returning:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_on_back_pressed()
	elif event is InputEventScreenTouch and event.pressed:
		_on_back_pressed()


func _unhandled_input(event: InputEvent) -> void:
	if not _can_interact or _is_returning:
		return
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("ui_accept"):
		_on_back_pressed()
	elif event is InputEventKey and event.pressed and not event.echo:
		if event.keycode in [KEY_SPACE, KEY_ENTER, KEY_KP_ENTER, KEY_ESCAPE]:
			_on_back_pressed()

