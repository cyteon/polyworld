extends Node

func _process(_delta: float) -> void:
	if not OS.has_feature("server"):
		Engine.get_singleton("DiscordRPC").run_callbacks()
