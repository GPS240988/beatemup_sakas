class_name BossAlessandroEnhanced
extends "res://scripts/actors/boss_alessandro.gd"

## Extensão pontual do chefe: segunda carne após o primeiro drop e esquiva
## reativa à voadora do jogador. A IA base permanece como autoridade principal.

const GabrielMeatHintDialogueClass = preload(
	"res://scripts/events/map4_meat_hint_dialogue.gd"
)
const GabrielSecondMeatDialogueClass = preload(
	"res://scripts/events/map4_second_meat_dialogue.gd"
)
const LoroTargetClass = preload("res://scripts/events/map4_loro_target.gd")

const SECOND_MEAT_DROP_DELAY: float = 8.0
const PLAYER_MELEE_EVADE_CHANCE: float = 0.70
const POST_EVASION_COUNTER_WINDOW: float = 0.75
const FAST_APPROACH_MIN_SPEED: float = 210.0
const MAP_LEFT_WALL_X: float = 80.0
const MAP_RIGHT_WALL_X: float = 1910.0
const CORNERED_LEFT_LIMIT_X: float = 145.0
const CORNERED_RIGHT_LIMIT_X: float = 1845.0
const CORNERED_PLAYER_RANGE_X: float = 150.0
const CORNERED_DEPTH_TOLERANCE: float = 56.0
const CORNERED_COMBO_REQUIRED_HITS: int = 4
const CORNERED_COMBO_WINDOW: float = 2.0
const LORO_REPEAT_DELAY: float = 8.0
const LORO_STUN_DURATION: float = 5.0
const POST_LORO_ESCAPE_DURATION: float = 1.35
const POST_LORO_ESCAPE_SPEED: float = 430.0

var _second_meat_timer: float = -1.0
var _second_meat_dropped: bool = false
var _first_meat_consumed: bool = false
var _post_evasion_counter_timer: float = 0.0
var _cornered_combo_hits: int = 0
var _cornered_combo_timer: float = 0.0
var _cornered_evasion_pending: bool = false
var _second_meat_hint_pending: bool = false
var _loro_target: Map4LoroTarget = null
var _loro_intro_active: bool = false
var _loro_intro_hold: bool = false
var _second_meat_dialogue_pending: bool = false
var _resume_meat_seeking_after_escape: bool = false
var _loro_stun_timer: float = 0.0
var _loro_repeat_timer: float = -1.0
var _loro_stun_visual: Label = null
var _post_loro_escape_timer: float = 0.0
var _post_loro_escape_direction: Vector2 = Vector2.ZERO
var _meat_eating_panel: PanelContainer = null
var _meat_eating_bar: ProgressBar = null
var _stun_hurtbox_shape: CollisionShape2D = null
var _original_hurtbox_shape: Shape2D = null
var _original_hurtbox_shape_position: Vector2 = Vector2.ZERO
var _impact_zones: ImpactZones = null
var _original_impact_zone_bounds: Array[float] = []


func _ready() -> void:
	super._ready()
	_cache_loro_stun_hurtbox()
	# A cadência anterior de 4,25s deixava longos intervalos entre as salvas.
	_truffle_cooldown = 2.5


func _physics_process(delta: float) -> void:
	# Os relógios usam tempo de gameplay e congelam durante hitstop.
	if not is_in_hitstop():
		_process_second_meat_timer(delta)
		_post_evasion_counter_timer = maxf(0.0, _post_evasion_counter_timer - delta)
		_update_cornered_combo_window(delta)
		_process_loro_timers(delta)

	if _loro_stun_timer > 0.0:
		_process_loro_stun(delta)
		return
	if _loro_intro_hold:
		velocity = Vector2.ZERO
		move_and_slide()
		return
	if _post_loro_escape_timer > 0.0:
		_process_post_loro_escape(delta)
		return
	super._physics_process(delta)
	_update_meat_eating_indicator()


func _process_second_meat_timer(delta: float) -> void:
	if _second_meat_timer < 0.0 or _second_meat_dropped:
		return
	if current_state == State.DEAD or health_component == null or health_component.is_dead:
		_second_meat_timer = -1.0
		return

	_second_meat_timer = maxf(0.0, _second_meat_timer - delta)
	if is_zero_approx(_second_meat_timer):
		_second_meat_timer = -1.0
		_drop_second_healing_meat()


func _drop_second_healing_meat() -> void:
	if _second_meat_dropped or current_state == State.DEAD:
		return

	var world_root: Node = get_tree().current_scene
	var destructibles: Node = world_root.find_child("Destructibles", true, false) if world_root != null else null
	if destructibles == null:
		destructibles = get_parent()
	if destructibles == null:
		push_warning("BossAlessandro: container Destructibles não encontrado para a segunda carne.")
		return

	var meat: DestructibleProp = MEAT_SCENE.instantiate() as DestructibleProp
	if meat == null:
		push_warning("BossAlessandro: não foi possível instanciar a segunda carne de cura.")
		return

	# A segunda porção nasce no extremo oposto da arena. A distância força
	# Alessandro a atravessar o mapa e dá ao jogador uma janela real para destruí-la.
	var drop_x: float = 180.0 if global_position.x >= 1025.0 else 1800.0
	var drop_position := Vector2(
		drop_x,
		clampf(global_position.y, 545.0, 735.0)
	)
	destructibles.add_child(meat)
	meat.global_position = drop_position
	meat.prop_destroyed.connect(_on_healing_meat_destroyed.bind(meat), CONNECT_ONE_SHOT)
	_meat_instances.append(meat)
	_second_meat_dropped = true
	CombatFeedback.spawn_dust(destructibles, drop_position + Vector2(0.0, 2.0), 0.72)

	# A queda da segunda carne interrompe temporariamente a fase inteira.
	# Alessandro só começa a perseguição depois que o jogador confirma a dica.
	_release_combat_resources()
	if melee_attack != null:
		melee_attack.cancel_attack()
	if punch_visual != null:
		punch_visual.visible = false
	_special_behavior = SpecialBehavior.NONE
	_special_timer = 0.0
	_truffle_shot_timer = 0.0
	_truffles_remaining = 0
	velocity = Vector2.ZERO
	if current_state not in [State.DEAD, State.FALL, State.DOWNED, State.GETUP]:
		current_state = State.FLANKING
	if anim_sprite != null and current_state == State.FLANKING:
		_play_anim("idle")

	# Sequência bloqueante: primeiro Gabriel orienta a destruir a carne;
	# depois apresenta a dica do Loro. O papagaio só grita após a segunda confirmação.
	_loro_intro_active = true
	_loro_intro_hold = true
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().paused = true
	_ensure_loro_target()
	if not _show_gabriel_second_meat_dialogue() and not _show_gabriel_meat_hint():
		_finish_second_meat_dialogue_sequence()


func _ensure_loro_target() -> void:
	if _loro_target != null and is_instance_valid(_loro_target):
		return
	var scene_root: Node = get_tree().current_scene
	if scene_root == null:
		return
	var loro_sprite: AnimatedSprite2D = scene_root.find_child("loro", true, false) as AnimatedSprite2D
	if loro_sprite == null:
		push_warning("BossAlessandro: sprite do Loro não encontrado no Mapa 4.")
		return
	var loro_anchor: Node2D = loro_sprite.get_parent() as Node2D
	if loro_anchor == null:
		return
	_loro_target = LoroTargetClass.new() as Map4LoroTarget
	if _loro_target == null:
		return
	_loro_target.name = "Map4LoroTarget"
	_loro_target.process_mode = Node.PROCESS_MODE_ALWAYS
	scene_root.add_child(_loro_target)
	_loro_target.configure(loro_sprite, loro_anchor)
	_loro_target.hit_by_player.connect(_on_loro_hit)


func _process_loro_timers(delta: float) -> void:
	if current_state == State.DEAD or health_component == null or health_component.is_dead:
		_loro_intro_active = false
		_loro_repeat_timer = -1.0
		if _loro_target != null and is_instance_valid(_loro_target):
			_loro_target.stop_shouting()
		return

	# O grito permanece ativo até o jogador atingir o Loro; o ciclo é
	# rearmado a cada oito segundos enquanto Alessandro continuar vivo.
	if _loro_repeat_timer > 0.0 and _loro_stun_timer <= 0.0 and not _loro_intro_active:
		_loro_repeat_timer = maxf(0.0, _loro_repeat_timer - delta)
		if _loro_repeat_timer <= 0.0:
			_start_loro_shout_cycle()


func _on_loro_hit() -> void:
	if _loro_stun_timer > 0.0 or current_state == State.DEAD:
		return
	_loro_repeat_timer = -1.0
	# A busca pela segunda carne pode ser interrompida pela dica do Loro;
	# durante o consumo, porém, a animação e a recuperação permanecem protegidas.
	if _special_behavior == SpecialBehavior.MEAT_EATING:
		_loro_repeat_timer = LORO_REPEAT_DELAY
		return
	if _loro_intro_active or _second_meat_dialogue_pending or _second_meat_hint_pending:
		return
	_start_loro_stun()


func _start_loro_stun() -> void:
	var was_seeking_meat: bool = _special_behavior == SpecialBehavior.MEAT_SEEKING
	_resume_meat_seeking_after_escape = was_seeking_meat and not _meat_instances.is_empty()
	_release_combat_resources()
	_clear_active_truffles()
	if melee_attack != null:
		melee_attack.cancel_attack()
	if punch_visual != null:
		punch_visual.visible = false
	_special_behavior = SpecialBehavior.NONE
	_special_timer = 0.0
	_truffle_shot_timer = 0.0
	_truffles_remaining = 0
	if not was_seeking_meat:
		_meat_target = null
		_meat_eating_target = null
		_meat_dialogue_started = false
		_meat_chatter_timer = 0.0
	velocity = Vector2.ZERO
	if current_state != State.DEAD:
		current_state = State.FLANKING
	_loro_stun_timer = LORO_STUN_DURATION
	_expand_loro_stun_hurtbox()
	if anim_sprite != null:
		anim_sprite.speed_scale = 0.65
		_play_anim("hurt")
	_spawn_falling_hearts()
	_show_loro_dizzy_visual()


func _process_loro_stun(delta: float) -> void:
	# A IA base não roda durante a tontura; portanto, este estado precisa
	# consumir o hitstop local por conta própria para não congelar o timer.
	if _hitstop_timer > 0.0:
		_hitstop_timer = maxf(0.0, _hitstop_timer - delta)
		if _hitstop_timer <= 0.0 and anim_sprite != null:
			anim_sprite.speed_scale = _saved_anim_speed_scale
		return
	_loro_stun_timer = maxf(0.0, _loro_stun_timer - delta)
	velocity = Vector2.ZERO
	move_and_slide()
	if _loro_stun_timer <= 0.0:
		_finish_loro_stun()


func _finish_loro_stun() -> void:
	_loro_stun_timer = 0.0
	_restore_loro_stun_hurtbox()
	if _loro_stun_visual != null and is_instance_valid(_loro_stun_visual):
		_loro_stun_visual.queue_free()
	_loro_stun_visual = null
	if current_state == State.DEAD:
		return
	_special_behavior = SpecialBehavior.NONE
	current_state = State.FLANKING
	velocity = Vector2.ZERO
	_attack_timer = maxf(_attack_timer, 1.25)
	_truffle_cooldown = maxf(_truffle_cooldown, 1.5)
	_start_post_loro_escape()
	if anim_sprite != null:
		anim_sprite.speed_scale = 1.0
		if _post_loro_escape_timer > 0.0:
			_play_anim("walk")
		else:
			_play_anim("idle")
	# O próximo ciclo começa oito segundos após a recuperação da tontura.
	_loro_repeat_timer = LORO_REPEAT_DELAY


func _spawn_falling_hearts() -> void:
	var scene_root: Node = get_tree().current_scene
	if scene_root == null:
		return
	for _heart_index: int in range(12):
		var heart := Label.new()
		heart.text = "♥"
		heart.add_theme_font_size_override("font_size", randi_range(25, 39))
		heart.add_theme_color_override("font_color", Color(1.0, 0.28, 0.58, 1.0))
		heart.add_theme_color_override("font_outline_color", Color(0.16, 0.025, 0.08, 1.0))
		heart.add_theme_constant_override("outline_size", 4)
		heart.size = Vector2(48.0, 48.0)
		heart.z_index = 150
		scene_root.add_child(heart)
		var x_offset: float = randf_range(-135.0, 135.0)
		heart.position = global_position + Vector2(x_offset, -330.0 - randf_range(0.0, 170.0))
		var landing := global_position + Vector2(x_offset * 0.35, -115.0)
		var fall_tween: Tween = heart.create_tween()
		fall_tween.tween_property(heart, "position", landing, randf_range(0.75, 1.15)).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
		fall_tween.parallel().tween_property(heart, "rotation", randf_range(-0.45, 0.45), 0.9)
		fall_tween.parallel().tween_property(heart, "modulate:a", 0.0, 0.35).set_delay(0.75)
		fall_tween.finished.connect(heart.queue_free)


func _show_loro_dizzy_visual() -> void:
	if _loro_stun_visual != null and is_instance_valid(_loro_stun_visual):
		_loro_stun_visual.queue_free()
	_loro_stun_visual = Label.new()
	_loro_stun_visual.name = "LoroDizzyStars"
	_loro_stun_visual.text = "✦   ✦   ✦"
	_loro_stun_visual.position = Vector2(-85.0, -235.0)
	_loro_stun_visual.size = Vector2(170.0, 48.0)
	_loro_stun_visual.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_loro_stun_visual.add_theme_font_size_override("font_size", 30)
	_loro_stun_visual.add_theme_color_override("font_color", Color(1.0, 0.9, 0.3, 1.0))
	_loro_stun_visual.add_theme_color_override("font_outline_color", Color(0.1, 0.05, 0.08, 1.0))
	_loro_stun_visual.add_theme_constant_override("outline_size", 5)
	_loro_stun_visual.z_index = 150
	add_child(_loro_stun_visual)
	var dizzy_tween: Tween = _loro_stun_visual.create_tween().set_loops()
	dizzy_tween.tween_property(_loro_stun_visual, "rotation", 0.16, 0.35)
	dizzy_tween.tween_property(_loro_stun_visual, "rotation", -0.16, 0.35)


func _start_loro_shout_cycle() -> void:
	if current_state == State.DEAD or health_component == null or health_component.is_dead:
		_loro_repeat_timer = -1.0
		return
	_ensure_loro_target()
	if _loro_target == null:
		_loro_repeat_timer = LORO_REPEAT_DELAY
		return
	_loro_target.start_shouting()
	_loro_repeat_timer = LORO_REPEAT_DELAY


func _start_meat_seeking_for_remaining_drop() -> void:
	if current_state == State.DEAD or _meat_instances.is_empty():
		return
	_release_combat_resources()
	if melee_attack != null:
		melee_attack.cancel_attack()
	if punch_visual != null:
		punch_visual.visible = false

	_special_behavior = SpecialBehavior.MEAT_SEEKING
	current_state = State.FLANKING
	velocity = Vector2.ZERO
	_select_next_healing_meat()
	if _meat_target == null:
		return
	_meat_chatter_timer = MEAT_CHATTER_INTERVAL
	_show_meat_chase_dialogue()
	if anim_sprite != null:
		_play_anim("walk")


func _finish_special_behavior() -> void:
	var finished_behavior: SpecialBehavior = _special_behavior
	var was_eating_meat: bool = finished_behavior == SpecialBehavior.MEAT_EATING

	# Abre uma janela curta para o jogador punir a recuperação da esquiva.
	# O cooldown de trufas impede que a salva interrompa essa oportunidade.
	if finished_behavior == SpecialBehavior.EVADING:
		_truffle_cooldown = maxf(_truffle_cooldown, POST_EVASION_COUNTER_WINDOW + 0.25)

	super._finish_special_behavior()
	if finished_behavior in [SpecialBehavior.TRUFFLE_WINDUP, SpecialBehavior.THROWING_TRUFFLES]:
		_truffle_cooldown = 2.5

	if was_eating_meat and current_state != State.DEAD and not _meat_instances.is_empty():
		_start_meat_seeking_for_remaining_drop()

	if finished_behavior in [SpecialBehavior.MEAT_SEEKING, SpecialBehavior.MEAT_EATING] and _meat_instances.is_empty():
		_restore_battle_after_meat()

	if finished_behavior == SpecialBehavior.EVADING and current_state != State.DEAD:
		_evasion_cooldown = 0.0
		_post_evasion_counter_timer = POST_EVASION_COUNTER_WINDOW


func _begin_meat_eating() -> void:
	super._begin_meat_eating()
	if _special_behavior == SpecialBehavior.MEAT_EATING:
		_show_meat_eating_indicator()


func _show_meat_eating_indicator() -> void:
	_clear_meat_eating_indicator()
	_meat_eating_panel = PanelContainer.new()
	_meat_eating_panel.name = "MeatEatingTimeout"
	_meat_eating_panel.position = Vector2(-92.0, -330.0)
	_meat_eating_panel.custom_minimum_size = Vector2(184.0, 62.0)
	_meat_eating_panel.size = Vector2(184.0, 62.0)
	_meat_eating_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_meat_eating_panel.z_index = 145

	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.055, 0.035, 0.045, 0.92)
	panel_style.border_color = Color(1.0, 0.72, 0.25, 1.0)
	panel_style.set_border_width_all(2)
	panel_style.set_corner_radius_all(7)
	panel_style.content_margin_left = 8.0
	panel_style.content_margin_right = 8.0
	panel_style.content_margin_top = 5.0
	panel_style.content_margin_bottom = 5.0
	_meat_eating_panel.add_theme_stylebox_override("panel", panel_style)

	var content := VBoxContainer.new()
	content.name = "Content"
	content.add_theme_constant_override("separation", 3)
	_meat_eating_panel.add_child(content)

	var status_label := Label.new()
	status_label.name = "StatusLabel"
	status_label.text = "Comendo..."
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.add_theme_font_override("font", preload("res://assets/fonts/arcade_bold.ttf"))
	status_label.add_theme_font_size_override("font_size", 14)
	status_label.add_theme_color_override("font_color", Color(1.0, 0.91, 0.68, 1.0))
	status_label.add_theme_color_override("font_outline_color", Color(0.08, 0.04, 0.02, 1.0))
	status_label.add_theme_constant_override("outline_size", 3)
	content.add_child(status_label)

	_meat_eating_bar = ProgressBar.new()
	_meat_eating_bar.name = "TimeoutBar"
	_meat_eating_bar.custom_minimum_size = Vector2(164.0, 12.0)
	_meat_eating_bar.min_value = 0.0
	_meat_eating_bar.max_value = MEAT_APPEAR_EAT_SECONDS
	_meat_eating_bar.value = _special_timer
	_meat_eating_bar.show_percentage = false
	var bar_background := StyleBoxFlat.new()
	bar_background.bg_color = Color(0.12, 0.09, 0.08, 1.0)
	bar_background.set_corner_radius_all(3)
	var bar_fill := StyleBoxFlat.new()
	bar_fill.bg_color = Color(1.0, 0.68, 0.18, 1.0)
	bar_fill.set_corner_radius_all(3)
	_meat_eating_bar.add_theme_stylebox_override("background", bar_background)
	_meat_eating_bar.add_theme_stylebox_override("fill", bar_fill)
	content.add_child(_meat_eating_bar)
	add_child(_meat_eating_panel)


func _update_meat_eating_indicator() -> void:
	if _special_behavior == SpecialBehavior.MEAT_EATING and not _meat_dialogue_started:
		if _meat_eating_bar != null and is_instance_valid(_meat_eating_bar):
			_meat_eating_bar.value = clampf(_special_timer, 0.0, MEAT_APPEAR_EAT_SECONDS)
		return
	_clear_meat_eating_indicator()


func _clear_meat_eating_indicator() -> void:
	if _meat_eating_panel != null and is_instance_valid(_meat_eating_panel):
		_meat_eating_panel.queue_free()
	_meat_eating_panel = null
	_meat_eating_bar = null


func _cache_loro_stun_hurtbox() -> void:
	var hurtbox: Area2D = get_node_or_null("Hurtbox") as Area2D
	if hurtbox != null:
		_stun_hurtbox_shape = hurtbox.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if _stun_hurtbox_shape != null:
		_original_hurtbox_shape = _stun_hurtbox_shape.shape
		_original_hurtbox_shape_position = _stun_hurtbox_shape.position
	_impact_zones = get_node_or_null("ImpactZones") as ImpactZones
	if _impact_zones != null:
		_original_impact_zone_bounds = [
			_impact_zones.head_top_y, _impact_zones.head_bottom_y,
			_impact_zones.upper_torso_top_y, _impact_zones.upper_torso_bottom_y,
			_impact_zones.lower_torso_top_y, _impact_zones.lower_torso_bottom_y,
			_impact_zones.legs_top_y, _impact_zones.legs_bottom_y
		]


func _expand_loro_stun_hurtbox() -> void:
	if _stun_hurtbox_shape != null and _original_hurtbox_shape is RectangleShape2D:
		var expanded_shape := (_original_hurtbox_shape as RectangleShape2D).duplicate() as RectangleShape2D
		expanded_shape.size = Vector2(112.0, 184.0)
		_stun_hurtbox_shape.shape = expanded_shape
		_stun_hurtbox_shape.position = Vector2(0.0, -82.0)
	if _impact_zones != null:
		# A pose inclinada para trás desloca cabeça e tronco; as zonas são
		# temporariamente ampliadas para não exigir contato na pose em pé.
		_impact_zones.head_top_y = -225.0
		_impact_zones.head_bottom_y = -135.0
		_impact_zones.upper_torso_top_y = -145.0
		_impact_zones.upper_torso_bottom_y = -62.0
		_impact_zones.lower_torso_top_y = -72.0
		_impact_zones.lower_torso_bottom_y = -25.0
		_impact_zones.legs_top_y = -38.0
		_impact_zones.legs_bottom_y = 0.0


func _restore_loro_stun_hurtbox() -> void:
	if _stun_hurtbox_shape != null and is_instance_valid(_stun_hurtbox_shape):
		_stun_hurtbox_shape.shape = _original_hurtbox_shape
		_stun_hurtbox_shape.position = _original_hurtbox_shape_position
	if _impact_zones != null and _original_impact_zone_bounds.size() == 8:
		_impact_zones.head_top_y = _original_impact_zone_bounds[0]
		_impact_zones.head_bottom_y = _original_impact_zone_bounds[1]
		_impact_zones.upper_torso_top_y = _original_impact_zone_bounds[2]
		_impact_zones.upper_torso_bottom_y = _original_impact_zone_bounds[3]
		_impact_zones.lower_torso_top_y = _original_impact_zone_bounds[4]
		_impact_zones.lower_torso_bottom_y = _original_impact_zone_bounds[5]
		_impact_zones.legs_top_y = _original_impact_zone_bounds[6]
		_impact_zones.legs_bottom_y = _original_impact_zone_bounds[7]


func _start_post_loro_escape() -> void:
	if not _is_player_target_valid():
		_post_loro_escape_timer = 0.0
		return
	var away_direction: Vector2 = global_position - player_target.global_position
	if away_direction.length_squared() < 1.0:
		away_direction = Vector2(-facing_direction, 0.0)
	if global_position.x <= MAP_LEFT_WALL_X + 24.0 and away_direction.x < 0.0:
		away_direction.x = 0.0
		away_direction.y = -1.0 if player_target.global_position.y > global_position.y else 1.0
	elif global_position.x >= MAP_RIGHT_WALL_X - 24.0 and away_direction.x > 0.0:
		away_direction.x = 0.0
		away_direction.y = -1.0 if player_target.global_position.y > global_position.y else 1.0
	_post_loro_escape_direction = away_direction.normalized()
	_post_loro_escape_timer = POST_LORO_ESCAPE_DURATION
	if not is_zero_approx(_post_loro_escape_direction.x):
		facing_direction = signf(_post_loro_escape_direction.x)
		if visual_root != null:
			visual_root.scale.x = absf(visual_root.scale.y) * facing_direction


func _process_post_loro_escape(delta: float) -> void:
	if is_in_hitstop():
		super._physics_process(delta)
		return
	_post_loro_escape_timer = maxf(0.0, _post_loro_escape_timer - delta)
	velocity = _post_loro_escape_direction * POST_LORO_ESCAPE_SPEED
	if global_position.x <= MAP_LEFT_WALL_X and velocity.x < 0.0:
		velocity.x = 0.0
	if global_position.x >= MAP_RIGHT_WALL_X and velocity.x > 0.0:
		velocity.x = 0.0
	_play_anim("walk")
	move_and_slide()
	if _post_loro_escape_timer <= 0.0:
		velocity = Vector2.ZERO
		_attack_timer = maxf(_attack_timer, 1.25)
		_truffle_cooldown = maxf(_truffle_cooldown, 1.5)
		_play_anim("idle")
		if _resume_meat_seeking_after_escape:
			_resume_meat_seeking_after_escape = false
			_start_meat_seeking_for_remaining_drop()


func _show_meat_dialogue() -> void:
	# O método base é chamado no instante em que a carne some da arena, após
	# os 2,5s de consumo. A contagem começa aqui, não no início do drop nem
	# depois da fala de Alessandro.
	super._show_meat_dialogue()
	if not _first_meat_consumed:
		_first_meat_consumed = true
		_second_meat_timer = SECOND_MEAT_DROP_DELAY


func take_damage(damage_input: Variant) -> bool:
	if _loro_stun_timer > 0.0:
		return super.take_damage(damage_input)
	if _special_behavior in [SpecialBehavior.MEAT_SEEKING, SpecialBehavior.MEAT_EATING]:
		return false
	if not _is_player_melee_damage(damage_input):
		return super.take_damage(damage_input)

	# Encurralado, Alessandro deixa o jogador concluir um único combo de quatro
	# acertos. Depois do quarto golpe, bloqueia novos hits até executar a fuga.
	if _is_cornered_by_player():
		if _cornered_evasion_pending:
			return false
		var accepted_corner_hit: bool = super.take_damage(damage_input)
		if accepted_corner_hit:
			if _cornered_combo_timer <= 0.0:
				_cornered_combo_hits = 0
			_cornered_combo_hits += 1
			_cornered_combo_timer = CORNERED_COMBO_WINDOW
			if _cornered_combo_hits >= CORNERED_COMBO_REQUIRED_HITS:
				_cornered_combo_hits = 0
				_cornered_combo_timer = 0.0
				_cornered_evasion_pending = true
		return accepted_corner_hit

	_cornered_combo_hits = 0
	_cornered_combo_timer = 0.0

	# Se o jogador encurta a distância em alta velocidade logo após a esquiva,
	# Alessandro fica vulnerável: o golpe não pode ser esquivado novamente.
	if _post_evasion_counter_timer > 0.0 and _is_fast_player_approach():
		_post_evasion_counter_timer = 0.0
		if _special_behavior != SpecialBehavior.NONE:
			_interrupt_special_behavior_for_hit()
		return super.take_damage(damage_input)

	# Fora da janela de contra-ataque, Alessandro mantém 70% de chance de
	# esquivar dos golpes corpo a corpo do jogador, inclusive da voadora.
	if _evasion_cooldown <= 0.0 and _can_start_evasion():
		if randf() < PLAYER_MELEE_EVADE_CHANCE:
			_start_evasion()
			if _special_behavior == SpecialBehavior.EVADING:
				return false
		else:
			_evasion_cooldown = 0.35

	return super.take_damage(damage_input)


func _is_cornered_by_player() -> bool:
	if not _is_player_target_valid():
		return false
	var delta_x: float = player_target.global_position.x - global_position.x
	if absf(delta_x) > CORNERED_PLAYER_RANGE_X:
		return false
	if absf(player_target.global_position.y - global_position.y) > CORNERED_DEPTH_TOLERANCE:
		return false
	var trapped_at_left: bool = global_position.x <= CORNERED_LEFT_LIMIT_X and delta_x > 0.0
	var trapped_at_right: bool = global_position.x >= CORNERED_RIGHT_LIMIT_X and delta_x < 0.0
	return trapped_at_left or trapped_at_right


func _update_cornered_combo_window(delta: float) -> void:
	if _cornered_evasion_pending:
		return
	if not _is_cornered_by_player():
		_cornered_combo_hits = 0
		_cornered_combo_timer = 0.0
		return
	if _cornered_combo_timer > 0.0:
		_cornered_combo_timer = maxf(0.0, _cornered_combo_timer - delta)
		if _cornered_combo_timer <= 0.0:
			_cornered_combo_hits = 0


func _process_hurt(delta: float) -> void:
	super._process_hurt(delta)
	_try_execute_cornered_evasion()


func _process_getup(delta: float) -> void:
	super._process_getup(delta)
	_try_execute_cornered_evasion()


func _try_execute_cornered_evasion() -> void:
	if not _cornered_evasion_pending or current_state != State.FLANKING:
		return
	if _special_behavior != SpecialBehavior.NONE or not _is_player_target_valid():
		return
	_cornered_evasion_pending = false
	_start_evasion()
	if _special_behavior != SpecialBehavior.EVADING:
		return

	# Na parede, a fuga precisa apontar para o interior da arena, não contra o limite.
	var escape_x: float = 1.0 if global_position.x <= CORNERED_LEFT_LIMIT_X else -1.0
	var escape_y: float = -1.0 if global_position.y >= 640.0 else 1.0
	_evasion_direction = Vector2(escape_x, escape_y * 0.35).normalized()
	_cornered_combo_hits = 0
	_cornered_combo_timer = 0.0


func _restore_battle_after_meat() -> void:
	_clear_meat_eating_indicator()
	_meat_target = null
	_meat_eating_target = null
	_meat_dialogue_started = false
	_meat_chatter_timer = 0.0
	if _speech_bubble != null and is_instance_valid(_speech_bubble):
		_speech_bubble.queue_free()
	_speech_bubble = null
	_special_behavior = SpecialBehavior.NONE
	if current_state == State.DEAD:
		return
	current_state = State.FLANKING
	velocity = Vector2.ZERO
	_attack_timer = maxf(_attack_timer, 0.75)
	_truffle_cooldown = maxf(
		_truffle_cooldown,
		TRUFFLE_COOLDOWN_PHASE_TWO if _is_phase_two() else TRUFFLE_COOLDOWN_PHASE_ONE
	)
	if anim_sprite != null:
		anim_sprite.speed_scale = 1.0
		_play_anim("idle")


func _is_player_melee_damage(damage_input: Variant) -> bool:
	if not (damage_input is RefCounted):
		return false
	if str(damage_input.get("damage_type")) != "melee":
		return false
	var attacker: Node = damage_input.get("attacker") as Node
	return attacker != null and attacker == player_target and attacker.is_in_group("player")


func _is_fast_player_approach() -> bool:
	if not _is_player_target_valid():
		return false
	var player_body: CharacterBody2D = player_target as CharacterBody2D
	if player_body == null:
		return false
	var horizontal_delta: float = global_position.x - player_body.global_position.x
	var moving_toward_boss: bool = player_body.velocity.x * horizontal_delta > 0.0
	return (
		moving_toward_boss
		and absf(player_body.velocity.x) >= FAST_APPROACH_MIN_SPEED
		and absf(horizontal_delta) <= 170.0
		and absf(player_body.global_position.y - global_position.y) <= EVADE_DEPTH_TOLERANCE
	)


func _process_evasion(delta: float) -> void:
	# Se a arrancada encontra a parede, inverte o deslocamento e desliza para
	# o interior do mapa, evitando ficar preso contra o limite da arena.
	for collision_index: int in range(get_slide_collision_count()):
		var collision: KinematicCollision2D = get_slide_collision(collision_index)
		if collision == null:
			continue
		var wall_normal: Vector2 = collision.get_normal()
		if absf(wall_normal.x) > 0.7:
			_evasion_direction.x = signf(wall_normal.x)
			break

	if global_position.x <= MAP_LEFT_WALL_X and _evasion_direction.x < 0.0:
		_evasion_direction.x = 1.0
	elif global_position.x >= MAP_RIGHT_WALL_X and _evasion_direction.x > 0.0:
		_evasion_direction.x = -1.0

	if absf(_evasion_direction.x) > 0.01:
		_evasion_direction = Vector2(_evasion_direction.x, _evasion_direction.y).normalized()
	super._process_evasion(delta)


func _show_gabriel_second_meat_dialogue() -> bool:
	var scene_root: Node = get_tree().current_scene
	if scene_root == null:
		scene_root = get_tree().root
	if scene_root == null:
		return false

	var dialogue: CanvasLayer = GabrielSecondMeatDialogueClass.new() as CanvasLayer
	if dialogue == null:
		push_warning("BossAlessandro: não foi possível criar a orientação da segunda carne.")
		return false
	dialogue.name = "Map4SecondMeatDialogue"
	dialogue.connect("dialogue_closed", Callable(self, "_on_gabriel_second_meat_dialogue_closed"), CONNECT_ONE_SHOT)
	_second_meat_dialogue_pending = true
	get_tree().paused = true
	scene_root.add_child(dialogue)
	return true


func _on_gabriel_second_meat_dialogue_closed() -> void:
	if not _second_meat_dialogue_pending:
		return
	_second_meat_dialogue_pending = false
	if current_state == State.DEAD or health_component == null or health_component.is_dead:
		_finish_second_meat_dialogue_sequence()
		return
	if not _show_gabriel_meat_hint():
		_finish_second_meat_dialogue_sequence()


func _show_gabriel_meat_hint() -> bool:
	var scene_root: Node = get_tree().current_scene
	if scene_root == null:
		scene_root = get_tree().root
	if scene_root == null:
		return false

	var dialogue: CanvasLayer = GabrielMeatHintDialogueClass.new() as CanvasLayer
	if dialogue == null:
		push_warning("BossAlessandro: não foi possível criar a dica do Loro do Gabriel.")
		return false
	dialogue.name = "Map4MeatHintDialogue"
	dialogue.connect("dialogue_closed", Callable(self, "_on_gabriel_meat_hint_closed"), CONNECT_ONE_SHOT)
	_second_meat_hint_pending = true
	get_tree().paused = true
	scene_root.add_child(dialogue)
	return true


func _on_gabriel_meat_hint_closed() -> void:
	if not _second_meat_hint_pending:
		return
	_second_meat_hint_pending = false
	_finish_second_meat_dialogue_sequence()


func _finish_second_meat_dialogue_sequence() -> void:
	_loro_intro_active = false
	get_tree().paused = false
	process_mode = Node.PROCESS_MODE_INHERIT
	_loro_intro_hold = false
	if current_state == State.DEAD or health_component == null or health_component.is_dead:
		return
	_start_loro_shout_cycle()
	_start_meat_seeking_for_remaining_drop()
