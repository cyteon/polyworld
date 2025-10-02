extends Node

func _ready() -> void:
	SteamServer.server_connect_failure.connect(_server_connect_failure)
	SteamServer.server_disconnected.connect(_server_disconnected)
	SteamServer.validate_auth_ticket_response.connect(_validate_auth_ticket_response)

func _server_connect_failure(result: int, retrying: bool) -> void:
	if retrying:
		Log.warn("steam connection failed with result code %s, retrying..." % result)
	elif SteamServer.secure():
		Log.error("steam connection failed with result code %s, not retrying :(" % result)
		Log.error("as server mode is 'secure', this error is fatal")
	else:
		Log.warn("steam connection failed with result code %s, not retrying, this error is not fatal as server mode is 'insecure'")

func _server_disconnected(result: int) -> void:
	if SteamServer.secure():
		Log.error("steam disconnected with result code: %s" % result)
		Log.error("as server mode is 'secure', this error is fatal")
		get_tree().quit()
	else:
		Log.warn("steam disconnected with result code %s, this error is not fatal as server mode is 'insecure'")

func _validate_auth_ticket_response(_auth_id: int, response: int, owner_id: int):
	var peer_id: int = Network.id_peer_map[owner_id]
	
	if not SteamServer.secure():
		Network.rpc_id(
			peer_id,
			"_authenticated"
		)
	
	match response:
		SteamServer.AUTH_SESSION_RESPONSE_OK: 
			Log.info(
				"peer %s has been authenticated as '%s'" % [
					peer_id, 
					Network.users.get(peer_id).username
				]
			)
			
			Network.rpc_id(
				Network.id_peer_map[owner_id],
				"_authenticated"
			)
			
		#AUTH_SESSION_RESPONSE_USER_NOT_CONNECTED_TO_STEAM
		#AUTH_SESSION_RESPONSE_NO_LICENSE_OR_EXPIRED
		#AUTH_SESSION_RESPONSE_VAC_BANNED
		#AUTH_SESSION_RESPONSE_LOGGED_IN_ELSEWHERE
		#AUTH_SESSION_RESPONSE_VAC_CHECK_TIMED_OUT
		#AUTH_SESSION_RESPONSE_AUTH_TICKET_CANCELED
		#AUTH_SESSION_RESPONSE_AUTH_TICKET_INVALID_ALREADY_USED
		#AUTH_SESSION_RESPONSE_AUTH_TICKET_INVALID
		#AUTH_SESSION_RESPONSE_PUBLISHER_ISSUED_BAN
		#AUTH_SESSION_RESPONSE_AUTH_TICKET_NETWORK_IDENTITY_FAILURE
		_:
			Log.warn("unexpected response from steam while authenticating %s (peer %s)" % [
				Network.users.get(peer_id).username if Network.users.get(peer_id) else owner_id, peer_id
			])
			
			Network.rpc_id(
				peer_id,
				"_disconnect",
				"Unexpected response from steam while authenticating, please try to reconnect or reboot your game"
			)
			
			await get_tree().create_timer(1).timeout
			
			Network.peer.disconnect_peer(peer_id)
			return

func _process(_delta: float) -> void:
	SteamServer.run_callbacks()
