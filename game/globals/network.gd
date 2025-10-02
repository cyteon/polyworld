extends Node

var peer: ENetMultiplayerPeer = ENetMultiplayerPeer.new()
var server_host: String
var server_port: int

# CLIENT -> SERVER

@rpc("any_peer", "call_remote", "reliable")
func _authenticate(_id: Variant, _username: String, _auth_ticket: Dictionary) -> void: pass

@rpc("any_peer", "call_remote", "reliable")
func _player_ready() -> void: pass

# SERVER -> CLIENT

signal disconnect(reason: String)
@rpc("authority", "call_remote", "reliable")
func _disconnect(reason: String) -> void:
	disconnect.emit(reason)

signal authenticated
@rpc("authority", "call_remote", "reliable")
func _authenticated() -> void:
	authenticated.emit()

# CLIENT _CLIENT

signal state_change(state: Dictionary)
@rpc("any_peer", "call_remote", "unreliable")
func _state_change(state: Dictionary) -> void:
	state_change.emit(state)
