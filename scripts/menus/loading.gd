extends Control

var progress: Array[int] = [0]

var connected: bool = false

func _ready() -> void:
	ResourceLoader.load_threaded_request("res://scenes/world.tscn")
	
	multiplayer.connected_to_server.connect(func(): 
		print("[Client] Connection established")
		
		if len(Steam.getAuthSessionTicket().keys()) == 0:
			multiplayer.multiplayer_peer.close()
			$TimeoutConfirmed.stop()

			$Label.text = "Unable to authenticate"
			$Details/Label.text = "Generating steam authentication ticket failed\nIs steam running?"
			$Details.show()
			$ProgressBar.hide()
		
		Network.rpc_id(
			get_multiplayer_authority(),
			"_authenticate", 
			Steamworks.steam_id,
			Steamworks.steam_username,
			Steam.getAuthSessionTicket()
		)
		
		$Label.text = "Connected to server :D... Authenticating"
	)
	
	multiplayer.connection_failed.connect(func(): 
		$TimeoutConfirmed.stop()
		
		print("[Client] Connection to server failed :(")
		$Label.text = "Failed to connect :("
		
		multiplayer.multiplayer_peer.close()
		$TimeoutConfirmed.stop()
		
		$Details.show()
		$ProgressBar.hide()
	)
	
	Network.disconnected.connect(func(reason, details):
		connected = false
		
		$Label.text = "Failed to connect to server: %s" % reason
		
		multiplayer.multiplayer_peer.close()
		$TimeoutConfirmed.stop()
		
		$Details.show()
		$Details/Label.text = details
		$ProgressBar.hide()
	)
	
	Network.authentication_ok.connect(func(secure: bool):
		Network.server_is_sccure = secure
		
		connected = true
		print("[Client] Authentication finished, loading...")
	)
	
	$FunnyMessages.text = General.FUNNY_MESSAGES.pick_random()

func _process(_delta: float) -> void:
	var status = ResourceLoader.load_threaded_get_status("res://scenes/world.tscn", progress)
	
	match status:
		ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
			print("[Client] THREAD_LOAD_INVALID_RESOURCE")
			$Label.text = "Connected to server :D... Failed to load"
			
			multiplayer.multiplayer_peer.close()
			$TimeoutConfirmed.stop()
			
			$Details.show()
			$ProgressBar.hide()
		ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			$ProgressBar.value = progress[0]
		ResourceLoader.THREAD_LOAD_FAILED:
			print("[Client] THREAD_LOAD_FAILED")
			$Label.text = "Connected to server :D... Failed to load"
			
			multiplayer.multiplayer_peer.close()
			$TimeoutConfirmed.stop()
			
			$Details.show()
			$ProgressBar.hide()
		ResourceLoader.THREAD_LOAD_LOADED:
			if not connected: return
			#if len(Network.player_ids_to_spawn_on_world_entry) == 0:
				#$ProgressBar.value = 98
				#return
			
			$ProgressBar.value = 0.98
			
			get_tree().change_scene_to_packed(ResourceLoader.load_threaded_get("res://scenes/world.tscn"))


func _on_main_menu_button_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/menus/main.tscn")

func _on_timeout_warning_timeout() -> void:
	$Label.text = "Something is taking long... Stand by"

func _on_timeout_confirmed_timeout() -> void:
	connected = false
		
	$Label.text = "Server connection timed out"
	multiplayer.multiplayer_peer.close()
	
	$Details.show()
	$ProgressBar.hide()


func _on_change_funny_message_timeout() -> void:
	$FunnyMessages.text = General.FUNNY_MESSAGES.pick_random()
