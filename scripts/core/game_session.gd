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

## Caminho da Fase 1 existente
const FIRST_LEVEL_PATH: String = "res://scenes/levels/test_street.tscn"

## Metadados e regras de desbloqueio de Personagens
const CHARACTERS: Dictionary = {
	"guilherme": {
		"name": "Guilherme",
		"title": "O Guerreiro de Sakas",
		"unlocked": true,
		"preview_path": "res://assets/sprites/characters/guilherme/idle.png"
	},
	"alessandro": {
		"name": "Alessandro",
		"title": "Cibernético",
		"unlocked": false,
		"preview_path": ""
	},
	"andre": {
		"name": "André",
		"title": "Especialista em Chutes",
		"unlocked": false,
		"preview_path": ""
	},
	"fernando": {
		"name": "Fernando",
		"title": "Lutador Brutal",
		"unlocked": false,
		"preview_path": ""
	},
	"gabriel": {
		"name": "Gabriel",
		"title": "Lâmina Veloz",
		"unlocked": false,
		"preview_path": ""
	},
	"juliana": {
		"name": "Juliana",
		"title": "Mestre da Fúria",
		"unlocked": false,
		"preview_path": ""
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
