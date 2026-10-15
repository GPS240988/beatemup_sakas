extends SceneTree
func _init():
    var s = load('res://scenes/ui/character_select.tscn').instantiate()
    root.add_child(s)
    await process_frame
    print('Initial (Guilherme):', s.current_hover_id, s.stat_forca_label.text)
    s._select_character_by_index(1, false) # Gabriel
    print('Hover 1 (Gabriel):', s.current_hover_id, s.stat_forca_label.text)
    s._select_character_by_index(0, false) # Back to Guilherme
    print('Hover 0 (Guilherme):', s.current_hover_id, s.stat_forca_label.text)
    quit(0)
