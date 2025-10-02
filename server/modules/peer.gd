extends Node

func _ready() -> void:
	Network.authenticate.connect(_authenticate_peer)

func _peer_connected(peer_id: int):
	Log.info("new peer with id %s has connected" % peer_id)
	
	Network.users.set(peer_id, {})

func _peer_disconnected(peer_id: int):
	Log.info("peer id %s has disconnected" % peer_id) # say username
	
	Network.users.set(peer_id, null)

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
	
	if SteamServer.secure():
		if id is not int:
			Log.warn("peer %s tried to authenticate, but their id was not an interger" % peer_id)
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
		
		if result == OK:
			Network.rpc_id(
				peer_id,
				"_authenticated"
			)
		else:
			pass
