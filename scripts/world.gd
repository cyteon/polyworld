extends Node3D

func _ready() -> void:
	Network.add_players.connect(_add_players)
	Network.remove_player.connect(_remove_player)

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
