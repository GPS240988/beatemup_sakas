class_name MenuCharacterData
extends RefCounted

## Configuração de Dados dos Personagens no Menu Principal (Sakas Neo-16-bit).
## Cada personagem mantém identidade, cor, escala relativa e ritmo próprio de idle.

var id: String = ""
var display_name: String = ""
var accent_color: Color = Color(0.26, 0.96, 0.69, 1.0)
var texture_path: String = ""
var breathe_duration: float = 2.1
var breathe_y_offset: float = 0.0 # Mantido por compatibilidade; não desloca mais os pés.
var breathe_scale_x: float = 1.002
var breathe_scale_y: float = 1.006
var shadow_scale_x_min: float = 0.985
var shadow_scale_x_max: float = 1.0
var shadow_alpha_min: float = 0.50
var shadow_alpha_max: float = 0.58
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
	data.accent_color = Color(0.26, 0.96, 0.69, 1.0)
	data.texture_path = "res://assets/sprites/characters/guilherme/idle.png"
	data.breathe_duration = 2.1
	data.breathe_scale_x = 1.002
	data.breathe_scale_y = 1.006
	data.shadow_scale_x_min = 0.985
	data.shadow_scale_x_max = 1.0
	data.shadow_alpha_min = 0.50
	data.shadow_alpha_max = 0.58
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
	data.accent_color = Color(1.0, 0.27, 0.37, 1.0)
	data.texture_path = "res://assets/sprites/characters/gabriel/idle.png"
	data.breathe_duration = 1.85
	data.breathe_scale_x = 1.003
	data.breathe_scale_y = 1.007
	data.shadow_scale_x_min = 0.985
	data.shadow_scale_x_max = 1.0
	data.shadow_alpha_min = 0.50
	data.shadow_alpha_max = 0.58
	data.aura_alpha_min = 0.10
	data.aura_alpha_max = 0.22
	data.scale_multiplier = 1.03
	data.enter_delay = 0.18
	data.flip_h = false
	data.is_active = true
	return data


static func create_andre() -> RefCounted:
	var data = (load("res://scripts/ui/menu_character_data.gd") as GDScript).new()
	data.id = "andre"
	data.display_name = "André"
	data.accent_color = Color(1.0, 0.83, 0.28, 1.0)
	data.texture_path = "res://assets/sprites/characters/andre/idle.png"
	data.breathe_duration = 2.5
	data.breathe_scale_x = 1.002
	data.breathe_scale_y = 1.005
	data.shadow_scale_x_min = 0.99
	data.shadow_scale_x_max = 1.005
	data.shadow_alpha_min = 0.52
	data.shadow_alpha_max = 0.60
	data.aura_alpha_min = 0.10
	data.aura_alpha_max = 0.22
	data.scale_multiplier = 1.10
	data.enter_delay = 0.36
	data.flip_h = false
	data.is_active = true
	return data


static func create_juliana() -> RefCounted:
	var data = (load("res://scripts/ui/menu_character_data.gd") as GDScript).new()
	data.id = "juliana"
	data.display_name = "Juliana"
	data.accent_color = Color(0.33, 0.78, 1.0, 1.0)
	data.texture_path = "res://assets/sprites/characters/juliana/idle.png"
	data.breathe_duration = 1.55
	data.breathe_scale_x = 1.003
	data.breathe_scale_y = 1.006
	data.shadow_scale_x_min = 0.98
	data.shadow_scale_x_max = 0.995
	data.shadow_alpha_min = 0.48
	data.shadow_alpha_max = 0.56
	data.aura_alpha_min = 0.10
	data.aura_alpha_max = 0.22
	data.scale_multiplier = 0.96
	data.enter_delay = 0.54
	data.flip_h = false
	data.is_active = true
	return data
