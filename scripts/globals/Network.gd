extends Node

# -- Client -> Client -- #
signal set_holding(peer: int, scene: String) 
signal ready_to_send_to(id: int)
signal despawn_item(path: NodePath)
signal spawn_item(scene, unique_id, icon_path, stackable, item_count, location) 

@rpc("any_peer", "call_remote")
func _set_holding(peer: int, scene: String):
	set_holding.emit(peer, scene)

@rpc("any_peer", "call_remote")
func _ready_to_send_to(id: int):
	ready_to_send_to.emit(id)

@rpc("any_peer", "call_local")
func _despawn_item(path: NodePath):
	despawn_item.emit(path)

@rpc("any_peer", "call_remote")
func _spawn_item(scene, unique_id, icon_path, stackable, item_count, location):
	spawn_item.emit(scene, unique_id, icon_path, stackable, item_count, location)

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
