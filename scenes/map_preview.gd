class_name MapPreview extends SubViewportContainer

signal chunk_hovered(coordinates: Vector2i)
signal blockpos_hovered(coordinates: Vector2i)

@onready var sub_vp: SubViewport = %SubViewport
@onready var tilemap: TileMapLayer = %TileMapLayer
@onready var cam: PanZoomCamera = %PanZoomCamera
@onready var block_pos_label: Label = %BlockPosLabel
@onready var chunk_pos_label: Label = %ChunkPosLabel
@onready var zoom_label: Label = %ZoomLabel
@onready var zoom_decrease_button: Button = %ZoomDecreaseButton
@onready var zoom_increase_button: Button = %ZoomIncreaseButton
@onready var selection_tool: SelectionTool = %SelectionTool

var _last_hovered_chunk := Vector2i(-9999, -9999)
var _last_hovered_block := Vector2i(-9999, -9999)

func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var block_pos: Vector2i = Vector2i(cam.get_global_mouse_position())
		var chunk_pos := tilemap.local_to_map(block_pos)

		#Logger.debug("Block pos : %s" % block_pos)
		#Logger.debug("Chunk pos : %s" % chunk_pos)

		if block_pos != _last_hovered_block:
			_last_hovered_block = block_pos
			block_pos_label.text = str(block_pos)
			blockpos_hovered.emit(chunk_pos)
		
		if chunk_pos != _last_hovered_chunk:
			_last_hovered_chunk = chunk_pos
			chunk_pos_label.text = str(chunk_pos)
			chunk_hovered.emit(chunk_pos)


func draw_silhouette_preview(relative_chunk_positions: Array[Vector2i]) -> void:
	tilemap.clear()
	for chunk_pos in relative_chunk_positions:
		tilemap.set_cell(chunk_pos, 0, Vector2i(1, 0))


func _on_zoom_increase_button_pressed() -> void:
	cam.set_zoom_level(cam.zoom.x * 1.5, cam.position)


func _on_zoom_decrease_button_pressed() -> void:
	cam.set_zoom_level(cam.zoom.x / 1.5, cam.position)


func _on_pan_zoom_camera_zoom_changed(value: float) -> void:
	zoom_label.text = str(int(100 * value)) + "%"
