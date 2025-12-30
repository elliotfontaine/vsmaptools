class_name MapPreview extends SubViewportContainer

signal chunk_hovered(coordinates: Vector2i)
signal blockpos_hovered(coordinates: Vector2i)

@onready var sub_vp: SubViewport = %SubViewport
@onready var tilemap: TileMapLayer = %TileMapLayer
@onready var cam: PanZoomCamera = %PanZoomCamera
@onready var block_pos_line_edit: LineEdit = %BlockPosLineEdit
@onready var chunk_pos_line_edit: LineEdit = %ChunkPosLineEdit
@onready var zoom_label: Label = %ZoomLabel
@onready var info_box_v_box_container: VBoxContainer = %InfoBoxVBoxContainer
@onready var zoom_decrease_button: Button = %ZoomDecreaseButton
@onready var zoom_increase_button: Button = %ZoomIncreaseButton
@onready var selection_tool: SelectionTool = %SelectionTool

var _last_hovered_chunk := Vector2i(-9999, -9999)
var _last_hovered_block := Vector2i(-9999, -9999)


func _input(event: InputEvent) -> void:
	if (
			event is not InputEventMouseMotion
			or block_pos_line_edit.has_focus()
			or chunk_pos_line_edit.has_focus()
	):
		return
	
	var block_pos: Vector2i = Vector2i(cam.get_global_mouse_position())
	var chunk_pos := tilemap.local_to_map(block_pos)
	if block_pos != _last_hovered_block:
		_last_hovered_block = block_pos
		block_pos_line_edit.text = str(block_pos).replace("(", "").replace(")", "")
		blockpos_hovered.emit(chunk_pos)
	
		if chunk_pos != _last_hovered_chunk:
			_last_hovered_chunk = chunk_pos
			chunk_pos_line_edit.text = str(chunk_pos).replace("(", "").replace(")", "")
			chunk_hovered.emit(chunk_pos)


## Fill the grid from a list of chunk coordinates
func draw_silhouette_preview(relative_chunk_positions: Array[Vector2i]) -> void:
	tilemap.clear()
	for chunk_pos in relative_chunk_positions:
		tilemap.set_cell(chunk_pos, 0, Vector2i(1, 0))


func center_view() -> void:
	var cam_target: Vector2i
	var explored_rect_center_chunk := tilemap.get_used_rect().get_center()
	if tilemap.get_cell_source_id(Vector2i.ZERO) != -1:
		cam_target = Vector2i.ZERO
	elif tilemap.get_cell_source_id(explored_rect_center_chunk) != -1:
		cam_target = explored_rect_center_chunk * Map.CHUNK_SIZE
		Logger.warn(
			"No explored chunk at (0,0). Centering view on the center of the explored map area instead."
		)
	else:
		cam_target = Vector2i.ZERO
	cam.global_position = cam_target


func _process_block_line_edit_change() -> void:
	var parsed := _parse_vector2i(block_pos_line_edit.text)
	
	if not parsed.ok:
		Logger.error(parsed.error)
		block_pos_line_edit.text = str(_last_hovered_block).replace("(", "").replace(")", "")
	else:
		Logger.debug("Vector2i correctly parsed : " + str(parsed.value))
		if parsed.value != _last_hovered_block:
			_last_hovered_block = parsed.value
			cam.global_position = _last_hovered_block


func _process_chunk_line_edit_change() -> void:
	var parsed := _parse_vector2i(chunk_pos_line_edit.text)
	
	if not parsed.ok:
		Logger.error(parsed.error)
		chunk_pos_line_edit.text = str(_last_hovered_chunk).replace("(", "").replace(")", "")
	else:
		Logger.debug("Vector2i correctly parsed : " + str(parsed.value))
		if parsed.value != _last_hovered_chunk:
			_last_hovered_chunk = parsed.value
			cam.global_position = _last_hovered_chunk * Map.CHUNK_SIZE


func _parse_vector2i(text: String) -> Dictionary:
	var result := {
		"ok": false,
		"value": Vector2i.ZERO,
		"error": ""
	}

	var cleaned := text.strip_edges()
	cleaned = cleaned.replace("(", "").replace(")", "")
	var parts := cleaned.split(",", false)

	if parts.size() != 2:
		result.error = "Expected format : x, y"
		return result

	var xy := []
	for i in range(2):
		var part := String(parts[i]).strip_edges()

		if not part.is_valid_int():
			result.error = "Value '%s' isn't an integer." % part
			return result

		xy.append(int(part))

	result.value = Vector2i(xy[0], xy[1])
	result.ok = true
	return result


func _on_zoom_increase_button_pressed() -> void:
	cam.set_zoom_level(cam.zoom.x * 1.5, cam.position)


func _on_zoom_decrease_button_pressed() -> void:
	cam.set_zoom_level(cam.zoom.x / 1.5, cam.position)


func _on_center_view_button_pressed() -> void:
	center_view()


func _on_pan_zoom_camera_zoom_changed(value: float) -> void:
	zoom_label.text = str(int(100 * value)) + "%"


func _on_block_pos_line_edit_text_submitted(_new_text: String) -> void:
	block_pos_line_edit.release_focus()


func _on_block_pos_line_edit_focus_exited() -> void:
	Logger.debug("block_pos_line_edit_focus_exited")
	_process_block_line_edit_change()
	self.grab_focus()


func _on_chunk_pos_line_edit_text_submitted(_new_text: String) -> void:
	chunk_pos_line_edit.release_focus()


func _on_chunk_pos_line_edit_focus_exited() -> void:
	Logger.debug("chunk_pos_line_edit_focus_exited")
	_process_chunk_line_edit_change()
	self.grab_focus()
