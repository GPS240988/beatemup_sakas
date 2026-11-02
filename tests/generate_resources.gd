extends SceneTree

func _init() -> void:
	print("--- Gerando Recursos Godot (SpriteFrames) ---")
	_generate_magic_frames()
	_generate_vfx_frames()
	print("--- Concluído com Sucesso ---")
	quit(0)

func _generate_magic_frames() -> void:
	var frames := SpriteFrames.new()
	var base_path := "res://assets/sprites/characters/inimigos/jogador de magic/"

	# Definição de animações e seus arquivos
	var anim_defs := {
		"idle": {"loop": true, "speed": 5.0, "files": ["walk1.png"]},
		"walk": {"loop": true, "speed": 8.0, "files": ["walk1.png", "walk2.png", "walk3.png", "walk4.png"]},
		"punch": {"loop": false, "speed": 10.0, "files": ["punch_01.png", "punch_02.png", "punch_03.png"]},
		"kick": {"loop": false, "speed": 10.0, "files": ["kick_01.png", "kick_02.png", "kick_03.png"]},
		"heavy": {"loop": false, "speed": 8.0, "files": ["heavy_01.png", "heavy_02.png", "heavy_03.png"]},
		"guard": {"loop": false, "speed": 5.0, "files": ["guard.png"]},
		"hurt": {"loop": false, "speed": 8.0, "files": ["hurt_01.png", "hurt_02.png"]},
		"fall": {"loop": false, "speed": 8.0, "files": ["fall_01.png", "fall_02.png", "fall_03.png"]},
		"downed": {"loop": false, "speed": 5.0, "files": ["fall_03.png"]},
		"getup": {"loop": false, "speed": 7.0, "files": ["getup_01.png", "getup_02.png"]},
		"death": {"loop": false, "speed": 5.0, "files": ["death.png"]},
		"jump_atk": {"loop": false, "speed": 8.0, "files": ["jump_atk_01.png", "jump_atk_02.png"]}
	}

	# Remove a animação padrão "default" se existir
	if frames.has_animation("default"):
		frames.remove_animation("default")

	for anim_name: String in anim_defs.keys():
		var data: Dictionary = anim_defs[anim_name]
		frames.add_animation(anim_name)
		frames.set_animation_loop(anim_name, data["loop"])
		frames.set_animation_speed(anim_name, data["speed"])

		for file_name: String in data["files"]:
			var tex_path: String = base_path + file_name
			var tex := load(tex_path) as Texture2D
			if tex == null:
				printerr("ERRO: Nao foi possivel carregar: ", tex_path)
			else:
				frames.add_frame(anim_name, tex)

	var target_path := "res://scenes/actors/enemies/jogador_de_magic_frames.tres"
	var err := ResourceSaver.save(frames, target_path)
	if err == OK:
		print("  [OK] Gerado com sucesso: ", target_path)
	else:
		printerr("  [ERRO] Falha ao salvar: ", target_path, " cod=", err)

func _generate_vfx_frames() -> void:
	# Cria diretório scenes/vfx se não existir
	var dir := DirAccess.open("res://scenes")
	if dir != null and not dir.dir_exists("vfx"):
		dir.make_dir("vfx")

	var frames := SpriteFrames.new()
	var base_path := "res://assets/sprites/Efeitos/"

	if frames.has_animation("default"):
		frames.remove_animation("default")

	var vfx_defs := {
		"impacto": {"loop": false, "speed": 22.0, "pattern": "impacto%d.png", "count": 9},
		"impactoazul": {"loop": false, "speed": 22.0, "pattern": "impactoazul%d.png", "count": 9},
		"combinado": {"loop": false, "speed": 20.0, "pattern": "combinado%d.png", "count": 7},
		"estrelas": {"loop": true, "speed": 12.0, "pattern": "estrelas%d.png", "count": 7},
		"poeira": {"loop": false, "speed": 18.0, "pattern": "poeira%d.png", "count": 6}
	}

	for anim_name: String in vfx_defs.keys():
		var data: Dictionary = vfx_defs[anim_name]
		frames.add_animation(anim_name)
		frames.set_animation_loop(anim_name, data["loop"])
		frames.set_animation_speed(anim_name, data["speed"])

		var pattern: String = data["pattern"]
		var count: int = data["count"]
		for i in range(1, count + 1):
			var file_name: String = pattern % i
			var tex_path: String = base_path + file_name
			var tex := load(tex_path) as Texture2D
			if tex == null:
				printerr("ERRO VFX: Nao foi possivel carregar: ", tex_path)
			else:
				frames.add_frame(anim_name, tex)

	var target_path := "res://scenes/vfx/hit_effects_frames.tres"
	var err := ResourceSaver.save(frames, target_path)
	if err == OK:
		print("  [OK] Gerado com sucesso: ", target_path)
	else:
		printerr("  [ERRO] Falha ao salvar VFX: ", target_path, " cod=", err)
