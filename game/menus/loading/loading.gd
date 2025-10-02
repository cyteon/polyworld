extends Control

var progress: Array[int] = [0]
var connected: bool = false
var failed: bool = false

func _ready() -> void:
	ResourceLoader.load_threaded_request("res://world/world.tscn")
	
	multiplayer.connected_to_server.connect(func():
		print("[Loading] Connected to server")
		
		var auth_ticket: Dictionary = Steam.getAuthSessionTicket()
		
		if len(auth_ticket.keys()) == 0:
			print("[Loading] Steam authentication ticket is empty, connection will work if server does not require authentication")
		else:
			print("[Loading] Generated steam authentication ticket")
		
		Network.rpc_id(
			get_multiplayer_authority(),
			"_authenticate", 
			Steamworks.steam_id,
			Steamworks.steam_username,
			auth_ticket
		)
	)
	
	multiplayer.connection_failed.connect(func(): 
		print("[Loading] Connection to server failed")
		
		Network.peer.close()
		failed = true
		
		$ErrorScreen.show()
		$ProgressBar.hide()
		$ErrorScreen/VBoxContainer/Message.text = "Connection to server failed for an unknown reason"
	)
	
	Network.disconnect.connect(func(reason: String):
		print("[Loading] Connection to server failed: %s" % reason)
		
		Network.peer.close()
		failed = true
		
		$ErrorScreen.show()
		$ProgressBar.hide()
		$ErrorScreen/VBoxContainer/Message.text = reason
	)
	
	Network.authenticated.connect(func():
		print("[Loading] Authentication succesfull")
		
		connected = true
	)

func _process(delta: float) -> void:
	if failed: return
	
	var status = ResourceLoader.load_threaded_get_status("res://world/world.tscn", progress)
	
	match status:
		ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
			print("[Loading] THREAD_LOAD_INVALID_RESOURCE")
			
			Network.peer.close()
			failed = true
			
			$ErrorScreen.show()
			$ProgressBar.hide()
			$ErrorScreen/VBoxContainer/Message.text = "Failed to load resources"
		ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			$ProgressBar.value = progress[0]
		ResourceLoader.THREAD_LOAD_FAILED:
			print("[Loading] THREAD_LOAD_FAILED")
			
			Network.peer.close()
			failed = true
			
			$ErrorScreen.show()
			$ProgressBar.hide()
			$ErrorScreen/VBoxContainer/Message.text = "Failed to load resources"
		ResourceLoader.THREAD_LOAD_LOADED:
			$ProgressBar.value = 0.98
			if not connected: return
			
			print("[Loading] Finished loading")
			
			get_tree().change_scene_to_packed(ResourceLoader.load_threaded_get("res://world/world.tscn"))


func _on_reconnect_button_pressed() -> void:
	ResourceLoader.load_threaded_request("res://world/world.tscn")
	
	failed = false
	$ErrorScreen.hide()
	$ProgressBar.show()
	
	var res = Network.peer.create_client(
		Network.server_host, Network.server_port
	)
	
	if res == OK:
		multiplayer.multiplayer_peer = Network.peer
	else:
		$ErrorScreen.show()
		$ProgressBar.hide()
		$ErrorScreen/VBoxContainer/Message.text = "Failed to create connection"

func _on_return_button_pressed() -> void:
	get_tree().change_scene_to_file("res://menus/main/main.tscn")
