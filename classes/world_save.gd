class_name WorldSave extends RefCounted

const REQUIRED_TABLES: Array[String] = [
	"chunk",
	"gamedata",
	"mapchunk",
	"mapregion",
	"playerdata",
	]

var _db: SQLite = null


func _init(db: SQLite) -> void:
	_db = db
	_db.read_only = true


static func is_valid_world(path: String) -> bool:
	if not FileAccess.file_exists(path):
		return false

	if path.get_extension().to_lower() != "vcdbs":
		return false

	var temp_db := SQLite.new()
	temp_db.path = path
	temp_db.read_only = true

	if not temp_db.open_db():
		return false

	var query := "SELECT name FROM sqlite_master WHERE type='table'"
	if not temp_db.query(query):
		temp_db.close_db()
		return false

	var existing_tables := {}
	for row in temp_db.query_result:
		if row.has("name"):
			existing_tables[row["name"]] = true

	temp_db.close_db()

	for table_name in REQUIRED_TABLES:
		if not existing_tables.has(table_name):
			return false

	return true


func get_world_size() -> Vector2i:
	var message := Proto.SaveGame.new()
	var data := _get_savegame_blob()
	if data.is_empty():
		Logger.error("No gamedata blob found (empty data).")
		return Vector2i.ZERO

	# TODO: this is the bottleneck. See Proto.PBPacker.unpack_message
	var result_code := message.from_bytes(data)
	if result_code != Proto.PB_ERR.NO_ERRORS:
		Logger.error("Error while decoding SaveGame protobuf (code=%s)." % str(result_code))
		return Vector2i.ZERO

	# Vintage Story: MapSizeX and MapSizeZ are the horizontal dimensions.
	# MapSizeY exists too but is usually 256 and not relevant for a 2D map size.
	if message.has_MapSizeX() and message.has_MapSizeZ():
		return Vector2i(message.get_MapSizeX(), message.get_MapSizeZ())
	else:
		return Vector2i.ZERO


func get_savegame_identifier() -> String:
	var message := Proto.SaveGame.new()
	var data := _get_savegame_blob()
	if data.is_empty():
		Logger.error("No gamedata blob found (empty data).")
		return ""

	var result_code := message.from_bytes(data)
	if result_code != Proto.PB_ERR.NO_ERRORS:
		Logger.error("Error while decoding SaveGame protobuf (code=%s)." % str(result_code))
		return ""

	if message.has_SavegameIdentifier():
		return message.get_SavegameIdentifier()
	else:
		return ""


func _get_savegame_blob() -> PackedByteArray:
	# We expect exactly one row in `gamedata`, but we use LIMIT 1 to be safe.
	_db.open_db()
	var ok := _db.query("SELECT data FROM gamedata LIMIT 1")
	if not ok:
		Logger.error("SQLite query failed while reading gamedata blob.")
		_db.close_db()
		return PackedByteArray()

	if _db.query_result.is_empty():
		Logger.error("No rows found in gamedata table.")
		_db.close_db()
		return PackedByteArray()
	
	_db.close_db()
	
	var row: Dictionary = _db.query_result[0]
	if not row.has("data"):
		Logger.error("gamedata row has no 'data' column.")
		_db.close_db()
		return PackedByteArray()

	var blob: Variant = row["data"]

	Logger.debug("Type of BLOB: %s" % [typeof(blob)])

	# Depending on the SQLite addon, the blob might already be a PackedByteArray,
	# or it might be returned as some other byte container.
	if blob is PackedByteArray:
		return blob

	# Fallback: try common cases (e.g. Array of ints) if your addon returns that.
	if blob is Array:
		var blob_array := blob as Array
		var bytes := PackedByteArray()
		bytes.resize(blob_array.size())
		for i in blob_array.size():
			bytes[i] = int(blob_array[i]) & 0xFF
		return bytes

	Logger.error("Unsupported blob type for gamedata.data: %s" % [typeof(blob)])
	return PackedByteArray()
