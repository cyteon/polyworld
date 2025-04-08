extends Control

var save_file_loc: String = "user://server_save.json"
# so smth dosent write while being read and stuff
var save_file_busy: bool = false

var unique_id: String = OS.get_unique_id()

var max_players: int = 4
var port: int = 4040

# port sent to api, this is port people should connect to
var advertise_port: int = 4040
var advertise_host: String = "localhost"
var server_name: String = "An Server"

var network: ENetMultiplayerPeer = ENetMultiplayerPeer.new()
# { String: { unique_id: String | null, holding: String, hotbar: array | null, inventory: array | null } }
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
	if FileAccess.file_exists(save_file_loc):
		var save_obj = JSON.parse_string(FileAccess.get_file_as_string(save_file_loc))
		
		for child in $Items.get_children():
			child.queue_free()
		
		for child in $World.get_children():
			child.queue_free()
		
		for item in save_obj["items"]:
			var p = bytes_to_var_with_objects(str_to_var(item))
			var node = p.instantiate()
			$Items.add_child(node)
		
		for foliage in save_obj["foliage"]:
			if FileAccess.file_exists(foliage["scene"]):
				var scene = load(foliage["scene"]).instantiate()
				scene.name = foliage["name"]
				
				$World.add_child(scene)
				scene.global_position = str_to_var("Vector3" + foliage["position"])
	
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
	Network.inv_data.connect(_inv_data)
	
	send_server_info()

func _inv_data(hotbar: PackedByteArray, inventory: PackedByteArray):
	var peer = multiplayer.get_remote_sender_id()
	
	if peer in peers:
		peers[peer].hotbar = hotbar
		peers[peer].inventory = hotbar

func _set_holding(peer: int, scene: String):
	if peer in peers:
		peers[peer].holding = scene

func _despawn_item(path: NodePath):
	if has_node(path):
		get_node(path).queue_free()
	else:
		push_warning("[Server Debug] Tried to free item that could not be found: %s" % path)

func _spawn_item(bytes, name_) -> void:
	var node = bytes_to_var_with_objects(bytes).instantiate()
	
	$Items.add_child(node)
	node.name = name_
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
		var i = item.duplicate()
		
		Util.set_owner_recursive(i, i)
		
		var p = PackedScene.new()
		p.pack(i)
		
		Network.rpc_id(
			target_id,
			"_spawn_item", 
			var_to_bytes_with_objects(p),
			i.name
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
	var data = peers.get(target_id)
	
	log_event("Peer disconnected: %s" % target_id)
	peers.erase(target_id)

	$Info/Players.text = "Players: %s" % len(peers)
	
	var health = get_node(str(target_id)).health
	var stamina = get_node(str(target_id)).stamina
	var hunger = get_node(str(target_id)).hunger
	var pos = get_node(str(target_id)).global_position
	
	Network.rpc("_remove_player", target_id)
	send_server_info()
	
	while save_file_busy:
		await get_tree().create_timer(0.5).timeout
	
	save_file_busy = true
	
	var save_obj = {
		"players": {},
		"items": [],
		"foliage": [],
	}
	
	if FileAccess.file_exists(save_file_loc):
		save_obj = JSON.parse_string(FileAccess.get_file_as_string(save_file_loc))
	
	save_obj["players"][data.unique_id] = {
			"hotbar": data.hotbar if "hotbar" in data else [],
			"inventory": data.inventory if "inventory" in data else [],
			"health": health,
			"stamina": stamina,
			"hunger": hunger,
			"position": pos
		}
		
	var text = JSON.stringify(save_obj, "\t")
	FileAccess.open(save_file_loc, FileAccess.WRITE).store_string(text)
	
	save_file_busy = false

func _peer_authorized(unique_id: String, peer_id: int):
	var data = peers.get(peer_id, null)
	
	if data == null:
		print("[Server] Peer tried to authorize but has disconnected")
		return
	
	data.unique_id = unique_id
	
	if FileAccess.file_exists(save_file_loc):
		save_file_busy = true
		
		var save_obj = JSON.parse_string(FileAccess.get_file_as_string(save_file_loc))
		
		save_file_busy = false
		
		if unique_id in save_obj["players"]:
			data.hotbar = save_obj["players"][unique_id].hotbar
			data.inventory = save_obj["players"][unique_id].inventory
			
			peers.set(peer_id, data)
			
			await get_tree().create_timer(1).timeout
			
			Network.rpc_id(
				peer_id, "_set_state",
				str_to_var("Vector3" + save_obj["players"][unique_id].position),
				save_obj["players"][unique_id].health,
				save_obj["players"][unique_id].stamina,
				save_obj["players"][unique_id].hunger,
				str_to_var(save_obj["players"][unique_id].hotbar),
				str_to_var(save_obj["players"][unique_id].inventory)
			)

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
		
		if waits >= 60:
			print("[Server] HTTP Client Busy for 1 minutes, aborting")
	
	$HTTPRequest.request("%s/api/servers" % Network.backend_url, headers, HTTPClient.METHOD_POST, json)

func _on_save_timeout() -> void:
	# TODO: put this next to binaries
	var save_obj = {}
	
	while save_file_busy:
		await get_tree().create_timer(0.5).timeout
	
	save_file_busy = true
	
	if FileAccess.file_exists(save_file_loc):
		save_obj = JSON.parse_string(FileAccess.get_file_as_string(save_file_loc))
	else:
		save_obj = {
			"players": {},
			"items": [],
			"foliage": [],
		}
	
	for peer in peers.keys():
		if not peers.has(peer):
			continue
		
		var data = peers[peer]
		
		save_obj["players"][data.unique_id] = {
			"hotbar": data.hotbar if "hotbar" in data else [],
			"inventory": data.inventory if "inventory" in data else [],
			"health": get_node(str(peer)).health,
			"stamina": get_node(str(peer)).stamina,
			"hunger": get_node(str(peer)).hunger,
			"position": get_node(str(peer)).global_position
		}
	
	save_obj["items"] = []
	for item in $Items.get_children():
		Util.set_owner_recursive(item, item)
		
		var p = PackedScene.new()
		p.pack(item)
		
		save_obj["items"].append(var_to_bytes_with_objects(p))
	
	save_obj["foliage"] = []
	for foliage in $World.get_children():
		save_obj["foliage"].append({
			"scene": foliage.scene_file_path,
			"position": foliage.global_position,
			"name": foliage.name
		})
	
	var text = JSON.stringify(save_obj, "\t")
	FileAccess.open(save_file_loc, FileAccess.WRITE).store_string(text)
	
	save_file_busy = false
