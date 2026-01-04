class_name MapPiece
extends RefCounted

const CHUNK_SIZE: int = 32

var blob: PackedByteArray
var pixel_data: PackedByteArray
var chunk_position: Vector2i
var block_position: Vector2i:
	set(value):
		chunk_position = value / CHUNK_SIZE
	get:
		return chunk_position * CHUNK_SIZE


func _init(position: int, data: PackedByteArray) -> void:
	chunk_position = _chunkpos_from_int(position)
	blob = data


func decode_blob(data: PackedByteArray) -> void:
	var message := Proto.MapPieceDB.new()

	# TODO: this is the bottleneck. See Proto.PBPacker.unpack_message
	var result_code := message.from_bytes(data)

	if result_code != Proto.PB_ERR.NO_ERRORS:
		push_error("ERROR WHILE READING PROTOBUF DATA")
		return

	var pixels: Array[int] = message.get_Pixels()
	if pixels.size() != CHUNK_SIZE * CHUNK_SIZE:
		push_error("Unexpected pixel array size")
		return

	pixel_data = PackedByteArray()
	pixel_data.resize(pixels.size() * 4) # 4 bytes per pixel

	for i in pixels.size():
		var color_int := pixels[i]
		var r := color_int & 0xFF
		var g := (color_int >> 8) & 0xFF
		var b := (color_int >> 16) & 0xFF
		var a := 255

		pixel_data[i * 4 + 0] = r
		pixel_data[i * 4 + 1] = g
		pixel_data[i * 4 + 2] = b
		pixel_data[i * 4 + 3] = a


func generate_image() -> Image:
	return Image.create_from_data(CHUNK_SIZE, CHUNK_SIZE, false, Image.FORMAT_RGBA8, pixel_data)


func _chunkpos_from_int(pos: int) -> Vector2i:
	var chunk_x := pos & ((1 << 21) - 1) # bits 0–20
	var chunk_z := (pos >> 27) & ((1 << 21) - 1) # bits 27–47
	return Vector2i(chunk_x, chunk_z)
