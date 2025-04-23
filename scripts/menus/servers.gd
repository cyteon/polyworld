extends Control

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	_on_refresh_button_pressed()

func _on_refresh_button_pressed() -> void:
	for child in $VBoxContainer/ScrollContainer/ServerList.get_children():
		if child.name != "Template":
			child.free()
	
	var secure_only: bool = $VBoxContainer/FilterSettings/SecureOnly.button_pressed
	var unsecure_only: bool = $VBoxContainer/FilterSettings/UnsecureOnly.button_pressed
	var exclude_full: bool = $VBoxContainer/FilterSettings/ExcludeFull.button_pressed
	var exclude_empty: bool = $VBoxContainer/FilterSettings/ExcludeEmpty.button_pressed
	
	var path: String = "%s/api/servers?secure_only=%s&unsecure_only=%s&exclude_full=%s&exclude_empty=%s" % [
			Network.backend_url, secure_only, unsecure_only, exclude_full, exclude_empty
	]
	
	$HTTPRequest.request(path)

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
		var node = $VBoxContainer/ScrollContainer/ServerList/Template.duplicate()
		node.name = str(randi())
		
		$VBoxContainer/ScrollContainer/ServerList.add_child(node)
		
		node.show()
		
		node.get_node("Name").text = server.name
		node.get_node("Players").text = "%s/%s players" % [int(server.players), int(server.max_players)]
		node.get_node("Secure").text = "Secure" if server.secure else "Unsecure"
		
		if int(server.players) >= int(server.max_players) or server.compatability_ver != Network.compatability_ver:
			node.get_node("Button").disabled = true
		
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


func _on_secure_only_toggled(toggled_on: bool) -> void:
	if toggled_on:
		$VBoxContainer/FilterSettings/UnsecureOnly.button_pressed = false


func _on_unsecure_only_toggled(toggled_on: bool) -> void:
	if toggled_on:
		$VBoxContainer/FilterSettings/SecureOnly.button_pressed = false


func _on_exclude_full_toggled(toggled_on: bool) -> void:
	if toggled_on:
		$VBoxContainer/FilterSettings/ExcludeEmpty.button_pressed = false


func _on_exclude_empty_toggled(toggled_on: bool) -> void:
	if toggled_on:
		$VBoxContainer/FilterSettings/ExcludeFull.button_pressed = false
