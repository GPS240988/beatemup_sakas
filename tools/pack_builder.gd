# tools/pack_builder.gd
extends SceneTree

## Ferramenta Oficial de Empacotamento Modular (Multi-PCK) do Projeto Sakas.
## Executada via CLI Headless:
##   godot_console.exe --headless -s tools/pack_builder.gd
##
## Responsável por:
## 1. Mapear os recursos por domínio (áudio, cinemáticas, mapas).
## 2. Resolver dependências importadas (.ctex, .mp3str, .import).
## 3. Empacotar via PCKPacker nativo de alta performance.
## 4. Validar o teto rígido de segurança de 45 MB por arquivo.
## 5. Gerar manifest.json com tamanhos e hashes para a Vercel/PWA.

const OUTPUT_DIR: String = "public/packs"
const MAX_PACK_BUDGET_BYTES: int = 45 * 1024 * 1024 # 45 MB

const PACK_DEFINITIONS: Dictionary = {
	"audio_bgm": {
		"file_name": "pack_audio_bgm.pck",
		"description": "Trilhas Sonoras BGM (Fase 1)",
		"sources": [
			"res://assets/audio/bgm/Menu.mp3",
			"res://assets/audio/bgm/Historia.mp3",
			"res://assets/audio/bgm/M_1_2 - Estágio 1.mp3",
			"res://assets/audio/bgm/M_3_4 - Estágio 1.mp3",
			"res://assets/audio/bgm/bonus_1.mp3"
		],
		"dirs": []
	},
	"story_cinematics": {
		"file_name": "pack_story_cinematics.pck",
		"description": "Cinemáticas e Ilustrações Narrativas HD",
		"sources": [
			"res://assets/backgrounds/intro_cena02.webp",
			"res://assets/backgrounds/intro_cena03.webp",
			"res://assets/backgrounds/intro_cena04.webp",
			"res://assets/backgrounds/intro_cena05.webp",
			"res://assets/backgrounds/intro_cena06.webp",
			"res://assets/backgrounds/intro_cena07.webp"
		],
		"dirs": [
			"res://assets/story"
		]
	},
	"stage1": {
		"file_name": "pack_stage1.pck",
		"description": "Cenários, Vídeos e Backgrounds do Estágio 1",
		"sources": [
			"res://assets/videos/stage1/video_fase1_3_andre.ogv",
			"res://assets/videos/stage1/video_fase1_3_juliana.ogv"
		],
		"dirs": [
			"res://assets/backgrounds/maps"
		]
	}
}


func _init() -> void:
	print("\n" + "=" . repeat(70))
	print(" SAKAS MULTI-PCK BUILDER - GODOT ENGINE 4.x")
	print("=" . repeat(70))

	# Garante que o diretório de saída exista
	if not DirAccess.dir_exists_absolute(OUTPUT_DIR):
		DirAccess.make_dir_recursive_absolute(OUTPUT_DIR)

	var manifest: Dictionary = {
		"generated_at": Time.get_datetime_string_from_system(true, true),
		"packs": {}
	}

	var all_ok: bool = true

	for pack_id in PACK_DEFINITIONS.keys():
		var success: bool = _build_pack(pack_id, PACK_DEFINITIONS[pack_id], manifest)
		if not success:
			all_ok = false

	# Salva o manifesto JSON
	var manifest_path: String = OUTPUT_DIR.path_join("manifest.json")
	var manifest_file = FileAccess.open(manifest_path, FileAccess.WRITE)
	if manifest_file:
		manifest_file.store_string(JSON.stringify(manifest, "\t"))
		manifest_file.close()
		print("\n[OK] Manifesto gerado com sucesso em: %s" % manifest_path)
	else:
		push_error("Falha ao salvar manifesto em: %s" % manifest_path)
		all_ok = false

	print("=" . repeat(70))
	if all_ok:
		print(" EMPACOTAMENTO MODULAR CONCLUÍDO COM SUCESSO! ")
	else:
		push_error(" Ocorreram erros durante o empacotamento modular!")
	print("=" . repeat(70) + "\n")

	quit(0 if all_ok else 1)


func _build_pack(pack_id: String, def: Dictionary, manifest: Dictionary) -> bool:
	var file_name: String = def["file_name"]
	var target_path: String = OUTPUT_DIR.path_join(file_name)
	print("\n-> Processando pacote [%s] -> %s" % [pack_id, target_path])

	# 1. Coleta todos os arquivos fonte
	var files_to_pack: Array[String] = []

	# Arquivos explícitos
	for src in def.get("sources", []):
		if FileAccess.file_exists(src) and not files_to_pack.has(src):
			files_to_pack.append(src)

	# Diretórios
	for dir_path in def.get("dirs", []):
		_collect_files_recursive(dir_path, files_to_pack)

	print("   Arquivos fonte selecionados: %d" % files_to_pack.size())

	if files_to_pack.is_empty():
		push_warning("   [AVISO] Nenhum arquivo encontrado para o pacote: %s" % pack_id)
		return true

	# 2. Inicializa o PCKPacker
	var packer = PCKPacker.new()
	var err = packer.pck_start(target_path, 32)
	if err != OK:
		push_error("   [ERRO] Falha ao iniciar PCKPacker para %s (Erro: %d)" % [target_path, err])
		return false

	var packed_items_count: int = 0
	var added_dest_files: Array[String] = []

	for res_path in files_to_pack:
		var relative_path: String = res_path.replace("res://", "")

		# Empacota o arquivo fonte bruto (se existir e não for ignorado)
		if FileAccess.file_exists(res_path):
			packer.add_file(res_path, relative_path)
			packed_items_count += 1

		# Verifica se possui arquivo .import correspondente
		var import_path: String = res_path + ".import"
		if FileAccess.file_exists(import_path):
			packer.add_file(import_path, import_path.replace("res://", ""))
			packed_items_count += 1

			# Lê o arquivo .import para descobrir os arquivos importados (.ctex, .mp3str, etc)
			var cfg = ConfigFile.new()
			if cfg.load(import_path) == OK:
				var dest_files = cfg.get_value("deps", "dest_files", [])
				for df in dest_files:
					var df_str: String = String(df)
					if not added_dest_files.has(df_str) and FileAccess.file_exists(df_str):
						packer.add_file(df_str, df_str.replace("res://", ""))
						added_dest_files.append(df_str)
						packed_items_count += 1

	# Finaliza o arquivo PCK
	var flush_err = packer.flush(true)
	if flush_err != OK:
		push_error("   [ERRO] Falha ao finalizar o PCK: %s (Erro: %d)" % [target_path, flush_err])
		return false

	# 3. Validação de tamanho e teto de orçamento
	var file = FileAccess.open(target_path, FileAccess.READ)
	if not file:
		push_error("   [ERRO] Não foi possível verificar o arquivo gerado: %s" % target_path)
		return false

	var size_bytes: int = file.get_length()
	var size_mb: float = float(size_bytes) / (1024.0 * 1024.0)
	var md5: String = FileAccess.get_md5(target_path)
	file.close()

	print("   Itens gravados no PCK: %d (incluindo metadados e streams importadas)" % packed_items_count)
	print("   Tamanho final gerado: %.2f MB (%d bytes)" % [size_mb, size_bytes])

	if size_bytes > MAX_PACK_BUDGET_BYTES:
		push_error("   [ALERTA DE SEGURANÇA] O pacote %s excedeu o teto de 45 MB! Tamanho: %.2f MB" % [file_name, size_mb])
		return false
	else:
		print("   [SUCESSO] Pacote validado com margem de segurança segura (< 45 MB)!")

	# Registra no manifesto
	manifest["packs"][pack_id] = {
		"file_name": file_name,
		"path": "packs/" + file_name,
		"size_bytes": size_bytes,
		"size_mb": round(size_mb * 100.0) / 100.0,
		"md5": md5,
		"items_count": packed_items_count
	}

	return true


func _collect_files_recursive(dir_path: String, output: Array[String]) -> void:
	var dir = DirAccess.open(dir_path)
	if not dir:
		return

	dir.list_dir_begin()
	var file_name = dir.get_next()
	while file_name != "":
		if file_name.begins_with("."):
			file_name = dir.get_next()
			continue

		var full_path = dir_path.path_join(file_name)
		if dir.current_is_dir():
			if file_name != "_raw_originals" and file_name != "_raw_backup":
				_collect_files_recursive(full_path, output)
		else:
			if not file_name.ends_with(".import") and not output.has(full_path):
				output.append(full_path)

		file_name = dir.get_next()
	dir.list_dir_end()

