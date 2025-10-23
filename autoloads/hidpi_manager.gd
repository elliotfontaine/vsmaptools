extends Node

const DEFAULT_RESOLUTION = Vector2i(1440, 960)

func _ready() -> void:
	var screen_scale := DisplayServer.screen_get_scale(DisplayServer.SCREEN_OF_MAIN_WINDOW)
	DisplayServer.window_set_size(DEFAULT_RESOLUTION * screen_scale)
	get_window().content_scale_factor = screen_scale
	
