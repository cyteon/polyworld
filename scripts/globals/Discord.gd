extends Node

func _process(delta: float) -> void:
	DiscordRPC.run_callbacks()
