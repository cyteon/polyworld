extends Node3D

func _ready() -> void:
	Network.add_players.connect(_add_players)
	Network.remove_player.connect(_remove_player)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if (
			Input.mouse_mode == Input.MOUSE_MODE_CAPTURED) else Input.MOUSE_MODE_CAPTURED
		
		$CanvasLayer/Control/PauseMenu.visible = not $CanvasLayer/Control/PauseMenu.visible

func _add_players(ids) -> void:
	for id in ids:
		var player = preload("res://scenes/player.tscn").instantiate()
		player.set_multiplayer_authority(id)
		player.name = str(id)
		add_child(player)
		
		if id == multiplayer.get_unique_id():
			player.get_node("Camera3D").current = true

func _remove_player(id) -> void:
	var node = get_node(str(id))
	
	if node:
		node.queue_free()


func _on_disconnect_pressed() -> void:
	multiplayer.multiplayer_peer.close()
	get_tree().change_scene_to_file("res://scenes/menus/main.tscn")

func _on_exit_to_desktop_pressed() -> void:
	multiplayer.multiplayer_peer.close()
	get_tree().quit()
