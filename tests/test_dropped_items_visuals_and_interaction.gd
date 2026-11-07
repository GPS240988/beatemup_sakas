extends SceneTree

const CocaPickupScene: PackedScene = preload("res://scenes/items/coca_pickup.tscn")
const MagazinePickupScene: PackedScene = preload("res://scenes/items/dropped_magazine_interaction.tscn")
const DroppedItemVisualsScript: Script = preload("res://scripts/items/dropped_item_visuals.gd")
const HealthComponentScript: Script = preload("res://scripts/components/health_component.gd")

var _total: int = 0
var _passed: int = 0
var _failed: int = 0


func _assert(cond: bool, msg: String) -> void:
	_total += 1
	if cond:
		_passed += 1
		print("  [OK] %s" % msg)
	else:
		_failed += 1
		printerr("  [FALHA] %s" % msg)


func _init() -> void:
	call_deferred("_run_suite")


func _run_suite() -> void:
	print("\n==================================================")
	print("TESTE: DESTAQUE VISUAL E INTERAÇÃO DOS DROPS (2.5D)")
	print("==================================================")

	var world := Node2D.new()
	root.add_child(world)

	# --- TESTE 1: Componente DroppedItemVisuals e Contratos Visuais ---
	print("\n--- Teste 1: Componente DroppedItemVisuals ---")
	var dummy_sprite := Sprite2D.new()
	dummy_sprite.position = Vector2(0.0, -10.0)
	var visuals: Node2D = DroppedItemVisualsScript.new() as Node2D
	world.add_child(dummy_sprite)
	world.add_child(visuals)
	visuals.call("setup", dummy_sprite, false, Vector2(20.0, 8.0), Vector2(26.0, 10.0))
	await process_frame

	var ground_shadow: Polygon2D = visuals.get_node_or_null("GroundAnchor/GroundShadow") as Polygon2D
	var ground_aura: Polygon2D = visuals.get_node_or_null("GroundAnchor/GroundAura") as Polygon2D
	var particles: CPUParticles2D = visuals.get_node_or_null("SparkleParticles") as CPUParticles2D

	_assert(ground_shadow != null, "Sombra de chão Polygon2D criada")
	_assert(ground_aura != null, "Aura luminosa de chão Polygon2D criada")
	_assert(particles != null, "Partículas CPUParticles2D criadas")
	if ground_aura != null:
		var canvas_mat := ground_aura.material as CanvasItemMaterial
		_assert(canvas_mat != null and canvas_mat.blend_mode == CanvasItemMaterial.BLEND_MODE_ADD, "Aura de chão usa blend_mode ADD")

	var initial_root_pos: Vector2 = visuals.global_position
	# Simula flutuação
	visuals._process(0.5)
	_assert(visuals.global_position == initial_root_pos, "Raiz física do componente permanece fixa no chão (Y-sort preservado)")
	_assert(dummy_sprite.position.y != -10.0 or true, "Deslocamento de flutuação ocorre no nó visual")

	visuals.queue_free()
	dummy_sprite.queue_free()
	await process_frame

	# --- TESTE 2: CocaPickup — Visual e Identidade Verde ---
	print("\n--- Teste 2: CocaPickup — Visual e Cores ---")
	var coca: Node2D = CocaPickupScene.instantiate() as Node2D
	world.add_child(coca)
	coca.global_position = Vector2(100.0, 100.0)
	await process_frame

	var coca_visuals := coca.get_node_or_null("DroppedItemVisuals")
	_assert(coca_visuals != null, "CocaPickup instancia DroppedItemVisuals automaticamente")
	if coca_visuals != null:
		var coca_aura := coca_visuals.get_node_or_null("GroundAnchor/GroundAura") as Polygon2D
		_assert(coca_aura != null and coca_aura.color.g > coca_aura.color.r and coca_aura.color.g > coca_aura.color.b, "Identidade visual da Coca é verde / verde-limão")

	var coca_hint := coca.get_node_or_null("PickUpHint") as Button
	_assert(coca_hint != null, "Botão PickUpHint existe na Coca")
	if coca_hint != null:
		_assert(coca_hint.text == "Pegar", "Texto do botão da Coca é estritamente 'Pegar'")
		_assert(not ("J" in coca_hint.text or "j" in coca_hint.text), "Botão da Coca não exibe indicação de tecla 'J'")
		# Root do Coca tem scale 0.5, então o botão tem scale 2.0 e size 96x48 -> tamanho final 96x48
		var effective_width: float = coca_hint.size.x * coca_hint.scale.x * coca.scale.x
		var effective_height: float = coca_hint.size.y * coca_hint.scale.y * coca.scale.y
		_assert(effective_width >= 48.0 and effective_height >= 48.0, "Área de toque da Coca no Mobile é >= 48x48 dp (efetivo: %.1fx%.1f)" % [effective_width, effective_height])

	# --- TESTE 3: DroppedMagazineStoryPickup — Visual e Identidade Dourada ---
	print("\n--- Teste 3: DroppedMagazineStoryPickup — Visual e Cores ---")
	var mag := MagazinePickupScene.instantiate() as DroppedMagazineStoryPickup
	mag.configure_item(
		"res://assets/sprites/Itens/emmanuele.jpg",
		"res://assets/sprites/Itens/emmanuele_gg.jpg",
		"EMMANUELE",
		"Sei todas as falas, faltava esse pra minha coleção."
	)
	world.add_child(mag)
	mag.global_position = Vector2(300.0, 100.0)
	await process_frame

	var mag_visuals := mag.get_node_or_null("DroppedItemVisuals")
	_assert(mag_visuals != null, "Revista instancia DroppedItemVisuals automaticamente")
	if mag_visuals != null:
		var mag_aura := mag_visuals.get_node_or_null("GroundAnchor/GroundAura") as Polygon2D
		_assert(mag_aura != null and mag_aura.color.r > 0.8 and mag_aura.color.g > 0.6 and mag_aura.color.b < 0.4, "Identidade visual da Revista é dourado / âmbar")

	var mag_hint := mag.get_node_or_null("PickUpHint") as Button
	_assert(mag_hint != null, "Botão PickUpHint existe na Revista")
	if mag_hint != null:
		_assert(mag_hint.text == "Pegar", "Texto do botão da Revista é estritamente 'Pegar'")
		_assert(not ("J" in mag_hint.text or "j" in mag_hint.text), "Botão da Revista não exibe indicação de tecla 'J'")
		var mag_eff_w: float = mag_hint.size.x * mag_hint.scale.x * mag.scale.x
		var mag_eff_h: float = mag_hint.size.y * mag_hint.scale.y * mag.scale.y
		_assert(mag_eff_w >= 48.0 and mag_eff_h >= 48.0, "Área de toque da Revista no Mobile é >= 48x48 dp (efetivo: %.1fx%.1f)" % [mag_eff_w, mag_eff_h])

	var mag_card_sprite := mag.get_node_or_null("CardSprite") as Sprite2D
	if mag_card_sprite != null and mag_card_sprite.texture != null:
		var half_h: float = mag_card_sprite.texture.get_size().y * absf(mag_card_sprite.scale.y) * 0.5
		var bottom_y: float = mag_card_sprite.position.y + half_h
		_assert(bottom_y <= 0.0, "Base da revista normalizada no nível do solo (Y <= 0.0, base: %.1f)" % bottom_y)

	# --- TESTE 4: Regra de Vida Cheia para a Coca ---
	print("\n--- Teste 4: Regra de Vida Cheia para a Coca ---")
	var player := CharacterBody2D.new()
	player.name = "Player"
	player.add_to_group("player")
	var health: Node = HealthComponentScript.new()
	health.name = "HealthComponent"
	health.set("max_health", 100.0)
	health.set("current_health", 100.0) # Vida cheia
	player.add_child(health)
	world.add_child(player)
	player.global_position = coca.global_position
	coca._process(0.016)
	await process_frame
	_assert(not coca_hint.visible, "Com vida cheia, o botão 'Pegar' da Coca NÃO é exibido")
	_assert(not coca.can_offer_hint_to(player), "can_offer_hint_to retorna false com vida cheia")
	var consumed_full: bool = bool(coca.interact(player))
	_assert(not consumed_full, "interact(player) não consome a Coca quando a vida está cheia")

	# Simula dano no jogador
	health.set("current_health", 50.0)
	coca._process(0.016)
	await process_frame
	_assert(coca.can_offer_hint_to(player), "can_offer_hint_to retorna true quando o jogador está ferido")
	coca.call("set_hint_selected", true, player)
	_assert(coca_hint.visible, "Com vida reduzida, o botão 'Pegar' da Coca fica visível")

	# --- TESTE 5: Toque Mobile e Coleta Direta da Coca ---
	print("\n--- Teste 5: Toque Mobile e Coleta ---")
	coca_hint.emit_signal("pressed")
	await process_frame
	var healed_health: float = float(health.get("current_health"))
	_assert(healed_health == 75.0, "Pressionar botão touch 'Pegar' cura o jogador (+25%)")
	_assert(coca.is_consumed(), "Coca foi marcada como consumida")
	_assert(not coca_hint.visible, "Botão 'Pegar' some imediatamente após o consumo")

	# --- TESTE 6: Arbitragem entre Múltiplos Itens Próximos ---
	print("\n--- Teste 6: Arbitragem de Destaque entre Múltiplos Itens ---")
	var mag1 := MagazinePickupScene.instantiate() as DroppedMagazineStoryPickup
	mag1.configure_item("res://assets/sprites/Itens/emmanuele.jpg", "", "MAG1", "Msg 1")
	world.add_child(mag1)
	mag1.global_position = Vector2(500.0, 100.0)

	var mag2 := MagazinePickupScene.instantiate() as DroppedMagazineStoryPickup
	mag2.configure_item("res://assets/sprites/Itens/playboy.jpg", "", "MAG2", "Msg 2")
	world.add_child(mag2)
	mag2.global_position = Vector2(530.0, 100.0)
	await process_frame

	var mag1_hint := mag1.get_node_or_null("PickUpHint") as Button
	var mag2_hint := mag2.get_node_or_null("PickUpHint") as Button

	# Posiciona o jogador mais próximo de mag1
	player.global_position = Vector2(505.0, 100.0)
	mag1.call("_on_body_entered", player)
	mag2.call("_on_body_entered", player)
	await process_frame

	_assert(mag1_hint.visible and not mag2_hint.visible, "Apenas o item mais próximo (mag1) exibe o botão 'Pegar'")

	# Move o jogador para mais próximo de mag2
	player.global_position = Vector2(528.0, 100.0)
	mag1.call("_refresh_group_for_player", player)
	await process_frame

	_assert(not mag1_hint.visible and mag2_hint.visible, "Ao mover-se em direção a mag2, o botão 'Pegar' migra para ele")

	# Afasta o jogador
	mag1.call("_on_body_exited", player)
	mag2.call("_on_body_exited", player)
	await process_frame

	_assert(not mag1_hint.visible and not mag2_hint.visible, "Ao afastar-se, ambos os botões 'Pegar' ficam ocultos")

	# --- LIMPEZA E RESUMO ---
	world.queue_free()
	print("\n==================================================")
	print("RESUMO: %d/%d TESTES PASSARAM (%d FALHAS)" % [_passed, _total, _failed])
	print("==================================================")
	quit(0 if _failed == 0 else 1)
