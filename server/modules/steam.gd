extends Node

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
	Log.info("got an auth ticket response, this is not implemented")

func _process(_delta: float) -> void:
	SteamServer.run_callbacks()
