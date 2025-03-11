extends Node

# will be used to see if server compatable with client
const compatability_ver: int = 1
const backend_url: String = "https://polyworld.cyteon.dev"

# -- Hybrid -- #
# aka: Server/Client -> Server/Client

signal despawn_item(path: NodePath)
signal spawn_item(scene, unique_id, icon_path, stackable, item_count, location, name_) 

@rpc("any_peer", "call_local")
func _despawn_item(path: NodePath):
	despawn_item.emit(path)

@rpc("any_peer", "call_remote")
func _spawn_item(scene, unique_id, icon_path, stackable, item_count, location, name_):
	spawn_item.emit(scene, unique_id, icon_path, stackable, item_count, location, name_)

# -- Client -> Client -- #
signal play_item_anim(peer: int)
signal set_holding(peer: int, scene: String) 
signal ready_to_send_to(id: int)

@rpc("any_peer", "call_remote")
func _play_item_anim(peer: int):
	play_item_anim.emit(peer)

# server will also recieve this and store it for syncing reasons
@rpc("any_peer", "call_remote")
func _set_holding(peer: int, scene: String):
	set_holding.emit(peer, scene)

@rpc("any_peer", "call_remote")
func _ready_to_send_to(id: int):
	ready_to_send_to.emit(id)

# -- Server -> Client -- #
signal disconnected(reason: String)
signal add_players(ids)
signal remove_player(id: int)
signal take_damage(damage: int)
signal spawn_scene(node: NodePath, scene: String, position: Vector3, name_: String)

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

@rpc("authority")
func _take_damage(damage: int):
	take_damage.emit(damage)

@rpc("authority")
func _spawn_scene(node: NodePath, scene: String, position: Vector3, name_: String):
	spawn_scene.emit(node, scene, position, name_)

# -- Client -> Server -- #
signal authorized(unique_id: String, peer_id: int)
signal attack_player(target_id: int, damage: int)

@rpc("any_peer", "call_remote")
func _authorize(unique_id: String):
	authorized.emit(unique_id, multiplayer.get_remote_sender_id())


@rpc("any_peer", "call_remote")
func _attack_player(target_id: int, damage: int):
	attack_player.emit(target_id, damage)
