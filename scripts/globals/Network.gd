extends Node

# -- Client -> Client -- #
signal ready_to_send_to(id: int)
signal despawn_item(path: NodePath)

@rpc("any_peer", "call_remote")
func _ready_to_send_to(id: int):
	ready_to_send_to.emit(id)

@rpc("any_peer", "call_local")
func _despawn_item(path: NodePath):
	despawn_item.emit(path)

# -- Server -> Client -- #
signal disconnected(reason: String)
signal add_players(ids)
signal remove_player(id: int)

@rpc("authority")
func _disconnect(reason: String):
	print("Disconnected from server with reason: %s" % reason)
	disconnected.emit(reason)

@rpc("authority")
func _add_players(ids):
	add_players.emit(ids)

@rpc("authority")
func _remove_player(id):
	remove_player.emit(id)

# -- Client -> Server -- #
signal authorized(unique_id: String, peer_id: int)

@rpc("any_peer", "call_remote")
func _authorize(unique_id: String):
	authorized.emit(unique_id, multiplayer.get_remote_sender_id())
