class_name Map extends Node

signal loading_step
signal export_progressed(percent: int)
signal loading_completed
signal export_image_ready

const TABLE_NAME := "mappiece"
const CHUNK_SIZE: int = MapPiece.CHUNK_SIZE
const STEP_SIZE_PERCENT := 0.02
const N_BATCHES := 100

var _load_thread: Thread
var _db: SQLite = null
var _map_pieces: Dictionary[Vector2i, MapPiece] = {}

# Export state
var _export_batches: Array[Array]
var _task_id: int = -1
var _export_progress := 0 # (as %)
var _topleft: Vector2i
var _export: Image

var chunks_count: int = 0
var top_left_bound: Vector2i = Vector2i.MAX
var bottom_right_bound: Vector2i = Vector2i.MIN


func _init(db: SQLite) -> void:
	_db = db
	_load_thread = Thread.new()


func _process(_delta: float) -> void:
	if _task_id == -1:
		return
		
	if WorkerThreadPool.is_group_task_completed(_task_id):
		_clean_up_worker()
	elif WorkerThreadPool.get_group_processed_element_count(_task_id) != 0:
		@warning_ignore("integer_division")
		var percent: int = 100 * WorkerThreadPool.get_group_processed_element_count(_task_id) / N_BATCHES
		if percent != _export_progress:
			_export_progress = percent
			export_progressed.emit(percent)


func load_pieces() -> void:
	Logger.debug("Map load_pieces() called.")
	_set_chunks_count()
	_load_thread.start(_load_pieces_threaded)


func build_export_threaded(topleft: Vector2i, bottomright: Vector2i, whole_map: bool) -> void:
	_topleft = topleft
	var size: Vector2i = bottomright - topleft
	var image_rect: Rect2i = Rect2i(topleft, size)
	_export = Image.create_empty(size.x, size.y, true, Image.FORMAT_RGBA8)
	
	var pieces_to_process: Array[MapPiece]
	if whole_map:
		pieces_to_process = _map_pieces.values()
	else:
		for piece: MapPiece in _map_pieces.values():
			var piece_rect := Rect2i(piece.block_position, Vector2i(CHUNK_SIZE, CHUNK_SIZE))
			if image_rect.has_point(piece.block_position) or image_rect.intersects(piece_rect):
				pieces_to_process.append(piece)
	
	_export_batches = Utils.split_array_evenly(pieces_to_process, N_BATCHES)
	_task_id = WorkerThreadPool.add_group_task(
		_process_export_batch,
		_export_batches.size(),
		max(min(4, OS.get_processor_count() - 2), 1),
		true,
	)


func _process_export_batch(batch_index: int) -> void:
	var batch: Array[MapPiece] = _export_batches[batch_index]
	for piece in batch:
		if not piece.pixel_data: # do not decode if already done
			piece.decode_blob(piece.blob)


func _clean_up_worker() -> void:
	WorkerThreadPool.wait_for_group_task_completion(_task_id)
	_task_id = -1
	
	for batch in _export_batches:
		for piece: MapPiece in batch:
			var image := piece.generate_image()
			_export.blit_rect(
				image,
				Rect2i(Vector2i.ZERO, Vector2i(CHUNK_SIZE, CHUNK_SIZE)),
				piece.block_position - _topleft
			)
	
	export_image_ready.emit.call_deferred()


func get_pieces_relative_chunk_positions(origin_chunk: Vector2i) -> Array[Vector2i]:
	var ret: Array[Vector2i]
	for pos: Vector2i in _map_pieces.keys():
		ret.append(pos - origin_chunk)
	return ret


func get_export_image() -> Image:
	if _task_id != -1 and not WorkerThreadPool.is_task_completed(_task_id):
		Logger.warn("Export worker still alive (unexpected).")
		return null
	else:
		return _export


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
