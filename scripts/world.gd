extends Node3D

func _ready() -> void:
	Network.add_players.connect(_add_players)

func _add_players(ids) -> void:
	print(ids)
	
	for id in ids:
		var player = preload("res://scenes/player.tscn").instantiate()
		player.set_multiplayer_authority(id)
		player.name = str(id)
		add_child(player)
		
		if id == multiplayer.get_unique_id():
			pass # player.get_node("Camera3D").current = true
