extends Control

var unique_id: String = OS.get_unique_id()

var max_players: int = 4
var port: int = 4040

# port sent to api, this is port people should connect to
var advertise_port: int = 4040
var advertise_host: String = "localhost"
var server_name: String = "An Server"

var network: ENetMultiplayerPeer = ENetMultiplayerPeer.new()
# { String: { unique_id: String | null, holding: String } }
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
		var input = OS.read_string_from_stdin(64)
		
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
	for arg in OS.get_cmdline_args():
		if arg.find("=") > -1:
			var key = arg.split("=")[0].lstrip("--")
			var value = arg.split("=")[1].lstrip("\"").rstrip("\"")
			
			match key:
				"port":# --headless --advertise_port=4040 --advertise_host=127.0.01 --server_name="dev server"
					if value.is_valid_int():
						port = value.to_int()
					else:
						print("[Server] %s (port) is not a valid integer" % value)
				"advertise_host":
					advertise_host = value
					print("[Server] Advertising host %s" % value)
				"advertise_port":
					if value.is_valid_int():
						advertise_port = value.to_int()
						print("[Server] Advertising port %s" % value)
					else:
						print("[Server] %s (advertise_port) is not a valid integer" % value)
				"server_name":
					server_name = value
					print("[Server] Set server name to '%s'" % value)
					
					if value.find(" ") <= -1:
						print("[Hint] Use '%20' for space if the above only has 1 word/is missing spaces")
				"max_players":
					if value.is_valid_int():
						max_players = value.to_int()
						print("[Server] Setting max players to %s" % value)
					else:
						print("[Server] %s (max_players) is not a valid integer" % value)
				
	
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
	
	Network.despawn_item.connect(_despawn_item)
	Network.spawn_item.connect(_spawn_item)
	Network.authorized.connect(_peer_authorized)
	Network.attack_player.connect(_attack_player)
	Network.set_holding.connect(_set_holding)
	
	send_server_info()

func _set_holding(peer: int, scene: String):
	if peer in peers:
		peers[peer].holding = scene

func _despawn_item(path: NodePath):
	if has_node(path):
		get_node(path).queue_free()
	else:
		push_warning("[Server Debug] Tried to free item that could not be found: %s" % path)

func _spawn_item(scene, unique_id, icon_path, stackable, item_count, location, name_) -> void:
	var node = load(scene).instantiate()
	node.unique_id = unique_id
	node.icon_path = icon_path
	node.stackable = stackable
	node.item_count = item_count
	node.scene = scene
	node.name = name_
	
	$Items.add_child(node)
	node.global_position = location
	node.freeze = true

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
	
	send_server_info()
	
	var player = preload("res://server/mock_player.tscn").instantiate()
	player.set_multiplayer_authority(target_id)
	player.name = str(target_id)
	add_child(player)
	
	for id in peers.keys():
		if id != target_id:
			Network.rpc_id(id, "_add_players", [target_id])
	
	await get_tree().create_timer(1).timeout
	
	Network.rpc_id(target_id, "_add_players", peers.keys())
	
	for id in peers.keys():
		if id != target_id:
			Network.rpc_id(target_id, "_set_holding", id, peers[id].holding if peers[id].has("holding") else "")
	
	for item in $Items.get_children():
		Network.rpc_id(
			target_id,
			"_spawn_item", 
			item.scene, item.unique_id, 
			item.icon_path, item.stackable, 
			item.item_count, item.global_position,
			item.name
		)
	
	for node in $World.get_children():
		Network.rpc_id(
			target_id,
			"_spawn_scene",
			$World.get_path(),
			node.scene_file_path,
			node.global_position,
			node.name
		)

func _peer_disconnected(target_id: int):
	log_event("Peer disconnected: %s" % target_id)
	peers.erase(target_id)
	$Info/Players.text = "Players: %s" % len(peers)
	
	Network.rpc("_remove_player", target_id)
	send_server_info()

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


func send_server_info() -> void:
	# Check if its local only
	if (
		advertise_host.begins_with("10.") 
		or advertise_host.begins_with("172.16.") 
		or advertise_host.begins_with("192.168.") 
		or advertise_host == "127.0.0.1"
		or advertise_host == "0.0.0.0"
		or advertise_host == "localhost"
	):
		return
	
	var json = JSON.stringify({
		"unique_id": unique_id,
		"port": advertise_port,
		"host": advertise_host,
		"max_players": max_players,
		"players": len(peers),
		"name": server_name,
		"version": ProjectSettings.get_setting("application/config/version"),
		"compatability_ver": Network.compatability_ver
	})
	
	var headers = ["Content-Type: Application/JSON"]
	
	var waits = 0
	
	while $HTTPRequest.get_http_client_status() != 0:
		await get_tree().create_timer(1).timeout
		waits += 1
		
		if waits >= 120:
			print("[Server] HTTP Client Busy for 2 minutes, aborting")
	
	$HTTPRequest.request("%s/api/servers" % Network.backend_url, headers, HTTPClient.METHOD_POST, json)
