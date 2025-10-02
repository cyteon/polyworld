extends Node

func _ready() -> void:
	Network.peer.peer_connected.connect(_peer_connected)
	Network.peer.peer_disconnected.connect(_peer_disconnected)
	
	Network.authenticate.connect(_authenticate_peer)
	Network.player_ready.connect(_player_ready)

func _peer_connected(peer_id: int):
	Log.info("new peer with id %s has connected" % peer_id)
	
	Network.users.set(peer_id, {})

func _peer_disconnected(peer_id: int):
	Log.info("%s (peer %s) has disconnected" % [
		Network.users.get(peer_id).username, peer_id
	])
	
	Network.users.set(peer_id, null)
	
	if has_node("../Players/%s" % peer_id):
		get_node("../Players/%s" % peer_id).queue_free()

func _player_ready() -> void:
	var peer_id = multiplayer.get_remote_sender_id()

	var player = preload("res://entities/player.tscn").instantiate()
	player.set_multiplayer_authority(peer_id)
	player.name = str(peer_id)
	
	$"../Players".add_child(player, true)

func _authenticate_peer(id: Variant, username: String, auth_ticket: Dictionary):
	var peer_id: int = multiplayer.get_remote_sender_id()
	var data = Network.users.get(peer_id, null)
	
	if data == null:
		Log.warn("peer %s tried to authenticate, but i could find their data" % peer_id)
		
		if SteamServer.secure():
			Network.rpc_id(
				peer_id,
				"_disconnect",
				"Your connection data was not found on the server, try reconnecting"
			)
			
			await get_tree().create_timer(1).timeout
			
			Network.peer.disconnect_peer(peer_id)
			return
		
		return
	
	Network.id_peer_map.set(id, peer_id)
	Network.users[peer_id].username = username
	Network.users[peer_id].steam_id = id
	
	if SteamServer.secure():
		if id is not int:
			Log.warn("%s (peer %s) tried to authenticate, but their id was not an interger" % [username, peer_id])
			Network.rpc_id(
				peer_id,
				"_disconnect",
				"Client tried to connect with a user id that was not an integer so the authentication failed.\n\nThis usually means that something went wrong with communicating with steam"
			)
			
			await get_tree().create_timer(1).timeout
			
			Network.peer.disconnect_peer(peer_id)
			return
		
		var result: int = SteamServer.beginAuthSession(
			auth_ticket.buffer,
			auth_ticket.size,
			id
		)
		
		if result != OK:
			match result:
				SteamServer.BEGIN_AUTH_SESSION_RESULT_INVALID_TICKET:
					Log.warn("%s (peer %s) tried to authenticate with an invalid authentication ticket" % [username, peer_id])
					Network.rpc_id(
						peer_id,
						"_disconnect",
						"Client tried to connect with an invalid authentication ticket, try to reconnect or reboot your game"
					)
				SteamServer.BEGIN_AUTH_SESSION_RESULT_DUPLICATE_REQUEST: pass
				SteamServer.BEGIN_AUTH_SESSION_RESULT_INVALID_VERSION: pass
				SteamServer.BEGIN_AUTH_SESSION_RESULT_GAME_MISMATCH: pass
				SteamServer.BEGIN_AUTH_SESSION_RESULT_EXPIRED_TICKET: pass
			
			await get_tree().create_timer(1).timeout
			
			Network.peer.disconnect_peer(peer_id)
			return
	else:
		Network.rpc_id(
			peer_id,
			"_authenticated"
		)
