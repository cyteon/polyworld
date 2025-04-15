extends Node

# will be used to see if server compatable with client
const compatability_ver: int = 1
const backend_url: String = "https://polyworld.xyz"

# -- Hybrid -- #
# aka: Server/Client -> Server/Client

signal despawn_item(path: NodePath)
signal spawn_item(bytes: PackedByteArray, name_: String) 

@rpc("any_peer", "call_local")
func _despawn_item(path: NodePath):
	despawn_item.emit(path)

@rpc("any_peer", "call_remote")
func _spawn_item(bytes: PackedByteArray, name_: String):
	spawn_item.emit(bytes, name_)

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
signal disconnected(reason: String, details: String)
signal authentication_ok()
signal add_players(ids)
signal remove_player(id: int)
signal take_damage(damage: int)
signal spawn_scene(node: NodePath, scene: String, position: Vector3, name_: String)
signal set_state(position: Vector3, health: int, stamina: float, hunger: float, hotbar: PackedByteArray, inventory: PackedByteArray)

@rpc("authority")
func _disconnect(reason: String, details: String):
	print("[Client] Disconnected from server with reason: %s" % reason)
	disconnected.emit(reason, details)

@rpc("authority")
func _authentication_ok():
	authentication_ok.emit()

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

@rpc("authority")
func _set_state(position: Vector3, health: int, stamina: float, hunger: float, hotbar: PackedByteArray, inventory: PackedByteArray):
	set_state.emit(position, health, stamina, hunger, hotbar, inventory)

# -- Client -> Server -- #

signal world_loaded()
signal authenticate(unique_id: Variant, auth_ticket: Dictionary)
signal attack_player(target_id: int, damage: int)
signal attack_entity(entity: NodePath, damage: int)
signal inv_data(hotbar: PackedByteArray, inventory: PackedByteArray)

@rpc("any_peer", "call_remote")
func _world_loaded():
	world_loaded.emit()

@rpc("any_peer", "call_remote")
func _authenticate(unique_id: Variant, auth_ticket: Dictionary):
	authenticate.emit(unique_id, auth_ticket)

@rpc("any_peer", "call_remote")
func _attack_player(target_id: int, damage: int):
	attack_player.emit(target_id, damage)

@rpc("any_peer", "call_remote")
func _attack_entity(entity: NodePath, damage: int):
	attack_entity.emit(entity, damage)

@rpc("any_peer", "call_remote")
func _inv_data(hotbar: PackedByteArray, inventory: PackedByteArray):
	inv_data.emit(hotbar, inventory)
