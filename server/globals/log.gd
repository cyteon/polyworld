extends Node

func info(message: String) -> void:
	print("[INFO] [%s] %s" % [Time.get_time_string_from_system(), message])

func warn(message: String) -> void:
	push_warning("[%s] %s" % [Time.get_time_string_from_system(), message])

func error(message: String) -> void:
	push_error("[%s] %s" % [Time.get_time_string_from_system(), message])
