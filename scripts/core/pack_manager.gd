# scripts/core/pack_manager.gd
class_name PackManagerClass
extends Node

## Gerenciador Central de Pacotes Modulares (Multi-PCK) do Projeto Sakas.
##
## Responsável por montar pacotes adicionais (.pck) de forma transparente
## na raiz res://, permitindo que o jogo escale com múltiplos estágios,
## áudios e cinemáticas mantendo cada arquivo bem abaixo do limite de 100 MB.
##
## Suporta:
## 1. Montagem local síncrona (Desktop / Standalone / Editor).
## 2. Carregamento progressivo assíncrono (Web Streaming via copyToFS e Service Worker).
## 3. Rastreamento detalhado de progresso em bytes e percentual.
## 4. Recuperação e retentativa em caso de falha de conexão.

signal pack_mounted(pack_id: String)
signal pack_load_progress(pack_id: String, progress: float)
signal pack_progress(pack_id: String, loaded_bytes: int, total_bytes: int, percent: float)
signal pack_error(pack_id: String, error_message: String)
signal all_critical_packs_ready()

enum PackState {
	UNLOADED,
	QUEUED,
	DOWNLOADING,
	VERIFYING,
	MOUNTED,
	ERROR
}

# Definição do catálogo canônico de pacotes modulares
# Na arquitetura PWA Premium, pacotes secundários não são críticos na inicialização (critical = false),
# permitindo abertura imediata do Menu Principal com download sob demanda.
const KNOWN_PACKS: Dictionary = {
	"audio_bgm": {
		"file_name": "pack_audio_bgm.pck",
		"critical": false,
		"description": "Trilhas Sonoras de Fundo (BGM)",
		"expected_max_mb": 45.0
	},
	"story_cinematics": {
		"file_name": "pack_story_cinematics.pck",
		"critical": false,
		"description": "Cinemáticas e Ilustrações Narrativas",
		"expected_max_mb": 45.0
	},
	"stage1": {
		"file_name": "pack_stage1.pck",
		"critical": false,
		"description": "Cenários e Mapas do Estágio 1",
		"expected_max_mb": 45.0
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

	# Em builds exportadas (Web ou Standalone), monta os pacotes que já estiverem locais
	mount_all_available_local_packs()


## Retorna se um pacote já está montado e acessível em res://
func is_pack_mounted(pack_id: String) -> bool:
	return _pack_states.get(pack_id, PackState.UNLOADED) == PackState.MOUNTED


## Retorna a lista de IDs de pacotes atualmente montados
func get_mounted_packs() -> Array[String]:
	return _mounted_packs.duplicate()


## Retorna o estado atual de um pacote específico
func get_pack_state(pack_id: String) -> PackState:
	return _pack_states.get(pack_id, PackState.UNLOADED)


## Tenta montar um pacote específico localmente pelo seu ID
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
			var success: bool = ProjectSettings.load_resource_pack(path, true)
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

	_pack_states[pack_id] = PackState.UNLOADED
	return false


## Garante sincronicamente se o pacote está disponível (se já montado ou montável localmente)
func ensure_pack_loaded(pack_id: String) -> bool:
	if is_pack_mounted(pack_id):
		return true
	return mount_pack(pack_id)


## Método assíncrono oficial para carregamento sob demanda (Streaming Web ou montagem local)
## Retorna true se o pacote foi montado com sucesso ou já estava disponível.
func ensure_pack_loaded_async(pack_id: String) -> bool:
	if not KNOWN_PACKS.has(pack_id):
		push_error("[PackManager] Pacote desconhecido: %s" % pack_id)
		return false

	if is_pack_mounted(pack_id):
		return true

	# 1. Tenta montar de arquivos já locais (MEMFS, cache ou diretório)
	if mount_pack(pack_id):
		return true

	# 2. Se não estiver no ambiente Web e não estiver no disco, falha
	if not OS.has_feature("web"):
		_pack_states[pack_id] = PackState.ERROR
		var err_msg = "Arquivo %s não encontrado no disco local." % KNOWN_PACKS[pack_id]["file_name"]
		pack_error.emit(pack_id, err_msg)
		return false

	# 3. Na Web, dispara o streaming progressivo via camada JavaScript
	var file_name: String = KNOWN_PACKS[pack_id]["file_name"]
	_pack_states[pack_id] = PackState.DOWNLOADING
	pack_load_progress.emit(pack_id, 0.0)
	pack_progress.emit(pack_id, 0, 0, 0.0)

	JavaScriptBridge.eval("if (window.sakasStreamPack) { window.sakasStreamPack('%s', '%s'); }" % [pack_id, file_name])

	# 4. Loop de monitoramento de progresso e finalização
	var max_wait_sec: float = 90.0
	var elapsed: float = 0.0
	while elapsed < max_wait_sec:
		await get_tree().create_timer(0.08).timeout
		elapsed += 0.08

		var status_raw = JavaScriptBridge.eval("if (window.sakasGetPackStatus) { window.sakasGetPackStatus('%s'); } else { '{\"status\":\"unloaded\"}'; }" % pack_id)
		var status_str: String = str(status_raw)
		var data = JSON.parse_string(status_str)
		if data is Dictionary:
			var st: String = data.get("status", "")
			if st == "ready":
				var target_fs_path: String = "packs/" + file_name
				var success: bool = ProjectSettings.load_resource_pack(target_fs_path, true)
				if success:
					_pack_states[pack_id] = PackState.MOUNTED
					if not _mounted_packs.has(pack_id):
						_mounted_packs.append(pack_id)
					print("[PackManager] Pacote '%s' montado com sucesso via stream Web!" % pack_id)
					pack_mounted.emit(pack_id)
					_check_critical_packs()
					return true
				else:
					push_error("[PackManager] Falha ao executar load_resource_pack em: %s" % target_fs_path)
					_pack_states[pack_id] = PackState.ERROR
					pack_error.emit(pack_id, "Falha de montagem no motor após download")
					return false
			elif st == "error":
				_pack_states[pack_id] = PackState.ERROR
				var err_msg: String = str(data.get("error", "Erro de conexão ao baixar pacote"))
				pack_error.emit(pack_id, err_msg)
				return false
			elif st == "loading":
				var loaded: int = int(data.get("loaded", 0))
				var total: int = int(data.get("total", 0))
				var pct: float = float(data.get("percent", 0.0))
				pack_progress.emit(pack_id, loaded, total, pct)
				pack_load_progress.emit(pack_id, pct / 100.0)

	_pack_states[pack_id] = PackState.ERROR
	pack_error.emit(pack_id, "Tempo limite excedido ao carregar pacote da rede.")
	return false


## Cancela ou redefine o estado de um pacote para permitir nova tentativa
func reset_pack_state(pack_id: String) -> void:
	if KNOWN_PACKS.has(pack_id) and not is_pack_mounted(pack_id):
		_pack_states[pack_id] = PackState.UNLOADED
		if OS.has_feature("web"):
			JavaScriptBridge.eval("if (window.sakasResetPack) { window.sakasResetPack('%s'); }" % pack_id)


## Varre os diretórios locais conhecidos e monta todos os pacotes encontrados
func mount_all_available_local_packs() -> int:
	var count: int = 0
	for pack_id in KNOWN_PACKS.keys():
		if mount_pack(pack_id):
			count += 1
	_check_critical_packs()
	return count


## Verifica se um recurso específico já existe em res://
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
