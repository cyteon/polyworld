extends Node

var peer: ENetMultiplayerPeer = ENetMultiplayerPeer.new()
var server_host: String
var server_port: int

# CLIENT -> SERVER

@rpc("any_peer", "call_remote", "reliable")
func _authenticate(_id: Variant, _username: String, _auth_ticket: Dictionary):
	pass

# SERVER -> CLIENT

signal disconnect(reason: String)
@rpc("authority", "call_remote", "reliable")
func _disconnect(reason: String):
	disconnect.emit(reason)

signal authenticated
@rpc("authority", "call_remote", "reliable")
func _authenticated():
	authenticated.emit()
