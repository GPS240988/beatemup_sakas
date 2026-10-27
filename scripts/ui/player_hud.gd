class_name PlayerHUD
extends Control

## Componente Oficial de HUD do Jogador Arcade (Projeto Sakas | Godot 4.x)
## Apresenta Portrait com Aura Elétrica de Special Ready, Nome em faixa inclinada,
## Barras de Vida e Especial formadas por 8 segmentos em paralelogramo sem extravasamento,
## Continues (inicial 1) e Contador Dinâmico de Combo.
## Em estrita conformidade com modelo_hud_vf.jpg e GAME_RULES.md (Sem Nível).

signal combo_visibility_changed(is_visible: bool)
signal special_ready_changed(is_ready: bool)

## Configurações de animação da barra de vida e dano
@export var damage_buffer_delay: float = 0.35
@export var damage_buffer_duration: float = 0.40
@export var hp_heal_duration: float = 0.18
@export var special_transition_duration: float = 0.25

## Referências aos nós visuais (Unique Name in Owner)
@onready var portrait_texture: TextureRect = %PortraitTexture
@onready var portrait_frame: TextureRect = %PortraitFrame
@onready var electric_aura: TextureRect = %ElectricAura

@onready var name_frame: TextureRect = %NameFrame
@onready var name_label: Label = %NameLabel
@onready var continue_label: Label = %ContinueLabel

@onready var hp_bar: SegmentedBar = %HpBar
@onready var hp_label: Label = %HpLabel

@onready var special_bar: SegmentedBar = %SpecialBar
@onready var special_label: Label = %SpecialLabel

@onready var combo_container: Control = %ComboContainer
@onready var combo_hits_label: Label = %ComboHitsLabel

## Compatibilidade com suítes de teste e referências herdadas
class BufferProxy:
	var _hud: PlayerHUD
	var value: float:
		get:
			return _hud._buffer_hp_val if _hud != null else 0.0
		set(v):
			if _hud != null:
				_hud._buffer_hp_val = v
				if _hud.hp_bar != null:
					_hud.hp_bar.buffer_value = v

var _buffer_proxy: BufferProxy = null

var hp_bar_current: SegmentedBar:
	get:
		return hp_bar

var hp_bar_buffer: Variant:
	get:
		if _buffer_proxy == null:
			_buffer_proxy = BufferProxy.new()
			_buffer_proxy._hud = self
		return _buffer_proxy

## Estado interno
var player_name: String = "GUILHERME"
var current_character_id: String = "guilherme"
var current_continues: int = 1
var current_combo_hits: int = 0

var current_hp: float = 100.0
var max_hp: float = 100.0
var _buffer_hp_val: float = 100.0

var current_special: float = 0.0
var max_special: float = 100.0
var is_special_ready: bool = false

var _damage_buffer_tween: Tween = null
var _hp_heal_tween: Tween = null
var _special_tween: Tween = null
var _aura_pulse_tween: Tween = null
var _combo_punch_tween: Tween = null

var _bound_player: Node = null
var _bound_health_component: Node = null
var _has_initialized_hp: bool = false


func _ready() -> void:
	if combo_container != null:
		combo_container.visible = false
	if electric_aura != null:
		electric_aura.visible = false

	_update_name_display()
	_update_continue_display()
	_load_character_profile_from_session()
	_update_hp_display(false)
	_update_special_display(false)


## Define o nome do personagem exibido na moldura
func set_player_name(value: String) -> void:
	player_name = value.to_upper()
	_update_name_display()


## Define a textura do retrato do herói
func set_portrait(texture: Texture2D) -> void:
	if portrait_texture != null:
		portrait_texture.texture = texture


## Define o número de continues restantes (padrão 1 em nova sessão)
func set_continues(value: int) -> void:
	current_continues = maxi(value, 0)
	_update_continue_display()


## Aplica o tema visual oficial de acordo com a identidade do herói
func set_character_theme(char_id: String) -> void:
	current_character_id = char_id.to_lower()
	
	# Cores oficiais da referência modelo_hud_vf.jpg:
	# Guilherme: Azul Elétrico (#00A2FF)
	# Gabriel: Verde Neon (#00FF66)
	# André: Amarelo/Laranja (#FFCC00)
	# Juliana: Magenta/Roxo (#FF00CC)
	var theme_colors: Dictionary = {
		"guilherme": {
			"primary": Color(0.0, 0.65, 1.0, 1.0),
			"highlight": Color(0.60, 0.90, 1.0, 0.90),
			"shadow": Color(0.0, 0.30, 0.65, 0.80),
			"frame": Color(0.0, 0.64, 1.0, 1.0)
		},
		"gabriel": {
			"primary": Color(0.0, 0.95, 0.38, 1.0),
			"highlight": Color(0.70, 1.0, 0.80, 0.90),
			"shadow": Color(0.0, 0.45, 0.15, 0.80),
			"frame": Color(0.0, 1.0, 0.40, 1.0)
		},
		"andre": {
			"primary": Color(1.0, 0.80, 0.0, 1.0),
			"highlight": Color(1.0, 0.95, 0.60, 0.90),
			"shadow": Color(0.55, 0.40, 0.0, 0.80),
			"frame": Color(1.0, 0.78, 0.0, 1.0)
		},
		"juliana": {
			"primary": Color(1.0, 0.0, 0.80, 1.0),
			"highlight": Color(1.0, 0.70, 0.95, 0.90),
			"shadow": Color(0.55, 0.0, 0.45, 0.80),
			"frame": Color(1.0, 0.0, 0.80, 1.0)
		}
	}
	
	var palette = theme_colors.get(current_character_id, theme_colors["guilherme"])
	
	# Aplica moldura azul neon arcade e segmentos dourados/amarelos da referência 2
	if hp_bar != null:
		hp_bar.frame_color = Color(0.0, 0.65, 1.0, 1.0)
		hp_bar.filled_color = Color(1.0, 0.72, 0.05, 1.0)
		hp_bar.filled_highlight = Color(1.0, 0.90, 0.50, 0.90)
		hp_bar.filled_shadow = Color(0.70, 0.45, 0.0, 0.80)
		hp_bar.queue_redraw()
	
	# Configura a barra de Especial com a cor temática do herói (azul elétrico para Guilherme)
	if special_bar != null:
		special_bar.set_theme_colors(palette["primary"], palette["highlight"], palette["shadow"], palette["frame"])
	
	# Carrega banner com o nome para compatibilidade com a suite de testes
	var banner_path: String = "res://assets/ui/hud/hud_name_frame_%s.png" % current_character_id
	if ResourceLoader.exists(banner_path) and name_frame != null:
		var tex = load(banner_path) as Texture2D
		if tex != null:
			name_frame.texture = tex
	
	# Carrega retrato correspondente
	var portrait_path: String = "res://assets/ui/hud/portraits/portrait_%s.png" % current_character_id
	if ResourceLoader.exists(portrait_path):
		var p_tex = load(portrait_path) as Texture2D
		if p_tex != null:
			set_portrait(p_tex)


## Atualiza os valores de vida e animação de Damage Buffer
func set_hp(new_current: float, new_max: float, immediate: bool = false) -> void:
	new_max = maxf(new_max, 1.0)
	new_current = clampf(new_current, 0.0, new_max)
	
	var is_first_init: bool = not _has_initialized_hp or immediate
	_has_initialized_hp = true
	
	var is_damage: bool = not is_first_init and new_current < current_hp
	var is_heal: bool = not is_first_init and new_current > current_hp
	
	current_hp = new_current
	max_hp = new_max
	
	if hp_bar == null:
		_update_hp_label()
		return
	
	hp_bar.max_value = max_hp
	
	if is_first_init:
		if _damage_buffer_tween != null and _damage_buffer_tween.is_valid():
			_damage_buffer_tween.kill()
		if _hp_heal_tween != null and _hp_heal_tween.is_valid():
			_hp_heal_tween.kill()
		_buffer_hp_val = current_hp
		hp_bar.value = current_hp
		hp_bar.buffer_value = current_hp
	elif is_damage:
		# 1. Segmentos principais caem imediatamente
		hp_bar.value = current_hp
		
		# 2. Interrompe animação anterior
		if _damage_buffer_tween != null and _damage_buffer_tween.is_valid():
			_damage_buffer_tween.kill()
		
		# 3. Buffer aguarda delay e depois reduz suavemente
		_damage_buffer_tween = create_tween()
		_damage_buffer_tween.tween_interval(damage_buffer_delay)
		_damage_buffer_tween.tween_method(
			func(val: float):
				_buffer_hp_val = val
				hp_bar.buffer_value = val,
			_buffer_hp_val,
			current_hp,
			damage_buffer_duration
		).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	elif is_heal:
		if _hp_heal_tween != null and _hp_heal_tween.is_valid():
			_hp_heal_tween.kill()
		
		_hp_heal_tween = create_tween().set_parallel(true)
		_hp_heal_tween.tween_property(hp_bar, "value", current_hp, hp_heal_duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		_hp_heal_tween.tween_method(
			func(val: float):
				_buffer_hp_val = val
				hp_bar.buffer_value = val,
			_buffer_hp_val,
			current_hp,
			hp_heal_duration
		).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	else:
		_buffer_hp_val = current_hp
		hp_bar.value = current_hp
		hp_bar.buffer_value = current_hp
	
	_update_hp_label()


## Atualiza a barra de Special e dispara estado READY com efeito elétrico ao atingir 100%
func set_special(new_current: float, new_max: float = 100.0, immediate: bool = false) -> void:
	max_special = maxf(new_max, 1.0)
	current_special = clampf(new_current, 0.0, max_special)
	
	if special_bar != null:
		special_bar.max_value = max_special
		if _special_tween != null and _special_tween.is_valid():
			_special_tween.kill()
		if immediate:
			special_bar.value = current_special
		else:
			_special_tween = create_tween()
			_special_tween.tween_property(special_bar, "value", current_special, special_transition_duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	
	_update_special_label()
	
	# Avalia estado READY (current >= max)
	var ready_now: bool = current_special >= max_special
	if ready_now != is_special_ready:
		is_special_ready = ready_now
		_apply_special_ready_effect(is_special_ready)
		special_ready_changed.emit(is_special_ready)


## Atualiza o contador de hits de combo com animação arcade
func set_combo_hits(hits: int) -> void:
	current_combo_hits = maxi(hits, 0)
	
	if combo_container == null:
		return
	
	if current_combo_hits <= 0:
		combo_container.visible = false
		combo_visibility_changed.emit(false)
		return
	
	combo_container.visible = true
	combo_visibility_changed.emit(true)
	
	if combo_hits_label != null:
		combo_hits_label.text = "%d HITS" % current_combo_hits
	
	if _combo_punch_tween != null and _combo_punch_tween.is_valid():
		_combo_punch_tween.kill()
	
	_combo_punch_tween = create_tween()
	combo_container.scale = Vector2(1.25, 1.25)
	_combo_punch_tween.tween_property(combo_container, "scale", Vector2.ONE, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## Conecta a HUD ao controlador do jogador
func bind_player(player_node: Node) -> void:
	if player_node == null or not is_instance_valid(player_node):
		return
	
	unbind_player()
	_bound_player = player_node
	
	# 1. HealthComponent
	var health_comp = player_node.get_node_or_null("HealthComponent")
	if health_comp != null and health_comp.has_signal("health_changed"):
		_bound_health_component = health_comp
		if not health_comp.health_changed.is_connected(_on_player_health_changed):
			health_comp.health_changed.connect(_on_player_health_changed)
		set_hp(health_comp.current_health, health_comp.max_health)
	elif "health" in player_node and "max_health" in player_node:
		set_hp(float(player_node.health), float(player_node.max_health))
	
	# 2. Special
	if player_node.has_signal("special_changed"):
		if not player_node.is_connected("special_changed", _on_player_special_changed):
			player_node.connect("special_changed", _on_player_special_changed)
	if "current_special" in player_node and "max_special" in player_node:
		set_special(float(player_node.current_special), float(player_node.max_special), true)
	
	# 3. Combo
	if player_node.has_signal("combo_changed"):
		if not player_node.is_connected("combo_changed", _on_player_combo_changed):
			player_node.connect("combo_changed", _on_player_combo_changed)
	
	# 4. Continues / Respawn Arcade
	if player_node.has_signal("player_respawned"):
		if not player_node.is_connected("player_respawned", _on_player_respawned):
			player_node.connect("player_respawned", _on_player_respawned)
	if "current_continues" in player_node:
		set_continues(int(player_node.current_continues))
	
	_load_character_profile_from_session()


func unbind_player() -> void:
	if _bound_health_component != null and is_instance_valid(_bound_health_component):
		if _bound_health_component.is_connected("health_changed", _on_player_health_changed):
			_bound_health_component.disconnect("health_changed", _on_player_health_changed)
	_bound_health_component = null
	
	if _bound_player != null and is_instance_valid(_bound_player):
		if _bound_player.has_signal("special_changed") and _bound_player.is_connected("special_changed", _on_player_special_changed):
			_bound_player.disconnect("special_changed", _on_player_special_changed)
		if _bound_player.has_signal("combo_changed") and _bound_player.is_connected("combo_changed", _on_player_combo_changed):
			_bound_player.disconnect("combo_changed", _on_player_combo_changed)
		if _bound_player.has_signal("player_respawned") and _bound_player.is_connected("player_respawned", _on_player_respawned):
			_bound_player.disconnect("player_respawned", _on_player_respawned)
	_bound_player = null


func _load_character_profile_from_session() -> void:
	var session = get_node_or_null("/root/GameSession")
	var char_id: String = "guilherme"
	if session != null and "selected_character_id" in session:
		char_id = str(session.selected_character_id).to_lower()
	
	if session != null and "current_continues" in session:
		set_continues(int(session.current_continues))
	
	var names: Dictionary = {
		"guilherme": "GUILHERME",
		"gabriel": "GABRIEL",
		"andre": "ANDRÉ",
		"juliana": "JULIANA"
	}
	set_player_name(names.get(char_id, "GUILHERME"))
	set_character_theme(char_id)


func _on_player_respawned(continues_left: int) -> void:
	set_continues(continues_left)


func _on_player_health_changed(cur: float, max_val: float) -> void:
	set_hp(cur, max_val)


func _on_player_special_changed(cur: float, max_val: float) -> void:
	var immediate: bool = (cur <= 0.0 or cur >= max_val)
	set_special(cur, max_val, immediate)


func _on_player_combo_changed(hits: int) -> void:
	set_combo_hits(hits)


func _update_name_display() -> void:
	if name_label != null:
		name_label.text = player_name
		name_label.visible = true


func _update_continue_display() -> void:
	if continue_label != null:
		continue_label.text = "%d" % current_continues


func _update_hp_display(_animate: bool) -> void:
	if hp_bar != null:
		hp_bar.max_value = max_hp
		hp_bar.value = current_hp
		hp_bar.buffer_value = current_hp
	_update_hp_label()


func _update_hp_label() -> void:
	if hp_label != null:
		hp_label.text = "%d / %d" % [int(current_hp), int(max_hp)]
		hp_label.visible = false


func _update_special_display(_animate: bool) -> void:
	if special_bar != null:
		special_bar.max_value = max_special
		special_bar.value = current_special
	_update_special_label()


func _update_special_label() -> void:
	if special_label != null:
		special_label.text = "%d / %d" % [int(current_special), int(max_special)]
		special_label.visible = false


func _apply_special_ready_effect(ready: bool) -> void:
	if _aura_pulse_tween != null and _aura_pulse_tween.is_valid():
		_aura_pulse_tween.kill()
	
	if electric_aura != null:
		electric_aura.visible = ready
		if ready:
			# Animação pulsante da aura elétrica azul ao redor do retrato
			_aura_pulse_tween = create_tween().set_loops()
			_aura_pulse_tween.tween_property(electric_aura, "modulate", Color(1.8, 2.2, 3.0, 1.0), 0.35).set_trans(Tween.TRANS_SINE)
			_aura_pulse_tween.tween_property(electric_aura, "modulate", Color(0.8, 1.2, 1.8, 0.75), 0.35).set_trans(Tween.TRANS_SINE)
		else:
			electric_aura.modulate = Color.WHITE
