extends Node

## Configuração de apresentação aplicada somente em dispositivos móveis.
## Desktop mantém integralmente a configuração original do projeto.

func _ready() -> void:
	if not _is_mobile_runtime():
		return

	# Em paisagem ultrawide, mantém a altura lógica do jogo e amplia a área
	# horizontal visível. Isso remove as barras laterais sem esticar sprites,
	# alterar a resolução-base ou redimensionar recursos.
	DisplayServer.screen_set_orientation(DisplayServer.SCREEN_LANDSCAPE)
	get_tree().root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP_HEIGHT


func _is_mobile_runtime() -> bool:
	return (
		OS.has_feature("mobile")
		or OS.has_feature("web_android")
		or OS.has_feature("web_ios")
	)
