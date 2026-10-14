extends SceneTree

func _init() -> void:
	var stream = load("res://scratch/test_theora.ogv")
	print("Loaded ogv yuv420p: ", stream)
	var vp = VideoStreamPlayer.new()
	vp.stream = stream
	vp.play()
	root.add_child(vp)
	# Wait a few frames
	for i in range(10):
		await process_frame
	var tex = vp.get_video_texture()
	print("Video texture: ", tex)
	if tex != null:
		var img = tex.get_image()
		if img != null:
			img.save_png("scratch/test_video_captured_frame.png")
			print("Saved captured video frame successfully!")
	quit(0)
