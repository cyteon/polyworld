extends Node3D

func _ready() -> void:
	for child in get_viewport().get_node("/root/Players").get_children():
		child.reparent($Players)
	get_viewport().get_node("/root/Players").queue_free()
	
	Network.rpc_id(1, "_player_ready")
