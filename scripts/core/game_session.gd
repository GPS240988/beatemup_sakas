class_name GameSessionClass
extends Node

## Gerenciador de sessão e estado de início de jogo (Autoload: GameSession)
## Preserva o personagem, skin e dificuldade selecionados pelo jogador.

signal character_selected(character_id: String)
signal skin_selected(skin_id: String)
signal difficulty_selected(difficulty_id: String)
signal game_started(character_id: String, skin_id: String, difficulty_id: String)

## Identificadores de estado da sessão
var selected_character_id: String = "guilherme"
var selected_skin_id: String = "palmeirense"
var difficulty_id: String = ""

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
		"enemy_health_mult": 1.4,
		"enemy_damage_mult": 1.3
	}
}


func _ready() -> void:
	# Inicialização padrão da sessão
	reset_session()


## Redefine os dados da sessão para os padrões iniciais
func reset_session() -> void:
	selected_character_id = "guilherme"
	selected_skin_id = "palmeirense"
	difficulty_id = ""


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
