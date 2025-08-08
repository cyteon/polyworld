extends Control

const RESOURCES_TO_SPAWN: Array = [
	{
		"scene": "res://scenes/world/harvestables/rock.tscn",
		"weight": 1,
		"offset": Vector3(0, 0, 0)
	},
	{
		"scene": "res://scenes/world/harvestables/tree.tscn",
		"weight": 2,
		"offset": Vector3(0, -1, 0)
	}
]

var save_file_loc: String = OS.get_executable_path().get_base_dir() + "/save.json"

var server_id: String = OS.get_unique_id()

var max_players: int = 4
var port: int = 4040
var gslt: String = ""

# port sent to api, this is port people should connect to
var advertise_port: int = 4040
var advertise_host: String = "localhost"
var server_name: String = "An Server"

var debug: bool = false

var network: ENetMultiplayerPeer = ENetMultiplayerPeer.new()

# Any may be null
# { String: { unique_id: String, username: String, chat_mute: bool, holding: String, hotbar: array, inventory: array } }
var peers: Dictionary = {}
var id_peer_map: Dictionary = {}

var thread: Thread

func _ready() -> void:
	log_event("Server is starting")
	
	if OS.get_cmdline_user_args().has("--debug"):
		debug = true
	
	$Info/MaxPlayers.text = "Max Players: %s" % max_players
	$Info/Port.text = "Port: %s" % port
	
	start_server()
	
	thread = Thread.new()
	thread.start(_input_loop)

func _process(_delta: float) -> void:
	SteamServer.run_callbacks()

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

func handle_cmdline_arg(arg) -> void:
	if arg.find("=") > -1:
		var key = arg.split("=")[0].lstrip("--")
		var value = arg.split("=")[1].lstrip("\"").rstrip("\"")
		
		match key:
			# Params example:
			# --headless --advertise_port=4040 --advertise_host=127.0.0.1 --max_players=2
			# --server_name="dev server" --insecure --debug --gslt="abc123"
			"gslt":
				gslt = value
				# We will use this to identify with the master server as it's better than hwid
				server_id = gslt
			"port":
				if value.is_valid_int():
					port = value.to_int()
				else:
					log_event("%s (port) is not a valid integer" % value)
			"advertise_host":
				advertise_host = value
				log_event("Advertising host %s" % value)
			"advertise_port":
				if value.is_valid_int():
					advertise_port = value.to_int()
					log_event("Advertising port %s" % value)
				else:
					log_event("%s (advertise_port) is not a valid integer" % value)
			"server_name":
				server_name = value
				log_event("Set server name to '%s'" % value)
				
				if value.find(" ") <= -1:
					print("[Hint] Use '%20' for space if the above only has 1 word/is missing spaces")
			"max_players":
				if value.is_valid_int():
					max_players = value.to_int()
					log_event("Setting max players to %s" % value)
				else:
					log_event("%s (max_players) is not a valid integer" % value)

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
	
	for arg in OS.get_cmdline_user_args():
		handle_cmdline_arg(arg)
	
	for arg in OS.get_cmdline_args():
		handle_cmdline_arg(arg)
	
	var mode: SteamServer.ServerMode
	
	# Some diffrent ways to make the server not secure
	if (OS.get_cmdline_user_args().has("--insecure") 
		or OS.get_cmdline_args().has("--insecure")
		or OS.get_cmdline_user_args().has("--unsecure")
		or OS.get_cmdline_args().has("--unsecure")):
		mode = SteamServer.SERVER_MODE_NO_AUTHENTICATION
	else:
		mode = SteamServer.SERVER_MODE_AUTHENTICATION_AND_SECURE
	
	var res: Dictionary = SteamServer.serverInitEx(
		"127.0.0.1",
		port,
		port + 1,
		mode,
		ProjectSettings.get_setting("application/config/version")
	)
	
	log_event("%s, status code %s" % [res.verbal, res.status])
	
	SteamServer.setServerName(server_name)
	SteamServer.setMaxPlayerCount(max_players)
	SteamServer.setProduct("3650810")
	SteamServer.setDedicatedServer(true)
	SteamServer.setAdvertiseServerActive(true)
	
	SteamServer.server_connected.connect(func():
		log_event("Connected to steam")
		
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
	)
	
	SteamServer.server_connect_failure.connect(func(result: int, retrying: bool):
		log_event("Failed to connect to steam, status code %s. Retrying = %s" % [result, retrying])
		
		match result:
			SteamServer.RESULT_INVALID_PARAM:
				log_event("Status code 8 = \"Invalid Paramter\" (is your GSLT correct?)")
	)
	
	SteamServer.server_disconnected.connect(func(result):
		log_event("Lost connection to steam, status code %s" % result)
	)
	
	SteamServer.validate_auth_ticket_response.connect(_auth_ticket_response)
	
	if gslt == "":
		SteamServer.logOnAnonymous()
	else:
		SteamServer.logOn(gslt)
	
	network.peer_connected.connect(_peer_connected)
	network.peer_disconnected.connect(_peer_disconnected)
	
	Network.world_loaded.connect(_peer_world_loaded)
	Network.despawn_item.connect(_despawn_item)
	Network.spawn_item.connect(_spawn_item)
	Network.authenticate.connect(_authenticate_peer)
	Network.attack_player.connect(_attack_player)
	Network.attack_entity.connect(_attack_entity)
	Network.set_holding.connect(_set_holding)
	Network.inv_data.connect(_inv_data)
	Network.chatmsg_server.connect(_chatmsg)
	
	send_server_info()
	
	# save server on start so like u dont start, 
	# initial stuff there, player join and leave which makes save file
	# with only player info, then restart before safe and nothing there, causing a softlock i guess
	_on_save_timeout()

func _inv_data(hotbar: PackedByteArray, inventory: PackedByteArray) -> void:
	var peer = multiplayer.get_remote_sender_id()
	
	if peer in peers:
		peers[peer].hotbar = hotbar
		peers[peer].inventory = inventory

func _chatmsg(content: String) -> void:
	var peer: int = multiplayer.get_remote_sender_id()
	
	if not SteamServer.secure():
		Network.rpc_id(
			peer,
			"_chatmsg",
			content,
			"server",
			# 1 is server peer ID
			"1_%s" % ResourceUID.create_id()
		)
		
		return
	
	var data: Dictionary = peers.get(peer)
	
	var id: String = "%s_%s" % [data.unique_id, ResourceUID.create_id()]
	
	# TODO: chat filtering
	
	Network.rpc(
		"_chatmsg",
		content,
		data.username,
		id
	)
	
	var body: Dictionary = {
		"id": id,
		"server_id": server_id,
		"author": data.unique_id,
		"content": content,
	}
	
	var waits: float = 0.0
	
	while $MessagesHTTP.get_http_client_status() != 0:
		await get_tree().create_timer(0.5).timeout
		waits += 0.5
		
		if waits >= 60.0:
			log_event("HTTP Client Busy for 1 minute, aborting")
	
	$MessagesHTTP.request(
		"%s/api/messages" % Network.backend_url,
		["Content-Type: application/json"],
		HTTPClient.METHOD_POST,
		JSON.stringify(body)
	)

func _set_holding(peer: int, scene: String) -> void:
	if peer in peers:
		peers[peer].holding = scene

func _despawn_item(path: NodePath) -> void:
	if has_node(path):
		get_node(path).queue_free()
	else:
		push_warning("[Server Debug] Tried to free item that could not be found: %s" % path)

func _spawn_item(bytes) -> void:
	var node = bytes_to_var_with_objects(bytes).instantiate()
	
	$Items.add_child(node)
	node.freeze = true

func _attack_entity(path: NodePath, damage: int) -> void:
	if has_node(path):
		get_node(path).damage(damage)

func _attack_player(target_id: int, damage: int) -> void:
	var peer = multiplayer.get_remote_sender_id()
	
	if not has_node(str(target_id)):
		return
	
	var peer_node = get_node(str(peer))
	var target_node = get_node(str(target_id))
	
	var distance = peer_node.global_position.distance_to(target_node.global_position)
	
	# ShortRaycast is 1.5m, but we have some more incase lag or shit
	if distance > 2.5:
		log_event("%s attacked %s but was %s away, might be network lag or smth else" % [peer, target_id, distance])
		return
	
	Network.rpc_id(target_id, "_take_damage", damage)

func _peer_connected(peer_id: int):
	if len(peers) == max_players:
		Network.rpc_id(peer_id, "_disconnect", "Server is full", "")
		log_event("Peer %s tried to connect but server is full" % peer_id)
		
		await get_tree().create_timer(1).timeout
		
		network.disconnect_peer(peer_id)
		return
	
	log_event("New peer connected: %s" % peer_id)
	peers.set(peer_id, { })
	
	$Info/Players.text = "Players: %s" % len(peers)
	
	send_server_info()
	
	var player = preload("res://server/mock_player.tscn").instantiate()
	player.set_multiplayer_authority(peer_id)
	player.name = str(peer_id)
	add_child(player)
	
	for id in peers.keys():
		if id != peer_id:
			Network.rpc_id(id, "_add_players", [peer_id])

func _peer_world_loaded():
	var peer_id = multiplayer.get_remote_sender_id()
	
	Network.rpc_id(peer_id, "_add_players", peers.keys())
	
	for id in peers.keys():
		if id != peer_id:
			Network.rpc_id(peer_id, "_set_holding", id, peers[id].holding if peers[id].has("holding") else "")
	
	for i in $Items.get_children():
		Util.set_owner_recursive(i, i)
		
		var p = PackedScene.new()
		p.pack(i)
		
		Network.rpc_id(
			peer_id,
			"_spawn_item", 
			var_to_bytes_with_objects(p)
		)
	
	for node in $World.get_children():
		Network.rpc_id(
			peer_id,
			"_spawn_scene",
			$World.get_path(),
			node.scene_file_path,
			node.global_position,
			node.name
		)
	
	var data = peers.get(peer_id, null)
	
	if FileAccess.file_exists(save_file_loc):
		var save_obj = JSON.parse_string(FileAccess.get_file_as_string(save_file_loc))
		
		if data.unique_id in save_obj["players"]:
			data.hotbar = save_obj["players"][data.unique_id].hotbar
			data.inventory = save_obj["players"][data.unique_id].inventory
			
			peers.set(peer_id, data)
			
			var hotbar = str_to_var(data.hotbar) if data.hotbar is String else var_to_bytes({})
			var inventory = str_to_var(data.inventory) if data.inventory is String else var_to_bytes([])
			
			Network.rpc_id(
				peer_id, "_set_state",
				str_to_var("Vector3" + save_obj["players"][data.unique_id].position),
				save_obj["players"][data.unique_id].health,
				save_obj["players"][data.unique_id].stamina,
				save_obj["players"][data.unique_id].hunger,
				hotbar,
				inventory
			)

func _peer_disconnected(peer_id: int):
	var data = peers.get(peer_id)
	
	log_event("%s has left the game (peer id: %s)" % [peers[peer_id].username, peer_id])
	peers.erase(peer_id)

	$Info/Players.text = "Players: %s" % len(peers)
	
	Network.rpc("_remove_player", peer_id)
	send_server_info()
	
	if not data:
		return
	
	if SteamServer.secure():
		SteamServer.endAuthSession(int(data.unique_id))
	
	var health: float = get_node(str(peer_id)).health
	var stamina: float = get_node(str(peer_id)).stamina
	var hunger: float = get_node(str(peer_id)).hunger
	var pos: Vector3 = get_node(str(peer_id)).global_position
	
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
	var file = FileAccess.open(save_file_loc, FileAccess.WRITE)
	
	if file:
		file.store_string(text)
	else:
		log_event("Failed to open save file, error %s" % [FileAccess.get_open_error()])

func _auth_ticket_response(_auth_id: int, response: int, owner_id: int):
	if not SteamServer.secure():
		Network.rpc_id(
			id_peer_map[owner_id],
			"_authentication_ok",
			false
		)
		
		return
	
	match response:
		SteamServer.AUTH_SESSION_RESPONSE_OK:
			Network.rpc_id(
				id_peer_map[owner_id],
				"_authentication_ok",
				true
			)
		#AUTH_SESSION_RESPONSE_USER_NOT_CONNECTED_TO_STEAM
		#AUTH_SESSION_RESPONSE_NO_LICENSE_OR_EXPIRED
		#AUTH_SESSION_RESPONSE_VAC_BANNED
		#AUTH_SESSION_RESPONSE_LOGGED_IN_ELSEWHERE
		#AUTH_SESSION_RESPONSE_VAC_CHECK_TIMED_OUT
		#AUTH_SESSION_RESPONSE_AUTH_TICKET_CANCELED
		#AUTH_SESSION_RESPONSE_AUTH_TICKET_INVALID_ALREADY_USED
		#AUTH_SESSION_RESPONSE_AUTH_TICKET_INVALID
		SteamServer.AUTH_SESSION_RESPONSE_PUBLISHER_ISSUED_BAN:
			log_event("Auth failed for SteamID %s (peer %s): User is banned from secure servers" % [owner_id, id_peer_map[owner_id]])
			
			Network.rpc_id(
				id_peer_map[owner_id], "_disconnect", 
				"Authentication to secure server failed",
				"Your account has an active game ban.\nYou can not connect to secure servers"
			)
		#AUTH_SESSION_RESPONSE_AUTH_TICKET_NETWORK_IDENTITY_FAILURE
		_:
			log_event("Auth failed for SteamID %s (peer %s): Unknown Error" % [owner_id, id_peer_map[owner_id]])
			
			Network.rpc_id(
				id_peer_map[owner_id], "_disconnect", 
				"Authentication to secure server failed",
				"Your client failed to authenticate due to an unknown error :(\nTry to reconnect or reboot your game"
			)

func _authenticate_peer(unique_id: Variant, username: String, auth_ticket: Dictionary):
	var peer_id: int = multiplayer.get_remote_sender_id()
	var data = peers.get(peer_id, null)
	
	if data == null:
		log_event("Peer tried to authorize but has disconnected")
		return
	
	if SteamServer.secure():
		if unique_id is not int:
			log_event("Disconnecting peer %s, ID (%s) was not an int, could not proceed with authentication and server is secure" % [peer_id, unique_id])
			Network.rpc_id(peer_id, "_disconnect", "Authentication to secure server failed")
			
			await get_tree().create_timer(0.5).timeout
			
			network.disconnect_peer(peer_id)
			return
		
		var result: int = SteamServer.beginAuthSession(
			auth_ticket.buffer,
			auth_ticket.size,
			unique_id
		)
		
		if result != 0:
			match result:
				SteamServer.BEGIN_AUTH_SESSION_RESULT_INVALID_TICKET:
					log_event("Auth failed for SteamID %s (peer %s): invalid auth ticket" % [unique_id, peer_id])
					Network.rpc_id(
						peer_id, "_disconnect", 
						"Authentication to secure server failed",
						"Your client provided the server an invalid auth ticket.\nTry to reconnect, or restart your game if that does not work"
					)
				SteamServer.BEGIN_AUTH_SESSION_RESULT_DUPLICATE_REQUEST:
					log_event("Auth failed for SteamID %s (peer %s): duplicate auth request" % [unique_id, peer_id])
					Network.rpc_id(
						peer_id, "_disconnect", 
						"Authentication to secure server failed",
						"The server has recieved a duplicate authentication attempt.\nTry to reconnect or restart your game."
					)
				SteamServer.BEGIN_AUTH_SESSION_RESULT_INVALID_VERSION:
					log_event("Auth failed for SteamID %s (peer %s): outdated steamworks interface (contact polyworld dev)" % [unique_id, peer_id])
					Network.rpc_id(
						peer_id, "_disconnect", 
						"Authentication to secure server failed",
						"Your client appears to be using an outdated steamworks interface.\nMake sure your game is updated to the latest version"
					)
				SteamServer.BEGIN_AUTH_SESSION_RESULT_GAME_MISMATCH:
					log_event("Auth failed for SteamID %s (peer %s): wrong appID (contact polyworld dev)" % [unique_id, peer_id])
					Network.rpc_id(
						peer_id, "_disconnect", 
						"Authentication to secure server failed",
						"Your client appears to have tried to authenticate with an auth ticket that dosent match the server appID\nTry to restart your game"
					)
				SteamServer.BEGIN_AUTH_SESSION_RESULT_EXPIRED_TICKET:
					log_event("Auth failed for SteamID %s (Peer %s): auth ticket timeout" % [unique_id, peer_id])
					Network.rpc_id(
						peer_id, "_disconnect", 
						"Authentication to secure server timeouted",
						"Authentication has failed due to an expired auth ticket, try to reconnect"
					)
			
			await get_tree().create_timer(0.5).timeout
			network.disconnect_peer(peer_id)
			return
	else:
		Network.rpc_id(peer_id, "_authentication_ok", false)
	
	id_peer_map[unique_id] = peer_id
	
	unique_id = str(unique_id)
	data.unique_id = unique_id
	data.username = username
	
	log_event("%s has joined the game (peer id: %s)" % [username, peer_id])

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
		"unique_id": server_id, # GSLT unless not provided
		"port": advertise_port,
		"host": advertise_host,
		"max_players": max_players,
		"players": len(peers),
		"name": server_name,
		"version": ProjectSettings.get_setting("application/config/version"),
		"compatability_ver": Network.compatability_ver,
		"secure": SteamServer.secure()
	})

	
	var waits: float = 0.0
	
	while $ServerInfoHTTP.get_http_client_status() != 0:
		await get_tree().create_timer(0.5).timeout
		waits += 0.5
		
		if waits >= 60.0:
			log_event("HTTP Client Busy for 1 minute, aborting")
	
	$ServerInfoHTTP.request(
		"%s/api/servers" % Network.backend_url, 
		["Content-Type: application/json"], 
		HTTPClient.METHOD_POST, 
		json
	)

func _on_save_timeout() -> void:
	# TODO: put this next to binaries
	var save_obj = {}
	
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
			"hotbar": data.hotbar if "hotbar" in data else "[]",
			"inventory": data.inventory if "inventory" in data else "[]",
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
	var file = FileAccess.open(save_file_loc, FileAccess.WRITE)
	
	if file:
		file.store_string(text)
	else:
		log_event("Failed to open save file, error %s" % [FileAccess.get_open_error()])

func _on_spawn_resource_timeout() -> void:
	if $World.get_child_count() > 500:
		return
	
	var weighted = []
	
	for r in RESOURCES_TO_SPAWN:
		for i in range(0, r.weight):
			weighted.append(r)
	
	var resource: Dictionary = weighted.pick_random()
	
	var point = NavigationServer3D.map_get_random_point(
		$NavigationRegion3D.get_navigation_map(), 1, true
	) + resource.offset
	
	var scene = load(resource.scene).instantiate()
	$World.add_child(scene)
	scene.global_position = point
	
	Network.rpc(
		"_spawn_scene",
		$World.get_path(),
		resource.scene,
		point,
		scene.name
	)
