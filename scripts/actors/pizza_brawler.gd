class_name PizzaBrawler
extends EnemyAI

## Inimigo Pizza Brawler (Fase 2-3 / Map 7 — HAPPEN).
## Suporta rotina inicial sentado na cadeira (sit_idle -> getup -> EnemyAI) ou
## de costas no balcão pegando comida (counter_eat -> alerta -> EnemyAI),
## com efeito de gordura/suor na pele e suporte completo a paletas e arquétipos.

enum IdleRoutine {
	NONE,
	SITTING,
	COUNTER_EATING
}

enum BrawlerPhase {
	SITTING,
	COUNTER_EATING,
	GETTING_UP,
	CHAIR_AMBUSH,
	COMBAT
}

signal chair_ambush_started()
signal chair_ambush_resolved(dodged: bool)

@export var initial_routine: IdleRoutine = IdleRoutine.SITTING
@export var start_sitting: bool = true
@export var wake_on_proximity: bool = true
@export var peaceful_until_attacked: bool = false
@export var wake_trigger_radius: float = 200.0
@export var initial_facing: float = -1.0
@export var getup_fallback_duration: float = 0.68
@export var counter_turn_duration: float = 0.24
@export var step_out_offset: Vector2 = Vector2.ZERO
@export_range(0.0, 0.5, 0.01) var skin_oil_sheen: float = 0.26
@export var enable_chair_ambush: bool = false
@export var ambush_chair_path: NodePath = NodePath("")
@export var qte_duration: float = 4.0
@export var chair_ambush_damage: float = 28.0
@export var ambush_speech_text: String = "OLHA A CADEIRADA!"
@export var ambush_speech_duration: float = 0.85
@export var auto_ambush_after_previous: bool = false
@export var auto_ambush_delay_seconds: float = 5.0
@export var qte_reverse_sequence: bool = false
@export var ambush_prop_mode: String = "chair"
@export var use_waitress_visual: bool = false
@export var waitress_outfit_color: Color = Color(0.68, 0.20, 0.78, 1.0)
@export var waitress_dark_skin: bool = false

@onready var wake_trigger: Area2D = get_node_or_null("WakeTrigger") as Area2D

var _brawler_phase: BrawlerPhase = BrawlerPhase.COMBAT
var _getup_timer: float = 0.0
var _waking_from_counter: bool = false
var _chair_ambush_done: bool = false
var _ambush_speech_timer: float = 0.0
var _ambush_waiting_speech: bool = false
var _ambush_bubble_layer: CanvasLayer = null
var _held_chair_sprite: Sprite2D = null
var _qte_overlay: CanvasLayer = null
var _paused_enemies: Array[Node] = []
var _grease_drip: CPUParticles2D = null
var _grease_burst: CPUParticles2D = null

const BANHA_HURT_SFX: String = "res://assets/audio/sfx/banha_gorducho.mp3"
const CHAIR_WOOD_SFX: String = "res://assets/audio/sfx/chair_wood_hit.wav"
const WAITRESS_AIIIN_SFX: String = "res://assets/audio/sfx/garconete_aiiin.wav"
const ARCADE_FONT: FontFile = preload("res://assets/fonts/arcade_bold.ttf")
const QTE_OVERLAY_SCENE: PackedScene = preload("res://scenes/ui/qte_prompt_overlay.tscn")
const QTEOverlayClass = preload("res://scripts/ui/qte_prompt_overlay.gd")
const DEFAULT_CHAIR_TEXTURE: Texture2D = preload("res://assets/sprites/props/happen/dining_chair_front.png")
const GARCONETE_FRAMES: SpriteFrames = preload("res://scenes/actors/npc/garconete_frames.tres")
const WAITRESS_OUTFIT_SHADER: Shader = preload("res://shaders/waitress_outfit_swap.gdshader")

static var _grease_pixel_tex: Texture2D = null
static var _active_chair_ambush_owner: Node = null
static var _ambush_resolved_count: int = 0
static var _last_ambush_resolved_msec: int = 0


static func reset_global_chair_ambush_state() -> void:
	_active_chair_ambush_owner = null
	_ambush_resolved_count = 0
	_last_ambush_resolved_msec = 0


static func is_any_chair_ambush_active() -> bool:
	return _active_chair_ambush_owner != null and is_instance_valid(_active_chair_ambush_owner)


func _ready() -> void:
	if use_waitress_visual:
		display_name = "GARÇONETE"
	elif display_name == "JOGADOR DE MAGIC" or display_name == "PIZZA BRAWLER" or display_name.is_empty():
		display_name = "GORDUCHO"

	# Preserva archetype e palette_variant configurados por instância na cena (não sobrescrever!)
	super._ready()
	if use_waitress_visual:
		_apply_waitress_visual_override()
	else:
		_apply_skin_oil_shader()
		_setup_grease_particles()

	if anim_sprite != null and not anim_sprite.animation_finished.is_connected(_on_brawler_animation_finished):
		anim_sprite.animation_finished.connect(_on_brawler_animation_finished)

	if wake_trigger != null:
		var wake_shape := wake_trigger.get_node_or_null("CollisionShape2D") as CollisionShape2D
		if wake_shape != null and wake_shape.shape is CircleShape2D:
			var dup_shape := (wake_shape.shape as CircleShape2D).duplicate() as CircleShape2D
			dup_shape.radius = wake_trigger_radius
			wake_shape.shape = dup_shape
		if not wake_trigger.body_entered.is_connected(_on_wake_trigger_body_entered):
			wake_trigger.body_entered.connect(_on_wake_trigger_body_entered)

	var effective_routine: IdleRoutine = initial_routine
	if not start_sitting and effective_routine == IdleRoutine.SITTING:
		effective_routine = IdleRoutine.NONE

	match effective_routine:
		IdleRoutine.SITTING:
			_enter_sitting_phase()
		IdleRoutine.COUNTER_EATING:
			_enter_counter_eating_phase()
		_:
			_brawler_phase = BrawlerPhase.COMBAT
			set_collision_mask_value(2, true)

	if not start_sitting and enable_chair_ambush and ambush_prop_mode == "waitress":
		_attach_ambush_chair_visual()

	if peaceful_until_attacked:
		remove_from_group("enemies")
		if combat_director != null and is_instance_valid(combat_director) and combat_director.has_method("unregister_enemy"):
			combat_director.call("unregister_enemy", self)
		if effective_routine != IdleRoutine.SITTING and effective_routine != IdleRoutine.COUNTER_EATING:
			current_state = State.WAITING
			facing_direction = -1.0 if initial_facing < 0.0 else 1.0
			if visual_root != null:
				visual_root.scale.x = absf(visual_root.scale.y) * facing_direction
			_play_anim("idle")
			if anim_sprite != null and anim_sprite.is_playing():
				anim_sprite.stop()
				anim_sprite.frame = 0


func is_sitting() -> bool:
	return _brawler_phase == BrawlerPhase.SITTING


func is_counter_eating() -> bool:
	return _brawler_phase == BrawlerPhase.COUNTER_EATING


func is_getting_up() -> bool:
	return _brawler_phase == BrawlerPhase.GETTING_UP


func is_in_combat() -> bool:
	return _brawler_phase == BrawlerPhase.COMBAT


func _enter_sitting_phase() -> void:
	_brawler_phase = BrawlerPhase.SITTING
	current_state = State.WAITING
	velocity = Vector2.ZERO
	# Relaxa colisão contra mobília enquanto sentado para não ser empurrado para fora da cadeira
	set_collision_mask_value(2, false)
	facing_direction = -1.0 if initial_facing < 0.0 else 1.0
	if visual_root != null:
		visual_root.scale.x = absf(visual_root.scale.y) * facing_direction
	_play_anim("sit_idle")


func _enter_counter_eating_phase() -> void:
	_brawler_phase = BrawlerPhase.COUNTER_EATING
	current_state = State.WAITING
	velocity = Vector2.ZERO
	set_collision_mask_value(2, false)
	facing_direction = -1.0 if initial_facing < 0.0 else 1.0
	if visual_root != null:
		visual_root.scale.x = absf(visual_root.scale.y) * facing_direction
	_play_anim("counter_eat")


func trigger_wake_up() -> void:
	if _brawler_phase != BrawlerPhase.SITTING and _brawler_phase != BrawlerPhase.COUNTER_EATING:
		return
	if current_state == State.DEAD:
		return
	if enable_chair_ambush and not _chair_ambush_done and is_any_chair_ambush_active():
		return

	var was_counter: bool = (_brawler_phase == BrawlerPhase.COUNTER_EATING)
	if enable_chair_ambush and not _chair_ambush_done and not was_counter:
		_active_chair_ambush_owner = self
	_waking_from_counter = was_counter
	_brawler_phase = BrawlerPhase.GETTING_UP
	velocity = Vector2.ZERO
	emit_grease_burst(10)

	if was_counter:
		_getup_timer = counter_turn_duration
		if player_target != null and is_instance_valid(player_target):
			_update_facing(player_target.global_position.x)
		CombatFeedback.spawn_floating_text(self, global_position + Vector2(0.0, -195.0), "!", Color(1.0, 0.84, 0.24, 1.0))
		_play_anim("guard")
		return

	_getup_timer = getup_fallback_duration
	if anim_sprite != null and anim_sprite.sprite_frames != null and anim_sprite.sprite_frames.has_animation("getup"):
		anim_sprite.play("getup")
	else:
		_finish_wake_up()


func _finish_wake_up() -> void:
	if _brawler_phase != BrawlerPhase.GETTING_UP:
		return
	_waking_from_counter = false
	if step_out_offset != Vector2.ZERO:
		global_position += step_out_offset
	set_collision_mask_value(2, true)
	if enable_chair_ambush and not _chair_ambush_done and player_target != null and is_instance_valid(player_target):
		if not is_any_chair_ambush_active() or _active_chair_ambush_owner == self:
			_start_chair_ambush()
			return
	_brawler_phase = BrawlerPhase.COMBAT
	if current_state != State.DEAD:
		current_state = State.FLANKING
		_play_anim("idle")


func _physics_process(delta: float) -> void:
	if not peaceful_until_attacked and (combat_director == null or not is_instance_valid(combat_director)):
		_find_combat_director()

	if current_state == State.DEAD:
		if _grease_drip != null:
			_grease_drip.emitting = false
		super._physics_process(delta)
		return

	if _brawler_phase == BrawlerPhase.SITTING or _brawler_phase == BrawlerPhase.COUNTER_EATING:
		velocity = Vector2.ZERO
		_play_anim("sit_idle" if _brawler_phase == BrawlerPhase.SITTING else "counter_eat")
		if enable_chair_ambush and not _chair_ambush_done and is_any_chair_ambush_active():
			return
		if auto_ambush_after_previous and enable_chair_ambush and not _chair_ambush_done and _ambush_resolved_count > 0:
			var elapsed_ms: int = Time.get_ticks_msec() - _last_ambush_resolved_msec
			if elapsed_ms >= int(auto_ambush_delay_seconds * 1000.0):
				if player_target == null or not is_instance_valid(player_target):
					_find_player_target()
				trigger_wake_up()
				return
		if wake_on_proximity:
			if player_target == null or not is_instance_valid(player_target):
				_find_player_target()
			if player_target != null and is_instance_valid(player_target):
				if global_position.distance_to(player_target.global_position) <= wake_trigger_radius:
					trigger_wake_up()
		return

	if _brawler_phase == BrawlerPhase.GETTING_UP:
		velocity = Vector2.ZERO
		_getup_timer -= delta
		if _getup_timer <= 0.0:
			_finish_wake_up()
		return

	if _brawler_phase == BrawlerPhase.CHAIR_AMBUSH:
		velocity = Vector2.ZERO
		move_and_slide()
		if _ambush_waiting_speech:
			_ambush_speech_timer -= delta
			if _ambush_speech_timer <= 0.0:
				_ambush_waiting_speech = false
				_hide_ambush_speech_bubble()
				_open_chair_qte_prompt()
		return

	if peaceful_until_attacked:
		velocity = Vector2.ZERO
		current_state = State.WAITING
		if anim_sprite != null and anim_sprite.is_playing():
			anim_sprite.stop()
			anim_sprite.frame = 0
		return

	if _brawler_phase == BrawlerPhase.COMBAT and enable_chair_ambush and not _chair_ambush_done and not is_any_chair_ambush_active():
		if player_target == null or not is_instance_valid(player_target):
			_find_player_target()
		if player_target != null and is_instance_valid(player_target):
			if global_position.distance_to(player_target.global_position) <= wake_trigger_radius:
				_active_chair_ambush_owner = self
				_start_chair_ambush()
				return

	super._physics_process(delta)


func _on_wake_trigger_body_entered(body: Node2D) -> void:
	if not wake_on_proximity:
		return
	if _brawler_phase != BrawlerPhase.SITTING and _brawler_phase != BrawlerPhase.COUNTER_EATING:
		return
	if enable_chair_ambush and not _chair_ambush_done and is_any_chair_ambush_active():
		return
	if body != null and body.is_in_group("player"):
		trigger_wake_up()


func _on_brawler_animation_finished() -> void:
	if _brawler_phase == BrawlerPhase.GETTING_UP and not _waking_from_counter and anim_sprite != null and anim_sprite.animation == &"getup":
		_finish_wake_up()


func _trigger_attack() -> void:
	emit_grease_burst(8)
	super._trigger_attack()


func _become_hostile_on_attack() -> void:
	if not is_in_group("enemies"):
		add_to_group("enemies")
	if combat_director != null and is_instance_valid(combat_director):
		combat_director.register_enemy(self)


func _play_banha_hurt_sound() -> void:
	CombatFeedback.play_sound(self, BANHA_HURT_SFX, 1.5, 0.08)


func _on_damaged(amount: float) -> void:
	_become_hostile_on_attack()
	if _brawler_phase != BrawlerPhase.COMBAT:
		if _brawler_phase == BrawlerPhase.GETTING_UP and _active_chair_ambush_owner == self:
			_active_chair_ambush_owner = null
		_brawler_phase = BrawlerPhase.COMBAT
		_waking_from_counter = false
		if step_out_offset != Vector2.ZERO:
			global_position += step_out_offset
		set_collision_mask_value(2, true)
	emit_grease_burst(12)
	_play_banha_hurt_sound()
	super._on_damaged(amount)


func _on_damaged_info(info: RefCounted) -> void:
	_become_hostile_on_attack()
	if _brawler_phase != BrawlerPhase.COMBAT:
		if _brawler_phase == BrawlerPhase.GETTING_UP and _active_chair_ambush_owner == self:
			_active_chair_ambush_owner = null
		_brawler_phase = BrawlerPhase.COMBAT
		_waking_from_counter = false
		if step_out_offset != Vector2.ZERO:
			global_position += step_out_offset
		set_collision_mask_value(2, true)
	emit_grease_burst(12)
	_play_banha_hurt_sound()
	super._on_damaged_info(info)


func _on_died() -> void:
	_cleanup_chair_ambush_state()
	if not peaceful_until_attacked and (combat_director == null or not is_instance_valid(combat_director)):
		_find_combat_director()
	if _grease_drip != null:
		_grease_drip.emitting = false
	super._on_died()


func _exit_tree() -> void:
	_cleanup_chair_ambush_state()


func get_active_qte_overlay() -> CanvasLayer:
	return _qte_overlay


func is_in_chair_ambush() -> bool:
	return _brawler_phase == BrawlerPhase.CHAIR_AMBUSH


func _start_chair_ambush() -> void:
	if is_any_chair_ambush_active() and _active_chair_ambush_owner != self:
		_brawler_phase = BrawlerPhase.COMBAT
		if current_state != State.DEAD:
			current_state = State.FLANKING
			_play_anim("idle")
		return

	_active_chair_ambush_owner = self
	_chair_ambush_done = true
	_brawler_phase = BrawlerPhase.CHAIR_AMBUSH
	velocity = Vector2.ZERO

	if player_target != null and is_instance_valid(player_target):
		_update_facing(player_target.global_position.x)
		if player_target.has_method("set_qte_locked"):
			player_target.call("set_qte_locked", true)

	_set_other_enemies_paused(true)
	_attach_ambush_chair_visual()

	if anim_sprite != null and anim_sprite.sprite_frames != null and anim_sprite.sprite_frames.has_animation("heavy"):
		anim_sprite.play("heavy")
		anim_sprite.pause()
		anim_sprite.frame = 0

	chair_ambush_started.emit()

	if ambush_speech_duration > 0.0 and not ambush_speech_text.strip_edges().is_empty():
		_ambush_waiting_speech = true
		_ambush_speech_timer = ambush_speech_duration
		_show_ambush_speech_bubble(ambush_speech_text)
	else:
		_ambush_waiting_speech = false
		_open_chair_qte_prompt()


func _open_chair_qte_prompt() -> void:
	if _brawler_phase != BrawlerPhase.CHAIR_AMBUSH or current_state == State.DEAD:
		return
	_qte_overlay = QTE_OVERLAY_SCENE.instantiate() as CanvasLayer
	if _qte_overlay != null:
		var host_root: Node = get_tree().current_scene if get_tree().current_scene != null else get_tree().root
		host_root.add_child(_qte_overlay)
		_qte_overlay.connect("qte_succeeded", _on_chair_qte_succeeded, CONNECT_ONE_SHOT)
		_qte_overlay.connect("qte_failed", _on_chair_qte_failed, CONNECT_ONE_SHOT)
		var seq: Array[StringName] = []
		if qte_reverse_sequence:
			seq = [&"attack", &"move_left", &"move_right", &"move_up", &"move_down"]
		_qte_overlay.call("start_qte", seq, qte_duration)


func _show_ambush_speech_bubble(text: String) -> void:
	_hide_ambush_speech_bubble()
	if get_tree() == null:
		return
	var host_root: Node = get_tree().current_scene if get_tree().current_scene != null else get_tree().root
	_ambush_bubble_layer = CanvasLayer.new()
	_ambush_bubble_layer.name = "AmbushSpeechLayer"
	_ambush_bubble_layer.layer = 42
	host_root.add_child(_ambush_bubble_layer)

	var root_ctrl := Control.new()
	root_ctrl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root_ctrl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ambush_bubble_layer.add_child(root_ctrl)

	var bubble := PanelContainer.new()
	bubble.name = "AmbushSpeechBubble"
	bubble.custom_minimum_size = Vector2(280.0, 0.0)
	bubble.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.03, 0.03, 0.06, 0.95)
	style.border_color = Color(0.94, 0.75, 0.39, 1.0)
	style.set_border_width_all(3)
	style.set_corner_radius_all(6)
	style.content_margin_left = 14.0
	style.content_margin_top = 8.0
	style.content_margin_right = 14.0
	style.content_margin_bottom = 10.0
	bubble.add_theme_stylebox_override("panel", style)
	root_ctrl.add_child(bubble)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	bubble.add_child(vbox)

	var speaker := Label.new()
	speaker.text = display_name if not display_name.is_empty() else "GORDUCHO"
	speaker.add_theme_font_override("font", ARCADE_FONT)
	speaker.add_theme_font_size_override("font_size", 15)
	speaker.add_theme_color_override("font_color", Color(1.0, 0.80, 0.25, 1.0))
	vbox.add_child(speaker)

	var body := Label.new()
	body.text = text
	body.add_theme_font_override("font", ARCADE_FONT)
	body.add_theme_font_size_override("font_size", 20)
	body.add_theme_color_override("font_color", Color(0.98, 0.96, 0.92, 1.0))
	vbox.add_child(body)

	bubble.reset_size()
	var bsize := bubble.get_combined_minimum_size()
	bsize.x = maxf(bsize.x, 280.0)
	bubble.size = bsize

	var anchor: Vector2 = get_global_transform_with_canvas().origin
	var vp: Vector2 = get_viewport().get_visible_rect().size if get_viewport() != null else Vector2(1280.0, 720.0)
	bubble.position = Vector2(
		clampf(anchor.x - bsize.x * 0.5, 16.0, maxf(16.0, vp.x - bsize.x - 16.0)),
		clampf(anchor.y - 230.0 - bsize.y, 18.0, maxf(18.0, vp.y - bsize.y - 24.0))
	)


func _hide_ambush_speech_bubble() -> void:
	if _ambush_bubble_layer != null and is_instance_valid(_ambush_bubble_layer):
		_ambush_bubble_layer.queue_free()
		_ambush_bubble_layer = null


func is_ambush_speech_visible() -> bool:
	return _ambush_bubble_layer != null and is_instance_valid(_ambush_bubble_layer)


func _acquire_ambush_chair_texture() -> Texture2D:
	if ambush_prop_mode == "waitress" and GARCONETE_FRAMES != null:
		if GARCONETE_FRAMES.has_animation("react") and GARCONETE_FRAMES.get_frame_count("react") > 0:
			return GARCONETE_FRAMES.get_frame_texture("react", 0)
		if GARCONETE_FRAMES.has_animation("idle") and GARCONETE_FRAMES.get_frame_count("idle") > 0:
			return GARCONETE_FRAMES.get_frame_texture("idle", 0)

	var chair_node: Node = null
	if not ambush_chair_path.is_empty():
		chair_node = get_node_or_null(ambush_chair_path)
	if chair_node == null and get_tree() != null:
		var root_node: Node = get_tree().current_scene if get_tree().current_scene != null else get_parent()
		if root_node != null:
			chair_node = root_node.find_child("ChairFrontLeft01", true, false)

	if chair_node != null:
		var chair_sprite := chair_node.get_node_or_null("Sprite2D") as Sprite2D
		var col_shape := chair_node.get_node_or_null("Collision/CollisionShape2D") as CollisionShape2D
		if col_shape != null:
			col_shape.set_deferred("disabled", true)
		if chair_node is CanvasItem:
			(chair_node as CanvasItem).visible = false
		if chair_sprite != null and chair_sprite.texture != null:
			return chair_sprite.texture

	return DEFAULT_CHAIR_TEXTURE


func _attach_ambush_chair_visual() -> void:
	if visual_root == null:
		return
	if _held_chair_sprite != null and is_instance_valid(_held_chair_sprite):
		return
	var tex: Texture2D = _acquire_ambush_chair_texture()
	_held_chair_sprite = Sprite2D.new()
	_held_chair_sprite.name = "HeldAmbushProp"
	_held_chair_sprite.texture = tex
	_held_chair_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var is_waitress: bool = (ambush_prop_mode == "waitress")
	_held_chair_sprite.scale = Vector2(0.75, 0.75) if is_waitress else Vector2(0.85, 0.85)
	_held_chair_sprite.position = Vector2(18.0, -70.0)
	_held_chair_sprite.rotation_degrees = -90.0 if is_waitress else -15.0
	_held_chair_sprite.z_index = 2
	visual_root.add_child(_held_chair_sprite)

	var lift_tw := create_tween()
	lift_tw.tween_property(_held_chair_sprite, "position", Vector2(8.0, -182.0), 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	lift_tw.parallel().tween_property(_held_chair_sprite, "rotation_degrees", -90.0 if is_waitress else -32.0, 0.22)


func _on_chair_qte_succeeded() -> void:
	_finish_chair_ambush(true)


func _on_chair_qte_failed(_reason: String) -> void:
	_finish_chair_ambush(false)


func _finish_chair_ambush(dodged: bool) -> void:
	if _brawler_phase != BrawlerPhase.CHAIR_AMBUSH:
		return

	if anim_sprite != null and anim_sprite.sprite_frames != null and anim_sprite.sprite_frames.has_animation("heavy"):
		anim_sprite.play("heavy")

	var target_pos: Vector2 = global_position + Vector2(facing_direction * 95.0, 0.0)
	if player_target != null and is_instance_valid(player_target):
		target_pos = player_target.global_position

	if dodged:
		if player_target != null and is_instance_valid(player_target) and player_target.has_method("perform_qte_dodge"):
			player_target.call("perform_qte_dodge", global_position.x)
		_launch_chair_trajectory(true, target_pos)
	else:
		# A cadeira voa até o jogador, acerta com dano + knockdown e depois cai no chão e some
		_launch_chair_trajectory(false, target_pos)

	_set_other_enemies_paused(false)
	_free_qte_overlay()
	if _active_chair_ambush_owner == self:
		_active_chair_ambush_owner = null
	_ambush_resolved_count += 1
	_last_ambush_resolved_msec = Time.get_ticks_msec()

	_brawler_phase = BrawlerPhase.COMBAT
	if current_state != State.DEAD:
		current_state = State.FLANKING
	chair_ambush_resolved.emit(dodged)


func _launch_chair_trajectory(dodged: bool, target_ground_pos: Vector2) -> void:
	var chair_tex: Texture2D = DEFAULT_CHAIR_TEXTURE
	var start_global: Vector2 = global_position + Vector2(facing_direction * 14.0, -172.0)
	if _held_chair_sprite != null and is_instance_valid(_held_chair_sprite):
		if _held_chair_sprite.texture != null:
			chair_tex = _held_chair_sprite.texture
		start_global = _held_chair_sprite.global_position
		_destroy_held_chair_visual()

	var host_parent: Node = get_parent()
	if host_parent == null:
		host_parent = get_tree().current_scene if get_tree() != null else null
	if host_parent == null:
		if not dodged and player_target != null and is_instance_valid(player_target) and player_target.has_method("apply_qte_chair_hit"):
			player_target.call("apply_qte_chair_hit", global_position, chair_ambush_damage)
		return

	var is_waitress: bool = (ambush_prop_mode == "waitress")
	var proj := Sprite2D.new()
	proj.name = "ThrownChairTrajectory"
	proj.texture = chair_tex
	proj.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	proj.scale = Vector2(0.75, 0.75) if is_waitress else Vector2(0.85, 0.85)
	proj.rotation_degrees = -90.0 if is_waitress else 0.0
	proj.global_position = start_global
	proj.z_index = 8
	host_parent.add_child(proj)

	var dir_x: float = 1.0 if target_ground_pos.x >= global_position.x else -1.0
	var impact_sfx: String = WAITRESS_AIIIN_SFX if is_waitress else CHAIR_WOOD_SFX
	var hit_label: String = "GARÇONETE!" if is_waitress else "CADEIRADA!"
	var tw: Tween = proj.create_tween()

	if dodged:
		# Voa pelo ar passando do alvo até bater no chão, quicar e sumir
		var floor_hit_pos := Vector2(target_ground_pos.x + dir_x * 46.0, target_ground_pos.y - 12.0)
		var bounce_pos := floor_hit_pos + Vector2(dir_x * 26.0, -18.0)
		var settle_pos := floor_hit_pos + Vector2(dir_x * 42.0, 0.0)
		tw.tween_property(proj, "global_position", floor_hit_pos, 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		if not is_waitress:
			tw.parallel().tween_property(proj, "rotation_degrees", dir_x * 165.0, 0.22)
		tw.tween_callback(func() -> void:
			if is_instance_valid(self):
				CombatFeedback.play_sound(self, impact_sfx, 1.0 if is_waitress else 0.85, 0.06)
				CombatFeedback.spawn_hit_spark(self, floor_hit_pos, Vector2(dir_x, 0.0), "light")
		)
		tw.tween_property(proj, "global_position", bounce_pos, 0.11).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		if not is_waitress:
			tw.parallel().tween_property(proj, "rotation_degrees", dir_x * 220.0, 0.11)
		tw.tween_property(proj, "global_position", settle_pos, 0.11).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.parallel().tween_property(proj, "modulate:a", 0.0, 0.26).set_delay(0.06)
		tw.tween_callback(proj.queue_free)
	else:
		# Voa até atingir o jogador, causa dano + knockdown, cai no chão e some
		var hit_pos := Vector2(target_ground_pos.x, target_ground_pos.y - 68.0)
		var floor_drop_pos := Vector2(target_ground_pos.x + dir_x * 24.0, target_ground_pos.y - 12.0)
		var bounce_pos := floor_drop_pos + Vector2(dir_x * 18.0, -14.0)
		tw.tween_property(proj, "global_position", hit_pos, 0.15).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		if not is_waitress:
			tw.parallel().tween_property(proj, "rotation_degrees", dir_x * 140.0, 0.15)
		tw.tween_callback(func() -> void:
			if is_instance_valid(self):
				CombatFeedback.play_sound(self, impact_sfx, 1.0, 0.05)
				if player_target != null and is_instance_valid(player_target) and player_target.has_method("apply_qte_chair_hit"):
					player_target.call("apply_qte_chair_hit", global_position, chair_ambush_damage)
				CombatFeedback.spawn_floating_text(self, hit_pos + Vector2(0.0, -90.0), hit_label, Color(1.0, 0.25, 0.20, 1.0))
				CombatFeedback.spawn_hit_spark(self, hit_pos, Vector2(dir_x, 0.0), "heavy")
		)
		tw.tween_property(proj, "global_position", floor_drop_pos, 0.14).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		if not is_waitress:
			tw.parallel().tween_property(proj, "rotation_degrees", dir_x * 215.0, 0.14)
		tw.tween_callback(func() -> void:
			if is_instance_valid(self) and not is_waitress:
				CombatFeedback.play_sound(self, CHAIR_WOOD_SFX, 0.78, 0.05)
		)
		tw.tween_property(proj, "global_position", bounce_pos, 0.09).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(proj, "global_position", floor_drop_pos + Vector2(dir_x * 24.0, 0.0), 0.09).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.parallel().tween_property(proj, "modulate:a", 0.0, 0.25).set_delay(0.05)
		tw.tween_callback(proj.queue_free)


func _destroy_held_chair_visual() -> void:
	if _held_chair_sprite != null and is_instance_valid(_held_chair_sprite):
		_held_chair_sprite.queue_free()
		_held_chair_sprite = null


func _free_qte_overlay() -> void:
	if _qte_overlay != null and is_instance_valid(_qte_overlay):
		_qte_overlay.cancel_qte()
		_qte_overlay.queue_free()
		_qte_overlay = null


func _set_other_enemies_paused(paused: bool) -> void:
	if paused:
		_paused_enemies.clear()
		if get_tree() == null:
			return
		for enemy in get_tree().get_nodes_in_group("enemies"):
			if enemy != self and is_instance_valid(enemy) and enemy.is_physics_processing():
				enemy.set_physics_process(false)
				_paused_enemies.append(enemy)
	else:
		for enemy in _paused_enemies:
			if is_instance_valid(enemy):
				enemy.set_physics_process(true)
		_paused_enemies.clear()


func _cleanup_chair_ambush_state() -> void:
	_ambush_waiting_speech = false
	_hide_ambush_speech_bubble()
	_destroy_held_chair_visual()
	_free_qte_overlay()
	if _active_chair_ambush_owner == self or not is_any_chair_ambush_active():
		_active_chair_ambush_owner = null
		_set_other_enemies_paused(false)
		if player_target != null and is_instance_valid(player_target) and player_target.has_method("set_qte_locked"):
			player_target.call("set_qte_locked", false)


func _apply_waitress_visual_override() -> void:
	if anim_sprite == null:
		return
	anim_sprite.sprite_frames = GARCONETE_FRAMES
	anim_sprite.position = Vector2(0.0, -112.0)
	anim_sprite.scale = Vector2(0.80, 0.80)
	anim_sprite.animation = &"idle"
	anim_sprite.frame = 0
	anim_sprite.stop()
	anim_sprite.material = null


func _apply_skin_oil_shader() -> void:
	if anim_sprite == null or anim_sprite.material == null:
		return
	var mat := anim_sprite.material as ShaderMaterial
	if mat == null:
		return
	mat.set_shader_parameter("oil_sheen_strength", skin_oil_sheen)
	mat.set_shader_parameter("skin_source_hue", 24.0)
	mat.set_shader_parameter("skin_hue_tolerance", 12.0)


func _get_grease_pixel_texture() -> Texture2D:
	if _grease_pixel_tex == null:
		var img := Image.create(3, 3, false, Image.FORMAT_RGBA8)
		img.fill(Color(0, 0, 0, 0))
		# Pequeno cluster pixel-art de gota oleosa (núcleo claro + borda âmbar)
		img.set_pixel(1, 0, Color(1.0, 0.92, 0.58, 1.0))
		img.set_pixel(0, 1, Color(0.95, 0.72, 0.25, 0.95))
		img.set_pixel(1, 1, Color(1.0, 0.96, 0.78, 1.0))
		img.set_pixel(2, 1, Color(0.95, 0.72, 0.25, 0.95))
		img.set_pixel(1, 2, Color(0.88, 0.58, 0.18, 0.90))
		_grease_pixel_tex = ImageTexture.create_from_image(img)
	return _grease_pixel_tex


func _create_grease_ramp() -> Gradient:
	var grad := Gradient.new()
	grad.set_color(0, Color(1.0, 0.95, 0.72, 0.92))
	grad.set_color(1, Color(0.88, 0.55, 0.14, 0.0))
	return grad


func _setup_grease_particles() -> void:
	if visual_root == null:
		return
	var tex: Texture2D = _get_grease_pixel_texture()
	var ramp: Gradient = _create_grease_ramp()

	if visual_root.get_node_or_null("GreaseParticles") == null:
		_grease_drip = CPUParticles2D.new()
		_grease_drip.name = "GreaseParticles"
		_grease_drip.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		_grease_drip.texture = tex
		_grease_drip.position = Vector2(0.0, -96.0)
		_grease_drip.amount = 10
		_grease_drip.lifetime = 0.75
		_grease_drip.randomness = 0.35
		_grease_drip.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
		_grease_drip.emission_rect_extents = Vector2(36.0, 44.0)
		_grease_drip.direction = Vector2(0.0, 1.0)
		_grease_drip.spread = 22.0
		_grease_drip.gravity = Vector2(0.0, 145.0)
		_grease_drip.initial_velocity_min = 6.0
		_grease_drip.initial_velocity_max = 22.0
		_grease_drip.scale_amount_min = 0.9
		_grease_drip.scale_amount_max = 1.35
		_grease_drip.color_ramp = ramp
		_grease_drip.emitting = true
		visual_root.add_child(_grease_drip)
	else:
		_grease_drip = visual_root.get_node_or_null("GreaseParticles") as CPUParticles2D

	if visual_root.get_node_or_null("GreaseBurstParticles") == null:
		_grease_burst = CPUParticles2D.new()
		_grease_burst.name = "GreaseBurstParticles"
		_grease_burst.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		_grease_burst.texture = tex
		_grease_burst.position = Vector2(0.0, -96.0)
		_grease_burst.amount = 12
		_grease_burst.lifetime = 0.48
		_grease_burst.one_shot = true
		_grease_burst.explosiveness = 0.92
		_grease_burst.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
		_grease_burst.emission_rect_extents = Vector2(32.0, 38.0)
		_grease_burst.direction = Vector2(0.0, -0.5)
		_grease_burst.spread = 160.0
		_grease_burst.gravity = Vector2(0.0, 360.0)
		_grease_burst.initial_velocity_min = 45.0
		_grease_burst.initial_velocity_max = 115.0
		_grease_burst.scale_amount_min = 1.0
		_grease_burst.scale_amount_max = 1.6
		_grease_burst.color_ramp = ramp
		_grease_burst.emitting = false
		visual_root.add_child(_grease_burst)
	else:
		_grease_burst = visual_root.get_node_or_null("GreaseBurstParticles") as CPUParticles2D


func emit_grease_burst(burst_amount: int = 10) -> void:
	if _grease_burst == null or not is_instance_valid(_grease_burst):
		return
	if current_state == State.DEAD:
		return
	_grease_burst.amount = clampi(burst_amount, 4, 20)
	_grease_burst.restart()
	_grease_burst.emitting = true
