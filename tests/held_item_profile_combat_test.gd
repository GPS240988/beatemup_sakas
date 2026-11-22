extends SceneTree

const PlayerScene: PackedScene = preload("res://scenes/actors/player/player.tscn")
const BottleProfile: HeldItemProfile = preload("res://resources/items/held_item_profiles/soda_glass_bottle.tres")

var passed: int = 0
var failed: int = 0

func _init() -> void:
	call_deferred("_run")

func _assert(condition: bool, label: String) -> void:
	if condition:
		passed += 1
		print("[OK] ", label)
	else:
		failed += 1
		printerr("[FALHA] ", label)

func _run() -> void:
	var player := PlayerScene.instantiate() as PlayerController
	root.add_child(player)
	await process_frame
	var held := HeldItemComponent.attach_to_player(player)
	var combat := player.get_node_or_null("HeldItemCombatComponent") as HeldItemCombatComponent
	_assert(held != null, "Componente visual conectado ao jogador")
	_assert(combat != null, "Componente de combate anexado ao jogador")
	_assert(held.equip_profile(BottleProfile), "Perfil da garrafa equipado")
	_assert(held.is_holding_item(&"soda_glass_bottle"), "ID de item atual correto")

	var original_socket: Vector2 = held.get_hand_anchor_offset()
	var bat := BottleProfile.duplicate(true) as HeldItemProfile
	bat.item_id = &"test_bat"
	bat.hand_offset = Vector2(13.0, -4.0)
	bat.attack_enabled = true
	bat.override_attack_timing = true
	bat.attack_startup = 0.08
	bat.attack_active = 0.14
	bat.attack_recovery = 0.28
	bat.attack_damage = 44.0
	bat.attack_range = 155.0
	bat.attack_hitbox_height = 88.0
	_assert(held.equip_profile(bat), "Perfil do bastão substitui o perfil da garrafa")
	_assert(held.get_item_sprite().position == original_socket + bat.hand_offset, "Offset do bastão é relativo ao socket do personagem")
	_assert(held.get_hand_anchor_offset() == original_socket, "Perfil não altera o socket anatômico")
	_assert(combat.is_item_combat_enabled(), "Perfil de arma ativa combate")

	var melee := player.get_node_or_null("MeleeAttack") as MeleeAttack
	var old_damage: float = melee.damage
	var old_range: float = melee.horizontal_range
	var old_startup: float = melee.startup_duration
	combat._on_attack_phase_changed(MeleeAttack.Phase.STARTUP)
	_assert(is_equal_approx(melee.damage, 44.0), "Dano do perfil aplicado antes da hitbox")
	_assert(is_equal_approx(melee.startup_duration, 0.08), "Startup do perfil aplicado antes do timer de fase")
	_assert(is_equal_approx(melee._phase_timer, 0.08), "Timer de startup sincronizado ao perfil")
	combat._on_attack_started()
	_assert(is_equal_approx(melee.horizontal_range, 155.0), "Alcance do perfil aplicado ao MeleeAttack oficial")
	combat._on_attack_phase_changed(MeleeAttack.Phase.ACTIVE)
	_assert(is_equal_approx(melee._phase_timer, 0.14), "Janela active sincronizada ao perfil")
	combat._on_attack_phase_changed(MeleeAttack.Phase.INACTIVE)
	_assert(is_equal_approx(melee.damage, old_damage), "Dano base restaurado")
	_assert(is_equal_approx(melee.horizontal_range, old_range), "Alcance base restaurado")
	_assert(is_equal_approx(melee.startup_duration, old_startup), "Startup original restaurado")

	# A voadora usa os parâmetros aéreos do PlayerController, nunca os da arma.
	player.set("_current_attack_anim", &"jump_atk")
	melee.damage = 36.0
	melee.horizontal_range = 210.0
	combat._on_attack_phase_changed(MeleeAttack.Phase.STARTUP)
	_assert(is_equal_approx(melee.damage, 36.0), "Perfil de arma não sobrescreve o dano da voadora")
	_assert(is_equal_approx(melee.horizontal_range, 210.0), "Perfil de arma não sobrescreve o alcance da voadora")
	player.set("_current_attack_anim", &"punch")
	melee.damage = old_damage
	melee.horizontal_range = old_range

	# Remoção no meio de um golpe é aplicada após o ciclo, sem perfil órfão.
	melee.is_attacking = true
	combat.clear_profile(&"test_bat")
	_assert(combat._has_pending_profile_change, "Remoção durante ataque é adiada explicitamente")
	melee.is_attacking = false
	combat._on_attack_phase_changed(MeleeAttack.Phase.INACTIVE)
	_assert(combat.current_profile == null, "Perfil removido ao encerrar o golpe")

	var barrel := bat.duplicate(true) as HeldItemProfile
	barrel.item_id = &"test_barrel"
	barrel.grip_mode = HeldItemProfile.GripMode.TWO_HANDS
	barrel.secondary_hand_texture = BottleProfile.texture
	barrel.secondary_hand_offset = Vector2(-24.0, -10.0)
	_assert(held.equip_profile(barrel), "Perfil de duas mãos equipado")
	var second_hand := held.get_node_or_null("HeldItemSecondaryHand") as Sprite2D
	_assert(second_hand != null and second_hand.visible, "Sprite da segunda mão habilitado pelo perfil")
	_assert(held.unequip_item(&"test_barrel"), "Item removido pelo ID esperado")
	_assert(not held.is_holding_item(), "Item liberado")

	player.queue_free()
	await process_frame
	print("HeldItemProfile/Combat: %d passaram; %d falharam." % [passed, failed])
	quit(1 if failed > 0 else 0)
