extends SceneTree
func _init():
    var path = 'res://assets/ui/character_select/stats_guilherme.png'
    var global_p = ProjectSettings.globalize_path(path)
    var img = Image.load_from_file(global_p)
    print('Image loaded:', img)
    if img != null:
        var tex = ImageTexture.create_from_image(img)
        print('ImageTexture created:', tex, 'size:', tex.get_size())
    quit(0)
