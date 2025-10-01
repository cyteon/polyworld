extends Control

func _on_connect_button_pressed() -> void:
	$ServerConnectMenu.show()

func _on_settings_button_pressed() -> void:
	pass # Replace with function body.

func _on_quit_button_pressed() -> void:
	get_tree().quit()

func _on_query_button_pressed() -> void:
	$ServerConnectMenu/VBoxContainer/ServerInfo/Grid.hide()
	
	var result = Steamworks.ping_server(
		$ServerConnectMenu/VBoxContainer/ServerAddress/LineEdit.text,
		$ServerConnectMenu/VBoxContainer/ServerPort/SpinBox.value + 1
	)
	
	$ServerConnectMenu/VBoxContainer/ServerInfo/Grid/Ping/Value.text = "%sms" % result.ping
	$ServerConnectMenu/VBoxContainer/ServerInfo/Grid/PlayerCount/Value.text = "%s/%s" % [
		result.players, result.max_players
	]
	$ServerConnectMenu/VBoxContainer/ServerInfo/Grid/Version/Value.text = result.version
	$ServerConnectMenu/VBoxContainer/ServerInfo/Grid/Secure/Value.text = "yes" if result.vac else "no"
	
	$ServerConnectMenu/VBoxContainer/ServerInfo/Grid.show()

func _on_final_connect_button_2_pressed() -> void:
	pass # Replace with function body.
