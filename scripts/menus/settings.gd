extends Control

var loaded: bool = false

func _ready() -> void:
	$HBoxContainer/Graphics/MaxFPS/SpinBox.value = Settings.max_fps
	$HBoxContainer/Graphics/AntiAliasing/OptionButton.selected = Settings.anti_aliasing
	$HBoxContainer/Graphics/FXAA/CheckButton.button_pressed = Settings.fxaa
	$HBoxContainer/Graphics/TAA/CheckButton.button_pressed = Settings.taa
	$HBoxContainer/Graphics/VSync/CheckButton.button_pressed = Settings.vsync
	
	$HBoxContainer/Display/FullScreen/CheckButton.button_pressed = Settings.fullscreen
	$HBoxContainer/Display/Resolution/OptionButton.selected = Settings.resolution
	$HBoxContainer/Display/Resolution/OptionButton.disabled = Settings.fullscreen
	
	$HBoxContainer/Other/DisabeChat/CheckButton.button_pressed = Settings.disable_chat
	$HBoxContainer/Other/PerfMonitor/CheckButton.button_pressed = Settings.perf_monitor
	
	loaded = true

func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/menus/main.tscn")

func _value_changed(_val) -> void:
	if not loaded:
		return
	
	Settings.max_fps = $HBoxContainer/Graphics/MaxFPS/SpinBox.value
	Settings.anti_aliasing = $HBoxContainer/Graphics/AntiAliasing/OptionButton.selected
	Settings.fxaa = $HBoxContainer/Graphics/FXAA/CheckButton.button_pressed
	Settings.taa = $HBoxContainer/Graphics/TAA/CheckButton.button_pressed
	Settings.vsync = $HBoxContainer/Graphics/VSync/CheckButton.button_pressed
	
	Settings.fullscreen = $HBoxContainer/Display/FullScreen/CheckButton.button_pressed
	Settings.resolution = $HBoxContainer/Display/Resolution/OptionButton.selected
	$HBoxContainer/Display/Resolution/OptionButton.disabled = Settings.fullscreen
	
	Settings.disable_chat = $HBoxContainer/Other/DisabeChat/CheckButton.button_pressed
	Settings.perf_monitor = $HBoxContainer/Other/PerfMonitor/CheckButton.button_pressed 
	
	Settings.save()
