class_name Map extends Node

signal loading_step
signal export_step
signal loading_completed
signal export_image_ready

const TABLE_NAME := "mappiece"
const CHUNK_SIZE: int = MapPiece.CHUNK_SIZE
const STEP_SIZE_PERCENT := 0.02

var _load_thread: Thread
var _export_thread: Thread
var _db: SQLite = null
var _map_pieces: Dictionary[Vector2i, MapPiece] = {}

var chunks_count: int = 0
var top_left_bound: Vector2i = Vector2i.MAX
var bottom_right_bound: Vector2i = Vector2i.MIN


func _init(db: SQLite) -> void:
	_db = db
	_load_thread = Thread.new()
	_export_thread = Thread.new()


func load_pieces() -> void:
	Logger.debug("Map load_pieces() called.")
	_set_chunks_count()
	_load_thread.start(_load_pieces_threaded)


func build_export_threaded(topleft: Vector2i, bottomright: Vector2i, whole_map: bool) -> void:
	_export_thread.start(_build_export.bind(topleft, bottomright, whole_map))


func get_piece(chunk_position: Vector2i) -> MapPiece:
	return _map_pieces.get(chunk_position)


func get_pieces_relative_chunk_positions(origin_chunk: Vector2i) -> Array[Vector2i]:
	var ret: Array[Vector2i]
	for pos: Vector2i in _map_pieces.keys():
		ret.append(pos - origin_chunk)
	return ret


func _build_export(topleft: Vector2i, bottomright: Vector2i, whole_map: bool) -> Image:
	var size: Vector2i = bottomright - topleft
	var image_rect: Rect2i = Rect2i(topleft, size)
	var image := Image.create_empty(size.x, size.y, true, Image.FORMAT_RGBA8)
	
	var pieces_to_process: Array[MapPiece]
	if whole_map:
		pieces_to_process = _map_pieces.values()
	else:
		for piece: MapPiece in _map_pieces.values():
			var piece_rect := Rect2i(piece.block_position, Vector2i(CHUNK_SIZE, CHUNK_SIZE))
			if image_rect.has_point(piece.block_position) or image_rect.intersects(piece_rect):
				pieces_to_process.append(piece)
	
	var n_processed_pieces := 0
	var steps := range(0, pieces_to_process.size(), int(STEP_SIZE_PERCENT * pieces_to_process.size()))
	for piece in pieces_to_process:
		var piece_img := MapPiece._image_from_blob(piece.blob)
		image.blit_rect(
			piece_img,
			Rect2i(Vector2i.ZERO, Vector2i(CHUNK_SIZE, CHUNK_SIZE)),
			piece.block_position - topleft
		)
		n_processed_pieces += 1
		if n_processed_pieces in steps:
			export_step.emit.call_deferred(float(n_processed_pieces) / float(pieces_to_process.size()))
	
	export_image_ready.emit.call_deferred()
	return image


func get_export_image() -> Image:
	if _export_thread.is_alive():
		Logger.warn("Export thread still alive (unexpected).")
		return null
	else:
		return _export_thread.wait_to_finish()


func get_map_density() -> float:
	if top_left_bound == Vector2i.MAX or bottom_right_bound == Vector2i.MIN:
		return 0.0
	var size := (bottom_right_bound.x - top_left_bound.x + 1) * (bottom_right_bound.y - top_left_bound.y + 1)
	return float(chunks_count) / float(size)


func _load_pieces_threaded() -> void:
	var packet_size: int = max(1, int(ceil(chunks_count * STEP_SIZE_PERCENT)))
	var step := 0
	
	_db.open_db()
	while step * packet_size < chunks_count:
		var query := "SELECT * FROM mappiece LIMIT %d OFFSET %d" % [packet_size, step * packet_size]
		_db.query(query)
		for row in _db.query_result:
			pass
			var map_piece := MapPiece.new(row["position"], row["data"])
			_map_pieces[map_piece.chunk_position] = map_piece
			_update_bounds(map_piece.chunk_position)
		step += 1
		loading_step.emit.call_deferred(STEP_SIZE_PERCENT * step)
		#await get_tree().process_frame
	_db.close_db()
	loading_completed.emit.call_deferred()


func _update_bounds(mappiece_pos: Vector2i) -> void:
	if mappiece_pos.x < top_left_bound.x:
		top_left_bound.x = mappiece_pos.x
	if mappiece_pos.y < top_left_bound.y:
		top_left_bound.y = mappiece_pos.y
	if mappiece_pos.x > bottom_right_bound.x:
		bottom_right_bound.x = mappiece_pos.x
	if mappiece_pos.y > bottom_right_bound.y:
		bottom_right_bound.y = mappiece_pos.y


func _set_chunks_count() -> void:
	_db.open_db()
	_db.query("SELECT COUNT(1) FROM {TABLE_NAME}".format({&"TABLE_NAME": TABLE_NAME}))
	chunks_count = _db.query_result[0]["COUNT(1)"]
	_db.close_db()


func _exit_tree() -> void:
	if _load_thread.is_started():
		_load_thread.wait_to_finish()
	if _export_thread.is_started():
		_export_thread.wait_to_finish()
