class_name Map
extends Node

signal loading_step
signal export_progressed(percent: int)
signal loading_completed
signal export_image_ready

# Region preview streaming
signal region_texture_ready(region: Vector2i, texture: Texture2D, request_id: int)
signal region_texture_failed(region: Vector2i, error: String, request_id: int)
signal region_cache_evicted(region: Vector2i)

const TABLE_NAME := "mappiece"
const STEP_SIZE_PERCENT := 0.02
const N_BATCHES := 100
const DEFAULT_REGION_CACHE_CAPACITY: int = 100

@warning_ignore("narrowing_conversion")
const DEFAULT_WORLD_SIZE := Vector2i(1024E3, 1024E3)

var world_size: Vector2i = Vector2i.ZERO
var chunks_count: int = 0

## Explored bounds in chunk space, absolute.
## Invariant (once set): size is inclusive, i.e. size == (max - min) + 1
var explored_chunks_rect_abs: Rect2i = Rect2i(0, 0, 0, 0)

var _load_thread: Thread
var _db: SQLite = null
var _map_pieces: Dictionary[Vector2i, MapPiece] = { }

# Region preview state
var _region_provider: RegionTextureProvider

# Export state
var _export_batches: Array[Array]
var _task_id: int = -1
var _export_progress := 0 # (as %)
var _export_topleft_block_abs: Vector2i
var _export_image: Image
var _export_downscale_factor: int


func _init(db: SQLite) -> void:
	_db = db
	_load_thread = Thread.new()
	_region_provider_init()


func _region_provider_init() -> void:
	# Provider is self-contained and safe to keep alive across map reloads.
	# It reads _map_pieces only from the main thread.
	_region_provider = RegionTextureProvider.new(self)
	_region_provider.set_cache_capacity(DEFAULT_REGION_CACHE_CAPACITY)


func _process(_delta: float) -> void:
	# Pump region preview results on main thread.
	if _region_provider != null:
		_region_provider.process_main_thread()

	if _task_id == -1:
		return

	if WorkerThreadPool.is_group_task_completed(_task_id):
		_clean_up_worker()
	elif WorkerThreadPool.get_group_processed_element_count(_task_id) != 0:
		@warning_ignore("integer_division")
		var percent: int = (
			100 * WorkerThreadPool.get_group_processed_element_count(_task_id) / N_BATCHES
		)
		if percent != _export_progress:
			_export_progress = percent
			export_progressed.emit(percent)


func _exit_tree() -> void:
	if _load_thread.is_started():
		_load_thread.wait_to_finish()
	if _region_provider != null:
		_region_provider.shutdown()
		_region_provider = null


func load_pieces() -> void:
	Logger.debug("Map load_pieces() called.")
	_set_chunks_count()
	_load_thread.start(_load_pieces_threaded)


func build_export_threaded(
		topleft_block_abs: Vector2i,
		bottomright_block_abs: Vector2i,
		whole_map: bool,
		downscale_factor: int,
) -> void:
	_export_topleft_block_abs = topleft_block_abs
	_export_downscale_factor = downscale_factor

	var export_size_blocks: Vector2i = bottomright_block_abs - topleft_block_abs
	var export_block_rect_abs: Rect2i = Rect2i(topleft_block_abs, export_size_blocks)

	@warning_ignore("integer_division")
	_export_image = Image.create_empty(
		export_size_blocks.x / downscale_factor,
		export_size_blocks.y / downscale_factor,
		false,
		Image.FORMAT_RGBA8,
	)

	var pieces_to_process: Array[MapPiece]
	if whole_map:
		pieces_to_process = _map_pieces.values()
	else:
		for piece: MapPiece in _map_pieces.values():
			var piece_block_rect_abs := MapMath.chunk_pos_to_block_rect(piece.chunk_pos_abs)
			# Keep pieces that overlap the export rect (in block coordinates).
			if (
				export_block_rect_abs.has_point(piece_block_rect_abs.position)
				or export_block_rect_abs.intersects(piece_block_rect_abs)
			):
				pieces_to_process.append(piece)

	_export_batches = Utils.split_array_evenly(pieces_to_process, N_BATCHES)
	_task_id = WorkerThreadPool.add_group_task(
		_process_export_batch,
		_export_batches.size(),
		max(min(4, OS.get_processor_count() - 2), 1),
		true,
	)

# --- Region preview streaming API (forwarded to RegionTextureProvider) ---


func set_region_cache_capacity(max_regions: int) -> void:
	if _region_provider != null:
		_region_provider.set_cache_capacity(max_regions)


func set_region_max_inflight(max_inflight: int) -> void:
	if _region_provider != null:
		_region_provider.set_max_inflight(max_inflight)


func clear_region_cache() -> void:
	if _region_provider != null:
		_region_provider.clear_cache()


func get_region_cache_stats() -> Dictionary:
	return _region_provider.get_stats() if _region_provider != null else { }


func request_region_textures(regions: Array[Vector2i], priority_center: Vector2i, request_id: int = 0) -> void:
	if _region_provider != null:
		_region_provider.request_regions(regions, priority_center, request_id)


func request_region_texture(region: Vector2i, priority: int = 0, request_id: int = 0) -> void:
	if _region_provider != null:
		_region_provider.request_region(region, priority, request_id)


func get_pieces_chunk_pos_abs() -> Array[Vector2i]:
	return _map_pieces.keys()


func get_export_image() -> Image:
	if _task_id != -1 and not WorkerThreadPool.is_task_completed(_task_id):
		Logger.warn("Export worker still alive (unexpected).")
		return null
	return _export_image


func get_map_density() -> float:
	if not explored_chunks_rect_abs.has_area():
		return 0.0
	var rect_total_chunks := explored_chunks_rect_abs.get_area()
	return float(chunks_count) / float(rect_total_chunks)


func get_explored_block_center_abs() -> Vector2i:
	var explored_block_rect_abs := MapMath.chunk_rect_to_block_rect(explored_chunks_rect_abs)
	if explored_block_rect_abs.size == Vector2i.ZERO:
		return Vector2i.ZERO
	return (explored_block_rect_abs.position + explored_block_rect_abs.end) / 2


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
			var image := piece.generate_image(_export_downscale_factor)
			var piece_block_pos_abs := MapMath.chunk_pos_to_block_pos(piece.chunk_pos_abs)
			_export_image.blit_rect(
				image,
				image.get_used_rect(),
				(piece_block_pos_abs - _export_topleft_block_abs) / _export_downscale_factor,
			)
	export_image_ready.emit.call_deferred()


func _load_pieces_threaded() -> void:
	var packet_size: int = max(1, int(ceil(chunks_count * STEP_SIZE_PERCENT)))
	var step := 0

	_db.open_db()
	while step * packet_size < chunks_count:
		var query := "SELECT * FROM mappiece LIMIT %d OFFSET %d" % [packet_size, step * packet_size]
		_db.query(query)
		for row in _db.query_result:
			var map_piece := MapPiece.new(row["position"], row["data"])
			_map_pieces[map_piece.chunk_pos_abs] = map_piece
			_update_explored_chunks_rect_abs(map_piece.chunk_pos_abs)
		step += 1
		loading_step.emit.call_deferred(STEP_SIZE_PERCENT * step)
	_db.close_db()

	if not world_size:
		world_size = _guess_world_size()
		Logger.warn.call_deferred(
			"World size was inferred from map content instead of save data; " +
			"the result may be inaccurate.",
		)

	loading_completed.emit.call_deferred()


func _update_explored_chunks_rect_abs(chunk_pos_abs: Vector2i) -> void:
	if not explored_chunks_rect_abs.has_area():
		explored_chunks_rect_abs = Rect2i(chunk_pos_abs, Vector2i.ONE)
		return

	explored_chunks_rect_abs = explored_chunks_rect_abs.expand(chunk_pos_abs)
	explored_chunks_rect_abs = explored_chunks_rect_abs.expand(chunk_pos_abs + Vector2i.ONE)


func _set_chunks_count() -> void:
	_db.open_db()
	# TODO: this query will freeze the app with larger maps
	_db.query("SELECT COUNT(1) FROM {TABLE_NAME}".format({ &"TABLE_NAME": TABLE_NAME }))
	chunks_count = _db.query_result[0]["COUNT(1)"]
	_db.close_db()


func _guess_world_size() -> Vector2i:
	if not explored_chunks_rect_abs.has_area():
		return DEFAULT_WORLD_SIZE

	var explored_block_rect_abs := MapMath.chunk_rect_to_block_rect(explored_chunks_rect_abs)
	if explored_block_rect_abs.size == Vector2i.ZERO:
		return DEFAULT_WORLD_SIZE

	# We want the last explored block (inclusive) for the preset checks.
	var bottom_right_block_pos_abs := explored_block_rect_abs.end - Vector2i.ONE

	var possible_x_sizes: Array[int] = []
	var possible_z_sizes: Array[int] = []
	for size in MapMath.WORLD_SIZE_PRESETS:
		var s := int(size)
		if s >= bottom_right_block_pos_abs.x:
			possible_x_sizes.append(s)
		if s >= bottom_right_block_pos_abs.y:
			possible_z_sizes.append(s)

	var explored_center_abs := get_explored_block_center_abs()

	# Choose the preset whose center is the closest to the explored region center.
	var pick_best_size := func(possible_sizes: Array[int], explored_axis_center: int) -> int:
		if possible_sizes.is_empty():
			return DEFAULT_WORLD_SIZE.x
		var best_fit_size := possible_sizes[0]
		@warning_ignore("integer_division")
		var best_fit_dist := absi(best_fit_size / 2 - explored_axis_center)
		for s in possible_sizes:
			@warning_ignore("integer_division")
			var dist := absi(s / 2 - explored_axis_center)
			if dist < best_fit_dist:
				best_fit_dist = dist
				best_fit_size = s
		return best_fit_size

	var best_x: int = pick_best_size.call(possible_x_sizes, explored_center_abs.x)
	var best_z: int = pick_best_size.call(possible_z_sizes, explored_center_abs.y)
	return Vector2i(best_x, best_z)


## A self-contained streaming provider for per-region textures (16x16 chunks).
##
## Contract:
## - request_* methods must be called from the main thread.
## - _map._map_pieces is read from the main thread only.
## - decoding/blitting happens in worker threads.
## - Image->Texture conversion (and mipmap generation) happens on the main thread.
class RegionTextureProvider extends RefCounted:
	const _FORMAT := Image.FORMAT_RGBA8

	var _map: Map
	var _cache_capacity: int = DEFAULT_REGION_CACHE_CAPACITY
	var _max_inflight: int = 4

	# Cache (Texture2D) and LRU order (least-recently-used at index 0)
	var _cache: Dictionary[Vector2i, Texture2D] = { }
	var _lru: Array[Vector2i] = []

	# Requests
	var _queued: Dictionary[Vector2i, bool] = { }
	var _queue: Array[Dictionary] = []
	var _inflight: Dictionary[Vector2i, bool] = { }

	# Worker results
	var _results_mutex := Mutex.new()
	var _results: Array[Dictionary] = []

	# Stats
	var _hits: int = 0
	var _misses: int = 0

	var _is_shutdown: bool = false


	func _init(map: Map) -> void:
		_map = map
		# Conservative default; the export already uses up to 4.
		_max_inflight = max(min(4, OS.get_processor_count() - 2), 1)


	func shutdown() -> void:
		_is_shutdown = true
		_queue.clear()
		_queued.clear()
		# Inflight tasks cannot be cancelled; results will be ignored.


	func set_cache_capacity(max_regions: int) -> void:
		_cache_capacity = maxi(0, max_regions)
		_evict_if_needed()


	func set_max_inflight(max_inflight: int) -> void:
		_max_inflight = maxi(1, max_inflight)
		_kick_workers()


	func clear_cache() -> void:
		_cache.clear()
		_lru.clear()
		_hits = 0
		_misses = 0


	func get_stats() -> Dictionary:
		return {
			"count": _cache.size(),
			"capacity": _cache_capacity,
			"hits": _hits,
			"misses": _misses,
			"queued": _queue.size(),
			"inflight": _inflight.size(),
		}


	func request_regions(regions: Array[Vector2i], priority_center: Vector2i, request_id: int) -> void:
		if _is_shutdown:
			return

		# Enqueue requests. We compute a simple Manhattan distance priority.
		for r in regions:
			var tex: Texture2D = _cache.get(r)
			if tex != null:
				_hits += 1
				_touch_lru(r)
				_map.region_texture_ready.emit.call_deferred(r, tex, request_id)
				continue

			_misses += 1
			if _queued.has(r) or _inflight.has(r):
				continue

			# Collect inputs on main thread.
			var inputs := _collect_region_inputs(r)
			if inputs.is_empty():
				# Nothing explored in this region.
				_map.region_texture_ready.emit.call_deferred(r, null, request_id)
				continue

			var pri := absi(r.x - priority_center.x) + absi(r.y - priority_center.y)
			_queue.append(
				{
					"region": r,
					"priority": pri,
					"request_id": request_id,
					"inputs": inputs,
				},
			)
			_queued[r] = true

		_kick_workers()


	func request_region(region: Vector2i, priority: int, request_id: int) -> void:
		# Single region request with explicit priority.
		if _is_shutdown:
			return

		var tex: Texture2D = _cache.get(region)
		if tex != null:
			_hits += 1
			_touch_lru(region)
			_map.region_texture_ready.emit.call_deferred(region, tex, request_id)
			return

		_misses += 1
		if _queued.has(region) or _inflight.has(region):
			return

		var inputs := _collect_region_inputs(region)
		if inputs.is_empty():
			_map.region_texture_ready.emit.call_deferred(region, null, request_id)
			return

		_queue.append(
			{
				"region": region,
				"priority": priority,
				"request_id": request_id,
				"inputs": inputs,
			},
		)
		_queued[region] = true
		_kick_workers()


	func process_main_thread() -> void:
		if _is_shutdown:
			# Still drain results to avoid unbounded growth.
			_drain_results(true)
			return
		_drain_results(false)


	func _drain_results(ignore_results: bool) -> void:
		var local: Array[Dictionary] = []
		_results_mutex.lock()
		if not _results.is_empty():
			local = _results
			_results = []
		_results_mutex.unlock()

		if local.is_empty():
			return

		for item in local:
			var region: Vector2i = item["region"]
			var request_id: int = item["request_id"]
			_inflight.erase(region)
			if ignore_results:
				continue

			var err: String = item.get("error", "")
			if err != "":
				_map.region_texture_failed.emit(region, err, request_id)
				continue

			var img: Image = item.get("image")
			if img == null:
				_map.region_texture_ready.emit(region, null, request_id)
				continue

			# Mipmaps + texture creation must happen on main thread.
			img.generate_mipmaps()
			var tex := ImageTexture.create_from_image(img)
			_cache[region] = tex
			_touch_lru(region)
			_evict_if_needed()
			_map.region_texture_ready.emit(region, tex, request_id)

		_kick_workers()


	func _kick_workers() -> void:
		if _is_shutdown:
			return
		if _queue.is_empty():
			return
		if _inflight.size() >= _max_inflight:
			return

		# Sort by priority (smallest first). Stable enough for our use.
		_queue.sort_custom(
			func(a: Dictionary, b: Dictionary) -> bool:
				return int(a["priority"]) < int(b["priority"])
		)

		while _inflight.size() < _max_inflight and not _queue.is_empty():
			var job: Dictionary = _queue.pop_front()
			var region: Vector2i = job["region"]
			_queued.erase(region)
			_inflight[region] = true

			var inputs: Array = job["inputs"]
			var request_id: int = job["request_id"]
			var callable := Callable(self, "_worker_build_region").bind(region, request_id, inputs)
			WorkerThreadPool.add_task(callable)


	func _touch_lru(region: Vector2i) -> void:
		var idx := _lru.find(region)
		if idx != -1:
			_lru.remove_at(idx)
		_lru.append(region)


	func _evict_if_needed() -> void:
		if _cache_capacity <= 0:
			# Evict everything.
			for r: Vector2i in _cache.keys():
				_map.region_cache_evicted.emit.call_deferred(r)
			_cache.clear()
			_lru.clear()
			return

		while _cache.size() > _cache_capacity and not _lru.is_empty():
			var evict_region: Vector2i = _lru.pop_front()
			if _cache.has(evict_region):
				_cache.erase(evict_region)
				_map.region_cache_evicted.emit.call_deferred(evict_region)


	func _collect_region_inputs(region: Vector2i) -> Array[Dictionary]:
		# Region coordinates are in units of 16 chunks.
		var origin_chunk_abs := MapMath.region_pos_to_chunk_pos(region)
		var inputs: Array[Dictionary] = []

		# IMPORTANT: read _map._map_pieces only from the main thread.
		for dz in range(MapMath.REGION_WIDTH_CHUNKS):
			for dx in range(MapMath.REGION_WIDTH_CHUNKS):
				var chunk_pos_abs := origin_chunk_abs + Vector2i(dx, dz)
				var piece: MapPiece = _map._map_pieces.get(chunk_pos_abs)
				if piece == null:
					continue
				inputs.append(
					{
						"dx": dx,
						"dz": dz,
						"blob": piece.blob,
					},
				)

		return inputs


	func _worker_build_region(region: Vector2i, request_id: int, inputs: Array[Dictionary]) -> void:
		var region_block_size := MapMath.region_pos_to_block_rect(Vector2i.ZERO).size
		var chunk_block_size := MapMath.chunk_pos_to_block_rect(Vector2i.ZERO).size
		var img := Image.create_empty(region_block_size.x, region_block_size.y, false, _FORMAT)
		img.fill(Color(0, 0, 0, 0))

		for item: Dictionary in inputs:
			if _is_shutdown:
				return
			var dx: int = int(item["dx"])
			var dz: int = int(item["dz"])
			var blob: PackedByteArray = item["blob"]
			var rgba := MapPiece.decode_blob_to_rgba32(blob)
			if rgba.is_empty():
				continue
			var chunk_img := Image.create_from_data(
				chunk_block_size.x,
				chunk_block_size.y,
				false,
				_FORMAT,
				rgba,
			)
			img.blit_rect(
				chunk_img,
				Rect2i(Vector2i.ZERO, chunk_block_size),
				Vector2i(dx * chunk_block_size.x, dz * chunk_block_size.y),
			)

		_results_mutex.lock()
		_results.append(
			{
				"region": region,
				"request_id": request_id,
				"image": img,
			},
		)
		_results_mutex.unlock()
