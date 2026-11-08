# scripts/core/pack_manager.gd
class_name PackManagerClass
extends Node

## Gerenciador Central de Pacotes Modulares (Multi-PCK) do Projeto Sakas.
##
## Responsável por montar pacotes adicionais (.pck) de forma transparente
## na raiz res://, permitindo que o jogo escale com múltiplos estágios,
## áudios e cinemáticas mantendo cada arquivo bem abaixo do limite de 100 MB.

signal pack_mounted(pack_id: String)
signal pack_load_progress(pack_id: String, progress: float)
signal pack_error(pack_id: String, error_message: String)
signal all_critical_packs_ready()

enum PackState {
	UNLOADED,
	LOADING,
	MOUNTED,
	ERROR
}

# Definição do catálogo canônico de pacotes modulares
const KNOWN_PACKS: Dictionary = {
	"audio_bgm": {
		"file_name": "pack_audio_bgm.pck",
		"critical": true,
		"description": "Trilhas Sonoras de Fundo (BGM)",
		"expected_max_mb": 35.0
	},
	"story_cinematics": {
		"file_name": "pack_story_cinematics.pck",
		"critical": true,
		"description": "Cinemáticas e Ilustrações Narrativas",
		"expected_max_mb": 45.0
	},
	"stage1": {
		"file_name": "pack_stage1.pck",
		"critical": true,
		"description": "Cenários e Mapas do Estágio 1",
		"expected_max_mb": 35.0
	}
}

var _pack_states: Dictionary = {}
var _mounted_packs: Array[String] = []


func _ready() -> void:
	# Inicializa estados
	for pack_id in KNOWN_PACKS.keys():
		_pack_states[pack_id] = PackState.UNLOADED

	# No Editor do Godot, os arquivos já existem em res:// por padrão
	if OS.has_feature("editor"):
		print("[PackManager] Modo Editor detectado: todos os recursos já estão disponíveis.")
		for pack_id in KNOWN_PACKS.keys():
			_pack_states[pack_id] = PackState.MOUNTED
			_mounted_packs.append(pack_id)
		all_critical_packs_ready.emit()
		return

	# Em builds exportadas (Web ou Standalone), monta todos os pacotes presentes no disco/FS
	mount_all_available_local_packs()


## Retorna se um pacote já está montado e acessível em res://
func is_pack_mounted(pack_id: String) -> bool:
	return _pack_states.get(pack_id, PackState.UNLOADED) == PackState.MOUNTED


## Retorna a lista de IDs de pacotes atualmente montados
func get_mounted_packs() -> Array[String]:
	return _mounted_packs.duplicate()


## Tenta montar um pacote específico pelo seu ID
func mount_pack(pack_id: String) -> bool:
	if not KNOWN_PACKS.has(pack_id):
		push_error("[PackManager] Pacote desconhecido: %s" % pack_id)
		return false

	if is_pack_mounted(pack_id):
		return true

	var file_name: String = KNOWN_PACKS[pack_id]["file_name"]
	var search_paths: Array[String] = _get_search_paths_for_file(file_name)

	for path in search_paths:
		if FileAccess.file_exists(path):
			var success: bool = ProjectSettings.load_resource_pack(path, false)
			if success:
				_pack_states[pack_id] = PackState.MOUNTED
				if not _mounted_packs.has(pack_id):
					_mounted_packs.append(pack_id)
				print("[PackManager] Pacote '%s' montado com sucesso a partir de '%s'!" % [pack_id, path])
				pack_mounted.emit(pack_id)
				_check_critical_packs()
				return true
			else:
				push_error("[PackManager] Falha ao executar load_resource_pack em: %s" % path)

	_pack_states[pack_id] = PackState.ERROR
	pack_error.emit(pack_id, "Arquivo %s não encontrado nos caminhos de busca." % file_name)
	return false


## Varre os diretórios locais conhecidos e monta todos os pacotes encontrados
func mount_all_available_local_packs() -> int:
	var count: int = 0
	for pack_id in KNOWN_PACKS.keys():
		if mount_pack(pack_id):
			count += 1
	_check_critical_packs()
	return count


## Verifica se um recurso específico já existe em res:// (pode ser usado para checagem dinâmica)
func is_resource_available(res_path: String) -> bool:
	return ResourceLoader.exists(res_path)


func _check_critical_packs() -> void:
	for pack_id in KNOWN_PACKS.keys():
		if KNOWN_PACKS[pack_id].get("critical", false):
			if not is_pack_mounted(pack_id):
				return
	all_critical_packs_ready.emit()


func _get_search_paths_for_file(file_name: String) -> Array[String]:
	var paths: Array[String] = []

	# 1. Caminho relativo ao executável ou virtual root
	paths.append("packs/%s" % file_name)
	paths.append("res://packs/%s" % file_name)
	paths.append("res://%s" % file_name)

	# 2. Caminho no armazenamento local do usuário / IndexedDB
	paths.append("user://packs/%s" % file_name)
	paths.append("user://%s" % file_name)

	# 3. Caminho standalone desktop baseado no executável
	if not OS.has_feature("web"):
		var exe_dir: String = OS.get_executable_path().get_base_dir()
		paths.append(exe_dir.path_join("packs").path_join(file_name))
		paths.append(exe_dir.path_join(file_name))

	return paths

