extends Control

func _on_connect_button_pressed() -> void:
	$ServerConnectMenu.show()

func _on_settings_button_pressed() -> void:
	pass # Replace with function body.

func _on_quit_button_pressed() -> void:
	get_tree().quit()

var query_thread: Thread
func _on_query_button_pressed() -> void:
	$ServerConnectMenu/VBoxContainer/ServerInfo/Status.show()
	$ServerConnectMenu/VBoxContainer/ServerInfo/Status.text = "querying..."
	
	$ServerConnectMenu/VBoxContainer/ServerInfo/Grid.hide()
	
	if query_thread and query_thread.is_alive():
		query_thread.wait_to_finish()
	query_thread = Thread.new()
	
	query_thread.start(_query_server.bind(
		$ServerConnectMenu/VBoxContainer/ServerAddress/LineEdit.text,
		$ServerConnectMenu/VBoxContainer/ServerPort/SpinBox.value + 1
	))

func _query_server(host: String, port: int) -> void:
	var result = Steamworks.ping_server(host, port)
	call_deferred("_query_server_result", result)

func _query_server_result(result: Dictionary) -> void:
	if len(result.keys()) == 0:
		$ServerConnectMenu/VBoxContainer/ServerInfo/Status.text = "server did not respond"
		return
	
	$ServerConnectMenu/VBoxContainer/ServerInfo/Grid/Ping/Value.text = "%sms" % result.ping
	$ServerConnectMenu/VBoxContainer/ServerInfo/Grid/PlayerCount/Value.text = "%s/%s" % [
		result.players, result.max_players
	]
	$ServerConnectMenu/VBoxContainer/ServerInfo/Grid/Version/Value.text = result.version
	$ServerConnectMenu/VBoxContainer/ServerInfo/Grid/Secure/Value.text = "yes" if result.vac else "no"
	
	$ServerConnectMenu/VBoxContainer/ServerInfo/Status.hide()
	$ServerConnectMenu/VBoxContainer/ServerInfo/Grid.show()


func _on_final_connect_button_pressed() -> void:
	$ServerConnectMenu/VBoxContainer/ServerInfo/Grid.hide()
	$ServerConnectMenu/VBoxContainer/ServerInfo/Status.show()
	$ServerConnectMenu/VBoxContainer/ServerInfo/Status.text = "connecting..."
	
	var res = Network.peer.create_client(
		$ServerConnectMenu/VBoxContainer/ServerAddress/LineEdit.text,
		$ServerConnectMenu/VBoxContainer/ServerPort/SpinBox.value
	)
	
	Network.server_host = $ServerConnectMenu/VBoxContainer/ServerAddress/LineEdit.text
	Network.server_port = $ServerConnectMenu/VBoxContainer/ServerPort/SpinBox.value
	
	if res == OK:
		multiplayer.multiplayer_peer = Network.peer
		$ServerConnectMenu/VBoxContainer/ServerInfo/Status.text = "loading server..."
		get_tree().change_scene_to_file("res://menus/loading/loading.tscn")
	else:
		$ServerConnectMenu/VBoxContainer/ServerInfo/Status.text = "failed to connect"
