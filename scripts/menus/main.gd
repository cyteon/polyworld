extends Control

func _ready() -> void:
	$Version.text = ProjectSettings.get_setting("application/config/version")
	
	for arg in OS.get_cmdline_args():
		if arg.find("=") > -1:
			var key = arg.split("=")[0].lstrip("--")
			var value = arg.split("=")[1].lstrip("\"").rstrip("\"")
			
			match key:
				"join":
					var host = value.split(":")[0]
					var portArg = value.split(":")[1]
					
					if portArg.is_valid_int():
						portArg
						print("[Client] --join was passed, joining server...")
	
						var network = ENetMultiplayerPeer.new()
						var err = network.create_client(host, portArg.to_int())
						multiplayer.multiplayer_peer = network
						
						if err == OK:
							print("[Client] Created network client")
							get_tree().change_scene_to_file("res://scenes/menus/loading.tscn")
						else:
							print("[Client] Could not connect to server")

func _on_ping_server_button_pressed() -> void:
	$PopupPanel/VBoxContainer/PingError.hide()
	$PopupPanel/VBoxContainer/ServerDetailsRow1.hide()
	$PopupPanel/VBoxContainer/ServerDetailsRow2.hide()
	$PopupPanel.size.y = 300
	
	var data: Dictionary = Network.ping_server(
		$PopupPanel/VBoxContainer/IPEdit.text,
		$PopupPanel/VBoxContainer/PortEdit.value + 1
	)
	
	if len(data.keys()) == 0:
		$PopupPanel/VBoxContainer/PingError.show()
	else:
		$PopupPanel/VBoxContainer/ServerDetailsRow1/ServerName.text = "Name: " + data.name
		$PopupPanel/VBoxContainer/ServerDetailsRow1/Ping.text = "Ping: %sms" % data.ping
		$PopupPanel/VBoxContainer/ServerDetailsRow2/Secure.text = "Secure? " + ("Yes" if data.secure else "No")
		$PopupPanel/VBoxContainer/ServerDetailsRow2/MaxPlayers.text = "Max Players: %s" % data.max_players
		
		$PopupPanel/VBoxContainer/ServerDetailsRow1.show()
		$PopupPanel/VBoxContainer/ServerDetailsRow2.show()
		$PopupPanel/VBoxContainer/PingError.hide()

func _on_connect_button_pressed() -> void:
	$PopupPanel.show()

func _on_actual_connect_button_pressed() -> void:
	print("[Client] Connecting to server")
	
	var network = ENetMultiplayerPeer.new()
	
	var err = network.create_client(
		$PopupPanel/VBoxContainer/IPEdit.text, 
		$PopupPanel/VBoxContainer/PortEdit.value
	)
	
	multiplayer.multiplayer_peer = network
	
	if err == OK:
		print("[Client] Created network client")
		get_tree().change_scene_to_file("res://scenes/menus/loading.tscn")
	else:
		print("[Client] Could not create network client")

func _on_quit_button_pressed() -> void:
	get_tree().quit()

func _on_credits_button_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/menus/credits.tscn")

func _on_servers_button_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/menus/servers.tscn")
