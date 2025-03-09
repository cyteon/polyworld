extends Control

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	_on_refresh_button_pressed()

func _on_refresh_button_pressed() -> void:
	for child in $ScrollContainer/ServerList.get_children():
		if child.name != "Template":
			child.free()
	
	$HTTPRequest.request("%s/api/servers" % Network.backend_url)

func _request_completed(
	result: int, 
	_response_code: int, 
	_headers: PackedStringArray, 
	body: PackedByteArray
) -> void:
	if result != OK:
		return
	
	var json = JSON.parse_string(body.get_string_from_utf8())
	
	for server in json:
		var node = $ScrollContainer/ServerList/Template.duplicate()
		node.name = str(randi())
		
		$ScrollContainer/ServerList.add_child(node)
		
		node.show()
		
		node.get_node("Name").text = server.name
		node.get_node("Players").text = "%s/%s Players" % [int(server.players), int(server.max_players)]
		node.get_node("Button").pressed.connect(func():
			print("[Client] Connecting to server")

			var network = ENetMultiplayerPeer.new()
			var err = network.create_client(server.host, server.port)
			multiplayer.multiplayer_peer = network
			
			if err == OK:
				print("[Client] Created network client")
				get_tree().change_scene_to_file("res://scenes/menus/loading.tscn")
			else:
				print("[Client] Could not connect to server")
		)

func _on_back_button_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/menus/main.tscn")
