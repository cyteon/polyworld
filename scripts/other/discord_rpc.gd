extends Node

@export var details: String = "An low-poly open world multiplayer game"
@export var state: String = "In the main menu" # Ex: walking around
@export var large_image: String = ""
@export var large_image_text: String = ""
@export var small_image: String = ""
@export var small_image_text: String = ""

func _ready() -> void:
	DiscordRPC.app_id = 1355611489255428148
	DiscordRPC.details = details
	DiscordRPC.state = state
	DiscordRPC.large_image = large_image
	DiscordRPC.large_image_text = large_image_text
	DiscordRPC.small_image = small_image
	DiscordRPC.small_image_text = small_image_text

	DiscordRPC.start_timestamp = int(Time.get_unix_time_from_system())

	DiscordRPC.refresh()
	
	print("Discord User: %s" % DiscordRPC.get_current_user())
	print("Discord Working: %s" % DiscordRPC.get_is_discord_working())
	print("Discord Result: %s" % DiscordRPC.get_result_int())
