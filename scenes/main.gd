extends Control

const VERBOSITY: SQLite.VerbosityLevel = SQLite.NORMAL
const BoundSquareView := preload("res://scenes/bounds_square_view.gd")

enum EXPORT_TYPE {PNG, JPEG}

var db: SQLite = null
var map: Map
var export_type := EXPORT_TYPE.PNG

var _export_progress: int = 0:
	set(value):
		_export_progress = value
		export_progress_bar.value = value

var min_X: int:
	set(value): export_properties_box.set_value(&"Min X", value)
	get: return export_properties_box.get_value(&"Min X")
var max_X: int:
	set(value): export_properties_box.set_value(&"Max X", value)
	get: return export_properties_box.get_value(&"Max X")
var min_Z: int:
	set(value): export_properties_box.set_value(&"Min Z", value)
	get: return export_properties_box.get_value(&"Min Z")
var max_Z: int:
	set(value): export_properties_box.set_value(&"Max Z", value)
	get: return export_properties_box.get_value(&"Max Z")
var use_relative_coords: bool:
	set(value): export_properties_box.set_value(&"Use Relative Coordinates", value)
	get: return export_properties_box.get_value(&"Use Relative Coordinates")
var spawnpoint_coords: int:
	set(value): export_properties_box.set_value(&"Spawnpoint Absolute Coordinates", value)
	get: return export_properties_box.get_value(&"Spawnpoint Absolute Coordinates")
var whole_map: bool:
	set(value): export_properties_box.set_value(&"Whole Map", value)
	get: return export_properties_box.get_value(&"Whole Map")

@onready var timer: Timer = %Timer
@onready var file_label: Label = %FileLabel
@onready var import_button: Button = %ImportButton
@onready var map_info_hint: Label = %MapInfoHint
@onready var loading_label: Label = %LoadingLabel
@onready var import_file_dialog: FileDialog = %ImportFileDialog
@onready var export_file_dialog: FileDialog = %ExportFileDialog
@onready var map_density_value: Label = %MapDensityValue
@onready var map_loading_bar: ProgressBar = %MapLoadingBar
@onready var loaded_map_info: VBoxContainer = %LoadedMapInfo
@onready var chunks_number_value: Label = %ChunksNumberValue
@onready var bounds_square_view: BoundSquareView = %BoundsSquareView
@onready var export_properties_box: PropertiesBox = %ExportPropertiesBox
@onready var loading_map_container: HBoxContainer = %LoadingMapContainer
@onready var image_size_label: Label = %ImageSizeLabel
@onready var export_button: Button = %ExportButton
@onready var export_progress_bar: ProgressBar = %ExportProgressBar
@onready var logs_rtl: RichTextLabel = %LogsRTL
@onready var map_preview: MapPreview = %MapPreview
@onready var version_tag: Label = %VersionTag


func _ready() -> void:
	_fill_export_properties_box()
	map_info_hint.show()
	loading_map_container.hide()
	loaded_map_info.hide()
	export_progress_bar.hide()
	export_button.disabled = true

	var main_module := Logger.get_module(&"main")
	var sink := RichTextLabelSink.new("rich_text_label", logs_rtl, Logger.ExternalSink.QUEUE_MODES.ALL)
	main_module.output_level = Logger.DEBUG if OS.is_debug_build() else Logger.INFO
	main_module.set_external_sink(sink)
	main_module.set_common_output_strategy(Logger.STRATEGY_PRINT_AND_EXTERNAL_SINK)
	map_preview.selection_tool.selected.connect(_on_selection_tool_selected)
	
	Logger.debug("Screen scale factor: %s" % DisplayServer.screen_get_scale(DisplayServer.SCREEN_OF_MAIN_WINDOW))

	var project_version: String = ProjectSettings.get_setting("application/config/version")
	version_tag.text = "v%s" % project_version
	Logger.info("Vintage Story Map Tools — v%s" % project_version)
	Logger.info("Godot version: %s" % Engine.get_version_info()["string"] + "— https://godotengine.org")
	Logger.info("Renderer: %s" % RenderingServer.get_video_adapter_name())


func get_filename_from_path(path: String) -> String:
	if path.is_absolute_path() or path.is_relative_path():
		return path.split("/")[-1]
	else:
		return ""


func update_displayed_bounds() -> void:
	if not map:
		return
	var absolute_pos := export_properties_box.get_int(&"Spawnpoint Absolute Coordinates")
	var is_relative := export_properties_box.get_bool(&"Use Relative Coordinates")
	bounds_square_view.set_bounds_from_vect(
		map.top_left_bound * Map.CHUNK_SIZE - Vector2i.ONE * absolute_pos * int(is_relative),
		map.bottom_right_bound * Map.CHUNK_SIZE - Vector2i.ONE * absolute_pos * int(is_relative),
	)


func update_displayed_image_size() -> void:
	var x := max_X - min_X
	var z := max_Z - min_Z
	if z > 16E3 or x > 16E3:
		image_size_label.text = str(x) + " x " + str(z) + " (too large)"
		image_size_label.add_theme_color_override("font_color", Color.RED)
	else:
		image_size_label.text = str(x) + " x " + str(z)
		image_size_label.remove_theme_color_override("font_color")


func _on_import_button_pressed() -> void:
	Logger.debug("Import button pressed.")
	import_file_dialog.current_dir = OS.get_data_dir().path_join("VintagestoryData").path_join("Maps")
	import_file_dialog.popup()


func _on_file_dialog_file_selected(path: String) -> void:
	Logger.debug("Map file selected.")
	db = SQLite.new()
	db.path = path
	db.verbosity_level = VERBOSITY
	Logger.debug("New SQLite database access with verbosity level: %s" % VERBOSITY)

	Logger.info("Loading map file at " + path)
	file_label.text = get_filename_from_path(path)
	file_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	
	import_button.disabled = true
	export_button.disabled = true

	if map:
		Logger.debug("Freeing previously loaded map")
		map.queue_free()
	
	map = Map.new(db)
	add_child(map)

	map.loading_step.connect(_on_map_loading_step)
	map.loading_completed.connect(_on_map_loading_completed)
	map.export_progressed.connect(_on_map_export_progressed)
	map.export_image_ready.connect(_on_export_image_ready)
	map.load_pieces()

	map_info_hint.hide()
	loaded_map_info.hide()
	loading_map_container.show()


func _on_map_loading_step(step: float) -> void:
	map_loading_bar.value = step * 100


func _on_map_loading_completed() -> void:
	Logger.info("Map loading completed.")
	chunks_number_value.text = str(map.chunks_count)
	map_density_value.text = str(int(map.get_map_density() * 100)) + "%"
	update_displayed_bounds()
	map_info_hint.hide()
	loading_map_container.hide()
	map_loading_bar.value = 0.0
	loaded_map_info.show()

	import_button.disabled = false
	export_button.disabled = false
	
	map_preview.draw_silhouette_preview(
		map.get_pieces_relative_chunk_positions(
			Vector2i(spawnpoint_coords, spawnpoint_coords) / map.CHUNK_SIZE
		)
	)


func _on_map_export_progressed(percent: int) -> void:
	_export_progress = percent


func _on_timer_timeout() -> void:
	match loading_label.text:
		&"Loading.":
			loading_label.text = &"Loading.."
		&"Loading..":
			loading_label.text = &"Loading..."
		&"Loading...":
			loading_label.text = &"Loading."


func _fill_export_properties_box() -> void:
	export_properties_box.add_bool(&"Whole Map", false)
	export_properties_box.add_group("Bounds (in blocks)")
	export_properties_box.add_int(&"Min X")
	export_properties_box.add_int(&"Max X")
	export_properties_box.add_int(&"Min Z")
	export_properties_box.add_int(&"Max Z")
	export_properties_box.end_group()
	export_properties_box.add_group("Advanced Options", true)
	export_properties_box.add_bool(&"Use Relative Coordinates", true)
	export_properties_box.add_int(&"Spawnpoint Absolute Coordinates")
	export_properties_box.set_value(&"Spawnpoint Absolute Coordinates", 512000)


func _on_export_properties_box_bool_changed(key: StringName, is_true: bool) -> void:
	if key == &"Use Relative Coordinates":
		var diff := export_properties_box.get_int(&"Spawnpoint Absolute Coordinates")
		var diff_sign := -1 if is_true else 1
		min_X += diff * diff_sign
		max_X += diff * diff_sign
		min_Z += diff * diff_sign
		max_Z += diff * diff_sign
		update_displayed_bounds()
	
	if key == &"Whole Map":
		if is_true:
			export_properties_box.toggle_editor(&"Min X", false)
			export_properties_box.toggle_editor(&"Max X", false)
			export_properties_box.toggle_editor(&"Min Z", false)
			export_properties_box.toggle_editor(&"Max Z", false)
			if not map:
				Logger.warn("You should load a map from file first.")
				return
			var absolute_pos := export_properties_box.get_int(&"Spawnpoint Absolute Coordinates")
			var is_relative := export_properties_box.get_bool(&"Use Relative Coordinates")
			var tl := map.top_left_bound * Map.CHUNK_SIZE - Vector2i.ONE * absolute_pos * int(is_relative)
			var br := (map.bottom_right_bound + Vector2i.ONE) * Map.CHUNK_SIZE - Vector2i.ONE * absolute_pos * int(is_relative)
			min_X = tl.x
			max_X = br.x
			min_Z = tl.y
			max_Z = br.y
		else:
			export_properties_box.toggle_editor(&"Min X", true)
			export_properties_box.toggle_editor(&"Max X", true)
			export_properties_box.toggle_editor(&"Min Z", true)
			export_properties_box.toggle_editor(&"Max Z", true)


func _on_export_properties_box_number_changed(_key: StringName, _new_value: bool) -> void:
	update_displayed_image_size()


func _on_export_button_pressed() -> void:
	if not _export_options_are_valid():
		return
	if not map:
		Logger.error("Cannot export since there isn't a loaded map.")
		return
	
	_export_progress = 0
	export_progress_bar.show()
	import_button.disabled = true
	export_button.disabled = true
	
	var topleft: Vector2i
	var bottomright: Vector2i
	if whole_map:
		topleft = map.top_left_bound * Map.CHUNK_SIZE
		bottomright = (map.bottom_right_bound + Vector2i.ONE) * Map.CHUNK_SIZE
		Logger.info("Exporting whole map. Bounds: {0}, {1}".format([topleft, bottomright]))
	else:
		if use_relative_coords:
			topleft = Vector2i(min_X + spawnpoint_coords, min_Z + spawnpoint_coords)
			bottomright = Vector2i(max_X + spawnpoint_coords, max_Z + spawnpoint_coords)
		else:
			topleft = Vector2i(min_X, min_Z)
			bottomright = Vector2i(max_X, max_Z)
		Logger.info("Exporting map subset. Bounds: {0}, {1}".format([topleft, bottomright]))
	
	Logger.info("Processing image for export...")
	map.build_export_threaded(topleft, bottomright, whole_map)


func _on_export_image_ready() -> void:
	Logger.info("Image processing completed.")
	export_progress_bar.hide()
	match export_type:
		EXPORT_TYPE.PNG:
			export_file_dialog.set_current_file("vintage_story_map.png")
		EXPORT_TYPE.JPEG:
			export_file_dialog.set_current_file("vintage_story_map.jpg")
		_:
			export_file_dialog.set_current_file("vintage_story_map.png")
	import_button.disabled = false
	export_button.disabled = false
	export_file_dialog.popup()
	

func _on_export_file_dialog_file_selected(path: String) -> void:
	var img := map.get_export_image()
	if img:
		Logger.info("Saving image to file: %s" % path)
		match export_type:
			EXPORT_TYPE.PNG:
				img.save_png(path)
			EXPORT_TYPE.JPEG:
				img.save_jpg(path, 0.75)
			_:
				img.save_png(path)
	else:
		Logger.error("No export image ready", &"main", ERR_DOES_NOT_EXIST)


func _on_file_label_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		import_button.pressed.emit()


func _export_options_are_valid() -> bool:
	if (max_X - min_X) > 16E3 or (max_X - min_X) > 16E3:
		Logger.error(
			"Images larger than 16k×16k are not supported due to internal limitations.",
			&"main",
			ERR_INVALID_DATA,
		)
		return false
	
	if whole_map:
		Logger.debug("Export options are valid.")
		return true
	elif min_X == max_X and max_X == min_Z and min_Z == max_Z:
		Logger.error(
			"Selection is empty because bounds are identical. Consider enabling `whole_map`.",
			&"main",
			ERR_INVALID_DATA,
		)
		return false
	elif not min_X < max_X:
		Logger.error("Min X should be lower than Max X.", &"main", ERR_INVALID_DATA)
		return false
	elif not min_Z < max_Z:
		Logger.error("Min Z should be lower than Max Z.", &"main", ERR_INVALID_DATA)
		return false
	else:
		Logger.debug("Export options are valid.")
		return true


func _on_filetype_option_button_item_selected(index: int) -> void:
	export_type = EXPORT_TYPE.values()[index]


func _on_selection_tool_selected(rect: Rect2) -> void:
	if whole_map:
		whole_map = false
	var rect_i := Rect2i(rect)
	min_X = rect_i.position.x + (spawnpoint_coords * int(!use_relative_coords))
	min_Z = rect_i.position.y + (spawnpoint_coords * int(!use_relative_coords))
	max_X = rect_i.end.x + (spawnpoint_coords * int(!use_relative_coords))
	max_Z = rect_i.end.y + (spawnpoint_coords * int(!use_relative_coords))
