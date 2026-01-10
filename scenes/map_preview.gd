class_name MapPreview
extends SubViewportContainer

signal chunk_hovered(coordinates: Vector2i)
signal blockpos_hovered(coordinates: Vector2i)

const REGION_MARGIN := 1

var _map: Map = null
var _origin_chunk_abs: Vector2i = Vector2i.ZERO
var _origin_block_abs: Vector2i = Vector2i.ZERO
var _region_sprites: Dictionary[Vector2i, Sprite2D] = { }
var _wanted_region_rect: Rect2i = Rect2i(Vector2i.ZERO, Vector2i.ZERO) # region coords (half-open)
# request generation id (ignore stale results)
var _request_id: int = 0

var _last_hovered_chunk := Vector2i(-9999, -9999)
var _last_hovered_block := Vector2i(-9999, -9999)

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


func _input(event: InputEvent) -> void:
	if (
		event is not InputEventMouseMotion
		or block_pos_line_edit.has_focus()
		or chunk_pos_line_edit.has_focus()
	):
		return

	var block_pos: Vector2i = Vector2i(cam.get_global_mouse_position())
	var chunk_pos := MapMath.block_pos_to_chunk_pos(block_pos)
	if block_pos != _last_hovered_block:
		_last_hovered_block = block_pos
		block_pos_line_edit.text = str(block_pos).replace("(", "").replace(")", "")
		blockpos_hovered.emit(chunk_pos)

		if chunk_pos != _last_hovered_chunk:
			_last_hovered_chunk = chunk_pos
			chunk_pos_line_edit.text = str(chunk_pos).replace("(", "").replace(")", "")
			chunk_hovered.emit(chunk_pos)


func bind_map(map: Map) -> void:
	if _map != null:
		_map.region_texture_ready.disconnect(_on_region_texture_ready)
		_map.region_texture_failed.disconnect(_on_region_texture_failed)

	_map = map
	_map.region_texture_ready.connect(_on_region_texture_ready)
	_map.region_texture_failed.connect(_on_region_texture_failed)


func set_origin_from_spawn(spawnpoint_abs: Vector2i) -> void:
	_origin_chunk_abs = MapMath.spawnpoint_chunk_abs(spawnpoint_abs)
	_origin_block_abs = spawnpoint_abs

	_update_all_region_positions()
	_update_visible_regions()


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
		cam_target = MapMath.chunk_pos_to_block_pos(explored_rect_center_chunk)
		Logger.warn(
			"No explored chunk at (0,0). " +
			"Centering view on the center of the explored map area instead.",
		)
	else:
		cam_target = Vector2i.ZERO
	cam.global_position = cam_target


func _update_visible_regions() -> void:
	if _map == null:
		return

	var rect_rel := _get_visible_block_rect_relative()
	var rect_abs := Rect2i(
		rect_rel.position + _origin_block_abs,
		rect_rel.size,
	)

	var new_region_rect_abs := MapMath.block_rect_to_region_rect(rect_abs, REGION_MARGIN)
	if new_region_rect_abs == _wanted_region_rect:
		return

	_request_id += 1
	var old_region_rect := _wanted_region_rect
	_wanted_region_rect = new_region_rect_abs

	# Remove sprites that are outside the wanted rect.
	for r: Vector2i in _region_sprites.keys():
		if not _wanted_region_rect.has_point(r):
			_remove_region_sprite(r)

	# Request textures only for the newly-visible regions (delta), prioritized
	# around the viewport center.
	var center_region_abs := MapMath.block_pos_to_region_pos(rect_abs.get_center())
	_request_new_regions(old_region_rect, _wanted_region_rect, center_region_abs, _request_id)


func _get_visible_block_rect_relative() -> Rect2i:
	var viewport_size := sub_vp.size
	var zoom := cam.zoom

	var half := Vector2(
		viewport_size.x / zoom.x,
		viewport_size.y / zoom.y,
	) * 0.5

	var top_left := cam.global_position - half
	return Rect2i(
		Vector2i(floor(top_left.x), floor(top_left.y)),
		Vector2i(ceil(half.x * 2.0), ceil(half.y * 2.0)),
	)


func _request_new_regions(old_rect: Rect2i, new_rect: Rect2i, center: Vector2i, request_id: int) -> void:
	if _map == null or not new_rect.has_area():
		return

	var regions_to_request: Array[Vector2i] = []

	# Compute up to 4 "newly visible" band-rects (half-open) and enumerate their cells.
	var bands := MapMath.region_rect_diff_bands(old_rect, new_rect)
	for r in bands:
		if not r.has_area():
			continue
		for rz in range(r.position.y, r.end.y):
			for rx in range(r.position.x, r.end.x):
				regions_to_request.append(Vector2i(rx, rz))

	if not regions_to_request.is_empty():
		_map.request_region_textures(regions_to_request, center, request_id)


func _create_region_sprite(region_pos: Vector2i) -> void:
	var sprite := Sprite2D.new()
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
	sprite.centered = false
	sprite.position = MapMath.block_abs_to_block_rel(
		MapMath.region_pos_to_block_pos(region_pos),
		_origin_block_abs,
	)
	tilemap.add_child(sprite)
	_region_sprites[region_pos] = sprite


func _remove_region_sprite(region: Vector2i) -> void:
	var sprite: Sprite2D = _region_sprites.get(region)
	if sprite != null:
		sprite.queue_free()
	_region_sprites.erase(region)


func _update_all_region_positions() -> void:
	for r: Vector2i in _region_sprites.keys():
		_region_sprites[r].position = MapMath.block_abs_to_block_rel(
			MapMath.region_pos_to_block_pos(r),
			_origin_block_abs,
		)


func _on_region_texture_ready(region: Vector2i, texture: Texture2D, request_id: int) -> void:
	if not _wanted_region_rect.has_point(region):
		return

	if texture == null:
		if _region_sprites.has(region):
			_remove_region_sprite(region)
		return

	if not _region_sprites.has(region):
		_create_region_sprite(region)
	_region_sprites[region].texture = texture


func _on_region_texture_failed(region: Vector2i, error: String, request_id: int) -> void:
	if request_id != _request_id:
		return
	push_warning("Region %s failed: %s" % [region, error])


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
			cam.global_position = MapMath.chunk_pos_to_block_pos(_last_hovered_chunk)


func _parse_vector2i(text: String) -> Dictionary:
	var result := {
		"ok": false,
		"value": Vector2i.ZERO,
		"error": "",
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
	cam.set_zoom_level(cam.zoom.x * 1.5)


func _on_zoom_decrease_button_pressed() -> void:
	cam.set_zoom_level(cam.zoom.x / 1.5)


func _on_center_view_button_pressed() -> void:
	center_view()


func _on_pan_zoom_camera_position_changed(_value: Vector2) -> void:
	_update_visible_regions()


func _on_pan_zoom_camera_zoom_changed(value: float) -> void:
	zoom_label.text = str(int(100 * value)) + "%"
	_update_visible_regions()


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
