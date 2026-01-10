class_name MapPiece
extends RefCounted

const CHUNK_WIDTH_BLOCKS: int = MapMath.CHUNK_WIDTH_BLOCKS

var blob: PackedByteArray
var pixel_data: PackedByteArray
var chunk_pos_abs: Vector2i


func _init(position: int, data: PackedByteArray) -> void:
	chunk_pos_abs = _chunkpos_from_int(position)
	blob = data


## Decodes a protobuf blob (Proto.MapPieceDB) into raw RGBA8 bytes (32x32x4).
##
## This is safe to call from worker threads because it does not touch any
## instance state. Returns an empty PackedByteArray on error.
static func decode_blob_to_rgba32(data: PackedByteArray) -> PackedByteArray:
	var message := Proto.MapPieceDB.new()

	# TODO: this is the bottleneck. See Proto.PBPacker.unpack_message
	var result_code := message.from_bytes(data)
	if result_code != Proto.PB_ERR.NO_ERRORS:
		push_error("ERROR WHILE READING PROTOBUF DATA")
		return PackedByteArray()

	var pixels: Array[int] = message.get_Pixels()
	if pixels.size() != MapMath.CHUNK_WIDTH_BLOCKS ** 2:
		push_error("Unexpected pixel array size")
		return PackedByteArray()

	var out := PackedByteArray()
	out.resize(pixels.size() * 4) # 4 bytes per pixel

	for i in pixels.size():
		var color_int := pixels[i]
		out[i * 4 + 0] = color_int & 0xFF # red
		out[i * 4 + 1] = (color_int >> 8) & 0xFF # green
		out[i * 4 + 2] = (color_int >> 16) & 0xFF # blue
		out[i * 4 + 3] = 255 # alpha

	return out


## Convenience helper: decodes a protobuf blob straight into a Godot Image.
## Returns null on error.
static func decode_blob_to_image(data: PackedByteArray, downscale_factor: int = 1) -> Image:
	var rgba := decode_blob_to_rgba32(data)
	if rgba.is_empty():
		return null
	var img := Image.create_from_data(
		CHUNK_WIDTH_BLOCKS,
		CHUNK_WIDTH_BLOCKS,
		false,
		Image.FORMAT_RGBA8,
		rgba,
	)
	if downscale_factor > 1:
		@warning_ignore("integer_division")
		img.resize(
			CHUNK_WIDTH_BLOCKS / downscale_factor,
			CHUNK_WIDTH_BLOCKS / downscale_factor,
			Image.INTERPOLATE_TRILINEAR,
		)
	return img


func decode_blob(data: PackedByteArray) -> void:
	pixel_data = decode_blob_to_rgba32(data)


func generate_image(downscale_factor: int = 1) -> Image:
	var img := Image.create_from_data(
		CHUNK_WIDTH_BLOCKS,
		CHUNK_WIDTH_BLOCKS,
		false,
		Image.FORMAT_RGBA8,
		pixel_data,
	)
	if downscale_factor > 1:
		@warning_ignore("integer_division")
		img.resize(
			CHUNK_WIDTH_BLOCKS / downscale_factor,
			CHUNK_WIDTH_BLOCKS / downscale_factor,
			Image.INTERPOLATE_TRILINEAR,
		)
	return img


func _chunkpos_from_int(pos: int) -> Vector2i:
	var chunk_x := pos & ((1 << 21) - 1) # bits 0–20
	var chunk_z := (pos >> 27) & ((1 << 21) - 1) # bits 27–47
	return Vector2i(chunk_x, chunk_z)
