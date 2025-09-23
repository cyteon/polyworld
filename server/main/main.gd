extends Node

func _ready() -> void:
	Log.info("starting server")
	
	var server_mode: SteamServer.ServerMode
	
	if (OS.get_cmdline_user_args().has("--insecure") 
		or OS.get_cmdline_args().has("--insecure")
		or OS.get_cmdline_user_args().has("--unsecure")
	or OS.get_cmdline_args().has("--unsecure")):
		server_mode = SteamServer.SERVER_MODE_NO_AUTHENTICATION
		
		Log.info("server mode is 'not secure', user authentication not required")
	else:
		server_mode = SteamServer.SERVER_MODE_AUTHENTICATION_AND_SECURE
		Log.info("server mode is 'secure', user authentication required")
	
	OS.set_environment("SteamAppId", "3650810")
	
	var steam_res: Dictionary = SteamServer.serverInitEx(
		"127.0.0.1",
		Network.port,
		Network.port + 1,
		server_mode,
		ProjectSettings.get_setting("application/config/version")
	)
	
	if steam_res.status == OK:
		Log.info("steam server initialized successfully")
	else:
		Log.error("failed to initialize steam server: %s" % steam_res.verbal)
		
		if server_mode == SteamServer.SERVER_MODE_AUTHENTICATION_AND_SECURE:
			Log.error("current server mode is 'secure', unable to proceed without steam")
			get_tree().quit()
	
	SteamServer.setServerName("An Server")
	SteamServer.setMaxPlayerCount(5)
	SteamServer.setProduct("3650810")
	SteamServer.setDedicatedServer(true)
	SteamServer.setAdvertiseServerActive(true)
	
	# i have this here instead of $Steam cause still initializing server stuff
	SteamServer.server_connected.connect(func():
		Log.info("steam successfully connected")
		Log.info("starting network peer")
		
		var error: int = Network.peer.create_server(Network.port)
		
		match error:
			OK:
				multiplayer.multiplayer_peer = Network.peer
				Log.info("server running port %s" % Network.port)
	)
	
	SteamServer.server_connect_failure.connect($Steam._server_connect_failure)
	SteamServer.server_disconnected.connect($Steam._server_disconnected)
	SteamServer.validate_auth_ticket_response.connect($Steam._validate_auth_ticket_response)
	
	Log.info("connecting to steam...")
	
	SteamServer.logOnAnonymous()
	
	Network.peer.peer_connected.connect($Peer._peer_connected)
	Network.peer.peer_disconnected.connect($Peer._peer_disconnected)
