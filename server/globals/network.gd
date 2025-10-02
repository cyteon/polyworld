extends Node

var peer: ENetMultiplayerPeer = ENetMultiplayerPeer.new()
var users: Dictionary = {}
var id_peer_map: Dictionary = {}

var port: int = 6070

# CLIENT -> SERVER

signal authenticate(id: Variant, username: String, auth_ticket: Dictionary)
@rpc("any_peer", "call_remote", "reliable")
func _authenticate(id: Variant, username: String, auth_ticket: Dictionary):
	authenticate.emit(id, username, auth_ticket)

signal player_ready # when player ready to "join world", aka they can be spawned
@rpc("any_peer", "call_remote", "reliable")
func _player_ready():
	player_ready.emit()

# SERVER -> CLIENT

@rpc("authority", "call_remote", "reliable")
func _disconnect(_reason: String): pass

@rpc("authority", "call_remote", "reliable")
func _authenticated(): pass

# CLIENT -> CLIENT
# i gotta have these here or error

@rpc("any_peer", "call_remote", "unreliable")
func _state_change(_state: Dictionary) -> void: pass
