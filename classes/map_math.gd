class_name MapMath
extends RefCounted

## Width of a map chunk, in blocks.
const CHUNK_WIDTH_BLOCKS := 32

## Width of a map region, in chunks.
const REGION_WIDTH_CHUNKS := 16

## Width of a map region, in blocks.
const REGION_WIDTH_BLOCKS := CHUNK_WIDTH_BLOCKS * REGION_WIDTH_CHUNKS

## Vintage Story world size presets (axis lengths, in blocks).
## Used to validate spawnpoint coordinates (absolute, positive, preset-aligned).
@warning_ignore("narrowing_conversion")
const WORLD_SIZE_PRESETS: Array[int] = [
	32,
	64,
	128,
	256,
	384,
	512,
	1024,
	5120,
	10240,
	25600,
	51200,
	102400,
	128E3,
	256E3,
	384E3,
	512E3,
	600E3,
	1024E3,
	2048E3,
	4096E3,
	8192E3,
]


## Integer floor division for grid coordinates (handles negatives correctly).
## Precondition: b > 0
static func floor_div(a: int, b: int) -> int:
	assert(b > 0)
	if a >= 0:
		@warning_ignore("integer_division")
		return a / b
	# floor(a/b) for negative a with positive b
	@warning_ignore("integer_division")
	return -(((-a + b - 1) / b))


## Component-wise floor division for Vector2i grid coordinates.
## Precondition: b > 0
static func floor_div_v2i(a: Vector2i, b: int) -> Vector2i:
	return Vector2i(floor_div(a.x, b), floor_div(a.y, b))


## Convert a block position to a chunk position.
## The coordinate space (abs or rel) is preserved.
static func block_pos_to_chunk_pos(block_pos: Vector2i) -> Vector2i:
	return floor_div_v2i(block_pos, CHUNK_WIDTH_BLOCKS)


## Convert a chunk position to the block position of its origin (top-left block).
## The coordinate space (abs or rel) is preserved.
static func chunk_pos_to_block_pos(chunk_pos: Vector2i) -> Vector2i:
	return chunk_pos * CHUNK_WIDTH_BLOCKS


## Convert a chunk position to a region position.
## The coordinate space (abs or rel) is preserved.
static func chunk_pos_to_region_pos(chunk_pos: Vector2i) -> Vector2i:
	return floor_div_v2i(chunk_pos, REGION_WIDTH_CHUNKS)


## Convert a region position to the chunk position of its origin (top-left chunk).
## The coordinate space (abs or rel) is preserved.
static func region_pos_to_chunk_pos(region_pos: Vector2i) -> Vector2i:
	return region_pos * REGION_WIDTH_CHUNKS


## Convert a block position to a region position.
## The coordinate space (abs or rel) is preserved.
static func block_pos_to_region_pos(block_pos: Vector2i) -> Vector2i:
	return floor_div_v2i(block_pos, REGION_WIDTH_BLOCKS)


## Convert a region position to the block position of its origin (top-left block).
## The coordinate space (abs or rel) is preserved.
static func region_pos_to_block_pos(region_pos: Vector2i) -> Vector2i:
	return region_pos * REGION_WIDTH_BLOCKS


## Convert a spawnpoint absolute block position to an absolute chunk position.
## Spawnpoint is a reference origin for relative coordinates and must be valid.
static func spawnpoint_chunk_abs(spawnpoint_block_abs: Vector2i) -> Vector2i:
	assert(is_spawnpoint_valid(spawnpoint_block_abs))
	return block_pos_to_chunk_pos(spawnpoint_block_abs)


## Convert a spawnpoint absolute block position to an absolute region position.
## Spawnpoint is a reference origin for relative coordinates and must be valid.
static func spawnpoint_region_abs(spawnpoint_block_abs: Vector2i) -> Vector2i:
	assert(is_spawnpoint_valid(spawnpoint_block_abs))
	return block_pos_to_region_pos(spawnpoint_block_abs)


## Convert an absolute block position to a relative block position (relative to spawnpoint).
static func block_abs_to_block_rel(block_abs: Vector2i, spawnpoint_block_abs: Vector2i) -> Vector2i:
	assert(is_spawnpoint_valid(spawnpoint_block_abs))
	return block_abs - spawnpoint_block_abs


## Convert a relative block position (relative to spawnpoint) to an absolute block position.
static func block_rel_to_block_abs(block_rel: Vector2i, spawnpoint_block_abs: Vector2i) -> Vector2i:
	assert(is_spawnpoint_valid(spawnpoint_block_abs))
	return block_rel + spawnpoint_block_abs


## Convert an absolute chunk position to a relative chunk position (relative to spawnpoint).
static func chunk_abs_to_chunk_rel(chunk_abs: Vector2i, spawnpoint_block_abs: Vector2i) -> Vector2i:
	assert(is_spawnpoint_valid(spawnpoint_block_abs))
	return chunk_abs - spawnpoint_chunk_abs(spawnpoint_block_abs)


## Convert a relative chunk position (relative to spawnpoint) to an absolute chunk position.
static func chunk_rel_to_chunk_abs(chunk_rel: Vector2i, spawnpoint_block_abs: Vector2i) -> Vector2i:
	assert(is_spawnpoint_valid(spawnpoint_block_abs))
	return chunk_rel + spawnpoint_chunk_abs(spawnpoint_block_abs)


## Convert an absolute region position to a relative region position (relative to spawnpoint).
static func region_abs_to_region_rel(region_abs: Vector2i, spawnpoint_block_abs: Vector2i) -> Vector2i:
	assert(is_spawnpoint_valid(spawnpoint_block_abs))
	return region_abs - spawnpoint_region_abs(spawnpoint_block_abs)


## Convert a relative region position (relative to spawnpoint) to an absolute region position.
static func region_rel_to_region_abs(region_rel: Vector2i, spawnpoint_block_abs: Vector2i) -> Vector2i:
	assert(is_spawnpoint_valid(spawnpoint_block_abs))
	return region_rel + spawnpoint_region_abs(spawnpoint_block_abs)


## Returns the half-open block rect occupied by a chunk, given its position.
## The coordinate space (abs or rel) is preserved.
static func chunk_pos_to_block_rect(chunk_pos: Vector2i) -> Rect2i:
	return Rect2i(chunk_pos * CHUNK_WIDTH_BLOCKS, Vector2i.ONE * CHUNK_WIDTH_BLOCKS)


## Returns the half-open block rect occupied by a region, given its position.
## The coordinate space (abs or rel) is preserved.
static func region_pos_to_block_rect(region_pos: Vector2i) -> Rect2i:
	return Rect2i(region_pos * REGION_WIDTH_BLOCKS, Vector2i.ONE * REGION_WIDTH_BLOCKS)


static func chunk_rect_to_block_rect(chunk_rect: Rect2i) -> Rect2i:
	if chunk_rect.size == Vector2i.ZERO:
		return Rect2i(chunk_pos_to_block_pos(chunk_rect.position), Vector2i.ZERO)

	var top_left_block_pos := chunk_pos_to_block_pos(chunk_rect.position)
	var bottom_right_chunk_pos := chunk_rect.end - Vector2i.ONE
	var bottom_right_block_end := chunk_pos_to_block_rect(bottom_right_chunk_pos).end
	return Rect2i(top_left_block_pos, bottom_right_block_end - top_left_block_pos)


static func region_rect_to_block_rect(region_rect: Rect2i) -> Rect2i:
	if region_rect.size == Vector2i.ZERO:
		return Rect2i(region_pos_to_block_pos(region_rect.position), Vector2i.ZERO)

	var top_left_block_pos := region_pos_to_block_pos(region_rect.position)
	var bottom_right_region_pos := region_rect.end - Vector2i.ONE
	var bottom_right_block_end := region_pos_to_block_rect(bottom_right_region_pos).end
	return Rect2i(top_left_block_pos, bottom_right_block_end - top_left_block_pos)


## Convert a block rect (half-open) to a chunk rect (half-open).
## The coordinate space (abs or rel) is preserved.
## Expanded by [param margin] chunks on each side.
static func block_rect_to_chunk_rect(block_rect: Rect2i, margin: int) -> Rect2i:
	assert(margin >= 0)
	if not block_rect.has_area():
		return Rect2i()

	var start := block_rect.position
	var end := block_rect.end # half-open

	var min_c := block_pos_to_chunk_pos(start)
	var max_block_inclusive := end - Vector2i.ONE
	var max_c_inclusive := block_pos_to_chunk_pos(max_block_inclusive)

	var min_out := min_c - Vector2i(margin, margin)
	var max_out_excl := (max_c_inclusive + Vector2i.ONE) + Vector2i(margin, margin)
	return Rect2i(min_out, max_out_excl - min_out)


## Convert a block rect (half-open) to a region rect (half-open).
## The coordinate space (abs or rel) is preserved.
## Expanded by [param margin] regions on each side.
static func block_rect_to_region_rect(block_rect: Rect2i, margin: int) -> Rect2i:
	assert(margin >= 0)
	if not block_rect.has_area():
		return Rect2i()

	var start := block_rect.position
	var end := block_rect.end # half-open

	var min_r := block_pos_to_region_pos(start)
	var max_block_inclusive := end - Vector2i.ONE
	var max_r_inclusive := block_pos_to_region_pos(max_block_inclusive)

	var min_out := min_r - Vector2i(margin, margin)
	var max_out_excl := (max_r_inclusive + Vector2i.ONE) + Vector2i(margin, margin)
	return Rect2i(min_out, max_out_excl - min_out)


## Return all chunk positions contained in a chunk rect (half-open).
## The coordinate space (abs or rel) is preserved.
static func get_all_chunks_in_rect(chunk_rect: Rect2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	if not chunk_rect.has_area():
		return out

	var x0 := chunk_rect.position.x
	var y0 := chunk_rect.position.y
	var x1 := x0 + chunk_rect.size.x
	var y1 := y0 + chunk_rect.size.y

	for y in range(y0, y1):
		for x in range(x0, x1):
			out.append(Vector2i(x, y))

	return out


## Return all region positions contained in a region rect (half-open).
## The coordinate space (abs or rel) is preserved.
static func get_all_regions_in_rect(region_rect: Rect2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	if not region_rect.has_area():
		return out

	var x0 := region_rect.position.x
	var y0 := region_rect.position.y
	var x1 := x0 + region_rect.size.x
	var y1 := y0 + region_rect.size.y

	for y in range(y0, y1):
		for x in range(x0, x1):
			out.append(Vector2i(x, y))

	return out


## Compute the "newly visible" bands when moving from [param old_r] to [param new_r].
## Both rects are half-open in region coordinates.
## Returns up to 4 half-open rects; their union equals (new_r - old_r), with no overlaps.
static func region_rect_diff_bands(old_r: Rect2i, new_r: Rect2i) -> Array[Rect2i]:
	var out: Array[Rect2i] = []

	if not new_r.has_area():
		return out

	if not old_r.has_area():
		out.append(new_r)
		return out

	# If they don't intersect at all, everything in new_r is "new".
	if not old_r.intersects(new_r):
		out.append(new_r)
		return out

	# Clamp old rect to new rect to avoid weird cases when old extends beyond new.
	var inter := old_r.intersection(new_r)

	# Left band: [new.left, inter.left)
	if new_r.position.x < inter.position.x:
		out.append(
			Rect2i(
				Vector2i(new_r.position.x, new_r.position.y),
				Vector2i(inter.position.x - new_r.position.x, new_r.size.y),
			),
		)

	# Right band: [inter.right, new.right)
	var inter_right := inter.position.x + inter.size.x
	var new_right := new_r.position.x + new_r.size.x
	if inter_right < new_right:
		out.append(
			Rect2i(
				Vector2i(inter_right, new_r.position.y),
				Vector2i(new_right - inter_right, new_r.size.y),
			),
		)

	# Top band: [new.top, inter.top) within x = inter.x-range
	if new_r.position.y < inter.position.y:
		out.append(
			Rect2i(
				Vector2i(inter.position.x, new_r.position.y),
				Vector2i(inter.size.x, inter.position.y - new_r.position.y),
			),
		)

	# Bottom band: [inter.bottom, new.bottom) within x = inter.x-range
	var inter_bottom := inter.position.y + inter.size.y
	var new_bottom := new_r.position.y + new_r.size.y
	if inter_bottom < new_bottom:
		out.append(
			Rect2i(
				Vector2i(inter.position.x, inter_bottom),
				Vector2i(inter.size.x, new_bottom - inter_bottom),
			),
		)

	return out


## Spawnpoint is an absolute block coordinate used as the origin for relative coordinates.
## It must be strictly positive on both axes and match Vintage Story's world-size presets.
static func is_spawnpoint_valid(spawnpoint_block_abs: Vector2i) -> bool:
	if not spawnpoint_block_abs.sign() == Vector2i.ONE:
		return false
	if not (
		spawnpoint_block_abs.x * 2 in WORLD_SIZE_PRESETS
		and spawnpoint_block_abs.y * 2 in WORLD_SIZE_PRESETS
	):
		return false
	return true
