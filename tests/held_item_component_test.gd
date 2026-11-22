extends SceneTree

var _passed: int = 0
var _failed: int = 0
var _total: int = 0


func _assert(condition: bool, message: String) -> void:
	_total += 1
	if condition:
		_passed += 1
		print("  [OK] %s" % message)
	else:
		_failed += 1
		printerr("  [FALHA] %s" % message)


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var player := Node2D.new()
	player.name = "DummyPlayer"
	player.add_to_group("player")
	var visual := Node2D.new()
	visual.name = "Visual"
	player.add_child(visual)

	var frames := SpriteFrames.new()
	frames.add_animation(&"idle")
	var first_image := Image.create(220, 300, false, Image.FORMAT_RGBA8)
	first_image.fill(Color(0, 0, 0, 0))
	first_image.fill_rect(Rect2i(128, 148, 76, 94), Color(0.8, 0.4, 0.2, 1.0))
	var first_texture := ImageTexture.create_from_image(first_image)
	frames.add_frame(&"idle", first_texture)
	var second_image := Image.create(220, 300, false, Image.FORMAT_RGBA8)
	second_image.fill(Color(0, 0, 0, 0))
	second_image.fill_rect(Rect2i(128, 148, 76, 94), Color(0.2, 0.7, 0.9, 1.0))
	var second_texture := ImageTexture.create_from_image(second_image)
	frames.add_frame(&"idle", second_texture)

	var animated_sprite := AnimatedSprite2D.new()
	animated_sprite.name = "AnimatedSprite2D"
	animated_sprite.position = Vector2(0.0, -118.0)
	animated_sprite.scale = Vector2(0.8, 0.8)
	animated_sprite.sprite_frames = frames
	visual.add_child(animated_sprite)
	root.add_child(player)
	animated_sprite.play(&"idle")
	await process_frame

	var component: HeldItemComponent = HeldItemComponent.attach_to_player(player)
	_assert(component != null, "Componente pode ser anexado sob Player/Visual")
	_assert(component != null and component.get_parent() == visual, "Componente pertence ao ramo Visual e acompanha flip/depth scale")
	_assert(HeldItemComponent.attach_to_player(player) == component, "attach_to_player é idempotente e não duplica componentes")

	if component != null:
		component.set_character_id(&"guilherme")
		_assert(component.get_hand_anchor_offset() == Vector2(38.0, -104.0), "Socket de Guilherme mantém a altura e o ponto calibrado")
		_assert(component.get_grip_region() == Rect2i(128, 148, 76, 94), "Recorte de mão de Guilherme usa região do sprite oficial")
		component.set_character_id(&"gabriel")
		_assert(component.get_hand_anchor_offset() == Vector2(45.0, -136.0), "Socket de Gabriel é independente")
		_assert(component.get_grip_region() == Rect2i(112, 76, 102, 108), "Recorte de mão de Gabriel usa região independente")
		component.set_character_id(&"guilherme")

		var image := Image.create(16, 48, false, Image.FORMAT_RGBA8)
		image.fill(Color(0.6, 0.2, 0.1, 1.0))
		var texture := ImageTexture.create_from_image(image)
		_assert(component.equip_item(&"test_bottle", texture, Vector2(0.25, 0.25), Vector2(-8.0, 0.0)), "Componente equipa textura arbitrária com offset relativo à mão")
		_assert(component.is_holding_item(&"test_bottle"), "Componente identifica o item equipado")

		var sprite: Sprite2D = component.get_item_sprite()
		var overlay: Sprite2D = component.get_hand_overlay_sprite()
		_assert(sprite != null and sprite.texture == texture, "Sprite visual do item é reutilizado")
		_assert(sprite != null and sprite.position == Vector2(30.0, -104.0), "Offset aproxima o item da palma sem alterar sua altura")
		_assert(sprite != null and sprite.z_index == 0 and sprite.z_as_relative, "Item herda o mesmo plano Y-Sort do jogador; sem Z absoluto/negativo")
		_assert(overlay != null and overlay.visible, "Recorte da mão é desenhado por cima do item")
		_assert(overlay != null and overlay.z_index == 0 and overlay.z_as_relative, "Overlay da mão preserva a mesma camada Y-Sort")
		_assert(overlay != null and overlay.texture == first_texture, "Overlay usa o frame atual do AnimatedSprite2D")
		_assert(overlay != null and overlay.position.is_equal_approx(Vector2(44.8, -82.0)), "Recorte da mão fica alinhado ao transform do sprite do personagem")
		_assert(component.get_index() > animated_sprite.get_index(), "Componente é desenhado após o corpo: item primeiro, mão por cima")

		var sprite_instance_id: int = sprite.get_instance_id() if sprite != null else 0
		animated_sprite.frame = 1
		component.call("_process", 0.016)
		_assert(overlay != null and overlay.texture == second_texture, "Overlay acompanha a troca de frame durante a animação")

		var replacement_image := Image.create(16, 16, false, Image.FORMAT_RGBA8)
		replacement_image.fill(Color(0.1, 0.4, 0.8, 1.0))
		var replacement_texture := ImageTexture.create_from_image(replacement_image)
		_assert(component.equip_item(&"test_weapon", replacement_texture, Vector2.ONE), "Novo equipamento substitui o anterior sem duplicar Sprite2D")
		_assert(sprite != null and sprite.get_instance_id() == sprite_instance_id and sprite.texture == replacement_texture, "A mesma instância visual é reutilizada entre itens")
		_assert(not component.unequip_item(&"test_bottle"), "Item não relacionado não consegue limpar o equipamento atual")
		_assert(component.unequip_item(&"test_weapon"), "Item pode ser removido explicitamente")
		_assert(not component.is_holding_item() and not overlay.visible, "Ao desequipar, item e recorte da mão ficam ocultos")

	player.queue_free()
	print("HeldItemComponent: %d/%d aprovados; %d falhas." % [_passed, _total, _failed])
	quit(0 if _failed == 0 else 1)
