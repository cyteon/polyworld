extends Node

var steam_started: bool = false
var app_owner: int = 0
var is_owned: bool = false

func _ready() -> void:
	if Engine.has_singleton("Steam"):
		var initialize_response: Dictionary = Steam.steamInitEx()
		print("Did Steam initialize?: %s " % initialize_response)
		
		if initialize_response.status == 0:
			steam_started = true
			is_owned = Steam.isSubscribed()
			app_owner = Steam.getAppOwner()

func _process(delta: float) -> void:
	if steam_started:
		Steam.run_callbacks()
