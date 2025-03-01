extends Control

var max_players: int = 3

var port: int = 4040

var network = ENetMultiplayerPeer.new()
# { string: { unique_id: String | null } }
var peers: Dictionary = {}

var thread: Thread

func _ready() -> void:
	log_event("Server is starting")
	
	$Info/MaxPlayers.text = "Max Players: %s" % max_players
	$Info/Port.text = "Port: %s" % port
	
	start_server()
	
	thread = Thread.new()
	thread.start(_input_loop)

func _input_loop() -> void:
	while true:
		var input = OS.read_string_from_stdin(256)
		
		match input:
			"peers":
				for peer in peers:
					print("[CMD] Peer: %s" % peer)
				
				if len(peers) == 0:
					print("[CMD] No connected peers")
			"":
				pass
			_:
				print("[CMD] Unknown command: %s" % input)

func start_server():
	var error: int = network.create_server(port)
	
	match error:
		OK:
			multiplayer.multiplayer_peer = network
			log_event("Started server on port %s" % port)
		ERR_ALREADY_IN_USE:
			log_event("Failed to bind to port %s" % port, true)
			$Notice.text = "Failed to start server"
		ERR_CANT_CREATE:
			log_event("Unable to create server :(", true)
			$Notice.text = "Failed to start server"
	
	network.peer_connected.connect(_peer_connected)
	network.peer_disconnected.connect(_peer_disconnected)
	
	Network.authorized.connect(_peer_authorized)
	Network.attack_player.connect(_attack_player)

func _attack_player(target_id: int, damage: int):
	var peer = multiplayer.get_remote_sender_id()
	
	if not has_node(str(target_id)):
		return
	
	var peer_node = get_node(str(peer))
	var target_node = get_node(str(target_id))
	
	var distance = peer_node.global_position.distance_to(target_node.global_position)
	
	# ShortRaycast is 1.5m, but we have some more incase lag or shit
	if distance > 2.5:
		print("[Server] %s attacked %s but was %s away, might be network lag or smth else" % [peer, target_id, distance])
		return
	
	Network.rpc_id(target_id, "_take_damage", damage)
	
func _peer_connected(target_id: int):
	if len(peers) == max_players:
		Network.rpc_id(target_id, "_disconnect", "Server is full")
		log_event("Peer %s tried to connect but server is full" % target_id)
		
		await get_tree().create_timer(1).timeout
		
		network.disconnect_peer(target_id)
		return
	
	log_event("New peer connected: %s" % target_id)
	peers.set(target_id, { })
	$Info/Players.text = "Players: %s" % len(peers)
	
	var player = preload("res://server/mock_player.tscn").instantiate()
	player.set_multiplayer_authority(target_id)
	player.name = str(target_id)
	add_child(player)
	
	for id in peers.keys():
		if id != target_id:
			Network.rpc_id(id, "_add_players", [target_id])
			
	await get_tree().create_timer(1).timeout
	
	Network.rpc_id(target_id, "_add_players", peers.keys())

func _peer_disconnected(target_id: int):
	log_event("Peer disconnected: %s" % target_id)
	peers.erase(target_id)
	$Info/Players.text = "Players: %s" % len(peers)
	
	Network.rpc("_remove_player", target_id)

func _peer_authorized(unique_id: String, peer_id: int):
	var data = peers.get(peer_id, null)
	
	if data == null:
		print("[Server] Peer tried to authorize but has disconnected")
		return
	
	data.unique_id = unique_id
	
	peers.set(peer_id, data)

func log_event(str: String, error = false):
	print("[Server] %s" % str)
	
	var label = Label.new()
	label.add_theme_font_size_override("font_size", 24)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	label.text = str
	
	if error:
		label.modulate = Color.RED
	
	$Events.add_child(label)
	
	if $Events.get_child_count() > 5:
		$Events.get_child(0).queue_free()
