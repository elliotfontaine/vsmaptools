class_name MapPiece extends RefCounted

const CHUNK_SIZE: int = 32

var blob: PackedByteArray
var image: Image
var chunk_position: Vector2i
var block_position: Vector2i:
	set(value): chunk_position = value / CHUNK_SIZE
	get: return chunk_position * CHUNK_SIZE


func _init(position: int, data: PackedByteArray) -> void:
	chunk_position = _chunkpos_from_int(position)
	blob = data


func _chunkpos_from_int(pos: int) -> Vector2i:
	var chunk_x := pos & ((1 << 21) - 1) # bits 0–20
	var chunk_z := (pos >> 27) & ((1 << 21) - 1) # bits 27–47
	return Vector2i(chunk_x, chunk_z)


static func _image_from_blob(data: PackedByteArray) -> Image:
	var message := Proto.MapPieceDB.new()

	# TODO: this is the bottleneck. See Proto.PBPacker.unpack_message
	var result_code := message.from_bytes(data)

	if result_code != Proto.PB_ERR.NO_ERRORS:
		push_error("ERROR WHILE READING PROTOBUF DATA")
		return Image.new() # empty image
	
	var pixels: Array[int] = message.get_Pixels()
	if pixels.size() != CHUNK_SIZE * CHUNK_SIZE:
		push_error("Unexpected pixel array size")
		return Image.new()
	
	# On crée un PackedByteArray pour RGBA
	var byte_data := PackedByteArray()
	byte_data.resize(pixels.size() * 4) # 4 bytes par pixel

	for i in pixels.size():
		var color_int := pixels[i]
		var r := color_int & 0xFF
		var g := (color_int >> 8) & 0xFF
		var b := (color_int >> 16) & 0xFF
		var a := 255 # si tu n’as pas d’alpha, on met 255

		# Godot attend bytes dans l’ordre RGBA
		byte_data[i * 4 + 0] = r
		byte_data[i * 4 + 1] = g
		byte_data[i * 4 + 2] = b
		byte_data[i * 4 + 3] = a

	return Image.create_from_data(CHUNK_SIZE, CHUNK_SIZE, false, Image.FORMAT_RGBA8, byte_data)
