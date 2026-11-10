class_name GameSessionClass
extends Node

## Gerenciador de sessão e estado de início de jogo (Autoload: GameSession)
## Preserva o personagem, skin e dificuldade selecionados pelo jogador.

signal character_selected(character_id: String)
signal skin_selected(skin_id: String)
signal difficulty_selected(difficulty_id: String)
signal game_started(character_id: String, skin_id: String, difficulty_id: String)
signal stage_unlocked(stage_num: int)
signal bonus_unlocked_signal()

## Identificadores de estado da sessão
var selected_character_id: String = "guilherme"
var selected_skin_id: String = "palmeirense"
var difficulty_id: String = ""
var has_played_intro: bool = false

## Progresso da campanha e fases desbloqueadas
var bonus_stage_unlocked: bool = false
var stage_2_unlocked: bool = false
var max_unlocked_stage: int = 1
var has_seen_bonus_transition: bool = false
var has_seen_stage_2_transition: bool = false
var has_seen_fase1_4_intro: bool = false
var pending_transition_target: String = ""
var pending_map_transition_mode: int = 0 # 0: POINT1_TO_BONUS, 1: BONUS_TO_POINT2, 2: FULL_PREVIEW
const CAMPAIGN_SAVE_PATH: String = "user://campaign_progression.json"

## Caminho oficial da Fase 1 (Mapa 1: A Locadora)
const FIRST_LEVEL_PATH: String = "res://scenes/levels/map_1.tscn"

## Metadados e regras de desbloqueio de Personagens
const CHARACTERS: Dictionary = {
	"guilherme": {
		"name": "Guilherme",
		"title": "O Guerreiro de Sakas",
		"unlocked": true,
		"preview_path": "res://assets/sprites/characters/guilherme/idle.png",
		"strength": 3,
		"speed": 2,
		"technique": 3
	},
	"gabriel": {
		"name": "Gabriel",
		"title": "Lâmina Veloz",
		"unlocked": false,
		"preview_path": "",
		"strength": 1,
		"speed": 4,
		"technique": 3
	},
	"andre": {
		"name": "André",
		"title": "Especialista em Chutes",
		"unlocked": false,
		"preview_path": "",
		"strength": 4,
		"speed": 2,
		"technique": 2
	},
	"juliana": {
		"name": "Juliana",
		"title": "Mestre da Fúria",
		"unlocked": false,
		"preview_path": "",
		"strength": 1,
		"speed": 3,
		"technique": 4
	},
	"alessandro": {
		"name": "Alessandro",
		"title": "Cibernético",
		"unlocked": false,
		"preview_path": "",
		"strength": 3,
		"speed": 3,
		"technique": 3
	},
	"fernando": {
		"name": "Fernando",
		"title": "Lutador Brutal",
		"unlocked": false,
		"preview_path": "",
		"strength": 5,
		"speed": 1,
		"technique": 2
	}
}

## Metadados e regras de desbloqueio de Skins
const SKINS: Dictionary = {
	"palmeirense": {
		"name": "Palmeirense",
		"unlocked": true,
		"description": "Visual autêntico com as cores sagradas"
	},
	"pelado": {
		"name": "Pelado",
		"unlocked": false,
		"description": "Skin especial bloqueada no momento"
	}
}

## Dificuldades disponíveis
const DIFFICULTIES: Dictionary = {
	"normal": {
		"name": "Normal",
		"description": "Desafio equilibrado",
		"enemy_health_mult": 1.0,
		"enemy_damage_mult": 1.0
	},
	"dificil": {
		"name": "Difícil",
		"description": "Um desafio maior",
		"enemy_health_mult": 2.1,
		"enemy_damage_mult": 1.95
	}
}


func _ready() -> void:
	# Inicialização padrão da sessão e restauração da progressão persistente da campanha
	reset_session()
	_load_campaign_progression()
	_init_bgm_pack_listener()


## Estado de progressão do jogador entre seções do mesmo mapa (ex: Fase 1)
var current_stage_group: String = "fase1"
var preserved_health: float = -1.0
var preserved_special: float = -1.0
var current_continues: int = 1

## Snapshot de mundo pendente para restauração ao carregar um save slot
## Populado por load_game_from_slot() e consumido por BaseLevel._ready()
var pending_save_snapshot: Dictionary = {}
var active_save_slot: int = 1


## Redefine os dados da sessão para os padrões iniciais (mantendo desbloqueios de campanha)
func reset_session() -> void:
	selected_character_id = "guilherme"
	selected_skin_id = "palmeirense"
	difficulty_id = ""
	has_played_intro = false
	has_seen_fase1_4_intro = false
	current_continues = 1
	pending_transition_target = ""
	pending_map_transition_mode = 0
	pending_save_snapshot = {}
	active_save_slot = 1
	clear_player_progression()


## Verifica se a Fase Bônus foi desbloqueada
func is_bonus_unlocked() -> bool:
	return bonus_stage_unlocked


## Desbloqueia a Fase Bônus e persiste a evolução
func unlock_bonus_stage() -> void:
	if not bonus_stage_unlocked:
		bonus_stage_unlocked = true
		_save_campaign_progression()
		bonus_unlocked_signal.emit()


## Verifica se a Fase 2 foi desbloqueada
func is_stage_2_unlocked() -> bool:
	return stage_2_unlocked


## Desbloqueia a Fase 2 e persiste a evolução
func unlock_stage_2() -> void:
	unlock_stage(2)


## Desbloqueia fase numérica especificada e persiste a evolução
func unlock_stage(stage_num: int) -> void:
	var was_unlocked := stage_2_unlocked
	if stage_num >= 2:
		stage_2_unlocked = true
	if stage_num > max_unlocked_stage:
		max_unlocked_stage = stage_num
	_save_campaign_progression()
	if not was_unlocked and stage_2_unlocked:
		stage_unlocked.emit(2)


## Grava dados de progressão da campanha (independente de slot de partida)
func _save_campaign_progression() -> void:
	var data: Dictionary = {
		"bonus_stage_unlocked": bonus_stage_unlocked,
		"stage_2_unlocked": stage_2_unlocked,
		"max_unlocked_stage": max_unlocked_stage,
		"has_seen_bonus_transition": has_seen_bonus_transition,
		"has_seen_stage_2_transition": has_seen_stage_2_transition
	}
	var file := FileAccess.open(CAMPAIGN_SAVE_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(data, "\t"))
		file.close()


## Restaura dados de progressão da campanha
func _load_campaign_progression() -> void:
	if not FileAccess.file_exists(CAMPAIGN_SAVE_PATH):
		return
	var file := FileAccess.open(CAMPAIGN_SAVE_PATH, FileAccess.READ)
	if file == null:
		return
	var text: String = file.get_as_text()
	file.close()
	var json := JSON.new()
	if json.parse(text) == OK and json.data is Dictionary:
		var d: Dictionary = json.data as Dictionary
		bonus_stage_unlocked = bool(d.get("bonus_stage_unlocked", false))
		stage_2_unlocked = bool(d.get("stage_2_unlocked", false))
		max_unlocked_stage = int(d.get("max_unlocked_stage", 1))
		has_seen_bonus_transition = bool(d.get("has_seen_bonus_transition", false))
		has_seen_stage_2_transition = bool(d.get("has_seen_stage_2_transition", false))



## Salva a vida e especial atuais do jogador para o grupo de mapa corrente
func save_player_progression(stage_group: String, health: float, special: float) -> void:
	current_stage_group = stage_group
	preserved_health = health
	preserved_special = special


## Retorna os valores preservados se pertencerem ao mesmo grupo de mapa
func get_preserved_player_progression(stage_group: String) -> Dictionary:
	if current_stage_group == stage_group and preserved_health > 0.0:
		return {
			"health": preserved_health,
			"special": preserved_special
		}
	return {}


## Limpa os dados de progressão (ao trocar para outro mapa ou reiniciar)
func clear_player_progression() -> void:
	preserved_health = -1.0
	preserved_special = -1.0


## Verifica se o personagem está desbloqueado
func is_character_unlocked(character_id: String) -> bool:
	if CHARACTERS.has(character_id):
		return CHARACTERS[character_id].get("unlocked", false)
	return false


## Tenta confirmar a seleção de um personagem
func select_character(character_id: String) -> bool:
	if not is_character_unlocked(character_id):
		return false
	selected_character_id = character_id
	character_selected.emit(character_id)
	return true


## Verifica se a skin está desbloqueada
func is_skin_unlocked(skin_id: String) -> bool:
	if SKINS.has(skin_id):
		return SKINS[skin_id].get("unlocked", false)
	return false


## Tenta confirmar a seleção de uma skin
func select_skin(skin_id: String) -> bool:
	if not is_skin_unlocked(skin_id):
		return false
	selected_skin_id = skin_id
	skin_selected.emit(skin_id)
	return true


## Verifica se a dificuldade é válida
func is_difficulty_valid(diff_id: String) -> bool:
	return DIFFICULTIES.has(diff_id)


## Confirma a dificuldade e inicia a Fase 1
func select_difficulty_and_start(diff_id: String) -> bool:
	if not is_difficulty_valid(diff_id):
		return false
	difficulty_id = diff_id
	difficulty_selected.emit(difficulty_id)
	game_started.emit(selected_character_id, selected_skin_id, difficulty_id)
	
	# Troca de cena para a Fase 1 existente
	var err := get_tree().change_scene_to_file(FIRST_LEVEL_PATH)
	return err == OK


## Retorna o dicionário de atributos do personagem
func get_character_stats(char_id: String) -> Dictionary:
	if CHARACTERS.has(char_id):
		var char_data: Dictionary = CHARACTERS[char_id]
		return {
			"strength": int(char_data.get("strength", 3)),
			"speed": int(char_data.get("speed", 2)),
			"technique": int(char_data.get("technique", 3))
		}
	return {"strength": 3, "speed": 2, "technique": 3}


## Multiplicador de dano derivado de Força (Base 3 = 1.0)
func get_strength_multiplier(char_id: String) -> float:
	var stats: Dictionary = get_character_stats(char_id)
	var str_val: float = float(stats.get("strength", 3))
	return 0.70 + (str_val * 0.10)


## Multiplicador de velocidade derivado de Velocidade (Base 2 = 1.0)
func get_speed_multiplier(char_id: String) -> float:
	var stats: Dictionary = get_character_stats(char_id)
	var spd_val: float = float(stats.get("speed", 2))
	return 0.70 + (spd_val * 0.15)


## Multiplicador técnico (alcance de combo e janela de acerto, Base 3 = 1.0)
func get_technique_multiplier(char_id: String) -> float:
	var stats: Dictionary = get_character_stats(char_id)
	var tec_val: float = float(stats.get("technique", 3))
	return 0.70 + (tec_val * 0.10)


# ============================================================
# SISTEMA DE SALVAMENTO PERSISTENTE (SLOTS 1 A 4)
# ============================================================
const SAVE_PATH_TEMPLATE: String = "user://save_slot_%d.json"

const LEVEL_NAMES: Dictionary = {
	"res://scenes/levels/map_1.tscn": "Mapa 1: A Locadora",
	"res://scenes/levels/map_2.tscn": "Mapa 2: Rua do Beco",
	"res://scenes/levels/map_3.tscn": "Mapa 3: Galpão Subterrâneo",
	"res://scenes/levels/map_4.tscn": "Mapa 4: O Bar da Vila",
}


## Verifica se existe arquivo de save válido para o slot indicado
func has_save_in_slot(slot: int) -> bool:
	if slot < 1 or slot > 4:
		return false
	var path: String = SAVE_PATH_TEMPLATE % slot
	return FileAccess.file_exists(path)


## Retorna os metadados do save no slot ou dicionário vazio se inexistente.
## Se o arquivo principal estiver corrompido, tenta recuperar do .bak automaticamente.
func get_save_info(slot: int) -> Dictionary:
	var path: String = SAVE_PATH_TEMPLATE % slot
	if not has_save_in_slot(slot):
		# Tenta recuperação pelo backup antes de desistir
		var bak_path: String = path + ".bak"
		if FileAccess.file_exists(bak_path):
			var recovered := _parse_save_file(bak_path)
			if not recovered.is_empty():
				# Restaura o backup como arquivo principal
				DirAccess.rename_absolute(bak_path, path)
				return recovered
		return {}
	var result := _parse_save_file(path)
	if result.is_empty():
		# Arquivo principal corrompido; tenta backup
		var bak_path: String = path + ".bak"
		if FileAccess.file_exists(bak_path):
			var recovered := _parse_save_file(bak_path)
			if not recovered.is_empty():
				DirAccess.rename_absolute(bak_path, path)
				return recovered
	return result


## Lê e parseia um arquivo JSON de save, retornando Dictionary ou vazio
func _parse_save_file(file_path: String) -> Dictionary:
	var file := FileAccess.open(file_path, FileAccess.READ)
	if file == null:
		return {}
	var json_str: String = file.get_as_text()
	file.close()
	var json := JSON.new()
	var parse_result := json.parse(json_str)
	if parse_result != OK or not (json.data is Dictionary):
		return {}
	return json.data as Dictionary


## Salva os dados completos da sessão e fase atual no slot escolhido.
## Se world_snapshot for fornecido (via BaseLevel.capture_world_snapshot()), armazena
## a posição exata do jogador, inimigos e estado da fase para restauração fiel.
## A gravação é atômica: escreve em .tmp, valida, e então substitui o .json real.
func save_game_to_slot(slot: int, level_path: String, player_hp: float = -1.0, player_sp: float = -1.0, world_snapshot: Dictionary = {}) -> bool:
	if slot < 1 or slot > 4:
		slot = 1

	var hp_to_save: float = player_hp if player_hp > 0.0 else (preserved_health if preserved_health > 0.0 else 100.0)
	var sp_to_save: float = player_sp if player_sp >= 0.0 else (preserved_special if preserved_special >= 0.0 else 0.0)

	var lvl_name: String = LEVEL_NAMES.get(level_path, "Fase Desconhecida")
	var time_dict := Time.get_datetime_dict_from_system()
	var date_formatted: String = "%02d/%02d/%04d %02d:%02d" % [
		time_dict.get("day", 1),
		time_dict.get("month", 1),
		time_dict.get("year", 2026),
		time_dict.get("hour", 0),
		time_dict.get("minute", 0)
	]

	# Se o snapshot não foi fornecido explicitamente, tenta capturar do nível atual
	if world_snapshot.is_empty():
		var current_level: Node = null
		if is_inside_tree() and get_tree() != null:
			current_level = get_tree().current_scene
		if current_level != null and current_level.has_method("capture_world_snapshot"):
			world_snapshot = current_level.capture_world_snapshot()

	var save_data: Dictionary = {
		"slot": slot,
		"timestamp": Time.get_unix_time_from_system(),
		"date_time": date_formatted,
		"level_path": level_path,
		"level_name": lvl_name,
		"character_id": selected_character_id,
		"skin_id": selected_skin_id,
		"difficulty_id": difficulty_id if difficulty_id != "" else "normal",
		"health": hp_to_save,
		"special": sp_to_save,
		"continues": current_continues,
		"bonus_stage_unlocked": bonus_stage_unlocked,
		"stage_2_unlocked": stage_2_unlocked,
		"max_unlocked_stage": max_unlocked_stage,
		"world_snapshot": world_snapshot
	}

	var json_text: String = JSON.stringify(save_data, "\t")
	var path: String = SAVE_PATH_TEMPLATE % slot
	var tmp_path: String = path + ".tmp"
	var bak_path: String = path + ".bak"

	# 1. Escreve no arquivo temporário
	var file := FileAccess.open(tmp_path, FileAccess.WRITE)
	if file == null:
		printerr("Erro ao abrir arquivo temporário para salvar slot %d: %d" % [slot, FileAccess.get_open_error()])
		return false
	file.store_string(json_text)
	file.close()

	# 2. Valida que o JSON temporário é legível e íntegro
	var verify_file := FileAccess.open(tmp_path, FileAccess.READ)
	if verify_file == null:
		printerr("Erro ao verificar arquivo temporário do slot %d" % slot)
		return false
	var verify_text: String = verify_file.get_as_text()
	verify_file.close()
	var verify_json := JSON.new()
	if verify_json.parse(verify_text) != OK or not (verify_json.data is Dictionary):
		printerr("Arquivo temporário do slot %d corrompido, abortando" % slot)
		DirAccess.remove_absolute(tmp_path)
		return false

	# 3. Backup do save anterior (se existir)
	if FileAccess.file_exists(path):
		if FileAccess.file_exists(bak_path):
			DirAccess.remove_absolute(bak_path)
		DirAccess.rename_absolute(path, bak_path)

	# 4. Promove o temporário para o save definitivo
	var rename_err := DirAccess.rename_absolute(tmp_path, path)
	if rename_err != OK:
		printerr("Erro ao promover save temporário do slot %d: %d" % [slot, rename_err])
		# Tenta restaurar o backup
		if FileAccess.file_exists(bak_path):
			DirAccess.rename_absolute(bak_path, path)
		return false

	active_save_slot = slot
	return true


## Carrega os dados de um slot salvo e realiza a transição de fase correspondente.
## Extrai o world_snapshot para pending_save_snapshot, que BaseLevel._ready() consumirá
## para restaurar posição do jogador, inimigos e progresso da fase.
func load_game_from_slot(slot: int) -> bool:
	var data := get_save_info(slot)
	if data.is_empty():
		return false

	selected_character_id = str(data.get("character_id", "guilherme"))
	selected_skin_id = str(data.get("skin_id", "palmeirense"))
	difficulty_id = str(data.get("difficulty_id", "normal"))
	current_continues = int(data.get("continues", 1))
	has_played_intro = true
	bonus_stage_unlocked = bool(data.get("bonus_stage_unlocked", bonus_stage_unlocked))
	stage_2_unlocked = bool(data.get("stage_2_unlocked", stage_2_unlocked))
	max_unlocked_stage = int(data.get("max_unlocked_stage", max_unlocked_stage))
	_save_campaign_progression()

	var hp: float = float(data.get("health", 100.0))
	var sp: float = float(data.get("special", 0.0))
	var lvl_path: String = str(data.get("level_path", FIRST_LEVEL_PATH))

	save_player_progression("fase1", hp, sp)

	# Extrai e armazena o snapshot do mundo para restauração ao carregar o nível
	var snapshot: Dictionary = data.get("world_snapshot", {}) as Dictionary
	pending_save_snapshot = snapshot if snapshot is Dictionary else {}
	active_save_slot = slot

	character_selected.emit(selected_character_id)
	skin_selected.emit(selected_skin_id)
	difficulty_selected.emit(difficulty_id)
	game_started.emit(selected_character_id, selected_skin_id, difficulty_id)

	var err := get_tree().change_scene_to_file(lvl_path)
	return err == OK


## Remove o save do slot (para reset)
func delete_save_slot(slot: int) -> bool:
	if not has_save_in_slot(slot):
		return true
	var path: String = SAVE_PATH_TEMPLATE % slot
	var err := DirAccess.remove_absolute(path)
	return err == OK


# =========================================================================
# GERENCIAMENTO DE TRILHA SONORA (BGM)
# =========================================================================

var _bgm_player: AudioStreamPlayer = null
var _current_bgm_path: String = ""
var _bgm_tween: Tween = null
var _pending_bgm_path: String = ""
var _pending_volume_db: float = -4.0
var _pending_fade_in: float = 0.0


func _init_bgm_pack_listener() -> void:
	var pack_mgr = get_node_or_null("/root/PackManager")
	if pack_mgr != null and pack_mgr.has_signal("pack_mounted"):
		if not pack_mgr.pack_mounted.is_connected(_on_pack_mounted_bgm_retry):
			pack_mgr.pack_mounted.connect(_on_pack_mounted_bgm_retry)


func _on_pack_mounted_bgm_retry(_pack_id: String) -> void:
	if not _pending_bgm_path.is_empty() and ResourceLoader.exists(_pending_bgm_path):
		var p_path := _pending_bgm_path
		var p_vol := _pending_volume_db
		var p_fade := _pending_fade_in
		_pending_bgm_path = ""
		play_bgm(p_path, p_vol, p_fade)


func _input(event: InputEvent) -> void:
	if OS.has_feature("web"):
		if event is InputEventMouseButton or event is InputEventScreenTouch or event is InputEventKey:
			if event.is_pressed():
				JavaScriptBridge.eval("""
					try {
						if (window.GodotAudio && window.GodotAudio.ctx && window.GodotAudio.ctx.state === 'suspended') {
							window.GodotAudio.ctx.resume();
						}
					} catch(e) {}
				""")
				if not _pending_bgm_path.is_empty() and ResourceLoader.exists(_pending_bgm_path):
					var p_path := _pending_bgm_path
					var p_vol := _pending_volume_db
					var p_fade := _pending_fade_in
					_pending_bgm_path = ""
					play_bgm(p_path, p_vol, p_fade)
				elif _bgm_player != null and not _bgm_player.playing and not _current_bgm_path.is_empty():
					_bgm_player.play()


## Reproduz a música de fundo (BGM) especificada.
## Se a faixa solicitada já estiver tocando, mantém a reprodução contínua sem interrupção.
## Permite fade_in_duration opcional (em segundos) para introdução suave/progressiva do volume.
func play_bgm(bgm_path: String, volume_db: float = -4.0, fade_in_duration: float = 0.0) -> void:
	if _current_bgm_path == bgm_path and _bgm_player != null and _bgm_player.playing:
		return

	if _bgm_player == null:
		_bgm_player = AudioStreamPlayer.new()
		_bgm_player.name = "GameSessionBGMPlayer"
		_bgm_player.process_mode = Node.PROCESS_MODE_ALWAYS
		_bgm_player.bus = &"Master"
		add_child(_bgm_player)

	if _bgm_tween != null and _bgm_tween.is_valid():
		_bgm_tween.kill()
		_bgm_tween = null

	if bgm_path.is_empty():
		stop_bgm()
		return

	if not ResourceLoader.exists(bgm_path):
		_pending_bgm_path = bgm_path
		_pending_volume_db = volume_db
		_pending_fade_in = fade_in_duration
		_init_bgm_pack_listener()
		stop_bgm()
		return

	_pending_bgm_path = ""
	var stream: AudioStream = load(bgm_path) as AudioStream
	if stream != null:
		if stream is AudioStreamMP3:
			(stream as AudioStreamMP3).loop = true
		_bgm_player.stream = stream
		if fade_in_duration > 0.0:
			_bgm_player.volume_db = -40.0
			_bgm_player.play()
			_bgm_tween = create_tween()
			_bgm_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
			_bgm_tween.tween_property(_bgm_player, "volume_db", volume_db, fade_in_duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		else:
			_bgm_player.volume_db = volume_db
			_bgm_player.play()
		_current_bgm_path = bgm_path


## Interrompe a reprodução de BGM atual
func stop_bgm() -> void:
	if _bgm_tween != null and _bgm_tween.is_valid():
		_bgm_tween.kill()
		_bgm_tween = null
	if _bgm_player != null and _bgm_player.playing:
		_bgm_player.stop()
	_current_bgm_path = ""


## Retorna o caminho da faixa de BGM em reprodução
func get_current_bgm_path() -> String:
	return _current_bgm_path
