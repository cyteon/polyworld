extends Node

const SETTINGS_PATH: String = "user://settings.cfg"
var config: ConfigFile = ConfigFile.new()

# graphics
var max_fps: int = 0
var show_perf_monitor: bool = false
var anti_aliasing: int = 2
var taa: bool = true
var fxaa: bool = false
var vsync: bool = false

# display
var fullscreen: bool = true
var resolution: int = 1

# other
var disable_chat: bool = true
var perf_monitor: bool = false

func _ready() -> void:
	load_()

func apply() -> void:
	Engine.max_fps = max_fps
	
	match anti_aliasing:
		0:
			get_viewport().msaa_3d = Viewport.MSAA_DISABLED
		1:
			get_viewport().msaa_3d = Viewport.MSAA_2X
		2:
			get_viewport().msaa_3d = Viewport.MSAA_4X
		3:
			get_viewport().msaa_3d = Viewport.MSAA_8X
	
	get_viewport().use_taa = taa
	get_viewport().screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA if fxaa else Viewport.SCREEN_SPACE_AA_DISABLED
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if vsync else DisplayServer.VSYNC_DISABLED)
	
	match resolution:
		0:
			get_window().set_size(Vector2(2560, 1440))
		1:
			get_window().set_size(Vector2(1920, 1080))
		2:
			get_window().set_size(Vector2(1600, 900))
		3:
			get_window().set_size(Vector2(1280, 720))
	
	DisplayServer.window_set_mode(
		DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen
		else DisplayServer.WINDOW_MODE_WINDOWED
	)

func save() -> void:
	config.set_value("graphics", "max_fps", max_fps)
	config.set_value("graphics", "show_perf_monitor", show_perf_monitor)
	config.set_value("graphics", "anti_aliasing", anti_aliasing)
	config.set_value("graphics", "taa", taa)
	config.set_value("graphics", "fxaa", fxaa)
	config.set_value("graphics", "vsync", vsync)
	
	config.set_value("display", "fullscreen", fullscreen)
	config.set_value("display", "resolution", resolution)
	
	config.set_value("multiplayer", "disable_chat", disable_chat)
	config.set_value("other", "perf_monitor", perf_monitor)
	
	config.save("user://settings.cfg")
	
	apply()

func load_() -> void:
	if OS.has_feature("server"): return
	
	var status = config.load(SETTINGS_PATH)
	
	if status == ERR_FILE_CANT_OPEN:
		print("[Client] Could not load settings.cfg")
		return
	
	max_fps = config.get_value("graphics", "max_fps", 0)
	show_perf_monitor = config.get_value("graphics", "show_perf_monitor", false)
	anti_aliasing = config.get_value("graphics", "anti_aliasing", 2)
	taa = config.get_value("graphics", "taa", true)
	fxaa = config.get_value("graphics", "fxaa", false)
	vsync = config.get_value("graphics", "vsync", false)
	
	fullscreen = config.get_value("display", "fullscreen", true)
	resolution = config.get_value("display", "resolution", 1)
	
	disable_chat = config.get_value("multiplayer", "disable_chat", false)
	perf_monitor = config.get_value("other", "perf_monitor", false)
	
	apply()
