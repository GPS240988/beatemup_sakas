extends SceneTree

func _init() -> void:
	var sec_select_res := load("res://scenes/ui/components/stage_section_select.tscn")
	var sec_select = sec_select_res.instantiate()
	root.add_child(sec_select)
	var vbox = sec_select.get_node_or_null("CenterContainer/PanelContainer/Margin/MainVBox/ButtonsVBox")
	print("VBox direct path: ", vbox)
	print("ButtonsVBox onready: ", sec_select.buttons_vbox)
	quit(0)
