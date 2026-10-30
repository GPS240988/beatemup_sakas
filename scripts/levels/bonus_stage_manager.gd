class_name BonusStageManager
extends Node

## Gerenciador Central da Fase Bônus — Garagem (Projeto Sakas)
## Centraliza:
## - Cronômetro global de 40 segundos.
## - Acompanhamento da destruição dos 2 veículos (Fiesta Laranja e Escort Azul).
## - Concessão idempotente de +1 continue por carro destruído (máx +2).
## - Persistência em GameSession e atualização em tempo real no PlayerHUD.
## - Encerramento formal ao destruir ambos ou quando o tempo expira.

signal timer_updated(time_remaining: float)
signal car_destroyed(car_node: Node, reward_continue_granted: bool)
signal bonus_stage_completed(cars_destroyed_count: int, bonus_continues_awarded: int)

@export var round_duration: float = 40.0
@export var orange_car_path: NodePath = NodePath("../World/Props/Vehicles/CarOrange")
@export var blue_car_path: NodePath = NodePath("../World/Props/Vehicles/CarBlue")

var time_left: float = 40.0
var is_active: bool = false
var is_completed: bool = false

var orange_car_destroyed: bool = false
var blue_car_destroyed: bool = false
var orange_continue_awarded: bool = false
var blue_continue_awarded: bool = false

var cars_destroyed_count: int = 0
var total_continues_awarded: int = 0

var _orange_car: Node = null
var _blue_car: Node = null
var _hud: Node = null
var _level_root: BaseLevel = null


func _ready() -> void:
	time_left = round_duration
	_level_root = get_parent() as BaseLevel
	
	call_deferred("_initialize_bonus_stage")


func _initialize_bonus_stage() -> void:
	_orange_car = get_node_or_null(orange_car_path)
	_blue_car = get_node_or_null(blue_car_path)
	
	if _orange_car != null and _orange_car.has_signal("prop_destroyed"):
		_orange_car.connect("prop_destroyed", Callable(self, "_on_orange_car_destroyed"))
	
	if _blue_car != null and _blue_car.has_signal("prop_destroyed"):
		_blue_car.connect("prop_destroyed", Callable(self, "_on_blue_car_destroyed"))
	
	_hud = get_parent().get_node_or_null("PrototypeHud")
	if _hud != null:
		var center_hud = _hud.get_node_or_null("%CenterHUD")
		if center_hud != null and center_hud.has_method("set_time_seconds"):
			center_hud.set_time_seconds(int(time_left))
			center_hud.set_stage_text("BÔNUS - 0/2")
	
	start_round()


func start_round() -> void:
	if is_active or is_completed:
		return
	is_active = true
	time_left = round_duration
	
	if _hud != null:
		var center_hud = _hud.get_node_or_null("%CenterHUD")
		if center_hud != null:
			center_hud.set_time_seconds(int(time_left))
			center_hud.start_timer()


func _process(delta: float) -> void:
	if not is_active or is_completed:
		return
	
	# Respeita o estado de pausa do jogo
	if get_tree() != null and get_tree().paused:
		return
	
	time_left = maxf(0.0, time_left - delta)
	timer_updated.emit(time_left)
	
	if _hud != null:
		var center_hud = _hud.get_node_or_null("%CenterHUD")
		if center_hud != null and center_hud.has_method("set_time_seconds"):
			center_hud.set_time_seconds(int(time_left))
	
	if time_left <= 0.0:
		_finish_round(false)


func _on_orange_car_destroyed() -> void:
	if orange_car_destroyed:
		return
	orange_car_destroyed = true
	_process_car_destruction(_orange_car, "orange")


func _on_blue_car_destroyed() -> void:
	if blue_car_destroyed:
		return
	blue_car_destroyed = true
	_process_car_destruction(_blue_car, "blue")


func _process_car_destruction(car: Node, car_id: String) -> void:
	if is_completed:
		return
	
	var continue_granted: bool = false
	if car_id == "orange" and not orange_continue_awarded:
		orange_continue_awarded = true
		continue_granted = true
	elif car_id == "blue" and not blue_continue_awarded:
		blue_continue_awarded = true
		continue_granted = true
	
	if continue_granted:
		total_continues_awarded += 1
		cars_destroyed_count += 1
		_grant_continue_reward()
	
	_update_hud_display()
	car_destroyed.emit(car, continue_granted)
	
	# Se ambos os carros foram destruídos, finaliza a rodada imediatamente
	if orange_car_destroyed and blue_car_destroyed:
		_finish_round(true)


func _grant_continue_reward() -> void:
	# 1. Atualiza GameSession global
	var game_session = get_node_or_null("/root/GameSession")
	if game_session == null and get_tree() != null:
		game_session = get_tree().root.get_node_or_null("GameSession")
	
	var new_total: int = 1
	if game_session != null and "current_continues" in game_session:
		game_session.current_continues += 1
		new_total = int(game_session.current_continues)
	
	# 2. Atualiza PlayerController se houver instância
	var player = get_tree().get_first_node_in_group("player") if get_tree() != null else null
	if player != null and "current_continues" in player:
		player.current_continues += 1
	
	# 3. Atualiza PlayerHUD visualmente
	if _hud != null:
		var player_hud = _hud.get_node_or_null("%PlayerHUD")
		if player_hud != null and player_hud.has_method("set_continues"):
			player_hud.set_continues(new_total)


func _update_hud_display() -> void:
	if _hud != null:
		var center_hud = _hud.get_node_or_null("%CenterHUD")
		if center_hud != null and center_hud.has_method("set_stage_text"):
			center_hud.set_stage_text("BÔNUS - %d/2" % cars_destroyed_count)


func _finish_round(both_destroyed: bool) -> void:
	if is_completed:
		return
	is_completed = true
	is_active = false
	
	if _hud != null:
		var center_hud = _hud.get_node_or_null("%CenterHUD")
		if center_hud != null and center_hud.has_method("stop_timer"):
			center_hud.stop_timer()
	
	# Desativa danos adicionais nos carros após o término da rodada
	if _orange_car != null and is_instance_valid(_orange_car) and _orange_car is DestructibleProp:
		(_orange_car as DestructibleProp).is_destructible = false
	if _blue_car != null and is_instance_valid(_blue_car) and _blue_car is DestructibleProp:
		(_blue_car as DestructibleProp).is_destructible = false
	
	bonus_stage_completed.emit(cars_destroyed_count, total_continues_awarded)
	
	# Transição automática para os créditos após breve pausa dramática arcade
	if _level_root != null:
		var timer := get_tree().create_timer(3.0)
		timer.timeout.connect(func():
			if _level_root != null and is_instance_valid(_level_root):
				_level_root._advance_to_next_map()
		)

