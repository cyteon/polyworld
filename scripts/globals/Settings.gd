extends Node

const SETTINGS_PATH: String = "user://settings.cfg"
var settings: ConfigFile = ConfigFile.new()

func _ready() -> void:
	if OS.has_feature("server"): return
	
	var status = settings.load(SETTINGS_PATH)
	
	if status == ERR_FILE_CANT_OPEN:
		print("[Client] Could not load settings.cfg")
