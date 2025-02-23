extends Control

func _ready() -> void:
	multiplayer.connected_to_server.connect(func(): 
		print("[Client] Connection established")
		
		Network.rpc_id(get_multiplayer_authority(), "_authorize", OS.get_unique_id())
		
		$Label.text = "Connected to server :D... Joining"
		
		get_tree().change_scene_to_file("res://scenes/world.tscn")
	)
	
	multiplayer.connection_failed.connect(func(): 
		print("[Client] Connection to server failed :(")
		multiplayer.multiplayer_peer.close()
	)
	
	Network.disconnected.connect(func(reason): 
		$Label.text = "Failed to connect to server: %s" % reason
	)
