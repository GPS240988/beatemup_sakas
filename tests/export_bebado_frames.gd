extends SceneTree

func _init() -> void:
	var path = "res://assets/sprites/characters/inimigos/bebado/bebado_grid_sheet.png"
	var img = Image.new()
	img.load(path)

	# As 44 regiões encontradas com bounding boxes limpas
	var rows_data = [
		# Row 0 (9 frames)
		[
			Rect2i(35, 18, 97, 179), Rect2i(197, 23, 95, 177), Rect2i(366, 23, 92, 179),
			Rect2i(513, 22, 113, 179), Rect2i(672, 23, 111, 181), Rect2i(826, 22, 107, 182),
			Rect2i(993, 23, 110, 185), Rect2i(1172, 23, 114, 181), Rect2i(1383, 20, 106, 184)
		],
		# Row 1 (9 frames)
		[
			Rect2i(25, 240, 103, 161), Rect2i(193, 243, 117, 159), Rect2i(349, 242, 119, 159),
			Rect2i(511, 242, 170, 159), Rect2i(672, 239, 144, 163), Rect2i(833, 242, 138, 159),
			Rect2i(1011, 246, 113, 159), Rect2i(1186, 243, 133, 170), Rect2i(1363, 268, 131, 153)
		],
		# Row 2 (8 frames)
		[
			Rect2i(17, 449, 133, 158), Rect2i(188, 460, 128, 149), Rect2i(364, 463, 148, 149),
			Rect2i(622, 465, 212, 138), Rect2i(893, 431, 166, 177), Rect2i(1101, 464, 128, 155),
			Rect2i(1274, 465, 107, 154), Rect2i(1416, 464, 104, 158)
		],
		# Row 3 (9 frames)
		[
			Rect2i(9, 649, 154, 152), Rect2i(202, 654, 125, 145), Rect2i(358, 663, 103, 135),
			Rect2i(502, 691, 131, 109), Rect2i(648, 709, 155, 87), Rect2i(841, 728, 217, 68),
			Rect2i(1084, 707, 147, 91), Rect2i(1242, 727, 145, 69), Rect2i(1387, 720, 131, 71)
		],
		# Row 4 (9 frames)
		[
			Rect2i(36, 846, 125, 153), Rect2i(208, 855, 133, 138), Rect2i(387, 842, 128, 152),
			Rect2i(547, 836, 114, 159), Rect2i(709, 848, 111, 148), Rect2i(876, 840, 112, 162),
			Rect2i(1049, 840, 90, 162), Rect2i(1222, 830, 101, 171), Rect2i(1386, 839, 100, 164)
		]
	]

	DirAccess.make_dir_recursive_absolute("res://tests/temp_bebado_frames")

	for r in range(rows_data.size()):
		for s in range(rows_data[r].size()):
			var rect: Rect2i = rows_data[r][s]
			var sub_img = img.get_region(rect)
			var fname = "res://tests/temp_bebado_frames/r%d_s%d.png" % [r, s]
			sub_img.save_png(fname)

	print("Exported all 44 frames to tests/temp_bebado_frames/!")
	quit(0)
