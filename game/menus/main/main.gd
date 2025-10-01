extends Control

func _on_connect_button_pressed() -> void:
	$ServerConnectMenu.show()

func _on_settings_button_pressed() -> void:
	pass # Replace with function body.

func _on_quit_button_pressed() -> void:
	get_tree().quit()

func _on_query_button_pressed() -> void:
	var result = Steamworks.ping_server(
		$ServerConnectMenu/VBoxContainer/ServerAddress/LineEdit.text,
		$ServerConnectMenu/VBoxContainer/ServerPort/SpinBox.value + 1
	)
	
	print(result)

func _on_final_connect_button_2_pressed() -> void:
	pass # Replace with function body.
