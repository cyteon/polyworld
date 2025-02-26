extends Control

func _ready() -> void:
	var label = $ScrollContainer/Label
	
	var license = FileAccess.open("res://LICENSE", FileAccess.READ).get_as_text()
	
	label.text += license
	label.text += "\n\n# -- This game was CREATED using the Godot Game Engine -- #\n"
	label.text += "# -- Below is a copy of the godot license -- #\n\n"
	
	var godot_license = FileAccess.open("res://GODOT_COPYRIGHT.txt", FileAccess.READ).get_as_text()
	label.text += godot_license


func _on_home_button_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/menus/main.tscn")
