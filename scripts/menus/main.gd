extends Control

var ip: String = "127.0.0.1"
var port: int = 4040

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

func _on_connect_button_pressed() -> void:
	$PopupPanel.show()

func _on_connect_button_final_pressed() -> void:
	print("[Client] Connecting to server")
	
	var network = ENetMultiplayerPeer.new()
	var err = network.create_client(ip, port)
	multiplayer.multiplayer_peer = network
	
	if err == OK:
		print("[Client] Created network client")
		get_tree().change_scene_to_file("res://scenes/menus/loading.tscn")
	else:
		print("[Client] Could not connect to server")

func _on_port_edit_value_changed(value: float) -> void:
	port = value


func _on_ip_edit_text_changed(new_text: String) -> void:
	ip = new_text

func _on_quit_button_pressed() -> void:
	get_tree().quit()

func _on_credits_button_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/menus/credits.tscn")


func _on_servers_button_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/menus/servers.tscn")
