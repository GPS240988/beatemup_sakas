class_name BossAlessandroEnhanced
extends "res://scripts/actors/boss_alessandro.gd"

## Extensão pontual do chefe: segunda carne após o primeiro drop e esquiva
## reativa à voadora do jogador. A IA base permanece como autoridade principal.

const GabrielMeatHintDialogueClass = preload(
	"res://scripts/events/map4_meat_hint_dialogue.gd"
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
const LORO_FIRST_SHOUT_DELAY: float = 3.0
const GABRIEL_HINT_DELAY: float = 6.0
const LORO_REPEAT_DELAY: float = 10.0
const LORO_STUN_DURATION: float = 5.0

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
var _loro_intro_elapsed: float = 0.0
var _loro_first_shout_done: bool = false
var _loro_hit_during_intro: bool = false
var _loro_stun_timer: float = 0.0
var _loro_repeat_timer: float = -1.0
var _loro_stun_visual: Label = null


func _ready() -> void:
	super._ready()
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
	super._physics_process(delta)


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

	# A sequência do Loro substitui a dica imediata: a fase já está pausada,
	# o papagaio grita aos 3s e Gabriel entra aos 6s. Só o evento segue ativo.
	_loro_intro_active = true
	_loro_intro_hold = true
	_loro_intro_elapsed = 0.0
	_loro_first_shout_done = false
	_loro_hit_during_intro = false
	# A fase permanece pausada durante a preparação do evento. O chefe e o
	# controlador do Loro usam PROCESS_MODE_ALWAYS para cumprir os 3s/6s.
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().paused = true
	_ensure_loro_target()


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
	if _loro_intro_active:
		_loro_intro_elapsed += delta
		if not _loro_first_shout_done and _loro_intro_elapsed >= LORO_FIRST_SHOUT_DELAY:
			_ensure_loro_target()
			if _loro_target != null:
				_loro_target.start_shouting()
			_loro_first_shout_done = true
		if _loro_intro_elapsed >= GABRIEL_HINT_DELAY:
			_loro_intro_active = false
			if not _show_gabriel_meat_hint():
				get_tree().paused = false
				process_mode = Node.PROCESS_MODE_INHERIT
				_loro_intro_hold = false
				if not _loro_hit_during_intro:
					_start_meat_seeking_for_remaining_drop()

	if _loro_repeat_timer > 0.0 and _loro_stun_timer <= 0.0:
		_loro_repeat_timer = maxf(0.0, _loro_repeat_timer - delta)
		if _loro_repeat_timer <= 0.0:
			_loro_repeat_timer = -1.0
			_ensure_loro_target()
			if _loro_target != null:
				_loro_target.start_shouting()


func _on_loro_hit() -> void:
	if _loro_stun_timer > 0.0 or current_state == State.DEAD:
		return
	# A refeição é uma janela protegida: o evento do Loro não interrompe
	# nem causa tontura enquanto Alessandro está buscando ou consumindo a carne.
	if _special_behavior in [SpecialBehavior.MEAT_SEEKING, SpecialBehavior.MEAT_EATING]:
		return
	if _loro_intro_active or _second_meat_hint_pending:
		_loro_hit_during_intro = true
	_start_loro_stun()


func _start_loro_stun() -> void:
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
	_meat_target = null
	_meat_eating_target = null
	_meat_dialogue_started = false
	_meat_chatter_timer = 0.0
	velocity = Vector2.ZERO
	if current_state != State.DEAD:
		current_state = State.FLANKING
	_loro_stun_timer = LORO_STUN_DURATION
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
	if _loro_stun_visual != null and is_instance_valid(_loro_stun_visual):
		_loro_stun_visual.queue_free()
	_loro_stun_visual = null
	if current_state == State.DEAD:
		return
	_special_behavior = SpecialBehavior.NONE
	current_state = State.FLANKING
	velocity = Vector2.ZERO
	_attack_timer = maxf(_attack_timer, 0.75)
	_truffle_cooldown = maxf(_truffle_cooldown, 1.0)
	if anim_sprite != null:
		anim_sprite.speed_scale = 1.0
		_play_anim("idle")
	# O próximo grito acontece dez segundos depois de o chefe se recuperar.
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
		_show_speech_bubble("Comendo...", MEAT_APPEAR_EAT_SECONDS)


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


func _show_gabriel_meat_hint() -> bool:
	var scene_root: Node = get_tree().current_scene
	if scene_root == null:
		scene_root = get_tree().root
	if scene_root == null:
		return false

	var dialogue: Map4MeatHintDialogue = GabrielMeatHintDialogueClass.new() as Map4MeatHintDialogue
	if dialogue == null:
		push_warning("BossAlessandro: não foi possível criar a dica do Gabriel.")
		return false
	dialogue.name = "Map4MeatHintDialogue"
	dialogue.dialogue_closed.connect(_on_gabriel_meat_hint_closed, CONNECT_ONE_SHOT)
	_second_meat_hint_pending = true
	get_tree().paused = true
	scene_root.add_child(dialogue)
	return true


func _on_gabriel_meat_hint_closed() -> void:
	if not _second_meat_hint_pending:
		return
	_second_meat_hint_pending = false
	get_tree().paused = false
	process_mode = Node.PROCESS_MODE_INHERIT
	_loro_intro_hold = false
	if current_state == State.DEAD or health_component == null or health_component.is_dead:
		return
	if _loro_hit_during_intro:
		_loro_hit_during_intro = false
		return
	_start_meat_seeking_for_remaining_drop()
