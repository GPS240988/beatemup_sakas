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
	print("==================================================")
	print("TESTE: RECURSOS AVANÇADOS DE ITENS EQUIPÁVEIS")
	print("==================================================")

	var player := PlayerScene.instantiate() as PlayerController
	root.add_child(player)
	await process_frame

	var held := HeldItemComponent.attach_to_player(player)
	var combat := player.get_node_or_null("HeldItemCombatComponent") as HeldItemCombatComponent
	_assert(held != null, "HeldItemComponent anexado ao jogador")
	_assert(combat != null, "HeldItemCombatComponent anexado ao jogador")

	# --- 1. Escalabilidade de Heróis (Sockets no HeroData) ---
	print("\n--- 1. Escalabilidade de Heróis ---")
	var custom_hero := HeroData.new()
	custom_hero.hero_id = "andre_custom"
	custom_hero.hand_socket_offset = Vector2(55.0, -120.0)
	custom_hero.grip_rect = Rect2i(100, 100, 50, 60)
	player.hero_data = custom_hero
	held.character_id = &"andre_custom"
	held._hero_data = custom_hero

	_assert(held.get_hand_anchor_offset() == Vector2(55.0, -120.0), "Socket dinâmico resolvido a partir do HeroData")
	_assert(held.get_grip_region() == Rect2i(100, 100, 50, 60), "Grip rect dinâmico resolvido a partir do HeroData")

	# --- 2. Reação a Dano e Knockdown (Drop on Hit) ---
	print("\n--- 2. Reação a Dano e Knockdown ---")
	var drop_profile := BottleProfile.duplicate(true) as HeldItemProfile
	drop_profile.item_id = &"drop_test_item"
	drop_profile.drop_on_knockdown = true
	_assert(held.equip_profile(drop_profile), "Perfil de teste de queda equipado")
	_assert(held.is_holding_item(&"drop_test_item"), "Item está seguro na mão")

	# Simula sinal de Fall do jogador
	player.state_changed.emit("Fall")
	_assert(not held.is_holding_item(&"drop_test_item"), "Item desequipado automaticamente ao sofrer Fall/Knockdown")

	# --- 3. Durabilidade & Desgaste ---
	print("\n--- 3. Durabilidade & Desgaste ---")
	var durable_profile := BottleProfile.duplicate(true) as HeldItemProfile
	durable_profile.item_id = &"durable_bat"
	durable_profile.attack_enabled = true
	durable_profile.max_durability = 3
	durable_profile.breaks_on_hit = false
	_assert(held.equip_profile(durable_profile), "Perfil com durabilidade 3 equipado")
	_assert(combat.current_durability == 3, "Durabilidade inicial calibrada para 3")

	# Hit 1
	combat._on_target_hit(null, 10.0)
	_assert(combat.current_durability == 2, "Durabilidade reduzida para 2 após 1º hit")
	_assert(held.is_holding_item(&"durable_bat"), "Item permanece equipado após 1º hit")

	# Hit 2
	combat._on_target_hit(null, 10.0)
	_assert(combat.current_durability == 1, "Durabilidade reduzida para 1 após 2º hit")
	_assert(held.is_holding_item(&"durable_bat"), "Item permanece equipado após 2º hit")

	# Hit 3 (Quebra)
	combat._on_target_hit(null, 10.0)
	_assert(not held.is_holding_item(&"durable_bat"), "Item quebrado e desequipado ao atingir 0 de durabilidade")

	# Teste breaks_on_hit (ex: garrafa frágil de vidro)
	var glass_profile := BottleProfile.duplicate(true) as HeldItemProfile
	glass_profile.item_id = &"fragile_glass"
	glass_profile.attack_enabled = true
	glass_profile.breaks_on_hit = true
	_assert(held.equip_profile(glass_profile), "Garrafa frágil equipada")
	combat._on_target_hit(null, 10.0)
	_assert(not held.is_holding_item(&"fragile_glass"), "Garrafa frágil quebra imediatamente no 1º hit")

	# --- 4. Arcos de Ataque Visuais (Swing Arc) ---
	print("\n--- 4. Arcos de Ataque Visuais ---")
	var swing_profile := BottleProfile.duplicate(true) as HeldItemProfile
	swing_profile.item_id = &"swing_pipe"
	swing_profile.attack_enabled = true
	swing_profile.rotation_degrees = 10.0
	swing_profile.swing_arc_enabled = true
	swing_profile.swing_start_angle = -50.0
	swing_profile.swing_end_angle = 50.0
	swing_profile.attack_active = 0.10
	_assert(held.equip_profile(swing_profile), "Perfil com swing arc equipado")
	_assert(is_equal_approx(held.get_item_sprite().rotation_degrees, 10.0), "Rotação neutra inicial respeitada")

	combat._on_attack_phase_changed(MeleeAttack.Phase.ACTIVE)
	_assert(is_equal_approx(held.get_item_sprite().rotation_degrees, -40.0), "Rotação inicial do arco (-50 + 10 = -40) aplicada na abertura ativa")

	combat._on_attack_phase_changed(MeleeAttack.Phase.INACTIVE)
	_assert(is_equal_approx(held.get_item_sprite().rotation_degrees, 10.0), "Rotação neutra restaurada após término da fase ativa")

	# --- 5. Gabriel e Armas de Fogo (Prioridade de Arma Branca) ---
	print("\n--- 5. Gabriel e Armas de Fogo ---")
	player.hero_data.hero_id = "gabriel"
	_assert(player.is_gabriel(), "Jogador configurado como Gabriel")

	# Sem item de combate: _is_holding_combat_item retorna false
	held.unequip_item()
	_assert(not player._is_holding_combat_item(), "Gabriel desarmado: _is_holding_combat_item é false (dispara projéteis)")

	# Com garrafa não-combatente: _is_holding_combat_item ainda é false
	_assert(held.equip_profile(BottleProfile), "Garrafa de arremesso equipada")
	_assert(not player._is_holding_combat_item(), "Gabriel com item não-combatente: disparos de tiro não são bloqueados")

	# Com arma de combate branca: _is_holding_combat_item é true
	var melee_weapon := BottleProfile.duplicate(true) as HeldItemProfile
	melee_weapon.item_id = &"iron_pipe"
	melee_weapon.attack_enabled = true
	_assert(held.equip_profile(melee_weapon), "Cano de ferro de combate equipado")
	_assert(player._is_holding_combat_item(), "Gabriel com arma de combate: _is_holding_combat_item é true (suprime projéteis)")

	# --- 6. Ocultação na Voadora e Oscilação Dinâmica (Walk / Punch / Outros) ---
	print("\n--- 6. Ocultação na Voadora e Oscilação Dinâmica ---")
	var anim_spr := player.get_node_or_null("Visual/AnimatedSprite2D") as AnimatedSprite2D
	if anim_spr != null:
		# Na voadora: item e overlay devem ser ocultados
		anim_spr.animation = &"jump_atk"
		held._process(0.016)
		_assert(not held.get_item_sprite().visible, "Item ocultado na voadora (jump_atk)")
		_assert(not held.get_hand_overlay_sprite().visible, "Overlay de mão ocultado na voadora")

		# No walk: visível e oscilando conforme passos
		anim_spr.animation = &"walk"
		anim_spr.frame = 1
		held._process(0.016)
		_assert(held.get_item_sprite().visible, "Item visível durante caminhada (walk)")
		var walk_pos: Vector2 = held.get_item_sprite().position
		anim_spr.frame = 2
		held._process(0.016)
		_assert(held.get_item_sprite().position != walk_pos, "Garrafa oscila acompanhando os frames da caminhada")

		# No punch: avança no impacto do golpe (frame 1)
		anim_spr.animation = &"punch"
		anim_spr.frame = 0
		held._process(0.016)
		var punch_start_x: float = held.get_item_sprite().position.x
		anim_spr.frame = 1
		held._process(0.016)
		_assert(held.get_item_sprite().position.x > punch_start_x, "Garrafa avança para frente acompanhando o golpe de soco (punch)")

	# --- 7. Posicionamento do Prompt Arremessar Acima da Cabeça e Salto ---
	print("\n--- 7. Posicionamento do Prompt Arremessar ---")
	var crate_scene := preload("res://scenes/items/gas_bottle_crate.tscn")
	var crate := crate_scene.instantiate() as GasBottleCrate
	root.add_child(crate)
	await process_frame
	crate.call("interact", player)
	var hint := player.get_node_or_null("PickUpHint") as Button
	_assert(hint != null and hint.text == "Arremessar", "Prompt mudou para Arremessar no jogador")
	_assert(hint != null and hint.position.y <= -240.0, "Prompt posicionado bem acima da cabeça do player (Y <= -240.0)")

	# Simula salto aéreo: visual_root sobe em Y negativo e o prompt deve acompanhar
	if player.visual_root != null:
		player.visual_root.position.y = -120.0
		crate._process(0.016)
		_assert(hint != null and hint.position.y <= -360.0, "Prompt acompanha o salto do jogador sobre sua cabeça (Y <= -360.0)")
		player.visual_root.position.y = 0.0
		crate._process(0.016)
		_assert(hint != null and hint.position.y == -250.0, "Prompt restaura a posição padrão ao pousar no solo")

	crate.call("interact", player) # Arremessa
	crate.queue_free()

	# --- 8. Projétil da Garrafa: Parábola Realista, Colisão com Mapa e Piscar/Sumir ---
	print("\n--- 8. Projétil da Garrafa e Colisão de Mapa ---")
	var proj_scene := preload("res://scenes/actors/projectiles/gas_bottle_projectile.tscn")
	var proj := proj_scene.instantiate() as GasBottleProjectile
	root.add_child(proj)
	await process_frame
	_assert(int(proj.collision_mask) & 2 != 0, "Projétil configurado com detecção de corpos sólidos do mapa (Layer 2)")
	_assert(int(proj.collision_mask) & 12 == 12, "Projétil configurado com detecção de alvos e inimigos (Layers 3 e 4)")
	_assert(proj.flight_arc_height <= 48.0, "Projétil configurado com arco realista e tenso de arremesso (<= 48px)")
	_assert(proj.speed >= 500.0, "Projétil configurado com velocidade rápida de impacto (>= 500px/s)")
	
	# Simula impacto com obstáculo sólido do mapa
	var wall := StaticBody2D.new()
	root.add_child(wall)
	proj.launch(player, 1.0)
	proj._on_body_entered(wall)
	_assert(bool(proj.get("_has_hit")), "Projétil registra acerto em obstáculo de mapa")
	wall.queue_free()
	proj.queue_free()

	player.queue_free()
	await process_frame

	print("\n==================================================")
	print("RESULTADO: %d PASSARAM (Falhas: %d)" % [passed, failed])
	print("==================================================")

	quit(0 if failed == 0 else 1)
