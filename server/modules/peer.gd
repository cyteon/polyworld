extends Node

func _peer_connected(peer_id: int):
	Log.info("new peer with id %s has connected" % peer_id)

func _peer_disconnected(peer_id: int):
	Log.info("peer id %s has disconnected" % peer_id) # say username
