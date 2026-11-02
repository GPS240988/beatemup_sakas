class_name CenterHUD
extends Control

## Componente Central da HUD Arcade (Fase e Cronômetro)
## Em estrita conformidade com a imagem de referência 2 (referência 2.webp).
## Exibe a fase atual (ex: FASE 1-1) e o cronômetro digital arcade em contagem decrescente.

@onready var stage_label: Label = %StageLabel
@onready var timer_label: Label = %TimerLabel
@onready var plaque: TextureRect = %Plaque

@export var initial_seconds: int = 157 # 02:37 padrão da referência 2
@export var count_down: bool = true

var _remaining_seconds: float = 157.0
var _is_running: bool = true


func _ready() -> void:
	_remaining_seconds = float(initial_seconds)
	_update_timer_display()


func _process(delta: float) -> void:
	if not _is_running:
		return
	
	if count_down:
		_remaining_seconds = maxf(0.0, _remaining_seconds - delta)
	else:
		_remaining_seconds += delta
	
	_update_timer_display()


func set_stage_text(text: String) -> void:
	if stage_label != null:
		stage_label.text = text.to_upper()


func set_stage_index(map_index: int, sub_index: int = 1) -> void:
	set_stage_text("FASE %d-%d" % [map_index, sub_index])


func set_stage(stage_num: int, section_num: int = 1) -> void:
	set_stage_index(stage_num, section_num)


func set_time_seconds(seconds: int) -> void:
	_remaining_seconds = float(maxi(0, seconds))
	_update_timer_display()


func start_timer() -> void:
	_is_running = true


func stop_timer() -> void:
	_is_running = false


func _update_timer_display() -> void:
	if timer_label == null:
		return
	
	var total_sec: int = int(_remaining_seconds)
	var minutes: int = total_sec / 60
	var seconds: int = total_sec % 60
	timer_label.text = "%02d:%02d" % [minutes, seconds]
