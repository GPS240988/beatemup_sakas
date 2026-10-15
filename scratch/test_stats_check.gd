extends SceneTree
func _init():
    var s = load('res://scenes/ui/character_select.tscn').instantiate()
    root.add_child(s)
    await process_frame
    print('Current hover:', s.current_hover_id)
    var tex = s.stats_texture_rect.texture
    print('Stats texture size:', tex.get_size() if tex else 'null')
    quit(0)
