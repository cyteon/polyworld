extends Control

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	$Version.text = "version %s on %s %s" % [
		ProjectSettings.get_setting("application/config/version"),
		"x64" if OS.has_feature("x86_64") else (
			"x32" if OS.has_feature("x86_32") else (
				"arm64" if OS.has_feature("arm64") else (
					"arm32" if OS.has_feature("arm32") else "unknown arch"
				)
			)
		),
		OS.get_name(),
	]
