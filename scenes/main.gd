extends Control

enum ImportType { WORLDSAVE, MAP, EXTERNAL_MAP }
enum ExportType { PNG, JPEG }
enum BoxProperty {
	MIN_X,
	MAX_X,
	MIN_Z,
	MAX_Z,
	USE_RELATIVE,
	WHOLE_MAP,
	WORLD_SIZE_X,
	WORLD_SIZE_Z,
}

const VERBOSITY: SQLite.VerbosityLevel = SQLite.NORMAL
const BoundSquareView := preload("res://scenes/bounds_square_view.gd")
const MAX_IMAGE_SIZE := int(16E3)
const JPEG_QUALITY := 0.75
const PROP_STRINGNAMES: Dictionary[BoxProperty, StringName] = {
	BoxProperty.MIN_X: &"Min X",
	BoxProperty.MAX_X: &"Max X",
	BoxProperty.MIN_Z: &"Min Z",
	BoxProperty.MAX_Z: &"Max Z",
	BoxProperty.USE_RELATIVE: &"Use Relative Coordinates",
	BoxProperty.WHOLE_MAP: &"Whole Map",
	BoxProperty.WORLD_SIZE_X: &"World Size (X axis)",
	BoxProperty.WORLD_SIZE_Z: &"World Size (Z axis)",
}

var db: SQLite = null
var map: Map
var export_type := ExportType.PNG
var VINTAGESTORYDATA_PATH: String = OS.get_data_dir().path_join("VintagestoryData")
var min_X: int:
	set(value):
		_set_box_property(BoxProperty.MIN_X, value)
	get:
		return _get_box_property(BoxProperty.MIN_X)
var max_X: int:
	set(value):
		_set_box_property(BoxProperty.MAX_X, value)
	get:
		return _get_box_property(BoxProperty.MAX_X)
var min_Z: int:
	set(value):
		_set_box_property(BoxProperty.MIN_Z, value)
	get:
		return _get_box_property(BoxProperty.MIN_Z)
var max_Z: int:
	set(value):
		_set_box_property(BoxProperty.MAX_Z, value)
	get:
		return _get_box_property(BoxProperty.MAX_Z)
var use_relative_coords: bool:
	set(value):
		_set_box_property(BoxProperty.USE_RELATIVE, value)
	get:
		return _get_box_property(BoxProperty.USE_RELATIVE)
var whole_map: bool:
	set(value):
		_set_box_property(BoxProperty.WHOLE_MAP, value)
	get:
		return _get_box_property(BoxProperty.WHOLE_MAP)
var world_size: Vector2i:
	set(value):
		_set_box_property(BoxProperty.WORLD_SIZE_X, value.x)
		_set_box_property(BoxProperty.WORLD_SIZE_Z, value.y)
	get:
		return Vector2i(
			_get_box_property(BoxProperty.WORLD_SIZE_X),
			_get_box_property(BoxProperty.WORLD_SIZE_Z),
		)
var spawnpoint_abs: Vector2i:
	get:
		return world_size / 2
var _export_progress: int = 0:
	set(value):
		_export_progress = value
		export_progress_bar.value = value
var _target_path: String
# Array of external files metadata for the ImportOptionButton.
var _recently_opened: Dictionary[String, ImportType] # strings are paths
var _selected_file: Dictionary # {type": ImportType, "path": String}
var _last_file_dialog_path: String = VINTAGESTORYDATA_PATH.path_join("Maps")

@onready var timer: Timer = %Timer
@onready var file_explorer_button: Button = %FileExplorerButton
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
@onready var import_option_button: OptionButton = %ImportOptionButton
@onready var load_map_button: Button = %LoadMapButton
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
	var sink := RichTextLabelSink.new(
		"rich_text_label",
		logs_rtl,
		Logger.ExternalSink.QUEUE_MODES.ALL,
	)
	main_module.output_level = Logger.DEBUG if OS.is_debug_build() else Logger.INFO
	main_module.set_external_sink(sink)
	main_module.set_common_output_strategy(Logger.STRATEGY_PRINT_AND_EXTERNAL_SINK)
	map_preview.selection_tool.selected.connect(_on_selection_tool_selected)

	var project_version: String = ProjectSettings.get_setting("application/config/version")
	version_tag.text = "v%s" % project_version
	Logger.info("Vintage Story Map Tools — v%s" % project_version)
	Logger.info(
		"Godot version: %s" % Engine.get_version_info()["string"] + "— https://godotengine.org",
	)
	Logger.info("Renderer: %s" % RenderingServer.get_video_adapter_name())
	Logger.debug(
		"Screen scale factor: %s" % DisplayServer.screen_get_scale(
			DisplayServer.SCREEN_OF_MAIN_WINDOW,
		),
	)


func update_displayed_bounds() -> void:
	if not map:
		return
	bounds_square_view.set_bounds_from_vect(
		map.top_left_block - spawnpoint_abs * int(use_relative_coords),
		map.bottom_right_block - spawnpoint_abs * int(use_relative_coords),
	)


func update_displayed_image_size() -> void:
	var x := max_X - min_X
	var z := max_Z - min_Z
	if z > MAX_IMAGE_SIZE or x > MAX_IMAGE_SIZE:
		image_size_label.text = str(x) + " x " + str(z) + " (too large)"
		image_size_label.add_theme_color_override("font_color", Color.ORANGE_RED)
	else:
		image_size_label.text = str(x) + " x " + str(z)
		image_size_label.remove_theme_color_override("font_color")


func _fill_export_properties_box() -> void:
	export_properties_box.add_bool(PROP_STRINGNAMES[BoxProperty.WHOLE_MAP], false)
	export_properties_box.add_group("Bounds (in blocks)")
	export_properties_box.add_int(PROP_STRINGNAMES[BoxProperty.MIN_X])
	export_properties_box.add_int(PROP_STRINGNAMES[BoxProperty.MAX_X])
	export_properties_box.add_int(PROP_STRINGNAMES[BoxProperty.MIN_Z])
	export_properties_box.add_int(PROP_STRINGNAMES[BoxProperty.MAX_Z])
	export_properties_box.end_group()
	export_properties_box.add_group("Advanced Options", true)
	export_properties_box.add_bool(PROP_STRINGNAMES[BoxProperty.USE_RELATIVE], true)
	export_properties_box.add_int(PROP_STRINGNAMES[BoxProperty.WORLD_SIZE_X])
	export_properties_box.add_int(PROP_STRINGNAMES[BoxProperty.WORLD_SIZE_Z])
	_set_box_property(BoxProperty.WORLD_SIZE_X, Map.DEFAULT_WORLD_SIZE.x)
	_set_box_property(BoxProperty.WORLD_SIZE_Z, Map.DEFAULT_WORLD_SIZE.y)


func _select_file_for_import(type: ImportType, path: String) -> void:
	var index := import_option_button.item_count
	if type == ImportType.EXTERNAL_MAP:
		import_option_button.add_item(path) # full path
	else:
		import_option_button.add_item(path.get_file())

	import_option_button.set_item_metadata(index, { &"type": type, &"path": path })
	import_option_button.select(index)
	load_map_button.disabled = false

	_selected_file = { &"type": type, &"path": path }

	if type in [ImportType.MAP, ImportType.EXTERNAL_MAP]:
		Logger.debug("Map file selected.")
	if type == ImportType.WORLDSAVE:
		Logger.debug("World Save file selected.")


func _set_selection_to_bounds() -> void:
	var tl := map.top_left_block - spawnpoint_abs * int(use_relative_coords)
	var br := map.bottom_right_block - spawnpoint_abs * int(use_relative_coords)
	min_X = tl.x
	max_X = br.x
	min_Z = tl.y
	max_Z = br.y


func _set_box_property(property: BoxProperty, value: Variant) -> void:
	var prop_name: StringName = PROP_STRINGNAMES.get(property, &"")
	if prop_name != &"":
		export_properties_box.set_value(prop_name, value)
	else:
		push_error("This property was never registered to the box.")


func _get_box_property(property: BoxProperty) -> Variant:
	var prop_name: StringName = PROP_STRINGNAMES.get(property, &"")
	if prop_name:
		return export_properties_box.get_value(prop_name)

	push_error("This property was never registered to the box.")
	return null


func _update_import_option_button_list() -> void:
	var button := import_option_button
	var meta: Dictionary = { }
	if button.selected:
		meta = button.get_selected_metadata()
	button.clear()

	var saves_dir := VINTAGESTORYDATA_PATH.path_join("Saves")
	var maps_dir := VINTAGESTORYDATA_PATH.path_join("Maps")

	if not DirAccess.dir_exists_absolute(VINTAGESTORYDATA_PATH):
		Logger.error(
			"Could not find the VintageStoryData directory. " +
			"Select a file with the file explorer.",
		)
		return

	button.add_separator("Select World")
	_add_directory_files_to_option_button(button, saves_dir, ImportType.WORLDSAVE)
	button.add_separator("Select Map Directly")
	_add_directory_files_to_option_button(button, maps_dir, ImportType.MAP)

	if not _recently_opened.is_empty():
		button.add_separator("Select Recently Opened")
		for recent_path in _recently_opened:
			var index := button.item_count
			var recent_meta := {
				&"type": _recently_opened[recent_path],
				&"path": recent_path,
			}
			button.add_item(recent_path)
			button.set_item_metadata(index, recent_meta)

	# reselect previous selection
	if not meta:
		return
	for idx in button.item_count:
		if button.get_item_metadata(idx) == meta:
			button.select(idx)
			break


func _add_directory_files_to_option_button(
		button: OptionButton,
		dir_path: String,
		import_type: ImportType,
) -> void:
	if not DirAccess.dir_exists_absolute(dir_path):
		Logger.warn("Directory not found: %s" % dir_path)
		return

	var dir := DirAccess.open(dir_path)
	if dir == null:
		Logger.warn("Failed to open directory: %s" % dir_path)
		return

	dir.list_dir_begin()
	var file_name := dir.get_next()

	while file_name != "":
		if file_name != "." and file_name != ".." and not dir.current_is_dir():
			var index := button.item_count
			var full_path := dir_path.path_join(file_name)
			button.add_item(file_name.get_basename())
			button.set_item_metadata(index, { &"type": import_type, &"path": full_path })
		file_name = dir.get_next()

	dir.list_dir_end()


func _export_options_are_valid() -> bool:
	if (max_X - min_X) > MAX_IMAGE_SIZE or (max_Z - min_Z) > MAX_IMAGE_SIZE:
		Logger.error(
			"Images larger than 16k×16k are not supported due to internal limitations. " +
			"Please disable 'Whole Map' and use manual bounds to export the map in multiple parts.",
			&"main",
			ERR_INVALID_DATA,
		)
		return false

	if whole_map:
		Logger.debug("Export options are valid.")
		return true
	if min_X == max_X and max_X == min_Z and min_Z == max_Z:
		Logger.error(
			"Selection is empty because bounds are identical. Consider enabling `whole_map`.",
			&"main",
			ERR_INVALID_DATA,
		)
		return false
	if not min_X < max_X:
		Logger.error("Min X should be lower than Max X.", &"main", ERR_INVALID_DATA)
		return false
	if not min_Z < max_Z:
		Logger.error("Min Z should be lower than Max Z.", &"main", ERR_INVALID_DATA)
		return false

	Logger.debug("Export options are valid.")
	return true


func _on_file_explorer_button_pressed() -> void:
	Logger.debug("Import button pressed.")
	import_file_dialog.current_dir = _last_file_dialog_path
	import_file_dialog.popup()


func _on_file_dialog_file_selected(path: String) -> void:
	var internal_map_dir := VINTAGESTORYDATA_PATH.path_join("Maps")
	if path.get_base_dir().begins_with(internal_map_dir):
		_select_file_for_import(ImportType.MAP, path)
	else:
		_select_file_for_import(ImportType.EXTERNAL_MAP, path)
		_recently_opened[path] = ImportType.EXTERNAL_MAP
	_last_file_dialog_path = path.get_base_dir()


func _load_file() -> void:
	if not _selected_file:
		return

	var map_path: String
	if _selected_file.type in [ImportType.MAP, ImportType.EXTERNAL_MAP]:
		map_path = _selected_file.path
	elif WorldSave.validate_db_file(_selected_file.path) != OK:
		Logger.error(
			"World save is invalid: %s" % _selected_file.path,
			&"main",
			WorldSave.validate_db_file(_selected_file.path),
		)
		return
	else:
		var potential_map_path := _get_map_path_from_save_path(_selected_file.path)
		if potential_map_path:
			map_path = potential_map_path
		else:
			Logger.error("Could not find map file associated to the selected save file.")
			return

	db = SQLite.new()
	db.path = map_path
	db.verbosity_level = VERBOSITY
	Logger.debug("New SQLite database access with verbosity level: %s" % VERBOSITY)

	Logger.info("Loading map file at " + map_path)

	file_explorer_button.disabled = true
	load_map_button.disabled = true
	export_button.disabled = true

	if map:
		Logger.debug("Freeing previously loaded map")
		map.queue_free()

	map = Map.new(db)
	add_child(map)

	if _selected_file.type == ImportType.WORLDSAVE:
		var save := WorldSave.new(_selected_file.path)
		map.world_size = save.get_world_size()

	map.loading_step.connect(_on_map_loading_step)
	map.loading_completed.connect(_on_map_loading_completed)
	map.export_progressed.connect(_on_map_export_progressed)
	map.export_image_ready.connect(_on_export_image_ready)
	map.load_pieces()

	map_info_hint.hide()
	loaded_map_info.hide()
	loading_map_container.show()


func _get_map_path_from_save_path(save_path: String) -> String:
	var save := WorldSave.new(save_path)
	var save_id := save.get_savegame_identifier()
	var map_files := DirAccess.get_files_at(VINTAGESTORYDATA_PATH.path_join("Maps"))
	if save_id + ".db" in map_files:
		return VINTAGESTORYDATA_PATH.path_join("Maps").path_join(save_id + ".db")

	return ""


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

	if whole_map:
		_set_selection_to_bounds()

	file_explorer_button.disabled = false
	load_map_button.disabled = false
	export_button.disabled = false

	world_size = map.world_size
	if world_size != Map.DEFAULT_WORLD_SIZE:
		Logger.info("World uses a custom size: %s" % world_size)

	map_preview.draw_silhouette_preview(
		map.get_pieces_relative_chunk_positions(
			spawnpoint_abs / map.CHUNK_SIZE,
		),
	)
	map_preview.center_view()


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


func _on_export_properties_box_bool_changed(key: StringName, is_true: bool) -> void:
	if key == PROP_STRINGNAMES[BoxProperty.USE_RELATIVE]:
		var diff := spawnpoint_abs
		var diff_sign := -1 if is_true else 1
		min_X += diff.x * diff_sign
		max_X += diff.x * diff_sign
		min_Z += diff.y * diff_sign
		max_Z += diff.y * diff_sign
		update_displayed_bounds()

	if key == PROP_STRINGNAMES[BoxProperty.WHOLE_MAP]:
		if is_true:
			export_properties_box.toggle_editor(PROP_STRINGNAMES[BoxProperty.MIN_X], false)
			export_properties_box.toggle_editor(PROP_STRINGNAMES[BoxProperty.MAX_X], false)
			export_properties_box.toggle_editor(PROP_STRINGNAMES[BoxProperty.MIN_Z], false)
			export_properties_box.toggle_editor(PROP_STRINGNAMES[BoxProperty.MAX_Z], false)
			if not map:
				Logger.warn("No map loaded. Please load a map first.")
				return
			_set_selection_to_bounds()
		else:
			export_properties_box.toggle_editor(PROP_STRINGNAMES[BoxProperty.MIN_X], true)
			export_properties_box.toggle_editor(PROP_STRINGNAMES[BoxProperty.MAX_X], true)
			export_properties_box.toggle_editor(PROP_STRINGNAMES[BoxProperty.MIN_Z], true)
			export_properties_box.toggle_editor(PROP_STRINGNAMES[BoxProperty.MAX_Z], true)


func _on_export_properties_box_number_changed(_key: StringName, _new_value: bool) -> void:
	update_displayed_image_size() # for changes to min_X, max_X, min_Z, max_Z
	update_displayed_bounds() # for changes to spawnpoint_abs


func _on_export_button_pressed() -> void:
	if not _export_options_are_valid():
		return
	if not map:
		Logger.error("Cannot export since there isn't a loaded map.")
		return

	match export_type:
		ExportType.PNG:
			export_file_dialog.set_current_file("vintage_story_map.png")
		ExportType.JPEG:
			export_file_dialog.set_current_file("vintage_story_map.jpg")
		_:
			export_file_dialog.set_current_file("vintage_story_map.png")
	export_file_dialog.popup()


func _on_export_file_dialog_file_selected(path: String) -> void:
	_target_path = path
	_export_progress = 0
	export_progress_bar.show()
	file_explorer_button.disabled = true
	load_map_button.disabled = true
	export_button.disabled = true

	var topleft: Vector2i
	var bottomright: Vector2i
	if whole_map:
		topleft = map.top_left_block
		bottomright = map.bottom_right_block
		Logger.info("Exporting whole map. Bounds: {0}, {1}".format([topleft, bottomright]))
	else:
		if use_relative_coords:
			topleft = Vector2i(min_X, min_Z) + spawnpoint_abs
			bottomright = Vector2i(max_X, max_Z) + spawnpoint_abs
		else:
			topleft = Vector2i(min_X, min_Z)
			bottomright = Vector2i(max_X, max_Z)
		Logger.info("Exporting map subset. Bounds: {0}, {1}".format([topleft, bottomright]))

	Logger.info("Processing image for export...")
	map.build_export_threaded(topleft, bottomright, whole_map)


func _on_export_image_ready() -> void:
	Logger.info("Image processing completed.")
	export_progress_bar.hide()

	file_explorer_button.disabled = false
	load_map_button.disabled = false
	export_button.disabled = false

	var img := map.get_export_image()
	if img:
		Logger.info("Saving image to file: %s" % _target_path)
		match export_type:
			ExportType.PNG:
				img.save_png(_target_path)
			ExportType.JPEG:
				img.save_jpg(_target_path, JPEG_QUALITY)
			_:
				img.save_png(_target_path)
	else:
		Logger.error("No export image ready", &"main", ERR_DOES_NOT_EXIST)


func _on_filetype_option_button_item_selected(index: int) -> void:
	export_type = ExportType.values()[index]


func _on_selection_tool_selected(rect: Rect2) -> void:
	if whole_map:
		whole_map = false
	var rect_i := Rect2i(rect)
	min_X = rect_i.position.x + (spawnpoint_abs.x * int(!use_relative_coords))
	min_Z = rect_i.position.y + (spawnpoint_abs.y * int(!use_relative_coords))
	max_X = rect_i.end.x + (spawnpoint_abs.x * int(!use_relative_coords))
	max_Z = rect_i.end.y + (spawnpoint_abs.y * int(!use_relative_coords))


func _on_import_option_button_item_selected(index: int) -> void:
	var meta: Dictionary = import_option_button.get_item_metadata(index)
	_select_file_for_import(meta.type, meta.path)


func _on_import_option_button_toggled(toggled_on: bool) -> void:
	if toggled_on:
		_update_import_option_button_list()


func _on_load_map_button_pressed() -> void:
	_load_file()
