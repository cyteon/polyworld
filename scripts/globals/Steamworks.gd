extends Node

var steam_started: bool = false
var app_owner: int = 0
var is_owned: bool = false

var steam_api

func _ready() -> void:
	if Engine.has_singleton("Steam"):
		steam_api = Engine.get_singleton("Steam")
		var initialize_response: Dictionary = steam_api.steamInitEx()
		print("Did Steam initialize?: %s " % initialize_response)
		
		if initialize_response.status == 0:
			steam_started = true
			is_owned = steam_api.isSubscribed()
			app_owner = steam_api.getAppOwner()

func _process(delta: float) -> void:
	if steam_started:
		steam_api.run_callbacks()
