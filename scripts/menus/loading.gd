extends Control

var progress: Array[int] = [0]

var connected: bool = false

func _ready() -> void:
	ResourceLoader.load_threaded_request("res://scenes/world.tscn")
	
	multiplayer.connected_to_server.connect(func(): 
		print("[Client] Connection established")
		connected = true
		
		Network.rpc_id(get_multiplayer_authority(), "_authorize", OS.get_unique_id())
		
		$Label.text = "Connected to server :D... Loading"
	)
	
	multiplayer.connection_failed.connect(func(): 
		print("[Client] Connection to server failed :(")
		multiplayer.multiplayer_peer.close()
	)
	
	Network.disconnected.connect(func(reason): 
		$Label.text = "Failed to connect to server: %s" % reason
	)

func _process(delta: float) -> void:	
	var status = ResourceLoader.load_threaded_get_status("res://scenes/world.tscn", progress)
	
	match status:
		ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
			print("[Client] THREAD_LOAD_INVALID_RESOURCE")
			$Label.text = "Connected to server :D... Failed to load"
		ResourceLoader.THREAD_LOAD_FAILED:
			print("[Client] THREAD_LOAD_FAILED")
			$Label.text = "Connected to server :D... Failed to load"
		ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			$ProgressBar.value = progress[0] * 100
		ResourceLoader.THREAD_LOAD_LOADED:
			if not connected: return
			#if len(Network.player_ids_to_spawn_on_world_entry) == 0:
				#$ProgressBar.value = 98
				#return
			
			$ProgressBar.value = 100
			
			get_tree().change_scene_to_packed(ResourceLoader.load_threaded_get("res://scenes/world.tscn"))
