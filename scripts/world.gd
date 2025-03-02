extends Node3D

func _ready() -> void:
	push_warning("[Client] Entered world") # for time refrence in debuggers
	
	Network.spawn_item.connect(_spawn_item)
	Network.despawn_item.connect(_despawn_item)
	Network.add_players.connect(_add_players)
	Network.remove_player.connect(_remove_player)

func _despawn_item(path: NodePath) -> void:
	if has_node(path):
		get_node(path).queue_free()

func _spawn_item(scene, unique_id, icon_path, stackable, item_count, location) -> void:
	var node = load(scene).instantiate()
	node.unique_id = unique_id
	node.icon_path = icon_path
	node.stackable = stackable
	node.item_count = item_count
	node.scene = scene
	
	$Items.add_child(node)
	node.global_position = location

func _add_players(ids) -> void:
	for id in ids:
		var player = preload("res://scenes/player.tscn").instantiate()
		player.set_multiplayer_authority(id)
		player.name = str(id)
		add_child(player)
		
		if id == multiplayer.get_unique_id():
			player.position.y += 5
			player.get_node("Camera3D").current = true
			$CanvasLayer/Control/Loading.hide()

func _remove_player(id) -> void:
	if has_node(str(id)):
		get_node(str(id)).queue_free()

func _on_disconnect_pressed() -> void:
	multiplayer.multiplayer_peer.close()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().change_scene_to_file("res://scenes/menus/main.tscn")

func _on_exit_to_desktop_pressed() -> void:
	multiplayer.multiplayer_peer.close()
	get_tree().quit()
