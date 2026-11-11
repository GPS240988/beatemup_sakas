class_name MenuCharacterData
extends RefCounted

## Configuração de Dados dos Personagens no Menu Principal (Sakas Neo-16-bit)
## Suporta os 4 protagonistas: Guilherme, Gabriel, André e Juliana.
## Cada um com paleta de destaque, duração e parâmetros de idle independentes.

var id: String = ""
var display_name: String = ""
var accent_color: Color = Color(0.26, 0.96, 0.69, 1.0)
var texture_path: String = ""
var breathe_duration: float = 2.1
var breathe_y_offset: float = -3.0
var breathe_scale_y: float = 1.008
var shadow_scale_x_min: float = 0.76
var shadow_scale_x_max: float = 0.84
var shadow_alpha_min: float = 0.45
var shadow_alpha_max: float = 0.75
var aura_alpha_min: float = 0.08
var aura_alpha_max: float = 0.20
var scale_multiplier: float = 1.0
var enter_delay: float = 0.0
var flip_h: bool = false
var is_active: bool = true


static func create_guilherme() -> RefCounted:
	var data = (load("res://scripts/ui/menu_character_data.gd") as GDScript).new()
	data.id = "guilherme"
	data.display_name = "Guilherme"
	data.accent_color = Color(0.26, 0.96, 0.69, 1.0) # #42f5b0 striker
	data.texture_path = "res://assets/sprites/characters/guilherme/idle.png"
	data.breathe_duration = 2.1
	data.breathe_y_offset = -3.0
	data.breathe_scale_y = 1.008
	data.shadow_scale_x_min = 0.76
	data.shadow_scale_x_max = 0.84
	data.shadow_alpha_min = 0.50
	data.shadow_alpha_max = 0.80
	data.aura_alpha_min = 0.10
	data.aura_alpha_max = 0.22
	data.scale_multiplier = 1.0
	data.enter_delay = 0.0
	data.flip_h = false
	data.is_active = true
	return data


static func create_gabriel() -> RefCounted:
	var data = (load("res://scripts/ui/menu_character_data.gd") as GDScript).new()
	data.id = "gabriel"
	data.display_name = "Gabriel"
	data.accent_color = Color(1.0, 0.27, 0.37, 1.0) # #ff465f brawler
	data.texture_path = "res://assets/sprites/characters/gabriel/idle.png"
	data.breathe_duration = 1.85
	data.breathe_y_offset = -3.5
	data.breathe_scale_y = 1.010
	data.shadow_scale_x_min = 0.74
	data.shadow_scale_x_max = 0.86
	data.shadow_alpha_min = 0.50
	data.shadow_alpha_max = 0.80
	data.aura_alpha_min = 0.10
	data.aura_alpha_max = 0.22
	data.scale_multiplier = 1.03
	data.enter_delay = 0.18
	data.flip_h = false
	data.is_active = true # Inativo nesta fase, pronto para expansão
	return data


static func create_andre() -> RefCounted:
	var data = (load("res://scripts/ui/menu_character_data.gd") as GDScript).new()
	data.id = "andre"
	data.display_name = "André"
	data.accent_color = Color(1.0, 0.83, 0.28, 1.0) # #ffd447 tank
	data.texture_path = "res://assets/sprites/characters/andre/idle.png"
	data.breathe_duration = 2.5
	data.breathe_y_offset = -2.5
	data.breathe_scale_y = 1.006
	data.shadow_scale_x_min = 0.80
	data.shadow_scale_x_max = 0.92
	data.shadow_alpha_min = 0.55
	data.shadow_alpha_max = 0.85
	data.aura_alpha_min = 0.10
	data.aura_alpha_max = 0.22
	data.scale_multiplier = 1.10
	data.enter_delay = 0.36
	data.flip_h = false
	data.is_active = true # Inativo nesta fase, pronto para expansão
	return data


static func create_juliana() -> RefCounted:
	var data = (load("res://scripts/ui/menu_character_data.gd") as GDScript).new()
	data.id = "juliana"
	data.display_name = "Juliana"
	data.accent_color = Color(0.33, 0.78, 1.0, 1.0) # #55c7ff speed
	data.texture_path = "res://assets/sprites/characters/juliana/idle.png"
	data.breathe_duration = 1.55
	data.breathe_y_offset = -3.0
	data.breathe_scale_y = 1.009
	data.shadow_scale_x_min = 0.72
	data.shadow_scale_x_max = 0.82
	data.shadow_alpha_min = 0.45
	data.shadow_alpha_max = 0.75
	data.aura_alpha_min = 0.10
	data.aura_alpha_max = 0.22
	data.scale_multiplier = 0.96
	data.enter_delay = 0.54
	data.flip_h = false
	data.is_active = true # Inativo nesta fase, pronto para expansão
	return data
