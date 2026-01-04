class_name MapViewGrid
extends Node2D

enum GridPattern { DOTS, LINES }

@export var camera_path: NodePath
@export var tilemap_path: NodePath
@export var grid_color: Color

var _pattern: int = GridPattern.LINES
var _camera: PanZoomCamera
var _tilemap: TileMapLayer


func _ready() -> void:
	_camera = get_node(camera_path)
	_tilemap = get_node(tilemap_path)
	_camera.zoom_changed.connect(_on_zoom_changed)
	_camera.position_changed.connect(_on_position_changed)
	get_viewport().size_changed.connect(_on_viewport_size_changed)


func _draw() -> void:
	var zoom := _camera.zoom.x
	var subvp: SubViewport = get_viewport()
	var size := Vector2(subvp.size.x, subvp.size.y) / zoom
	var offset := _camera.global_position - size / 2
	var default_cell_size := _tilemap.tile_set.tile_size.x

	var cell_size := default_cell_size if zoom > 0.3 else default_cell_size * 16

	match _pattern:
		GridPattern.DOTS:
			var dot_size := int(ceil(cell_size * 0.12))
			var x_start := int(offset.x / cell_size) - 1
			var x_end := int((size.x + offset.x) / cell_size) + 1
			var y_start := int(offset.y / cell_size) - 1
			var y_end := int((size.y + offset.y) / cell_size) + 1

			for x in range(x_start, x_end):
				for y in range(y_start, y_end):
					var pos := Vector2(x, y) * cell_size
					draw_rect(Rect2(pos.x, pos.y, dot_size, dot_size), grid_color)
		GridPattern.LINES:
			# Vertical lines
			var start_index := int(offset.x / cell_size) - 1
			var end_index := int((size.x + offset.x) / cell_size) + 1
			for i in range(start_index, end_index):
				var color: Color = Color.LIME_GREEN if i == 0 else grid_color
				draw_line(
					Vector2(i * cell_size, offset.y + size.y),
					Vector2(i * cell_size, offset.y - size.y),
					color,
				)

			# Horizontal lines
			start_index = int(offset.y / cell_size) - 1
			end_index = int((size.y + offset.y) / cell_size) + 1
			for i in range(start_index, end_index):
				var color: Color = Color.MEDIUM_VIOLET_RED if i == 0 else grid_color
				draw_line(
					Vector2(offset.x + size.x, i * cell_size),
					Vector2(offset.x - size.x, i * cell_size),
					color,
				)


func enable(e: bool) -> void:
	set_process(e)
	visible = e


func set_grid_pattern(pattern: int) -> void:
	_pattern = pattern
	queue_redraw()


func _on_zoom_changed(_zoom: float) -> void:
	queue_redraw()


func _on_position_changed(_pos: Vector2) -> void:
	queue_redraw()


func _on_viewport_size_changed() -> void:
	queue_redraw()
