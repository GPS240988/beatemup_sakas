class_name BossAlessandroEnhanced
extends "res://scripts/actors/boss_alessandro.gd"

## Extensão pontual do chefe: segunda carne após o primeiro drop e esquiva
## reativa à voadora do jogador. A IA base permanece como autoridade principal.

const GabrielMeatHintDialogueClass = preload(
	"res://scripts/events/map4_meat_hint_dialogue.gd"
)

const SECOND_MEAT_DROP_DELAY: float = 10.0
const JUMPKICK_EVADE_CHANCE: float = 0.80

var _second_meat_timer: float = -1.0
var _second_meat_dropped: bool = false


func _physics_process(delta: float) -> void:
	# O relógio usa tempo de gameplay e congela durante hitstop.
	if not is_in_hitstop():
		_process_second_meat_timer(delta)
	super._physics_process(delta)


func _activate_healing_meat() -> void:
	var first_drop_was_used: bool = _meat_phase_used
	super._activate_healing_meat()
	if not first_drop_was_used and not _meat_instances.is_empty():
		_second_meat_timer = SECOND_MEAT_DROP_DELAY


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

	# A segunda porção aparece no lado oposto ao primeiro drop para evitar
	# sobreposição quando a primeira ainda estiver no cenário.
	var drop_direction: float = 1.0 if global_position.x >= 1025.0 else -1.0
	var drop_position := Vector2(
		clampf(global_position.x + drop_direction * MEAT_DROP_OFFSET_X, 100.0, 1950.0),
		clampf(global_position.y, 545.0, 735.0)
	)
	destructibles.add_child(meat)
	meat.global_position = drop_position
	meat.prop_destroyed.connect(_on_healing_meat_destroyed.bind(meat), CONNECT_ONE_SHOT)
	_meat_instances.append(meat)
	_second_meat_dropped = true
	CombatFeedback.spawn_dust(destructibles, drop_position + Vector2(0.0, 2.0), 0.72)
	_show_gabriel_meat_hint()

	# Se Alessandro já estiver comendo, conclui a sequência atual e busca a
	# nova carne em seguida. Se estiver ferido/caído, o alvo fica reservado e
	# a IA base retoma a perseguição após a recuperação.
	if _special_behavior in [SpecialBehavior.MEAT_EATING, SpecialBehavior.MEAT_SEEKING]:
		return
	if _special_behavior != SpecialBehavior.NONE:
		_interrupt_special_behavior_for_hit()
	if current_state in [State.HURT, State.FALL, State.DOWNED, State.GETUP, State.DEAD]:
		_select_next_healing_meat()
		return
	_start_meat_seeking_for_remaining_drop()


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
	var was_eating_meat: bool = _special_behavior == SpecialBehavior.MEAT_EATING
	super._finish_special_behavior()
	if was_eating_meat and current_state != State.DEAD and not _meat_instances.is_empty():
		_start_meat_seeking_for_remaining_drop()


func take_damage(damage_input: Variant) -> bool:
	if _try_evade_jumpkick(damage_input):
		return false
	return super.take_damage(damage_input)


func _is_jumpkick_damage(damage_input: Variant) -> bool:
	if not (damage_input is RefCounted):
		return false
	if str(damage_input.get("damage_type")) != "melee":
		return false

	var attacker: Node = damage_input.get("attacker") as Node
	if attacker == null or attacker != player_target:
		return false
	if not attacker.is_in_group("player"):
		return false

	var attack_animation: String = str(attacker.get("_current_attack_anim"))
	var is_jumping: bool = bool(attacker.get("_is_jumping"))
	return attack_animation == "jump_atk" and is_jumping


func _try_evade_jumpkick(damage_input: Variant) -> bool:
	if not _is_jumpkick_damage(damage_input):
		return false
	if _evasion_cooldown > 0.0 or not _can_start_evasion():
		return false

	if randf() >= JUMPKICK_EVADE_CHANCE:
		_evasion_cooldown = 0.35
		return false

	_start_evasion()
	return _special_behavior == SpecialBehavior.EVADING


func _show_gabriel_meat_hint() -> void:
	var scene_root: Node = get_tree().current_scene
	if scene_root == null:
		scene_root = get_tree().root
	if scene_root == null:
		return

	var dialogue: CanvasLayer = GabrielMeatHintDialogueClass.new() as CanvasLayer
	if dialogue == null:
		push_warning("BossAlessandro: não foi possível criar a dica do Gabriel.")
		return
	dialogue.name = "Map4MeatHintDialogue"
	scene_root.add_child(dialogue)
