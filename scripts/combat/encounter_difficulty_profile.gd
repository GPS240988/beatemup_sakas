class_name EncounterDifficultyProfile
extends Resource

## Perfil de Dificuldade de Encontro (FASE COMBATE ARCADE)
## Modela a progressão de desafio por mapa através de composição, agressividade e ritmo,
## sem depender exclusivamente de aumentos arbitrários de vida dos inimigos.

@export var profile_id: String = "map_1_default"
@export var map_level: int = 1

## Controle de Tokens e Pressão Simultânea
@export var max_attack_tokens: int = 2
@export var max_simultaneous_active_enemy_attacks: int = 1
@export var token_timeout_seconds: float = 4.0

## Modificadores de Agressividade e Comportamento
@export var aggression_factor: float = 1.0 # Multiplicador de prontidão para solicitar token
@export var attack_frequency_multiplier: float = 1.0 # Reduz intervalo entre ataques
@export var telegraph_duration_multiplier: float = 1.0 # 1.0 = normal, 0.85 = reação mais rápida

## Multiplicadores Físicos e de Combate
@export var health_multiplier: float = 1.0
@export var damage_multiplier: float = 1.0

## Distribuição de Arquétipos Recomendada
@export var allow_flankers: bool = false
@export var allow_aggressors: bool = false
@export var allow_tanks: bool = false

## Intervalo para reforços de onda
@export var reinforcement_delay: float = 3.0


## Construtores de perfis canônicos para cada um dos 4 mapas
static func create_for_map(map_index: int) -> Resource:
	var script_res := load("res://scripts/combat/encounter_difficulty_profile.gd") as GDScript
	var p: Resource = script_res.new()
	p.set("map_level", map_index)


	match map_index:
		1:
			# MAPA 1: A Locadora (Ensinar o sistema)
			p.profile_id = "map_1_teaching"
			p.max_attack_tokens = 1
			p.max_simultaneous_active_enemy_attacks = 1
			p.token_timeout_seconds = 4.5
			p.aggression_factor = 0.85
			p.attack_frequency_multiplier = 0.90
			p.telegraph_duration_multiplier = 1.0
			p.health_multiplier = 1.0
			p.damage_multiplier = 1.0
			p.allow_flankers = false
			p.allow_aggressors = false
			p.allow_tanks = false
			p.reinforcement_delay = 4.0
		2:
			# MAPA 2: A Rua / Avenida (Introduzir pressão e flanqueamento)
			p.profile_id = "map_2_pressure"
			p.max_attack_tokens = 2
			p.max_simultaneous_active_enemy_attacks = 1
			p.token_timeout_seconds = 4.0
			p.aggression_factor = 1.0
			p.attack_frequency_multiplier = 1.0
			p.telegraph_duration_multiplier = 0.95
			p.health_multiplier = 1.15
			p.damage_multiplier = 1.10
			p.allow_flankers = true
			p.allow_aggressors = false
			p.allow_tanks = false
			p.reinforcement_delay = 3.0
		3:
			# MAPA 3: O Beco / Bar (Testar domínio e posicionamento)
			p.profile_id = "map_3_challenge"
			p.max_attack_tokens = 2
			p.max_simultaneous_active_enemy_attacks = 1
			p.token_timeout_seconds = 3.5
			p.aggression_factor = 1.25
			p.attack_frequency_multiplier = 1.15
			p.telegraph_duration_multiplier = 0.90
			p.health_multiplier = 1.30
			p.damage_multiplier = 1.25
			p.allow_flankers = true
			p.allow_aggressors = true
			p.allow_tanks = false
			p.reinforcement_delay = 2.5
		4:
			# MAPA 4: O Covil do Chefe (Domínio completo e clímax)
			p.profile_id = "map_4_mastery"
			p.max_attack_tokens = 2
			p.max_simultaneous_active_enemy_attacks = 1
			p.token_timeout_seconds = 3.2
			p.aggression_factor = 1.40
			p.attack_frequency_multiplier = 1.25
			p.telegraph_duration_multiplier = 0.85
			p.health_multiplier = 1.50
			p.damage_multiplier = 1.35
			p.allow_flankers = true
			p.allow_aggressors = true
			p.allow_tanks = true
			p.reinforcement_delay = 2.0
		_:
			p.profile_id = "generic_profile"

	return p
