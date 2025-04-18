extends Node

func _process(delta: float) -> void:
	if not OS.has_feature("server"):
		DiscordRPC.run_callbacks()
