extends Node

func _ready() -> void:
	var initialize_response: Dictionary = Steam.steamInitEx()
	print("SteamWorks | %s" % initialize_response)

func _process(_delta: float) -> void:
	Steam.run_callbacks()
