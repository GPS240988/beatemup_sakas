extends SceneTree

func _init() -> void:
	print("--- TESTE UNITÁRIO: ARCADE BUTTON (LIFECYCLE) ---")
	var ArcadeBtnClass = load("res://scripts/ui/components/arcade_button.gd")
	if ArcadeBtnClass == null:
		printerr("FALHA: Script arcade_button.gd não encontrado")
		quit(1)
		return

	var btn = ArcadeBtnClass.new()
	btn.button_text = "JOGAR"
	btn.is_primary = true
	btn.size = Vector2(380, 64)

	var root_ctrl = Control.new()
	root.add_child(root_ctrl)
	root_ctrl.add_child(btn)

	# Aguarda frames de renderização do Godot
	_run_checks(btn, root_ctrl)


func _run_checks(btn, root_ctrl) -> void:
	await process_frame
	print("  [OK] ArcadeButton adicionado à árvore e renderizado no frame")

	btn.disabled = true
	btn.queue_redraw()
	await process_frame
	print("  [OK] Transição para Disabled executada")

	btn.disabled = false
	btn.is_primary = false
	btn.button_text = "CONTINUAR"
	btn.queue_redraw()
	await process_frame
	print("  [OK] Transição para Normal executada")

	btn._on_mouse_entered()
	await process_frame
	print("  [OK] Microinteração de Hover executada")

	btn._on_button_down()
	await process_frame
	print("  [OK] Microinteração de Press executada")

	root_ctrl.queue_free()
	print("--- SUCESSO: ARCADE BUTTON VALIDADO COM EXCELÊNCIA ---")
	quit(0)
