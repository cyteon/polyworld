extends Node

var peer: ENetMultiplayerPeer = ENetMultiplayerPeer.new()
var users: Dictionary = {}

var port: int = 6070

# CLIENT -> SERVER

signal authenticate(id: Variant, username: String, auth_ticket: Dictionary)
@rpc("any_peer", "call_remote", "reliable")
func _authenticate(id: Variant, username: String, auth_ticket: Dictionary):
	authenticate.emit(id, username, auth_ticket)

# SERVER -> CLIENT

@rpc("authority", "call_remote", "reliable")
func _disconnect(_reason: String):
	pass

@rpc("authority", "call_remote", "reliable")
func _authenticated():
	pass
