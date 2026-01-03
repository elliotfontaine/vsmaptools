class_name Proto
@warning_ignore_start("untyped_declaration")
@warning_ignore_start("return_value_discarded")
@warning_ignore_start("inference_on_variant")
@warning_ignore_start("unsafe_method_access")
#
# BSD 3-Clause License
#
# Copyright (c) 2018 - 2023, Oleg Malyavkin
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
#
# * Redistributions of source code must retain the above copyright notice, this
#   list of conditions and the following disclaimer.
#
# * Redistributions in binary form must reproduce the above copyright notice,
#   this list of conditions and the following disclaimer in the documentation
#   and/or other materials provided with the distribution.
#
# * Neither the name of the copyright holder nor the names of its
#   contributors may be used to endorse or promote products derived from
#   this software without specific prior written permission.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
# AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
# DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE
# FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
# DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
# SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
# CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
# OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
# OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

# DEBUG_TAB redefine this "  " if you need, example: const DEBUG_TAB = "\t"

const PROTO_VERSION = 2

const DEBUG_TAB: String = "  "

enum PB_ERR {
	NO_ERRORS = 0,
	VARINT_NOT_FOUND = -1,
	REPEATED_COUNT_NOT_FOUND = -2,
	REPEATED_COUNT_MISMATCH = -3,
	LENGTHDEL_SIZE_NOT_FOUND = -4,
	LENGTHDEL_SIZE_MISMATCH = -5,
	PACKAGE_SIZE_MISMATCH = -6,
	UNDEFINED_STATE = -7,
	PARSE_INCOMPLETE = -8,
	REQUIRED_FIELDS = -9
}

enum PB_DATA_TYPE {
	INT32 = 0,
	SINT32 = 1,
	UINT32 = 2,
	INT64 = 3,
	SINT64 = 4,
	UINT64 = 5,
	BOOL = 6,
	ENUM = 7,
	FIXED32 = 8,
	SFIXED32 = 9,
	FLOAT = 10,
	FIXED64 = 11,
	SFIXED64 = 12,
	DOUBLE = 13,
	STRING = 14,
	BYTES = 15,
	MESSAGE = 16,
	MAP = 17
}

const DEFAULT_VALUES_2 = {
	PB_DATA_TYPE.INT32: null,
	PB_DATA_TYPE.SINT32: null,
	PB_DATA_TYPE.UINT32: null,
	PB_DATA_TYPE.INT64: null,
	PB_DATA_TYPE.SINT64: null,
	PB_DATA_TYPE.UINT64: null,
	PB_DATA_TYPE.BOOL: null,
	PB_DATA_TYPE.ENUM: null,
	PB_DATA_TYPE.FIXED32: null,
	PB_DATA_TYPE.SFIXED32: null,
	PB_DATA_TYPE.FLOAT: null,
	PB_DATA_TYPE.FIXED64: null,
	PB_DATA_TYPE.SFIXED64: null,
	PB_DATA_TYPE.DOUBLE: null,
	PB_DATA_TYPE.STRING: null,
	PB_DATA_TYPE.BYTES: null,
	PB_DATA_TYPE.MESSAGE: null,
	PB_DATA_TYPE.MAP: null
}

const DEFAULT_VALUES_3 = {
	PB_DATA_TYPE.INT32: 0,
	PB_DATA_TYPE.SINT32: 0,
	PB_DATA_TYPE.UINT32: 0,
	PB_DATA_TYPE.INT64: 0,
	PB_DATA_TYPE.SINT64: 0,
	PB_DATA_TYPE.UINT64: 0,
	PB_DATA_TYPE.BOOL: false,
	PB_DATA_TYPE.ENUM: 0,
	PB_DATA_TYPE.FIXED32: 0,
	PB_DATA_TYPE.SFIXED32: 0,
	PB_DATA_TYPE.FLOAT: 0.0,
	PB_DATA_TYPE.FIXED64: 0,
	PB_DATA_TYPE.SFIXED64: 0,
	PB_DATA_TYPE.DOUBLE: 0.0,
	PB_DATA_TYPE.STRING: "",
	PB_DATA_TYPE.BYTES: [],
	PB_DATA_TYPE.MESSAGE: null,
	PB_DATA_TYPE.MAP: []
}

enum PB_TYPE {
	VARINT = 0,
	FIX64 = 1,
	LENGTHDEL = 2,
	STARTGROUP = 3,
	ENDGROUP = 4,
	FIX32 = 5,
	UNDEFINED = 8
}

enum PB_RULE {
	OPTIONAL = 0,
	REQUIRED = 1,
	REPEATED = 2,
	RESERVED = 3
}

enum PB_SERVICE_STATE {
	FILLED = 0,
	UNFILLED = 1
}

class PBField:
	func _init(a_name: String, a_type: int, a_rule: int, a_tag: int, packed: bool, a_value = null):
		name = a_name
		type = a_type
		rule = a_rule
		tag = a_tag
		option_packed = packed
		value = a_value
		
	var name: String
	var type: int
	var rule: int
	var tag: int
	var option_packed: bool
	var value
	var is_map_field: bool = false
	var option_default: bool = false

class PBTypeTag:
	var ok: bool = false
	var type: int
	var tag: int
	var offset: int

class PBServiceField:
	var field: PBField
	var func_ref = null
	var state: int = PB_SERVICE_STATE.UNFILLED

class PBPacker:
	static func convert_signed(n: int) -> int:
		if n < -2147483648:
			return (n << 1) ^ (n >> 63)
		else:
			return (n << 1) ^ (n >> 31)

	static func deconvert_signed(n: int) -> int:
		if n & 0x01:
			return ~(n >> 1)
		else:
			return (n >> 1)

	static func pack_varint(value) -> PackedByteArray:
		var varint: PackedByteArray = PackedByteArray()
		if typeof(value) == TYPE_BOOL:
			if value:
				value = 1
			else:
				value = 0
		for _i in range(9):
			var b = value & 0x7F
			value >>= 7
			if value:
				varint.append(b | 0x80)
			else:
				varint.append(b)
				break
		if varint.size() == 9 && (varint[8] & 0x80 != 0):
			varint.append(0x01)
		return varint

	static func pack_bytes(value, count: int, data_type: int) -> PackedByteArray:
		var bytes: PackedByteArray = PackedByteArray()
		if data_type == PB_DATA_TYPE.FLOAT:
			var spb: StreamPeerBuffer = StreamPeerBuffer.new()
			spb.put_float(value)
			bytes = spb.get_data_array()
		elif data_type == PB_DATA_TYPE.DOUBLE:
			var spb: StreamPeerBuffer = StreamPeerBuffer.new()
			spb.put_double(value)
			bytes = spb.get_data_array()
		else:
			for _i in range(count):
				bytes.append(value & 0xFF)
				value >>= 8
		return bytes

	static func unpack_bytes(bytes: PackedByteArray, index: int, count: int, data_type: int):
		if data_type == PB_DATA_TYPE.FLOAT:
			return bytes.decode_float(index)
		elif data_type == PB_DATA_TYPE.DOUBLE:
			return bytes.decode_double(index)
		else:
			# Convert to big endian
			var slice: PackedByteArray = bytes.slice(index, index + count)
			slice.reverse()
			return slice

	static func unpack_varint(varint_bytes) -> int:
		var value: int = 0
		var i: int = varint_bytes.size() - 1
		while i > -1:
			value = (value << 7) | (varint_bytes[i] & 0x7F)
			i -= 1
		return value

	static func pack_type_tag(type: int, tag: int) -> PackedByteArray:
		return pack_varint((tag << 3) | type)

	static func isolate_varint(bytes: PackedByteArray, index: int) -> PackedByteArray:
		var i: int = index
		while i <= index + 10: # Protobuf varint max size is 10 bytes
			if !(bytes[i] & 0x80):
				return bytes.slice(index, i + 1)
			i += 1
		return [] # Unreachable

	static func unpack_type_tag(bytes: PackedByteArray, index: int) -> PBTypeTag:
		var varint_bytes: PackedByteArray = isolate_varint(bytes, index)
		var result: PBTypeTag = PBTypeTag.new()
		if varint_bytes.size() != 0:
			result.ok = true
			result.offset = varint_bytes.size()
			var unpacked: int = unpack_varint(varint_bytes)
			result.type = unpacked & 0x07
			result.tag = unpacked >> 3
		return result

	static func pack_length_delimeted(type: int, tag: int, bytes: PackedByteArray) -> PackedByteArray:
		var result: PackedByteArray = pack_type_tag(type, tag)
		result.append_array(pack_varint(bytes.size()))
		result.append_array(bytes)
		return result

	static func pb_type_from_data_type(data_type: int) -> int:
		if data_type == PB_DATA_TYPE.INT32 || data_type == PB_DATA_TYPE.SINT32 || data_type == PB_DATA_TYPE.UINT32 || data_type == PB_DATA_TYPE.INT64 || data_type == PB_DATA_TYPE.SINT64 || data_type == PB_DATA_TYPE.UINT64 || data_type == PB_DATA_TYPE.BOOL || data_type == PB_DATA_TYPE.ENUM:
			return PB_TYPE.VARINT
		elif data_type == PB_DATA_TYPE.FIXED32 || data_type == PB_DATA_TYPE.SFIXED32 || data_type == PB_DATA_TYPE.FLOAT:
			return PB_TYPE.FIX32
		elif data_type == PB_DATA_TYPE.FIXED64 || data_type == PB_DATA_TYPE.SFIXED64 || data_type == PB_DATA_TYPE.DOUBLE:
			return PB_TYPE.FIX64
		elif data_type == PB_DATA_TYPE.STRING || data_type == PB_DATA_TYPE.BYTES || data_type == PB_DATA_TYPE.MESSAGE || data_type == PB_DATA_TYPE.MAP:
			return PB_TYPE.LENGTHDEL
		else:
			return PB_TYPE.UNDEFINED

	static func pack_field(field: PBField) -> PackedByteArray:
		var type: int = pb_type_from_data_type(field.type)
		var type_copy: int = type
		if field.rule == PB_RULE.REPEATED && field.option_packed:
			type = PB_TYPE.LENGTHDEL
		var head: PackedByteArray = pack_type_tag(type, field.tag)
		var data: PackedByteArray = PackedByteArray()
		if type == PB_TYPE.VARINT:
			var value
			if field.rule == PB_RULE.REPEATED:
				for v in field.value:
					data.append_array(head)
					if field.type == PB_DATA_TYPE.SINT32 || field.type == PB_DATA_TYPE.SINT64:
						value = convert_signed(v)
					else:
						value = v
					data.append_array(pack_varint(value))
				return data
			else:
				if field.type == PB_DATA_TYPE.SINT32 || field.type == PB_DATA_TYPE.SINT64:
					value = convert_signed(field.value)
				else:
					value = field.value
				data = pack_varint(value)
		elif type == PB_TYPE.FIX32:
			if field.rule == PB_RULE.REPEATED:
				for v in field.value:
					data.append_array(head)
					data.append_array(pack_bytes(v, 4, field.type))
				return data
			else:
				data.append_array(pack_bytes(field.value, 4, field.type))
		elif type == PB_TYPE.FIX64:
			if field.rule == PB_RULE.REPEATED:
				for v in field.value:
					data.append_array(head)
					data.append_array(pack_bytes(v, 8, field.type))
				return data
			else:
				data.append_array(pack_bytes(field.value, 8, field.type))
		elif type == PB_TYPE.LENGTHDEL:
			if field.rule == PB_RULE.REPEATED:
				if type_copy == PB_TYPE.VARINT:
					if field.type == PB_DATA_TYPE.SINT32 || field.type == PB_DATA_TYPE.SINT64:
						var signed_value: int
						for v in field.value:
							signed_value = convert_signed(v)
							data.append_array(pack_varint(signed_value))
					else:
						for v in field.value:
							data.append_array(pack_varint(v))
					return pack_length_delimeted(type, field.tag, data)
				elif type_copy == PB_TYPE.FIX32:
					for v in field.value:
						data.append_array(pack_bytes(v, 4, field.type))
					return pack_length_delimeted(type, field.tag, data)
				elif type_copy == PB_TYPE.FIX64:
					for v in field.value:
						data.append_array(pack_bytes(v, 8, field.type))
					return pack_length_delimeted(type, field.tag, data)
				elif field.type == PB_DATA_TYPE.STRING:
					for v in field.value:
						var obj = v.to_utf8_buffer()
						data.append_array(pack_length_delimeted(type, field.tag, obj))
					return data
				elif field.type == PB_DATA_TYPE.BYTES:
					for v in field.value:
						data.append_array(pack_length_delimeted(type, field.tag, v))
					return data
				elif typeof(field.value[0]) == TYPE_OBJECT:
					for v in field.value:
						var obj: PackedByteArray = v.to_bytes()
						data.append_array(pack_length_delimeted(type, field.tag, obj))
					return data
			else:
				if field.type == PB_DATA_TYPE.STRING:
					var str_bytes: PackedByteArray = field.value.to_utf8_buffer()
					if PROTO_VERSION == 2 || (PROTO_VERSION == 3 && str_bytes.size() > 0):
						data.append_array(str_bytes)
						return pack_length_delimeted(type, field.tag, data)
				if field.type == PB_DATA_TYPE.BYTES:
					if PROTO_VERSION == 2 || (PROTO_VERSION == 3 && field.value.size() > 0):
						data.append_array(field.value)
						return pack_length_delimeted(type, field.tag, data)
				elif typeof(field.value) == TYPE_OBJECT:
					var obj: PackedByteArray = field.value.to_bytes()
					if obj.size() > 0:
						data.append_array(obj)
					return pack_length_delimeted(type, field.tag, data)
				else:
					pass
		if data.size() > 0:
			head.append_array(data)
			return head
		else:
			return data

	static func skip_unknown_field(bytes: PackedByteArray, offset: int, type: int) -> int:
		if type == PB_TYPE.VARINT:
			return offset + isolate_varint(bytes, offset).size()
		if type == PB_TYPE.FIX64:
			return offset + 8
		if type == PB_TYPE.LENGTHDEL:
			var length_bytes: PackedByteArray = isolate_varint(bytes, offset)
			var length: int = unpack_varint(length_bytes)
			return offset + length_bytes.size() + length
		if type == PB_TYPE.FIX32:
			return offset + 4
		return PB_ERR.UNDEFINED_STATE

	static func unpack_field(bytes: PackedByteArray, offset: int, field: PBField, type: int, message_func_ref) -> int:
		if field.rule == PB_RULE.REPEATED && type != PB_TYPE.LENGTHDEL && field.option_packed:
			var count = isolate_varint(bytes, offset)
			if count.size() > 0:
				offset += count.size()
				count = unpack_varint(count)
				if type == PB_TYPE.VARINT:
					var val
					var counter = offset + count
					while offset < counter:
						val = isolate_varint(bytes, offset)
						if val.size() > 0:
							offset += val.size()
							val = unpack_varint(val)
							if field.type == PB_DATA_TYPE.SINT32 || field.type == PB_DATA_TYPE.SINT64:
								val = deconvert_signed(val)
							elif field.type == PB_DATA_TYPE.BOOL:
								if val:
									val = true
								else:
									val = false
							field.value.append(val)
						else:
							return PB_ERR.REPEATED_COUNT_MISMATCH
					return offset
				elif type == PB_TYPE.FIX32 || type == PB_TYPE.FIX64:
					var type_size
					if type == PB_TYPE.FIX32:
						type_size = 4
					else:
						type_size = 8
					var val
					var counter = offset + count
					while offset < counter:
						if (offset + type_size) > bytes.size():
							return PB_ERR.REPEATED_COUNT_MISMATCH
						val = unpack_bytes(bytes, offset, type_size, field.type)
						offset += type_size
						field.value.append(val)
					return offset
			else:
				return PB_ERR.REPEATED_COUNT_NOT_FOUND
		else:
			if type == PB_TYPE.VARINT:
				var val = isolate_varint(bytes, offset)
				if val.size() > 0:
					offset += val.size()
					val = unpack_varint(val)
					if field.type == PB_DATA_TYPE.SINT32 || field.type == PB_DATA_TYPE.SINT64:
						val = deconvert_signed(val)
					elif field.type == PB_DATA_TYPE.BOOL:
						if val:
							val = true
						else:
							val = false
					if field.rule == PB_RULE.REPEATED:
						field.value.append(val)
					else:
						field.value = val
				else:
					return PB_ERR.VARINT_NOT_FOUND
				return offset
			elif type == PB_TYPE.FIX32 || type == PB_TYPE.FIX64:
				var type_size
				if type == PB_TYPE.FIX32:
					type_size = 4
				else:
					type_size = 8
				var val
				if (offset + type_size) > bytes.size():
					return PB_ERR.REPEATED_COUNT_MISMATCH
				val = unpack_bytes(bytes, offset, type_size, field.type)
				offset += type_size
				if field.rule == PB_RULE.REPEATED:
					field.value.append(val)
				else:
					field.value = val
				return offset
			elif type == PB_TYPE.LENGTHDEL:
				var inner_size = isolate_varint(bytes, offset)
				if inner_size.size() > 0:
					offset += inner_size.size()
					inner_size = unpack_varint(inner_size)
					if inner_size >= 0:
						if inner_size + offset > bytes.size():
							return PB_ERR.LENGTHDEL_SIZE_MISMATCH
						if message_func_ref != null:
							var message = message_func_ref.call()
							if inner_size > 0:
								var sub_offset = message.from_bytes(bytes, offset, inner_size + offset)
								if sub_offset > 0:
									if sub_offset - offset >= inner_size:
										offset = sub_offset
										return offset
									else:
										return PB_ERR.LENGTHDEL_SIZE_MISMATCH
								return sub_offset
							else:
								return offset
						elif field.type == PB_DATA_TYPE.STRING:
							var str_bytes: PackedByteArray = bytes.slice(offset, inner_size + offset)
							if field.rule == PB_RULE.REPEATED:
								field.value.append(str_bytes.get_string_from_utf8())
							else:
								field.value = str_bytes.get_string_from_utf8()
							return offset + inner_size
						elif field.type == PB_DATA_TYPE.BYTES:
							var val_bytes: PackedByteArray = bytes.slice(offset, inner_size + offset)
							if field.rule == PB_RULE.REPEATED:
								field.value.append(val_bytes)
							else:
								field.value = val_bytes
							return offset + inner_size
					else:
						return PB_ERR.LENGTHDEL_SIZE_NOT_FOUND
				else:
					return PB_ERR.LENGTHDEL_SIZE_NOT_FOUND
		return PB_ERR.UNDEFINED_STATE

	# TODO: Bottleneck (95% of total, 15ms per call)
	static func unpack_message(data, bytes: PackedByteArray, offset: int, limit: int) -> int:
		while true:
			var tt: PBTypeTag = unpack_type_tag(bytes, offset)
			if tt.ok:
				offset += tt.offset
				if data.has(tt.tag):
					var service: PBServiceField = data[tt.tag]
					var type: int = pb_type_from_data_type(service.field.type)
					if type == tt.type || (tt.type == PB_TYPE.LENGTHDEL && service.field.rule == PB_RULE.REPEATED && service.field.option_packed):
						var res: int = unpack_field(bytes, offset, service.field, type, service.func_ref)
						if res > 0:
							service.state = PB_SERVICE_STATE.FILLED
							offset = res
							if offset == limit:
								return offset
							elif offset > limit:
								return PB_ERR.PACKAGE_SIZE_MISMATCH
						elif res < 0:
							return res
						else:
							break
				else:
					var res: int = skip_unknown_field(bytes, offset, tt.type)
					if res > 0:
						offset = res
						if offset == limit:
							return offset
						elif offset > limit:
							return PB_ERR.PACKAGE_SIZE_MISMATCH
					elif res < 0:
						return res
					else:
						break
			else:
				return offset
		return PB_ERR.UNDEFINED_STATE

	static func pack_message(data) -> PackedByteArray:
		var DEFAULT_VALUES
		if PROTO_VERSION == 2:
			DEFAULT_VALUES = DEFAULT_VALUES_2
		elif PROTO_VERSION == 3:
			DEFAULT_VALUES = DEFAULT_VALUES_3
		var result: PackedByteArray = PackedByteArray()
		var keys: Array = data.keys()
		keys.sort()
		for i in keys:
			if data[i].field.value != null:
				if data[i].state == PB_SERVICE_STATE.UNFILLED \
				&& !data[i].field.is_map_field \
				&& typeof(data[i].field.value) == typeof(DEFAULT_VALUES[data[i].field.type]) \
				&& data[i].field.value == DEFAULT_VALUES[data[i].field.type]:
					continue
				elif data[i].field.rule == PB_RULE.REPEATED && data[i].field.value.size() == 0:
					continue
				result.append_array(pack_field(data[i].field))
			elif data[i].field.rule == PB_RULE.REQUIRED:
				Logger.error("Required field is not filled: Tag:", data[i].field.tag)
				return PackedByteArray()
		return result

	static func check_required(data) -> bool:
		var keys: Array = data.keys()
		for i in keys:
			if data[i].field.rule == PB_RULE.REQUIRED && data[i].state == PB_SERVICE_STATE.UNFILLED:
				return false
		return true

	static func construct_map(key_values):
		var result = {}
		for kv in key_values:
			result[kv.get_key()] = kv.get_value()
		return result
	
	static func tabulate(text: String, nesting: int) -> String:
		var tab: String = ""
		for _i in range(nesting):
			tab += DEBUG_TAB
		return tab + text
	
	static func value_to_string(value, field: PBField, nesting: int) -> String:
		var result: String = ""
		var text: String
		if field.type == PB_DATA_TYPE.MESSAGE:
			result += "{"
			nesting += 1
			text = message_to_string(value.data, nesting)
			if text != "":
				result += "\n" + text
				nesting -= 1
				result += tabulate("}", nesting)
			else:
				nesting -= 1
				result += "}"
		elif field.type == PB_DATA_TYPE.BYTES:
			result += "<"
			for i in range(value.size()):
				result += str(value[i])
				if i != (value.size() - 1):
					result += ", "
			result += ">"
		elif field.type == PB_DATA_TYPE.STRING:
			result += "\"" + value + "\""
		elif field.type == PB_DATA_TYPE.ENUM:
			result += "ENUM::" + str(value)
		else:
			result += str(value)
		return result
	
	static func field_to_string(field: PBField, nesting: int) -> String:
		var result: String = tabulate(field.name + ": ", nesting)
		if field.type == PB_DATA_TYPE.MAP:
			if field.value.size() > 0:
				result += "(\n"
				nesting += 1
				for i in range(field.value.size()):
					var local_key_value = field.value[i].data[1].field
					result += tabulate(value_to_string(local_key_value.value, local_key_value, nesting), nesting) + ": "
					local_key_value = field.value[i].data[2].field
					result += value_to_string(local_key_value.value, local_key_value, nesting)
					if i != (field.value.size() - 1):
						result += ","
					result += "\n"
				nesting -= 1
				result += tabulate(")", nesting)
			else:
				result += "()"
		elif field.rule == PB_RULE.REPEATED:
			if field.value.size() > 0:
				result += "[\n"
				nesting += 1
				for i in range(field.value.size()):
					result += tabulate(str(i) + ": ", nesting)
					result += value_to_string(field.value[i], field, nesting)
					if i != (field.value.size() - 1):
						result += ","
					result += "\n"
				nesting -= 1
				result += tabulate("]", nesting)
			else:
				result += "[]"
		else:
			result += value_to_string(field.value, field, nesting)
		result += ";\n"
		return result
		
	static func message_to_string(data, nesting: int = 0) -> String:
		var DEFAULT_VALUES
		if PROTO_VERSION == 2:
			DEFAULT_VALUES = DEFAULT_VALUES_2
		elif PROTO_VERSION == 3:
			DEFAULT_VALUES = DEFAULT_VALUES_3
		var result: String = ""
		var keys: Array = data.keys()
		keys.sort()
		for i in keys:
			if data[i].field.value != null:
				if data[i].state == PB_SERVICE_STATE.UNFILLED \
				&& !data[i].field.is_map_field \
				&& typeof(data[i].field.value) == typeof(DEFAULT_VALUES[data[i].field.type]) \
				&& data[i].field.value == DEFAULT_VALUES[data[i].field.type]:
					continue
				elif data[i].field.rule == PB_RULE.REPEATED && data[i].field.value.size() == 0:
					continue
				result += field_to_string(data[i].field, nesting)
			elif data[i].field.rule == PB_RULE.REQUIRED:
				result += data[i].field.name + ": " + "error"
		return result


############### USER DATA BEGIN ################


class Cuboidi:
	func _init():
		var service
		
		__X1 = PBField.new("X1", PB_DATA_TYPE.INT32, PB_RULE.OPTIONAL, 1, false, DEFAULT_VALUES_2[PB_DATA_TYPE.INT32])
		service = PBServiceField.new()
		service.field = __X1
		data[__X1.tag] = service
		
		__Y1 = PBField.new("Y1", PB_DATA_TYPE.INT32, PB_RULE.OPTIONAL, 2, false, DEFAULT_VALUES_2[PB_DATA_TYPE.INT32])
		service = PBServiceField.new()
		service.field = __Y1
		data[__Y1.tag] = service
		
		__Z1 = PBField.new("Z1", PB_DATA_TYPE.INT32, PB_RULE.OPTIONAL, 3, false, DEFAULT_VALUES_2[PB_DATA_TYPE.INT32])
		service = PBServiceField.new()
		service.field = __Z1
		data[__Z1.tag] = service
		
		__X2 = PBField.new("X2", PB_DATA_TYPE.INT32, PB_RULE.OPTIONAL, 4, false, DEFAULT_VALUES_2[PB_DATA_TYPE.INT32])
		service = PBServiceField.new()
		service.field = __X2
		data[__X2.tag] = service
		
		__Y2 = PBField.new("Y2", PB_DATA_TYPE.INT32, PB_RULE.OPTIONAL, 5, false, DEFAULT_VALUES_2[PB_DATA_TYPE.INT32])
		service = PBServiceField.new()
		service.field = __Y2
		data[__Y2.tag] = service
		
		__Z2 = PBField.new("Z2", PB_DATA_TYPE.INT32, PB_RULE.OPTIONAL, 6, false, DEFAULT_VALUES_2[PB_DATA_TYPE.INT32])
		service = PBServiceField.new()
		service.field = __Z2
		data[__Z2.tag] = service
		
	var data = {}
	
	var __X1: PBField
	func has_X1() -> bool:
		if __X1.value != null:
			return true
		return false
	func get_X1() -> int:
		return __X1.value
	func clear_X1() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		__X1.value = DEFAULT_VALUES_2[PB_DATA_TYPE.INT32]
	func set_X1(value: int) -> void:
		__X1.value = value
	
	var __Y1: PBField
	func has_Y1() -> bool:
		if __Y1.value != null:
			return true
		return false
	func get_Y1() -> int:
		return __Y1.value
	func clear_Y1() -> void:
		data[2].state = PB_SERVICE_STATE.UNFILLED
		__Y1.value = DEFAULT_VALUES_2[PB_DATA_TYPE.INT32]
	func set_Y1(value: int) -> void:
		__Y1.value = value
	
	var __Z1: PBField
	func has_Z1() -> bool:
		if __Z1.value != null:
			return true
		return false
	func get_Z1() -> int:
		return __Z1.value
	func clear_Z1() -> void:
		data[3].state = PB_SERVICE_STATE.UNFILLED
		__Z1.value = DEFAULT_VALUES_2[PB_DATA_TYPE.INT32]
	func set_Z1(value: int) -> void:
		__Z1.value = value
	
	var __X2: PBField
	func has_X2() -> bool:
		if __X2.value != null:
			return true
		return false
	func get_X2() -> int:
		return __X2.value
	func clear_X2() -> void:
		data[4].state = PB_SERVICE_STATE.UNFILLED
		__X2.value = DEFAULT_VALUES_2[PB_DATA_TYPE.INT32]
	func set_X2(value: int) -> void:
		__X2.value = value
	
	var __Y2: PBField
	func has_Y2() -> bool:
		if __Y2.value != null:
			return true
		return false
	func get_Y2() -> int:
		return __Y2.value
	func clear_Y2() -> void:
		data[5].state = PB_SERVICE_STATE.UNFILLED
		__Y2.value = DEFAULT_VALUES_2[PB_DATA_TYPE.INT32]
	func set_Y2(value: int) -> void:
		__Y2.value = value
	
	var __Z2: PBField
	func has_Z2() -> bool:
		if __Z2.value != null:
			return true
		return false
	func get_Z2() -> int:
		return __Z2.value
	func clear_Z2() -> void:
		data[6].state = PB_SERVICE_STATE.UNFILLED
		__Z2.value = DEFAULT_VALUES_2[PB_DATA_TYPE.INT32]
	func set_Z2(value: int) -> void:
		__Z2.value = value
	
	func _to_string() -> String:
		return PBPacker.message_to_string(data)
		
	func to_bytes() -> PackedByteArray:
		return PBPacker.pack_message(data)
		
	func from_bytes(bytes: PackedByteArray, offset: int = 0, limit: int = -1) -> int:
		var cur_limit = bytes.size()
		if limit != -1:
			cur_limit = limit
		var result = PBPacker.unpack_message(data, bytes, offset, cur_limit)
		if result == cur_limit:
			if PBPacker.check_required(data):
				if limit == -1:
					return PB_ERR.NO_ERRORS
			else:
				return PB_ERR.REQUIRED_FIELDS
		elif limit == -1 && result > 0:
			return PB_ERR.PARSE_INCOMPLETE
		return result
	
enum EnumBlockAccessFlags {
	EnumBlockAccessFlags_None = 0,
	EnumBlockAccessFlags_BuildOrBreak = 1,
	EnumBlockAccessFlags_Use = 2,
	EnumBlockAccessFlags_Traverse = 4
}

enum EnumFreeMovAxisLock {
	EnumFreeMovAxisLock_None = 0,
	EnumFreeMovAxisLock_X = 1,
	EnumFreeMovAxisLock_Y = 2,
	EnumFreeMovAxisLock_Z = 3
}

enum EnumGameMode {
	EnumGameMode_Guest = 0,
	EnumGameMode_Survival = 1,
	EnumGameMode_Creative = 2,
	EnumGameMode_Spectator = 3
}

enum EnumPlayStyle {
	EnumPlayStyle_WildernessSurvival = 0,
	EnumPlayStyle_SurviveAndBuild = 1,
	EnumPlayStyle_SurviveAndAutomate = 2,
	EnumPlayStyle_CreativeBuilding = 3
}

class LandClaim:
	func _init():
		var service
		
		var __Areas_default: Array[Cuboidi] = []
		__Areas = PBField.new("Areas", PB_DATA_TYPE.MESSAGE, PB_RULE.REPEATED, 1, false, __Areas_default)
		service = PBServiceField.new()
		service.field = __Areas
		service.func_ref = Callable(self, "add_Areas")
		data[__Areas.tag] = service
		
		__ProtectionLevel = PBField.new("ProtectionLevel", PB_DATA_TYPE.INT32, PB_RULE.OPTIONAL, 2, false, DEFAULT_VALUES_2[PB_DATA_TYPE.INT32])
		service = PBServiceField.new()
		service.field = __ProtectionLevel
		data[__ProtectionLevel.tag] = service
		
		__OwnedByEntityId = PBField.new("OwnedByEntityId", PB_DATA_TYPE.INT64, PB_RULE.OPTIONAL, 3, false, DEFAULT_VALUES_2[PB_DATA_TYPE.INT64])
		service = PBServiceField.new()
		service.field = __OwnedByEntityId
		data[__OwnedByEntityId.tag] = service
		
		__OwnedByPlayerUid = PBField.new("OwnedByPlayerUid", PB_DATA_TYPE.STRING, PB_RULE.OPTIONAL, 4, false, DEFAULT_VALUES_2[PB_DATA_TYPE.STRING])
		service = PBServiceField.new()
		service.field = __OwnedByPlayerUid
		data[__OwnedByPlayerUid.tag] = service
		
		__OwnedByPlayerGroupUid = PBField.new("OwnedByPlayerGroupUid", PB_DATA_TYPE.UINT32, PB_RULE.OPTIONAL, 5, false, DEFAULT_VALUES_2[PB_DATA_TYPE.UINT32])
		service = PBServiceField.new()
		service.field = __OwnedByPlayerGroupUid
		data[__OwnedByPlayerGroupUid.tag] = service
		
		__LastKnownOwnerName = PBField.new("LastKnownOwnerName", PB_DATA_TYPE.STRING, PB_RULE.OPTIONAL, 6, false, DEFAULT_VALUES_2[PB_DATA_TYPE.STRING])
		service = PBServiceField.new()
		service.field = __LastKnownOwnerName
		data[__LastKnownOwnerName.tag] = service
		
		__Description = PBField.new("Description", PB_DATA_TYPE.STRING, PB_RULE.OPTIONAL, 7, false, DEFAULT_VALUES_2[PB_DATA_TYPE.STRING])
		service = PBServiceField.new()
		service.field = __Description
		data[__Description.tag] = service
		
		var __PermittedPlayerGroupIds_default: Array = []
		__PermittedPlayerGroupIds = PBField.new("PermittedPlayerGroupIds", PB_DATA_TYPE.MAP, PB_RULE.REPEATED, 8, false, __PermittedPlayerGroupIds_default)
		service = PBServiceField.new()
		service.field = __PermittedPlayerGroupIds
		service.func_ref = Callable(self, "add_empty_PermittedPlayerGroupIds")
		data[__PermittedPlayerGroupIds.tag] = service
		
		var __PermittedPlayerUids_default: Array = []
		__PermittedPlayerUids = PBField.new("PermittedPlayerUids", PB_DATA_TYPE.MAP, PB_RULE.REPEATED, 9, false, __PermittedPlayerUids_default)
		service = PBServiceField.new()
		service.field = __PermittedPlayerUids
		service.func_ref = Callable(self, "add_empty_PermittedPlayerUids")
		data[__PermittedPlayerUids.tag] = service
		
		var __PermittedPlayerLastKnownPlayerName_default: Array = []
		__PermittedPlayerLastKnownPlayerName = PBField.new("PermittedPlayerLastKnownPlayerName", PB_DATA_TYPE.MAP, PB_RULE.REPEATED, 10, false, __PermittedPlayerLastKnownPlayerName_default)
		service = PBServiceField.new()
		service.field = __PermittedPlayerLastKnownPlayerName
		service.func_ref = Callable(self, "add_empty_PermittedPlayerLastKnownPlayerName")
		data[__PermittedPlayerLastKnownPlayerName.tag] = service
		
		__AllowUseEveryone = PBField.new("AllowUseEveryone", PB_DATA_TYPE.BOOL, PB_RULE.OPTIONAL, 11, false, DEFAULT_VALUES_2[PB_DATA_TYPE.BOOL])
		service = PBServiceField.new()
		service.field = __AllowUseEveryone
		data[__AllowUseEveryone.tag] = service
		
		__AllowTraverseEveryone = PBField.new("AllowTraverseEveryone", PB_DATA_TYPE.BOOL, PB_RULE.OPTIONAL, 12, false, DEFAULT_VALUES_2[PB_DATA_TYPE.BOOL])
		service = PBServiceField.new()
		service.field = __AllowTraverseEveryone
		data[__AllowTraverseEveryone.tag] = service
		
	var data = {}
	
	var __Areas: PBField
	func get_Areas() -> Array[Cuboidi]:
		return __Areas.value
	func clear_Areas() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		__Areas.value.clear()
	func add_Areas() -> Cuboidi:
		var element = Cuboidi.new()
		__Areas.value.append(element)
		return element
	
	var __ProtectionLevel: PBField
	func has_ProtectionLevel() -> bool:
		if __ProtectionLevel.value != null:
			return true
		return false
	func get_ProtectionLevel() -> int:
		return __ProtectionLevel.value
	func clear_ProtectionLevel() -> void:
		data[2].state = PB_SERVICE_STATE.UNFILLED
		__ProtectionLevel.value = DEFAULT_VALUES_2[PB_DATA_TYPE.INT32]
	func set_ProtectionLevel(value: int) -> void:
		__ProtectionLevel.value = value
	
	var __OwnedByEntityId: PBField
	func has_OwnedByEntityId() -> bool:
		if __OwnedByEntityId.value != null:
			return true
		return false
	func get_OwnedByEntityId() -> int:
		return __OwnedByEntityId.value
	func clear_OwnedByEntityId() -> void:
		data[3].state = PB_SERVICE_STATE.UNFILLED
		__OwnedByEntityId.value = DEFAULT_VALUES_2[PB_DATA_TYPE.INT64]
	func set_OwnedByEntityId(value: int) -> void:
		__OwnedByEntityId.value = value
	
	var __OwnedByPlayerUid: PBField
	func has_OwnedByPlayerUid() -> bool:
		if __OwnedByPlayerUid.value != null:
			return true
		return false
	func get_OwnedByPlayerUid() -> String:
		return __OwnedByPlayerUid.value
	func clear_OwnedByPlayerUid() -> void:
		data[4].state = PB_SERVICE_STATE.UNFILLED
		__OwnedByPlayerUid.value = DEFAULT_VALUES_2[PB_DATA_TYPE.STRING]
	func set_OwnedByPlayerUid(value: String) -> void:
		__OwnedByPlayerUid.value = value
	
	var __OwnedByPlayerGroupUid: PBField
	func has_OwnedByPlayerGroupUid() -> bool:
		if __OwnedByPlayerGroupUid.value != null:
			return true
		return false
	func get_OwnedByPlayerGroupUid() -> int:
		return __OwnedByPlayerGroupUid.value
	func clear_OwnedByPlayerGroupUid() -> void:
		data[5].state = PB_SERVICE_STATE.UNFILLED
		__OwnedByPlayerGroupUid.value = DEFAULT_VALUES_2[PB_DATA_TYPE.UINT32]
	func set_OwnedByPlayerGroupUid(value: int) -> void:
		__OwnedByPlayerGroupUid.value = value
	
	var __LastKnownOwnerName: PBField
	func has_LastKnownOwnerName() -> bool:
		if __LastKnownOwnerName.value != null:
			return true
		return false
	func get_LastKnownOwnerName() -> String:
		return __LastKnownOwnerName.value
	func clear_LastKnownOwnerName() -> void:
		data[6].state = PB_SERVICE_STATE.UNFILLED
		__LastKnownOwnerName.value = DEFAULT_VALUES_2[PB_DATA_TYPE.STRING]
	func set_LastKnownOwnerName(value: String) -> void:
		__LastKnownOwnerName.value = value
	
	var __Description: PBField
	func has_Description() -> bool:
		if __Description.value != null:
			return true
		return false
	func get_Description() -> String:
		return __Description.value
	func clear_Description() -> void:
		data[7].state = PB_SERVICE_STATE.UNFILLED
		__Description.value = DEFAULT_VALUES_2[PB_DATA_TYPE.STRING]
	func set_Description(value: String) -> void:
		__Description.value = value
	
	var __PermittedPlayerGroupIds: PBField
	func get_raw_PermittedPlayerGroupIds():
		return __PermittedPlayerGroupIds.value
	func get_PermittedPlayerGroupIds():
		return PBPacker.construct_map(__PermittedPlayerGroupIds.value)
	func clear_PermittedPlayerGroupIds():
		data[8].state = PB_SERVICE_STATE.UNFILLED
		__PermittedPlayerGroupIds.value = DEFAULT_VALUES_2[PB_DATA_TYPE.MAP]
	func add_empty_PermittedPlayerGroupIds() -> LandClaim.map_type_PermittedPlayerGroupIds:
		var element = LandClaim.map_type_PermittedPlayerGroupIds.new()
		__PermittedPlayerGroupIds.value.append(element)
		return element
	func add_PermittedPlayerGroupIds(a_key, a_value) -> void:
		var idx = -1
		for i in range(__PermittedPlayerGroupIds.value.size()):
			if __PermittedPlayerGroupIds.value[i].get_key() == a_key:
				idx = i
				break
		var element = LandClaim.map_type_PermittedPlayerGroupIds.new()
		element.set_key(a_key)
		element.set_value(a_value)
		if idx != -1:
			__PermittedPlayerGroupIds.value[idx] = element
		else:
			__PermittedPlayerGroupIds.value.append(element)
	
	var __PermittedPlayerUids: PBField
	func get_raw_PermittedPlayerUids():
		return __PermittedPlayerUids.value
	func get_PermittedPlayerUids():
		return PBPacker.construct_map(__PermittedPlayerUids.value)
	func clear_PermittedPlayerUids():
		data[9].state = PB_SERVICE_STATE.UNFILLED
		__PermittedPlayerUids.value = DEFAULT_VALUES_2[PB_DATA_TYPE.MAP]
	func add_empty_PermittedPlayerUids() -> LandClaim.map_type_PermittedPlayerUids:
		var element = LandClaim.map_type_PermittedPlayerUids.new()
		__PermittedPlayerUids.value.append(element)
		return element
	func add_PermittedPlayerUids(a_key, a_value) -> void:
		var idx = -1
		for i in range(__PermittedPlayerUids.value.size()):
			if __PermittedPlayerUids.value[i].get_key() == a_key:
				idx = i
				break
		var element = LandClaim.map_type_PermittedPlayerUids.new()
		element.set_key(a_key)
		element.set_value(a_value)
		if idx != -1:
			__PermittedPlayerUids.value[idx] = element
		else:
			__PermittedPlayerUids.value.append(element)
	
	var __PermittedPlayerLastKnownPlayerName: PBField
	func get_raw_PermittedPlayerLastKnownPlayerName():
		return __PermittedPlayerLastKnownPlayerName.value
	func get_PermittedPlayerLastKnownPlayerName():
		return PBPacker.construct_map(__PermittedPlayerLastKnownPlayerName.value)
	func clear_PermittedPlayerLastKnownPlayerName():
		data[10].state = PB_SERVICE_STATE.UNFILLED
		__PermittedPlayerLastKnownPlayerName.value = DEFAULT_VALUES_2[PB_DATA_TYPE.MAP]
	func add_empty_PermittedPlayerLastKnownPlayerName() -> LandClaim.map_type_PermittedPlayerLastKnownPlayerName:
		var element = LandClaim.map_type_PermittedPlayerLastKnownPlayerName.new()
		__PermittedPlayerLastKnownPlayerName.value.append(element)
		return element
	func add_PermittedPlayerLastKnownPlayerName(a_key, a_value) -> void:
		var idx = -1
		for i in range(__PermittedPlayerLastKnownPlayerName.value.size()):
			if __PermittedPlayerLastKnownPlayerName.value[i].get_key() == a_key:
				idx = i
				break
		var element = LandClaim.map_type_PermittedPlayerLastKnownPlayerName.new()
		element.set_key(a_key)
		element.set_value(a_value)
		if idx != -1:
			__PermittedPlayerLastKnownPlayerName.value[idx] = element
		else:
			__PermittedPlayerLastKnownPlayerName.value.append(element)
	
	var __AllowUseEveryone: PBField
	func has_AllowUseEveryone() -> bool:
		if __AllowUseEveryone.value != null:
			return true
		return false
	func get_AllowUseEveryone() -> bool:
		return __AllowUseEveryone.value
	func clear_AllowUseEveryone() -> void:
		data[11].state = PB_SERVICE_STATE.UNFILLED
		__AllowUseEveryone.value = DEFAULT_VALUES_2[PB_DATA_TYPE.BOOL]
	func set_AllowUseEveryone(value: bool) -> void:
		__AllowUseEveryone.value = value
	
	var __AllowTraverseEveryone: PBField
	func has_AllowTraverseEveryone() -> bool:
		if __AllowTraverseEveryone.value != null:
			return true
		return false
	func get_AllowTraverseEveryone() -> bool:
		return __AllowTraverseEveryone.value
	func clear_AllowTraverseEveryone() -> void:
		data[12].state = PB_SERVICE_STATE.UNFILLED
		__AllowTraverseEveryone.value = DEFAULT_VALUES_2[PB_DATA_TYPE.BOOL]
	func set_AllowTraverseEveryone(value: bool) -> void:
		__AllowTraverseEveryone.value = value
	
	class map_type_PermittedPlayerGroupIds:
		func _init():
			var service
			
			__key = PBField.new("key", PB_DATA_TYPE.INT32, PB_RULE.OPTIONAL, 1, false, DEFAULT_VALUES_2[PB_DATA_TYPE.INT32])
			__key.is_map_field = true
			service = PBServiceField.new()
			service.field = __key
			data[__key.tag] = service
			
			__value = PBField.new("value", PB_DATA_TYPE.ENUM, PB_RULE.OPTIONAL, 2, false, DEFAULT_VALUES_2[PB_DATA_TYPE.ENUM])
			__value.is_map_field = true
			service = PBServiceField.new()
			service.field = __value
			data[__value.tag] = service
			
		var data = {}
		
		var __key: PBField
		func has_key() -> bool:
			if __key.value != null:
				return true
			return false
		func get_key() -> int:
			return __key.value
		func clear_key() -> void:
			data[1].state = PB_SERVICE_STATE.UNFILLED
			__key.value = DEFAULT_VALUES_2[PB_DATA_TYPE.INT32]
		func set_key(value: int) -> void:
			__key.value = value
		
		var __value: PBField
		func has_value() -> bool:
			if __value.value != null:
				return true
			return false
		func get_value():
			return __value.value
		func clear_value() -> void:
			data[2].state = PB_SERVICE_STATE.UNFILLED
			__value.value = DEFAULT_VALUES_2[PB_DATA_TYPE.ENUM]
		func set_value(value) -> void:
			__value.value = value
		
		func _to_string() -> String:
			return PBPacker.message_to_string(data)
			
		func to_bytes() -> PackedByteArray:
			return PBPacker.pack_message(data)
			
		func from_bytes(bytes: PackedByteArray, offset: int = 0, limit: int = -1) -> int:
			var cur_limit = bytes.size()
			if limit != -1:
				cur_limit = limit
			var result = PBPacker.unpack_message(data, bytes, offset, cur_limit)
			if result == cur_limit:
				if PBPacker.check_required(data):
					if limit == -1:
						return PB_ERR.NO_ERRORS
				else:
					return PB_ERR.REQUIRED_FIELDS
			elif limit == -1 && result > 0:
				return PB_ERR.PARSE_INCOMPLETE
			return result
		
	class map_type_PermittedPlayerUids:
		func _init():
			var service
			
			__key = PBField.new("key", PB_DATA_TYPE.STRING, PB_RULE.OPTIONAL, 1, false, DEFAULT_VALUES_2[PB_DATA_TYPE.STRING])
			__key.is_map_field = true
			service = PBServiceField.new()
			service.field = __key
			data[__key.tag] = service
			
			__value = PBField.new("value", PB_DATA_TYPE.ENUM, PB_RULE.OPTIONAL, 2, false, DEFAULT_VALUES_2[PB_DATA_TYPE.ENUM])
			__value.is_map_field = true
			service = PBServiceField.new()
			service.field = __value
			data[__value.tag] = service
			
		var data = {}
		
		var __key: PBField
		func has_key() -> bool:
			if __key.value != null:
				return true
			return false
		func get_key() -> String:
			return __key.value
		func clear_key() -> void:
			data[1].state = PB_SERVICE_STATE.UNFILLED
			__key.value = DEFAULT_VALUES_2[PB_DATA_TYPE.STRING]
		func set_key(value: String) -> void:
			__key.value = value
		
		var __value: PBField
		func has_value() -> bool:
			if __value.value != null:
				return true
			return false
		func get_value():
			return __value.value
		func clear_value() -> void:
			data[2].state = PB_SERVICE_STATE.UNFILLED
			__value.value = DEFAULT_VALUES_2[PB_DATA_TYPE.ENUM]
		func set_value(value) -> void:
			__value.value = value
		
		func _to_string() -> String:
			return PBPacker.message_to_string(data)
			
		func to_bytes() -> PackedByteArray:
			return PBPacker.pack_message(data)
			
		func from_bytes(bytes: PackedByteArray, offset: int = 0, limit: int = -1) -> int:
			var cur_limit = bytes.size()
			if limit != -1:
				cur_limit = limit
			var result = PBPacker.unpack_message(data, bytes, offset, cur_limit)
			if result == cur_limit:
				if PBPacker.check_required(data):
					if limit == -1:
						return PB_ERR.NO_ERRORS
				else:
					return PB_ERR.REQUIRED_FIELDS
			elif limit == -1 && result > 0:
				return PB_ERR.PARSE_INCOMPLETE
			return result
		
	class map_type_PermittedPlayerLastKnownPlayerName:
		func _init():
			var service
			
			__key = PBField.new("key", PB_DATA_TYPE.STRING, PB_RULE.OPTIONAL, 1, false, DEFAULT_VALUES_2[PB_DATA_TYPE.STRING])
			__key.is_map_field = true
			service = PBServiceField.new()
			service.field = __key
			data[__key.tag] = service
			
			__value = PBField.new("value", PB_DATA_TYPE.STRING, PB_RULE.OPTIONAL, 2, false, DEFAULT_VALUES_2[PB_DATA_TYPE.STRING])
			__value.is_map_field = true
			service = PBServiceField.new()
			service.field = __value
			data[__value.tag] = service
			
		var data = {}
		
		var __key: PBField
		func has_key() -> bool:
			if __key.value != null:
				return true
			return false
		func get_key() -> String:
			return __key.value
		func clear_key() -> void:
			data[1].state = PB_SERVICE_STATE.UNFILLED
			__key.value = DEFAULT_VALUES_2[PB_DATA_TYPE.STRING]
		func set_key(value: String) -> void:
			__key.value = value
		
		var __value: PBField
		func has_value() -> bool:
			if __value.value != null:
				return true
			return false
		func get_value() -> String:
			return __value.value
		func clear_value() -> void:
			data[2].state = PB_SERVICE_STATE.UNFILLED
			__value.value = DEFAULT_VALUES_2[PB_DATA_TYPE.STRING]
		func set_value(value: String) -> void:
			__value.value = value
		
		func _to_string() -> String:
			return PBPacker.message_to_string(data)
			
		func to_bytes() -> PackedByteArray:
			return PBPacker.pack_message(data)
			
		func from_bytes(bytes: PackedByteArray, offset: int = 0, limit: int = -1) -> int:
			var cur_limit = bytes.size()
			if limit != -1:
				cur_limit = limit
			var result = PBPacker.unpack_message(data, bytes, offset, cur_limit)
			if result == cur_limit:
				if PBPacker.check_required(data):
					if limit == -1:
						return PB_ERR.NO_ERRORS
				else:
					return PB_ERR.REQUIRED_FIELDS
			elif limit == -1 && result > 0:
				return PB_ERR.PARSE_INCOMPLETE
			return result
		
	func _to_string() -> String:
		return PBPacker.message_to_string(data)
		
	func to_bytes() -> PackedByteArray:
		return PBPacker.pack_message(data)
		
	func from_bytes(bytes: PackedByteArray, offset: int = 0, limit: int = -1) -> int:
		var cur_limit = bytes.size()
		if limit != -1:
			cur_limit = limit
		var result = PBPacker.unpack_message(data, bytes, offset, cur_limit)
		if result == cur_limit:
			if PBPacker.check_required(data):
				if limit == -1:
					return PB_ERR.NO_ERRORS
			else:
				return PB_ERR.REQUIRED_FIELDS
		elif limit == -1 && result > 0:
			return PB_ERR.PARSE_INCOMPLETE
		return result
	
class MapPieceDB:
	func _init():
		var service
		
		var __Pixels_default: Array[int] = []
		__Pixels = PBField.new("Pixels", PB_DATA_TYPE.INT32, PB_RULE.REPEATED, 1, false, __Pixels_default)
		service = PBServiceField.new()
		service.field = __Pixels
		data[__Pixels.tag] = service
		
	var data = {}
	
	var __Pixels: PBField
	func get_Pixels() -> Array[int]:
		return __Pixels.value
	func clear_Pixels() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		__Pixels.value.clear()
	func add_Pixels(value: int) -> void:
		__Pixels.value.append(value)
	
	func _to_string() -> String:
		return PBPacker.message_to_string(data)
		
	func to_bytes() -> PackedByteArray:
		return PBPacker.pack_message(data)
		
	func from_bytes(bytes: PackedByteArray, offset: int = 0, limit: int = -1) -> int:
		var cur_limit = bytes.size()
		if limit != -1:
			cur_limit = limit
		var result = PBPacker.unpack_message(data, bytes, offset, cur_limit)
		if result == cur_limit:
			if PBPacker.check_required(data):
				if limit == -1:
					return PB_ERR.NO_ERRORS
			else:
				return PB_ERR.REQUIRED_FIELDS
		elif limit == -1 && result > 0:
			return PB_ERR.PARSE_INCOMPLETE
		return result
	
class PlayerSpawnPos:
	func _init():
		var service
		
		__x = PBField.new("x", PB_DATA_TYPE.INT32, PB_RULE.OPTIONAL, 1, false, DEFAULT_VALUES_2[PB_DATA_TYPE.INT32])
		service = PBServiceField.new()
		service.field = __x
		data[__x.tag] = service
		
		__y = PBField.new("y", PB_DATA_TYPE.INT32, PB_RULE.OPTIONAL, 2, false, DEFAULT_VALUES_2[PB_DATA_TYPE.INT32])
		service = PBServiceField.new()
		service.field = __y
		data[__y.tag] = service
		
		__z = PBField.new("z", PB_DATA_TYPE.INT32, PB_RULE.OPTIONAL, 3, false, DEFAULT_VALUES_2[PB_DATA_TYPE.INT32])
		service = PBServiceField.new()
		service.field = __z
		data[__z.tag] = service
		
		__yaw = PBField.new("yaw", PB_DATA_TYPE.FLOAT, PB_RULE.OPTIONAL, 4, false, DEFAULT_VALUES_2[PB_DATA_TYPE.FLOAT])
		service = PBServiceField.new()
		service.field = __yaw
		data[__yaw.tag] = service
		
		__pitch = PBField.new("pitch", PB_DATA_TYPE.FLOAT, PB_RULE.OPTIONAL, 5, false, DEFAULT_VALUES_2[PB_DATA_TYPE.FLOAT])
		service = PBServiceField.new()
		service.field = __pitch
		data[__pitch.tag] = service
		
		__roll = PBField.new("roll", PB_DATA_TYPE.FLOAT, PB_RULE.OPTIONAL, 6, false, DEFAULT_VALUES_2[PB_DATA_TYPE.FLOAT])
		service = PBServiceField.new()
		service.field = __roll
		data[__roll.tag] = service
		
		__RemainingUses = PBField.new("RemainingUses", PB_DATA_TYPE.INT32, PB_RULE.OPTIONAL, 7, false, DEFAULT_VALUES_2[PB_DATA_TYPE.INT32])
		service = PBServiceField.new()
		service.field = __RemainingUses
		data[__RemainingUses.tag] = service
		
	var data = {}
	
	var __x: PBField
	func has_x() -> bool:
		if __x.value != null:
			return true
		return false
	func get_x() -> int:
		return __x.value
	func clear_x() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		__x.value = DEFAULT_VALUES_2[PB_DATA_TYPE.INT32]
	func set_x(value: int) -> void:
		__x.value = value
	
	var __y: PBField
	func has_y() -> bool:
		if __y.value != null:
			return true
		return false
	func get_y() -> int:
		return __y.value
	func clear_y() -> void:
		data[2].state = PB_SERVICE_STATE.UNFILLED
		__y.value = DEFAULT_VALUES_2[PB_DATA_TYPE.INT32]
	func set_y(value: int) -> void:
		__y.value = value
	
	var __z: PBField
	func has_z() -> bool:
		if __z.value != null:
			return true
		return false
	func get_z() -> int:
		return __z.value
	func clear_z() -> void:
		data[3].state = PB_SERVICE_STATE.UNFILLED
		__z.value = DEFAULT_VALUES_2[PB_DATA_TYPE.INT32]
	func set_z(value: int) -> void:
		__z.value = value
	
	var __yaw: PBField
	func has_yaw() -> bool:
		if __yaw.value != null:
			return true
		return false
	func get_yaw() -> float:
		return __yaw.value
	func clear_yaw() -> void:
		data[4].state = PB_SERVICE_STATE.UNFILLED
		__yaw.value = DEFAULT_VALUES_2[PB_DATA_TYPE.FLOAT]
	func set_yaw(value: float) -> void:
		__yaw.value = value
	
	var __pitch: PBField
	func has_pitch() -> bool:
		if __pitch.value != null:
			return true
		return false
	func get_pitch() -> float:
		return __pitch.value
	func clear_pitch() -> void:
		data[5].state = PB_SERVICE_STATE.UNFILLED
		__pitch.value = DEFAULT_VALUES_2[PB_DATA_TYPE.FLOAT]
	func set_pitch(value: float) -> void:
		__pitch.value = value
	
	var __roll: PBField
	func has_roll() -> bool:
		if __roll.value != null:
			return true
		return false
	func get_roll() -> float:
		return __roll.value
	func clear_roll() -> void:
		data[6].state = PB_SERVICE_STATE.UNFILLED
		__roll.value = DEFAULT_VALUES_2[PB_DATA_TYPE.FLOAT]
	func set_roll(value: float) -> void:
		__roll.value = value
	
	var __RemainingUses: PBField
	func has_RemainingUses() -> bool:
		if __RemainingUses.value != null:
			return true
		return false
	func get_RemainingUses() -> int:
		return __RemainingUses.value
	func clear_RemainingUses() -> void:
		data[7].state = PB_SERVICE_STATE.UNFILLED
		__RemainingUses.value = DEFAULT_VALUES_2[PB_DATA_TYPE.INT32]
	func set_RemainingUses(value: int) -> void:
		__RemainingUses.value = value
	
	func _to_string() -> String:
		return PBPacker.message_to_string(data)
		
	func to_bytes() -> PackedByteArray:
		return PBPacker.pack_message(data)
		
	func from_bytes(bytes: PackedByteArray, offset: int = 0, limit: int = -1) -> int:
		var cur_limit = bytes.size()
		if limit != -1:
			cur_limit = limit
		var result = PBPacker.unpack_message(data, bytes, offset, cur_limit)
		if result == cur_limit:
			if PBPacker.check_required(data):
				if limit == -1:
					return PB_ERR.NO_ERRORS
			else:
				return PB_ERR.REQUIRED_FIELDS
		elif limit == -1 && result > 0:
			return PB_ERR.PARSE_INCOMPLETE
		return result
	
class SaveGame:
	func _init():
		var service
		
		__MapSizeX = PBField.new("MapSizeX", PB_DATA_TYPE.INT32, PB_RULE.OPTIONAL, 1, false, DEFAULT_VALUES_2[PB_DATA_TYPE.INT32])
		service = PBServiceField.new()
		service.field = __MapSizeX
		data[__MapSizeX.tag] = service
		
		__MapSizeY = PBField.new("MapSizeY", PB_DATA_TYPE.INT32, PB_RULE.OPTIONAL, 2, false, DEFAULT_VALUES_2[PB_DATA_TYPE.INT32])
		service = PBServiceField.new()
		service.field = __MapSizeY
		data[__MapSizeY.tag] = service
		
		__MapSizeZ = PBField.new("MapSizeZ", PB_DATA_TYPE.INT32, PB_RULE.OPTIONAL, 3, false, DEFAULT_VALUES_2[PB_DATA_TYPE.INT32])
		service = PBServiceField.new()
		service.field = __MapSizeZ
		data[__MapSizeZ.tag] = service
		
		var __PlayerDataByUID_default: Array = []
		__PlayerDataByUID = PBField.new("PlayerDataByUID", PB_DATA_TYPE.MAP, PB_RULE.REPEATED, 4, false, __PlayerDataByUID_default)
		service = PBServiceField.new()
		service.field = __PlayerDataByUID
		service.func_ref = Callable(self, "add_empty_PlayerDataByUID")
		data[__PlayerDataByUID.tag] = service
		
		__Seed = PBField.new("Seed", PB_DATA_TYPE.INT32, PB_RULE.OPTIONAL, 7, false, DEFAULT_VALUES_2[PB_DATA_TYPE.INT32])
		service = PBServiceField.new()
		service.field = __Seed
		data[__Seed.tag] = service
		
		__SimulationCurrentFrame = PBField.new("SimulationCurrentFrame", PB_DATA_TYPE.INT64, PB_RULE.OPTIONAL, 8, false, DEFAULT_VALUES_2[PB_DATA_TYPE.INT64])
		service = PBServiceField.new()
		service.field = __SimulationCurrentFrame
		data[__SimulationCurrentFrame.tag] = service
		
		__LastEntityId = PBField.new("LastEntityId", PB_DATA_TYPE.INT64, PB_RULE.OPTIONAL, 10, false, DEFAULT_VALUES_2[PB_DATA_TYPE.INT64])
		service = PBServiceField.new()
		service.field = __LastEntityId
		data[__LastEntityId.tag] = service
		
		var __ModData_default: Array = []
		__ModData = PBField.new("ModData", PB_DATA_TYPE.MAP, PB_RULE.REPEATED, 11, false, __ModData_default)
		service = PBServiceField.new()
		service.field = __ModData
		service.func_ref = Callable(self, "add_empty_ModData")
		data[__ModData.tag] = service
		
		__TotalGameSeconds = PBField.new("TotalGameSeconds", PB_DATA_TYPE.INT64, PB_RULE.OPTIONAL, 12, false, DEFAULT_VALUES_2[PB_DATA_TYPE.INT64])
		service = PBServiceField.new()
		service.field = __TotalGameSeconds
		data[__TotalGameSeconds.tag] = service
		
		__WorldName = PBField.new("WorldName", PB_DATA_TYPE.STRING, PB_RULE.OPTIONAL, 13, false, DEFAULT_VALUES_2[PB_DATA_TYPE.STRING])
		service = PBServiceField.new()
		service.field = __WorldName
		data[__WorldName.tag] = service
		
		__TotalSecondsPlayed = PBField.new("TotalSecondsPlayed", PB_DATA_TYPE.INT32, PB_RULE.OPTIONAL, 14, false, DEFAULT_VALUES_2[PB_DATA_TYPE.INT32])
		service = PBServiceField.new()
		service.field = __TotalSecondsPlayed
		data[__TotalSecondsPlayed.tag] = service
		
		__WorldPlayStyle = PBField.new("WorldPlayStyle", PB_DATA_TYPE.ENUM, PB_RULE.OPTIONAL, 16, false, DEFAULT_VALUES_2[PB_DATA_TYPE.ENUM])
		service = PBServiceField.new()
		service.field = __WorldPlayStyle
		data[__WorldPlayStyle.tag] = service
		
		__LastPlayed = PBField.new("LastPlayed", PB_DATA_TYPE.STRING, PB_RULE.OPTIONAL, 17, false, DEFAULT_VALUES_2[PB_DATA_TYPE.STRING])
		service = PBServiceField.new()
		service.field = __LastPlayed
		data[__LastPlayed.tag] = service
		
		__CreatedGameVersion = PBField.new("CreatedGameVersion", PB_DATA_TYPE.STRING, PB_RULE.OPTIONAL, 18, false, DEFAULT_VALUES_2[PB_DATA_TYPE.STRING])
		service = PBServiceField.new()
		service.field = __CreatedGameVersion
		data[__CreatedGameVersion.tag] = service
		
		__GameTimeSpeed = PBField.new("GameTimeSpeed", PB_DATA_TYPE.INT32, PB_RULE.OPTIONAL, 19, false, DEFAULT_VALUES_2[PB_DATA_TYPE.INT32])
		service = PBServiceField.new()
		service.field = __GameTimeSpeed
		data[__GameTimeSpeed.tag] = service
		
		__MiniDimensionsCreated = PBField.new("MiniDimensionsCreated", PB_DATA_TYPE.INT32, PB_RULE.OPTIONAL, 20, false, DEFAULT_VALUES_2[PB_DATA_TYPE.INT32])
		service = PBServiceField.new()
		service.field = __MiniDimensionsCreated
		data[__MiniDimensionsCreated.tag] = service
		
		__LastSavedGameVersion = PBField.new("LastSavedGameVersion", PB_DATA_TYPE.STRING, PB_RULE.OPTIONAL, 21, false, DEFAULT_VALUES_2[PB_DATA_TYPE.STRING])
		service = PBServiceField.new()
		service.field = __LastSavedGameVersion
		data[__LastSavedGameVersion.tag] = service
		
		__CreatedByPlayerName = PBField.new("CreatedByPlayerName", PB_DATA_TYPE.STRING, PB_RULE.OPTIONAL, 22, false, DEFAULT_VALUES_2[PB_DATA_TYPE.STRING])
		service = PBServiceField.new()
		service.field = __CreatedByPlayerName
		data[__CreatedByPlayerName.tag] = service
		
		__EntitySpawning = PBField.new("EntitySpawning", PB_DATA_TYPE.BOOL, PB_RULE.OPTIONAL, 23, false, DEFAULT_VALUES_2[PB_DATA_TYPE.BOOL])
		service = PBServiceField.new()
		service.field = __EntitySpawning
		data[__EntitySpawning.tag] = service
		
		__HoursPerDay = PBField.new("HoursPerDay", PB_DATA_TYPE.FLOAT, PB_RULE.OPTIONAL, 25, false, DEFAULT_VALUES_2[PB_DATA_TYPE.FLOAT])
		service = PBServiceField.new()
		service.field = __HoursPerDay
		data[__HoursPerDay.tag] = service
		
		__LastHerdId = PBField.new("LastHerdId", PB_DATA_TYPE.INT64, PB_RULE.OPTIONAL, 26, false, DEFAULT_VALUES_2[PB_DATA_TYPE.INT64])
		service = PBServiceField.new()
		service.field = __LastHerdId
		data[__LastHerdId.tag] = service
		
		var __LandClaims_default: Array[LandClaim] = []
		__LandClaims = PBField.new("LandClaims", PB_DATA_TYPE.MESSAGE, PB_RULE.REPEATED, 27, false, __LandClaims_default)
		service = PBServiceField.new()
		service.field = __LandClaims
		service.func_ref = Callable(self, "add_LandClaims")
		data[__LandClaims.tag] = service
		
		var __TimeSpeedModifiers_default: Array = []
		__TimeSpeedModifiers = PBField.new("TimeSpeedModifiers", PB_DATA_TYPE.MAP, PB_RULE.REPEATED, 28, false, __TimeSpeedModifiers_default)
		service = PBServiceField.new()
		service.field = __TimeSpeedModifiers
		service.func_ref = Callable(self, "add_empty_TimeSpeedModifiers")
		data[__TimeSpeedModifiers.tag] = service
		
		__PlayStyle = PBField.new("PlayStyle", PB_DATA_TYPE.STRING, PB_RULE.OPTIONAL, 29, false, DEFAULT_VALUES_2[PB_DATA_TYPE.STRING])
		service = PBServiceField.new()
		service.field = __PlayStyle
		data[__PlayStyle.tag] = service
		
		__WorldType = PBField.new("WorldType", PB_DATA_TYPE.STRING, PB_RULE.OPTIONAL, 30, false, DEFAULT_VALUES_2[PB_DATA_TYPE.STRING])
		service = PBServiceField.new()
		service.field = __WorldType
		data[__WorldType.tag] = service
		
		__WorldConfigBytes = PBField.new("WorldConfigBytes", PB_DATA_TYPE.BYTES, PB_RULE.OPTIONAL, 31, false, DEFAULT_VALUES_2[PB_DATA_TYPE.BYTES])
		service = PBServiceField.new()
		service.field = __WorldConfigBytes
		data[__WorldConfigBytes.tag] = service
		
		__PlayStyleLangCode = PBField.new("PlayStyleLangCode", PB_DATA_TYPE.STRING, PB_RULE.OPTIONAL, 32, false, DEFAULT_VALUES_2[PB_DATA_TYPE.STRING])
		service = PBServiceField.new()
		service.field = __PlayStyleLangCode
		data[__PlayStyleLangCode.tag] = service
		
		__LastBlockItemMappingVersion = PBField.new("LastBlockItemMappingVersion", PB_DATA_TYPE.INT32, PB_RULE.OPTIONAL, 33, false, DEFAULT_VALUES_2[PB_DATA_TYPE.INT32])
		service = PBServiceField.new()
		service.field = __LastBlockItemMappingVersion
		data[__LastBlockItemMappingVersion.tag] = service
		
		__SavegameIdentifier = PBField.new("SavegameIdentifier", PB_DATA_TYPE.STRING, PB_RULE.OPTIONAL, 34, false, DEFAULT_VALUES_2[PB_DATA_TYPE.STRING])
		service = PBServiceField.new()
		service.field = __SavegameIdentifier
		data[__SavegameIdentifier.tag] = service
		
		__CalendarSpeedMul = PBField.new("CalendarSpeedMul", PB_DATA_TYPE.FLOAT, PB_RULE.OPTIONAL, 35, false, DEFAULT_VALUES_2[PB_DATA_TYPE.FLOAT])
		service = PBServiceField.new()
		service.field = __CalendarSpeedMul
		data[__CalendarSpeedMul.tag] = service
		
		var __RemappingsAppliedByCode_default: Array = []
		__RemappingsAppliedByCode = PBField.new("RemappingsAppliedByCode", PB_DATA_TYPE.MAP, PB_RULE.REPEATED, 36, false, __RemappingsAppliedByCode_default)
		service = PBServiceField.new()
		service.field = __RemappingsAppliedByCode
		service.func_ref = Callable(self, "add_empty_RemappingsAppliedByCode")
		data[__RemappingsAppliedByCode.tag] = service
		
		__HighestChunkdataVersion = PBField.new("HighestChunkdataVersion", PB_DATA_TYPE.INT32, PB_RULE.OPTIONAL, 37, false, DEFAULT_VALUES_2[PB_DATA_TYPE.INT32])
		service = PBServiceField.new()
		service.field = __HighestChunkdataVersion
		data[__HighestChunkdataVersion.tag] = service
		
		__TotalGameSecondsStart = PBField.new("TotalGameSecondsStart", PB_DATA_TYPE.INT64, PB_RULE.OPTIONAL, 38, false, DEFAULT_VALUES_2[PB_DATA_TYPE.INT64])
		service = PBServiceField.new()
		service.field = __TotalGameSecondsStart
		data[__TotalGameSecondsStart.tag] = service
		
		__CreatedWorldGenVersion = PBField.new("CreatedWorldGenVersion", PB_DATA_TYPE.INT32, PB_RULE.OPTIONAL, 39, false, DEFAULT_VALUES_2[PB_DATA_TYPE.INT32])
		service = PBServiceField.new()
		service.field = __CreatedWorldGenVersion
		data[__CreatedWorldGenVersion.tag] = service
		
		__DefaultSpawn = PBField.new("DefaultSpawn", PB_DATA_TYPE.MESSAGE, PB_RULE.OPTIONAL, 40, false, DEFAULT_VALUES_2[PB_DATA_TYPE.MESSAGE])
		service = PBServiceField.new()
		service.field = __DefaultSpawn
		service.func_ref = Callable(self, "new_DefaultSpawn")
		data[__DefaultSpawn.tag] = service
		
	var data = {}
	
	var __MapSizeX: PBField
	func has_MapSizeX() -> bool:
		if __MapSizeX.value != null:
			return true
		return false
	func get_MapSizeX() -> int:
		return __MapSizeX.value
	func clear_MapSizeX() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		__MapSizeX.value = DEFAULT_VALUES_2[PB_DATA_TYPE.INT32]
	func set_MapSizeX(value: int) -> void:
		__MapSizeX.value = value
	
	var __MapSizeY: PBField
	func has_MapSizeY() -> bool:
		if __MapSizeY.value != null:
			return true
		return false
	func get_MapSizeY() -> int:
		return __MapSizeY.value
	func clear_MapSizeY() -> void:
		data[2].state = PB_SERVICE_STATE.UNFILLED
		__MapSizeY.value = DEFAULT_VALUES_2[PB_DATA_TYPE.INT32]
	func set_MapSizeY(value: int) -> void:
		__MapSizeY.value = value
	
	var __MapSizeZ: PBField
	func has_MapSizeZ() -> bool:
		if __MapSizeZ.value != null:
			return true
		return false
	func get_MapSizeZ() -> int:
		return __MapSizeZ.value
	func clear_MapSizeZ() -> void:
		data[3].state = PB_SERVICE_STATE.UNFILLED
		__MapSizeZ.value = DEFAULT_VALUES_2[PB_DATA_TYPE.INT32]
	func set_MapSizeZ(value: int) -> void:
		__MapSizeZ.value = value
	
	var __PlayerDataByUID: PBField
	func get_raw_PlayerDataByUID():
		return __PlayerDataByUID.value
	func get_PlayerDataByUID():
		return PBPacker.construct_map(__PlayerDataByUID.value)
	func clear_PlayerDataByUID():
		data[4].state = PB_SERVICE_STATE.UNFILLED
		__PlayerDataByUID.value = DEFAULT_VALUES_2[PB_DATA_TYPE.MAP]
	func add_empty_PlayerDataByUID() -> SaveGame.map_type_PlayerDataByUID:
		var element = SaveGame.map_type_PlayerDataByUID.new()
		__PlayerDataByUID.value.append(element)
		return element
	func add_PlayerDataByUID(a_key) -> ServerWorldPlayerData:
		var idx = -1
		for i in range(__PlayerDataByUID.value.size()):
			if __PlayerDataByUID.value[i].get_key() == a_key:
				idx = i
				break
		var element = SaveGame.map_type_PlayerDataByUID.new()
		element.set_key(a_key)
		if idx != -1:
			__PlayerDataByUID.value[idx] = element
		else:
			__PlayerDataByUID.value.append(element)
		return element.new_value()
	
	var __Seed: PBField
	func has_Seed() -> bool:
		if __Seed.value != null:
			return true
		return false
	func get_Seed() -> int:
		return __Seed.value
	func clear_Seed() -> void:
		data[7].state = PB_SERVICE_STATE.UNFILLED
		__Seed.value = DEFAULT_VALUES_2[PB_DATA_TYPE.INT32]
	func set_Seed(value: int) -> void:
		__Seed.value = value
	
	var __SimulationCurrentFrame: PBField
	func has_SimulationCurrentFrame() -> bool:
		if __SimulationCurrentFrame.value != null:
			return true
		return false
	func get_SimulationCurrentFrame() -> int:
		return __SimulationCurrentFrame.value
	func clear_SimulationCurrentFrame() -> void:
		data[8].state = PB_SERVICE_STATE.UNFILLED
		__SimulationCurrentFrame.value = DEFAULT_VALUES_2[PB_DATA_TYPE.INT64]
	func set_SimulationCurrentFrame(value: int) -> void:
		__SimulationCurrentFrame.value = value
	
	var __LastEntityId: PBField
	func has_LastEntityId() -> bool:
		if __LastEntityId.value != null:
			return true
		return false
	func get_LastEntityId() -> int:
		return __LastEntityId.value
	func clear_LastEntityId() -> void:
		data[10].state = PB_SERVICE_STATE.UNFILLED
		__LastEntityId.value = DEFAULT_VALUES_2[PB_DATA_TYPE.INT64]
	func set_LastEntityId(value: int) -> void:
		__LastEntityId.value = value
	
	var __ModData: PBField
	func get_raw_ModData():
		return __ModData.value
	func get_ModData():
		return PBPacker.construct_map(__ModData.value)
	func clear_ModData():
		data[11].state = PB_SERVICE_STATE.UNFILLED
		__ModData.value = DEFAULT_VALUES_2[PB_DATA_TYPE.MAP]
	func add_empty_ModData() -> SaveGame.map_type_ModData:
		var element = SaveGame.map_type_ModData.new()
		__ModData.value.append(element)
		return element
	func add_ModData(a_key, a_value) -> void:
		var idx = -1
		for i in range(__ModData.value.size()):
			if __ModData.value[i].get_key() == a_key:
				idx = i
				break
		var element = SaveGame.map_type_ModData.new()
		element.set_key(a_key)
		element.set_value(a_value)
		if idx != -1:
			__ModData.value[idx] = element
		else:
			__ModData.value.append(element)
	
	var __TotalGameSeconds: PBField
	func has_TotalGameSeconds() -> bool:
		if __TotalGameSeconds.value != null:
			return true
		return false
	func get_TotalGameSeconds() -> int:
		return __TotalGameSeconds.value
	func clear_TotalGameSeconds() -> void:
		data[12].state = PB_SERVICE_STATE.UNFILLED
		__TotalGameSeconds.value = DEFAULT_VALUES_2[PB_DATA_TYPE.INT64]
	func set_TotalGameSeconds(value: int) -> void:
		__TotalGameSeconds.value = value
	
	var __WorldName: PBField
	func has_WorldName() -> bool:
		if __WorldName.value != null:
			return true
		return false
	func get_WorldName() -> String:
		return __WorldName.value
	func clear_WorldName() -> void:
		data[13].state = PB_SERVICE_STATE.UNFILLED
		__WorldName.value = DEFAULT_VALUES_2[PB_DATA_TYPE.STRING]
	func set_WorldName(value: String) -> void:
		__WorldName.value = value
	
	var __TotalSecondsPlayed: PBField
	func has_TotalSecondsPlayed() -> bool:
		if __TotalSecondsPlayed.value != null:
			return true
		return false
	func get_TotalSecondsPlayed() -> int:
		return __TotalSecondsPlayed.value
	func clear_TotalSecondsPlayed() -> void:
		data[14].state = PB_SERVICE_STATE.UNFILLED
		__TotalSecondsPlayed.value = DEFAULT_VALUES_2[PB_DATA_TYPE.INT32]
	func set_TotalSecondsPlayed(value: int) -> void:
		__TotalSecondsPlayed.value = value
	
	var __WorldPlayStyle: PBField
	func has_WorldPlayStyle() -> bool:
		if __WorldPlayStyle.value != null:
			return true
		return false
	func get_WorldPlayStyle():
		return __WorldPlayStyle.value
	func clear_WorldPlayStyle() -> void:
		data[16].state = PB_SERVICE_STATE.UNFILLED
		__WorldPlayStyle.value = DEFAULT_VALUES_2[PB_DATA_TYPE.ENUM]
	func set_WorldPlayStyle(value) -> void:
		__WorldPlayStyle.value = value
	
	var __LastPlayed: PBField
	func has_LastPlayed() -> bool:
		if __LastPlayed.value != null:
			return true
		return false
	func get_LastPlayed() -> String:
		return __LastPlayed.value
	func clear_LastPlayed() -> void:
		data[17].state = PB_SERVICE_STATE.UNFILLED
		__LastPlayed.value = DEFAULT_VALUES_2[PB_DATA_TYPE.STRING]
	func set_LastPlayed(value: String) -> void:
		__LastPlayed.value = value
	
	var __CreatedGameVersion: PBField
	func has_CreatedGameVersion() -> bool:
		if __CreatedGameVersion.value != null:
			return true
		return false
	func get_CreatedGameVersion() -> String:
		return __CreatedGameVersion.value
	func clear_CreatedGameVersion() -> void:
		data[18].state = PB_SERVICE_STATE.UNFILLED
		__CreatedGameVersion.value = DEFAULT_VALUES_2[PB_DATA_TYPE.STRING]
	func set_CreatedGameVersion(value: String) -> void:
		__CreatedGameVersion.value = value
	
	var __GameTimeSpeed: PBField
	func has_GameTimeSpeed() -> bool:
		if __GameTimeSpeed.value != null:
			return true
		return false
	func get_GameTimeSpeed() -> int:
		return __GameTimeSpeed.value
	func clear_GameTimeSpeed() -> void:
		data[19].state = PB_SERVICE_STATE.UNFILLED
		__GameTimeSpeed.value = DEFAULT_VALUES_2[PB_DATA_TYPE.INT32]
	func set_GameTimeSpeed(value: int) -> void:
		__GameTimeSpeed.value = value
	
	var __MiniDimensionsCreated: PBField
	func has_MiniDimensionsCreated() -> bool:
		if __MiniDimensionsCreated.value != null:
			return true
		return false
	func get_MiniDimensionsCreated() -> int:
		return __MiniDimensionsCreated.value
	func clear_MiniDimensionsCreated() -> void:
		data[20].state = PB_SERVICE_STATE.UNFILLED
		__MiniDimensionsCreated.value = DEFAULT_VALUES_2[PB_DATA_TYPE.INT32]
	func set_MiniDimensionsCreated(value: int) -> void:
		__MiniDimensionsCreated.value = value
	
	var __LastSavedGameVersion: PBField
	func has_LastSavedGameVersion() -> bool:
		if __LastSavedGameVersion.value != null:
			return true
		return false
	func get_LastSavedGameVersion() -> String:
		return __LastSavedGameVersion.value
	func clear_LastSavedGameVersion() -> void:
		data[21].state = PB_SERVICE_STATE.UNFILLED
		__LastSavedGameVersion.value = DEFAULT_VALUES_2[PB_DATA_TYPE.STRING]
	func set_LastSavedGameVersion(value: String) -> void:
		__LastSavedGameVersion.value = value
	
	var __CreatedByPlayerName: PBField
	func has_CreatedByPlayerName() -> bool:
		if __CreatedByPlayerName.value != null:
			return true
		return false
	func get_CreatedByPlayerName() -> String:
		return __CreatedByPlayerName.value
	func clear_CreatedByPlayerName() -> void:
		data[22].state = PB_SERVICE_STATE.UNFILLED
		__CreatedByPlayerName.value = DEFAULT_VALUES_2[PB_DATA_TYPE.STRING]
	func set_CreatedByPlayerName(value: String) -> void:
		__CreatedByPlayerName.value = value
	
	var __EntitySpawning: PBField
	func has_EntitySpawning() -> bool:
		if __EntitySpawning.value != null:
			return true
		return false
	func get_EntitySpawning() -> bool:
		return __EntitySpawning.value
	func clear_EntitySpawning() -> void:
		data[23].state = PB_SERVICE_STATE.UNFILLED
		__EntitySpawning.value = DEFAULT_VALUES_2[PB_DATA_TYPE.BOOL]
	func set_EntitySpawning(value: bool) -> void:
		__EntitySpawning.value = value
	
	var __HoursPerDay: PBField
	func has_HoursPerDay() -> bool:
		if __HoursPerDay.value != null:
			return true
		return false
	func get_HoursPerDay() -> float:
		return __HoursPerDay.value
	func clear_HoursPerDay() -> void:
		data[25].state = PB_SERVICE_STATE.UNFILLED
		__HoursPerDay.value = DEFAULT_VALUES_2[PB_DATA_TYPE.FLOAT]
	func set_HoursPerDay(value: float) -> void:
		__HoursPerDay.value = value
	
	var __LastHerdId: PBField
	func has_LastHerdId() -> bool:
		if __LastHerdId.value != null:
			return true
		return false
	func get_LastHerdId() -> int:
		return __LastHerdId.value
	func clear_LastHerdId() -> void:
		data[26].state = PB_SERVICE_STATE.UNFILLED
		__LastHerdId.value = DEFAULT_VALUES_2[PB_DATA_TYPE.INT64]
	func set_LastHerdId(value: int) -> void:
		__LastHerdId.value = value
	
	var __LandClaims: PBField
	func get_LandClaims() -> Array[LandClaim]:
		return __LandClaims.value
	func clear_LandClaims() -> void:
		data[27].state = PB_SERVICE_STATE.UNFILLED
		__LandClaims.value.clear()
	func add_LandClaims() -> LandClaim:
		var element = LandClaim.new()
		__LandClaims.value.append(element)
		return element
	
	var __TimeSpeedModifiers: PBField
	func get_raw_TimeSpeedModifiers():
		return __TimeSpeedModifiers.value
	func get_TimeSpeedModifiers():
		return PBPacker.construct_map(__TimeSpeedModifiers.value)
	func clear_TimeSpeedModifiers():
		data[28].state = PB_SERVICE_STATE.UNFILLED
		__TimeSpeedModifiers.value = DEFAULT_VALUES_2[PB_DATA_TYPE.MAP]
	func add_empty_TimeSpeedModifiers() -> SaveGame.map_type_TimeSpeedModifiers:
		var element = SaveGame.map_type_TimeSpeedModifiers.new()
		__TimeSpeedModifiers.value.append(element)
		return element
	func add_TimeSpeedModifiers(a_key, a_value) -> void:
		var idx = -1
		for i in range(__TimeSpeedModifiers.value.size()):
			if __TimeSpeedModifiers.value[i].get_key() == a_key:
				idx = i
				break
		var element = SaveGame.map_type_TimeSpeedModifiers.new()
		element.set_key(a_key)
		element.set_value(a_value)
		if idx != -1:
			__TimeSpeedModifiers.value[idx] = element
		else:
			__TimeSpeedModifiers.value.append(element)
	
	var __PlayStyle: PBField
	func has_PlayStyle() -> bool:
		if __PlayStyle.value != null:
			return true
		return false
	func get_PlayStyle() -> String:
		return __PlayStyle.value
	func clear_PlayStyle() -> void:
		data[29].state = PB_SERVICE_STATE.UNFILLED
		__PlayStyle.value = DEFAULT_VALUES_2[PB_DATA_TYPE.STRING]
	func set_PlayStyle(value: String) -> void:
		__PlayStyle.value = value
	
	var __WorldType: PBField
	func has_WorldType() -> bool:
		if __WorldType.value != null:
			return true
		return false
	func get_WorldType() -> String:
		return __WorldType.value
	func clear_WorldType() -> void:
		data[30].state = PB_SERVICE_STATE.UNFILLED
		__WorldType.value = DEFAULT_VALUES_2[PB_DATA_TYPE.STRING]
	func set_WorldType(value: String) -> void:
		__WorldType.value = value
	
	var __WorldConfigBytes: PBField
	func has_WorldConfigBytes() -> bool:
		if __WorldConfigBytes.value != null:
			return true
		return false
	func get_WorldConfigBytes() -> PackedByteArray:
		return __WorldConfigBytes.value
	func clear_WorldConfigBytes() -> void:
		data[31].state = PB_SERVICE_STATE.UNFILLED
		__WorldConfigBytes.value = DEFAULT_VALUES_2[PB_DATA_TYPE.BYTES]
	func set_WorldConfigBytes(value: PackedByteArray) -> void:
		__WorldConfigBytes.value = value
	
	var __PlayStyleLangCode: PBField
	func has_PlayStyleLangCode() -> bool:
		if __PlayStyleLangCode.value != null:
			return true
		return false
	func get_PlayStyleLangCode() -> String:
		return __PlayStyleLangCode.value
	func clear_PlayStyleLangCode() -> void:
		data[32].state = PB_SERVICE_STATE.UNFILLED
		__PlayStyleLangCode.value = DEFAULT_VALUES_2[PB_DATA_TYPE.STRING]
	func set_PlayStyleLangCode(value: String) -> void:
		__PlayStyleLangCode.value = value
	
	var __LastBlockItemMappingVersion: PBField
	func has_LastBlockItemMappingVersion() -> bool:
		if __LastBlockItemMappingVersion.value != null:
			return true
		return false
	func get_LastBlockItemMappingVersion() -> int:
		return __LastBlockItemMappingVersion.value
	func clear_LastBlockItemMappingVersion() -> void:
		data[33].state = PB_SERVICE_STATE.UNFILLED
		__LastBlockItemMappingVersion.value = DEFAULT_VALUES_2[PB_DATA_TYPE.INT32]
	func set_LastBlockItemMappingVersion(value: int) -> void:
		__LastBlockItemMappingVersion.value = value
	
	var __SavegameIdentifier: PBField
	func has_SavegameIdentifier() -> bool:
		if __SavegameIdentifier.value != null:
			return true
		return false
	func get_SavegameIdentifier() -> String:
		return __SavegameIdentifier.value
	func clear_SavegameIdentifier() -> void:
		data[34].state = PB_SERVICE_STATE.UNFILLED
		__SavegameIdentifier.value = DEFAULT_VALUES_2[PB_DATA_TYPE.STRING]
	func set_SavegameIdentifier(value: String) -> void:
		__SavegameIdentifier.value = value
	
	var __CalendarSpeedMul: PBField
	func has_CalendarSpeedMul() -> bool:
		if __CalendarSpeedMul.value != null:
			return true
		return false
	func get_CalendarSpeedMul() -> float:
		return __CalendarSpeedMul.value
	func clear_CalendarSpeedMul() -> void:
		data[35].state = PB_SERVICE_STATE.UNFILLED
		__CalendarSpeedMul.value = DEFAULT_VALUES_2[PB_DATA_TYPE.FLOAT]
	func set_CalendarSpeedMul(value: float) -> void:
		__CalendarSpeedMul.value = value
	
	var __RemappingsAppliedByCode: PBField
	func get_raw_RemappingsAppliedByCode():
		return __RemappingsAppliedByCode.value
	func get_RemappingsAppliedByCode():
		return PBPacker.construct_map(__RemappingsAppliedByCode.value)
	func clear_RemappingsAppliedByCode():
		data[36].state = PB_SERVICE_STATE.UNFILLED
		__RemappingsAppliedByCode.value = DEFAULT_VALUES_2[PB_DATA_TYPE.MAP]
	func add_empty_RemappingsAppliedByCode() -> SaveGame.map_type_RemappingsAppliedByCode:
		var element = SaveGame.map_type_RemappingsAppliedByCode.new()
		__RemappingsAppliedByCode.value.append(element)
		return element
	func add_RemappingsAppliedByCode(a_key, a_value) -> void:
		var idx = -1
		for i in range(__RemappingsAppliedByCode.value.size()):
			if __RemappingsAppliedByCode.value[i].get_key() == a_key:
				idx = i
				break
		var element = SaveGame.map_type_RemappingsAppliedByCode.new()
		element.set_key(a_key)
		element.set_value(a_value)
		if idx != -1:
			__RemappingsAppliedByCode.value[idx] = element
		else:
			__RemappingsAppliedByCode.value.append(element)
	
	var __HighestChunkdataVersion: PBField
	func has_HighestChunkdataVersion() -> bool:
		if __HighestChunkdataVersion.value != null:
			return true
		return false
	func get_HighestChunkdataVersion() -> int:
		return __HighestChunkdataVersion.value
	func clear_HighestChunkdataVersion() -> void:
		data[37].state = PB_SERVICE_STATE.UNFILLED
		__HighestChunkdataVersion.value = DEFAULT_VALUES_2[PB_DATA_TYPE.INT32]
	func set_HighestChunkdataVersion(value: int) -> void:
		__HighestChunkdataVersion.value = value
	
	var __TotalGameSecondsStart: PBField
	func has_TotalGameSecondsStart() -> bool:
		if __TotalGameSecondsStart.value != null:
			return true
		return false
	func get_TotalGameSecondsStart() -> int:
		return __TotalGameSecondsStart.value
	func clear_TotalGameSecondsStart() -> void:
		data[38].state = PB_SERVICE_STATE.UNFILLED
		__TotalGameSecondsStart.value = DEFAULT_VALUES_2[PB_DATA_TYPE.INT64]
	func set_TotalGameSecondsStart(value: int) -> void:
		__TotalGameSecondsStart.value = value
	
	var __CreatedWorldGenVersion: PBField
	func has_CreatedWorldGenVersion() -> bool:
		if __CreatedWorldGenVersion.value != null:
			return true
		return false
	func get_CreatedWorldGenVersion() -> int:
		return __CreatedWorldGenVersion.value
	func clear_CreatedWorldGenVersion() -> void:
		data[39].state = PB_SERVICE_STATE.UNFILLED
		__CreatedWorldGenVersion.value = DEFAULT_VALUES_2[PB_DATA_TYPE.INT32]
	func set_CreatedWorldGenVersion(value: int) -> void:
		__CreatedWorldGenVersion.value = value
	
	var __DefaultSpawn: PBField
	func has_DefaultSpawn() -> bool:
		if __DefaultSpawn.value != null:
			return true
		return false
	func get_DefaultSpawn() -> PlayerSpawnPos:
		return __DefaultSpawn.value
	func clear_DefaultSpawn() -> void:
		data[40].state = PB_SERVICE_STATE.UNFILLED
		__DefaultSpawn.value = DEFAULT_VALUES_2[PB_DATA_TYPE.MESSAGE]
	func new_DefaultSpawn() -> PlayerSpawnPos:
		__DefaultSpawn.value = PlayerSpawnPos.new()
		return __DefaultSpawn.value
	
	class map_type_PlayerDataByUID:
		func _init():
			var service
			
			__key = PBField.new("key", PB_DATA_TYPE.STRING, PB_RULE.OPTIONAL, 1, false, DEFAULT_VALUES_2[PB_DATA_TYPE.STRING])
			__key.is_map_field = true
			service = PBServiceField.new()
			service.field = __key
			data[__key.tag] = service
			
			__value = PBField.new("value", PB_DATA_TYPE.MESSAGE, PB_RULE.OPTIONAL, 2, false, DEFAULT_VALUES_2[PB_DATA_TYPE.MESSAGE])
			__value.is_map_field = true
			service = PBServiceField.new()
			service.field = __value
			service.func_ref = Callable(self, "new_value")
			data[__value.tag] = service
			
		var data = {}
		
		var __key: PBField
		func has_key() -> bool:
			if __key.value != null:
				return true
			return false
		func get_key() -> String:
			return __key.value
		func clear_key() -> void:
			data[1].state = PB_SERVICE_STATE.UNFILLED
			__key.value = DEFAULT_VALUES_2[PB_DATA_TYPE.STRING]
		func set_key(value: String) -> void:
			__key.value = value
		
		var __value: PBField
		func has_value() -> bool:
			if __value.value != null:
				return true
			return false
		func get_value() -> ServerWorldPlayerData:
			return __value.value
		func clear_value() -> void:
			data[2].state = PB_SERVICE_STATE.UNFILLED
			__value.value = DEFAULT_VALUES_2[PB_DATA_TYPE.MESSAGE]
		func new_value() -> ServerWorldPlayerData:
			__value.value = ServerWorldPlayerData.new()
			return __value.value
		
		func _to_string() -> String:
			return PBPacker.message_to_string(data)
			
		func to_bytes() -> PackedByteArray:
			return PBPacker.pack_message(data)
			
		func from_bytes(bytes: PackedByteArray, offset: int = 0, limit: int = -1) -> int:
			var cur_limit = bytes.size()
			if limit != -1:
				cur_limit = limit
			var result = PBPacker.unpack_message(data, bytes, offset, cur_limit)
			if result == cur_limit:
				if PBPacker.check_required(data):
					if limit == -1:
						return PB_ERR.NO_ERRORS
				else:
					return PB_ERR.REQUIRED_FIELDS
			elif limit == -1 && result > 0:
				return PB_ERR.PARSE_INCOMPLETE
			return result
		
	class map_type_ModData:
		func _init():
			var service
			
			__key = PBField.new("key", PB_DATA_TYPE.STRING, PB_RULE.OPTIONAL, 1, false, DEFAULT_VALUES_2[PB_DATA_TYPE.STRING])
			__key.is_map_field = true
			service = PBServiceField.new()
			service.field = __key
			data[__key.tag] = service
			
			__value = PBField.new("value", PB_DATA_TYPE.BYTES, PB_RULE.OPTIONAL, 2, false, DEFAULT_VALUES_2[PB_DATA_TYPE.BYTES])
			__value.is_map_field = true
			service = PBServiceField.new()
			service.field = __value
			data[__value.tag] = service
			
		var data = {}
		
		var __key: PBField
		func has_key() -> bool:
			if __key.value != null:
				return true
			return false
		func get_key() -> String:
			return __key.value
		func clear_key() -> void:
			data[1].state = PB_SERVICE_STATE.UNFILLED
			__key.value = DEFAULT_VALUES_2[PB_DATA_TYPE.STRING]
		func set_key(value: String) -> void:
			__key.value = value
		
		var __value: PBField
		func has_value() -> bool:
			if __value.value != null:
				return true
			return false
		func get_value() -> PackedByteArray:
			return __value.value
		func clear_value() -> void:
			data[2].state = PB_SERVICE_STATE.UNFILLED
			__value.value = DEFAULT_VALUES_2[PB_DATA_TYPE.BYTES]
		func set_value(value: PackedByteArray) -> void:
			__value.value = value
		
		func _to_string() -> String:
			return PBPacker.message_to_string(data)
			
		func to_bytes() -> PackedByteArray:
			return PBPacker.pack_message(data)
			
		func from_bytes(bytes: PackedByteArray, offset: int = 0, limit: int = -1) -> int:
			var cur_limit = bytes.size()
			if limit != -1:
				cur_limit = limit
			var result = PBPacker.unpack_message(data, bytes, offset, cur_limit)
			if result == cur_limit:
				if PBPacker.check_required(data):
					if limit == -1:
						return PB_ERR.NO_ERRORS
				else:
					return PB_ERR.REQUIRED_FIELDS
			elif limit == -1 && result > 0:
				return PB_ERR.PARSE_INCOMPLETE
			return result
		
	class map_type_TimeSpeedModifiers:
		func _init():
			var service
			
			__key = PBField.new("key", PB_DATA_TYPE.STRING, PB_RULE.OPTIONAL, 1, false, DEFAULT_VALUES_2[PB_DATA_TYPE.STRING])
			__key.is_map_field = true
			service = PBServiceField.new()
			service.field = __key
			data[__key.tag] = service
			
			__value = PBField.new("value", PB_DATA_TYPE.FLOAT, PB_RULE.OPTIONAL, 2, false, DEFAULT_VALUES_2[PB_DATA_TYPE.FLOAT])
			__value.is_map_field = true
			service = PBServiceField.new()
			service.field = __value
			data[__value.tag] = service
			
		var data = {}
		
		var __key: PBField
		func has_key() -> bool:
			if __key.value != null:
				return true
			return false
		func get_key() -> String:
			return __key.value
		func clear_key() -> void:
			data[1].state = PB_SERVICE_STATE.UNFILLED
			__key.value = DEFAULT_VALUES_2[PB_DATA_TYPE.STRING]
		func set_key(value: String) -> void:
			__key.value = value
		
		var __value: PBField
		func has_value() -> bool:
			if __value.value != null:
				return true
			return false
		func get_value() -> float:
			return __value.value
		func clear_value() -> void:
			data[2].state = PB_SERVICE_STATE.UNFILLED
			__value.value = DEFAULT_VALUES_2[PB_DATA_TYPE.FLOAT]
		func set_value(value: float) -> void:
			__value.value = value
		
		func _to_string() -> String:
			return PBPacker.message_to_string(data)
			
		func to_bytes() -> PackedByteArray:
			return PBPacker.pack_message(data)
			
		func from_bytes(bytes: PackedByteArray, offset: int = 0, limit: int = -1) -> int:
			var cur_limit = bytes.size()
			if limit != -1:
				cur_limit = limit
			var result = PBPacker.unpack_message(data, bytes, offset, cur_limit)
			if result == cur_limit:
				if PBPacker.check_required(data):
					if limit == -1:
						return PB_ERR.NO_ERRORS
				else:
					return PB_ERR.REQUIRED_FIELDS
			elif limit == -1 && result > 0:
				return PB_ERR.PARSE_INCOMPLETE
			return result
		
	class map_type_RemappingsAppliedByCode:
		func _init():
			var service
			
			__key = PBField.new("key", PB_DATA_TYPE.STRING, PB_RULE.OPTIONAL, 1, false, DEFAULT_VALUES_2[PB_DATA_TYPE.STRING])
			__key.is_map_field = true
			service = PBServiceField.new()
			service.field = __key
			data[__key.tag] = service
			
			__value = PBField.new("value", PB_DATA_TYPE.BOOL, PB_RULE.OPTIONAL, 2, false, DEFAULT_VALUES_2[PB_DATA_TYPE.BOOL])
			__value.is_map_field = true
			service = PBServiceField.new()
			service.field = __value
			data[__value.tag] = service
			
		var data = {}
		
		var __key: PBField
		func has_key() -> bool:
			if __key.value != null:
				return true
			return false
		func get_key() -> String:
			return __key.value
		func clear_key() -> void:
			data[1].state = PB_SERVICE_STATE.UNFILLED
			__key.value = DEFAULT_VALUES_2[PB_DATA_TYPE.STRING]
		func set_key(value: String) -> void:
			__key.value = value
		
		var __value: PBField
		func has_value() -> bool:
			if __value.value != null:
				return true
			return false
		func get_value() -> bool:
			return __value.value
		func clear_value() -> void:
			data[2].state = PB_SERVICE_STATE.UNFILLED
			__value.value = DEFAULT_VALUES_2[PB_DATA_TYPE.BOOL]
		func set_value(value: bool) -> void:
			__value.value = value
		
		func _to_string() -> String:
			return PBPacker.message_to_string(data)
			
		func to_bytes() -> PackedByteArray:
			return PBPacker.pack_message(data)
			
		func from_bytes(bytes: PackedByteArray, offset: int = 0, limit: int = -1) -> int:
			var cur_limit = bytes.size()
			if limit != -1:
				cur_limit = limit
			var result = PBPacker.unpack_message(data, bytes, offset, cur_limit)
			if result == cur_limit:
				if PBPacker.check_required(data):
					if limit == -1:
						return PB_ERR.NO_ERRORS
				else:
					return PB_ERR.REQUIRED_FIELDS
			elif limit == -1 && result > 0:
				return PB_ERR.PARSE_INCOMPLETE
			return result
		
	func _to_string() -> String:
		return PBPacker.message_to_string(data)
		
	func to_bytes() -> PackedByteArray:
		return PBPacker.pack_message(data)
		
	func from_bytes(bytes: PackedByteArray, offset: int = 0, limit: int = -1) -> int:
		var cur_limit = bytes.size()
		if limit != -1:
			cur_limit = limit
		var result = PBPacker.unpack_message(data, bytes, offset, cur_limit)
		if result == cur_limit:
			if PBPacker.check_required(data):
				if limit == -1:
					return PB_ERR.NO_ERRORS
			else:
				return PB_ERR.REQUIRED_FIELDS
		elif limit == -1 && result > 0:
			return PB_ERR.PARSE_INCOMPLETE
		return result
	
class ServerWorldPlayerData:
	func _init():
		var service
		
		__PlayerUID = PBField.new("PlayerUID", PB_DATA_TYPE.STRING, PB_RULE.OPTIONAL, 1, false, DEFAULT_VALUES_2[PB_DATA_TYPE.STRING])
		service = PBServiceField.new()
		service.field = __PlayerUID
		data[__PlayerUID.tag] = service
		
		var __inventoriesSerialized_default: Array = []
		__inventoriesSerialized = PBField.new("inventoriesSerialized", PB_DATA_TYPE.MAP, PB_RULE.REPEATED, 2, false, __inventoriesSerialized_default)
		service = PBServiceField.new()
		service.field = __inventoriesSerialized
		service.func_ref = Callable(self, "add_empty_inventoriesSerialized")
		data[__inventoriesSerialized.tag] = service
		
		__EntityPlayerSerialized = PBField.new("EntityPlayerSerialized", PB_DATA_TYPE.BYTES, PB_RULE.OPTIONAL, 3, false, DEFAULT_VALUES_2[PB_DATA_TYPE.BYTES])
		service = PBServiceField.new()
		service.field = __EntityPlayerSerialized
		data[__EntityPlayerSerialized.tag] = service
		
		__GameMode = PBField.new("GameMode", PB_DATA_TYPE.ENUM, PB_RULE.OPTIONAL, 4, false, DEFAULT_VALUES_2[PB_DATA_TYPE.ENUM])
		service = PBServiceField.new()
		service.field = __GameMode
		data[__GameMode.tag] = service
		
		__MoveSpeedMultiplier = PBField.new("MoveSpeedMultiplier", PB_DATA_TYPE.FLOAT, PB_RULE.OPTIONAL, 5, false, DEFAULT_VALUES_2[PB_DATA_TYPE.FLOAT])
		service = PBServiceField.new()
		service.field = __MoveSpeedMultiplier
		data[__MoveSpeedMultiplier.tag] = service
		
		__FreeMove = PBField.new("FreeMove", PB_DATA_TYPE.BOOL, PB_RULE.OPTIONAL, 6, false, DEFAULT_VALUES_2[PB_DATA_TYPE.BOOL])
		service = PBServiceField.new()
		service.field = __FreeMove
		data[__FreeMove.tag] = service
		
		__NoClip = PBField.new("NoClip", PB_DATA_TYPE.BOOL, PB_RULE.OPTIONAL, 7, false, DEFAULT_VALUES_2[PB_DATA_TYPE.BOOL])
		service = PBServiceField.new()
		service.field = __NoClip
		data[__NoClip.tag] = service
		
		__Viewdistance = PBField.new("Viewdistance", PB_DATA_TYPE.INT32, PB_RULE.OPTIONAL, 8, false, DEFAULT_VALUES_2[PB_DATA_TYPE.INT32])
		service = PBServiceField.new()
		service.field = __Viewdistance
		data[__Viewdistance.tag] = service
		
		__selectedHotbarslot = PBField.new("selectedHotbarslot", PB_DATA_TYPE.INT32, PB_RULE.OPTIONAL, 9, false, DEFAULT_VALUES_2[PB_DATA_TYPE.INT32])
		service = PBServiceField.new()
		service.field = __selectedHotbarslot
		data[__selectedHotbarslot.tag] = service
		
		__freeMovePlaneLock = PBField.new("freeMovePlaneLock", PB_DATA_TYPE.ENUM, PB_RULE.OPTIONAL, 10, false, DEFAULT_VALUES_2[PB_DATA_TYPE.ENUM])
		service = PBServiceField.new()
		service.field = __freeMovePlaneLock
		data[__freeMovePlaneLock.tag] = service
		
		__PickingRange = PBField.new("PickingRange", PB_DATA_TYPE.FLOAT, PB_RULE.OPTIONAL, 11, false, DEFAULT_VALUES_2[PB_DATA_TYPE.FLOAT])
		service = PBServiceField.new()
		service.field = __PickingRange
		data[__PickingRange.tag] = service
		
		__areaSelectionMode = PBField.new("areaSelectionMode", PB_DATA_TYPE.BOOL, PB_RULE.OPTIONAL, 12, false, DEFAULT_VALUES_2[PB_DATA_TYPE.BOOL])
		service = PBServiceField.new()
		service.field = __areaSelectionMode
		data[__areaSelectionMode.tag] = service
		
		__didSelectSkin = PBField.new("didSelectSkin", PB_DATA_TYPE.BOOL, PB_RULE.OPTIONAL, 13, false, DEFAULT_VALUES_2[PB_DATA_TYPE.BOOL])
		service = PBServiceField.new()
		service.field = __didSelectSkin
		data[__didSelectSkin.tag] = service
		
		__spawnPosition = PBField.new("spawnPosition", PB_DATA_TYPE.MESSAGE, PB_RULE.OPTIONAL, 14, false, DEFAULT_VALUES_2[PB_DATA_TYPE.MESSAGE])
		service = PBServiceField.new()
		service.field = __spawnPosition
		service.func_ref = Callable(self, "new_spawnPosition")
		data[__spawnPosition.tag] = service
		
		var __ModData_default: Array = []
		__ModData = PBField.new("ModData", PB_DATA_TYPE.MAP, PB_RULE.REPEATED, 15, false, __ModData_default)
		service = PBServiceField.new()
		service.field = __ModData
		service.func_ref = Callable(self, "add_empty_ModData")
		data[__ModData.tag] = service
		
		__PreviousPickingRange = PBField.new("PreviousPickingRange", PB_DATA_TYPE.FLOAT, PB_RULE.OPTIONAL, 16, false, DEFAULT_VALUES_2[PB_DATA_TYPE.FLOAT])
		service = PBServiceField.new()
		service.field = __PreviousPickingRange
		data[__PreviousPickingRange.tag] = service
		
		__Deaths = PBField.new("Deaths", PB_DATA_TYPE.INT32, PB_RULE.OPTIONAL, 17, false, DEFAULT_VALUES_2[PB_DATA_TYPE.INT32])
		service = PBServiceField.new()
		service.field = __Deaths
		data[__Deaths.tag] = service
		
		__RenderMetaBlocks = PBField.new("RenderMetaBlocks", PB_DATA_TYPE.BOOL, PB_RULE.OPTIONAL, 18, false, DEFAULT_VALUES_2[PB_DATA_TYPE.BOOL])
		service = PBServiceField.new()
		service.field = __RenderMetaBlocks
		data[__RenderMetaBlocks.tag] = service
		
	var data = {}
	
	var __PlayerUID: PBField
	func has_PlayerUID() -> bool:
		if __PlayerUID.value != null:
			return true
		return false
	func get_PlayerUID() -> String:
		return __PlayerUID.value
	func clear_PlayerUID() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		__PlayerUID.value = DEFAULT_VALUES_2[PB_DATA_TYPE.STRING]
	func set_PlayerUID(value: String) -> void:
		__PlayerUID.value = value
	
	var __inventoriesSerialized: PBField
	func get_raw_inventoriesSerialized():
		return __inventoriesSerialized.value
	func get_inventoriesSerialized():
		return PBPacker.construct_map(__inventoriesSerialized.value)
	func clear_inventoriesSerialized():
		data[2].state = PB_SERVICE_STATE.UNFILLED
		__inventoriesSerialized.value = DEFAULT_VALUES_2[PB_DATA_TYPE.MAP]
	func add_empty_inventoriesSerialized() -> ServerWorldPlayerData.map_type_inventoriesSerialized:
		var element = ServerWorldPlayerData.map_type_inventoriesSerialized.new()
		__inventoriesSerialized.value.append(element)
		return element
	func add_inventoriesSerialized(a_key, a_value) -> void:
		var idx = -1
		for i in range(__inventoriesSerialized.value.size()):
			if __inventoriesSerialized.value[i].get_key() == a_key:
				idx = i
				break
		var element = ServerWorldPlayerData.map_type_inventoriesSerialized.new()
		element.set_key(a_key)
		element.set_value(a_value)
		if idx != -1:
			__inventoriesSerialized.value[idx] = element
		else:
			__inventoriesSerialized.value.append(element)
	
	var __EntityPlayerSerialized: PBField
	func has_EntityPlayerSerialized() -> bool:
		if __EntityPlayerSerialized.value != null:
			return true
		return false
	func get_EntityPlayerSerialized() -> PackedByteArray:
		return __EntityPlayerSerialized.value
	func clear_EntityPlayerSerialized() -> void:
		data[3].state = PB_SERVICE_STATE.UNFILLED
		__EntityPlayerSerialized.value = DEFAULT_VALUES_2[PB_DATA_TYPE.BYTES]
	func set_EntityPlayerSerialized(value: PackedByteArray) -> void:
		__EntityPlayerSerialized.value = value
	
	var __GameMode: PBField
	func has_GameMode() -> bool:
		if __GameMode.value != null:
			return true
		return false
	func get_GameMode():
		return __GameMode.value
	func clear_GameMode() -> void:
		data[4].state = PB_SERVICE_STATE.UNFILLED
		__GameMode.value = DEFAULT_VALUES_2[PB_DATA_TYPE.ENUM]
	func set_GameMode(value) -> void:
		__GameMode.value = value
	
	var __MoveSpeedMultiplier: PBField
	func has_MoveSpeedMultiplier() -> bool:
		if __MoveSpeedMultiplier.value != null:
			return true
		return false
	func get_MoveSpeedMultiplier() -> float:
		return __MoveSpeedMultiplier.value
	func clear_MoveSpeedMultiplier() -> void:
		data[5].state = PB_SERVICE_STATE.UNFILLED
		__MoveSpeedMultiplier.value = DEFAULT_VALUES_2[PB_DATA_TYPE.FLOAT]
	func set_MoveSpeedMultiplier(value: float) -> void:
		__MoveSpeedMultiplier.value = value
	
	var __FreeMove: PBField
	func has_FreeMove() -> bool:
		if __FreeMove.value != null:
			return true
		return false
	func get_FreeMove() -> bool:
		return __FreeMove.value
	func clear_FreeMove() -> void:
		data[6].state = PB_SERVICE_STATE.UNFILLED
		__FreeMove.value = DEFAULT_VALUES_2[PB_DATA_TYPE.BOOL]
	func set_FreeMove(value: bool) -> void:
		__FreeMove.value = value
	
	var __NoClip: PBField
	func has_NoClip() -> bool:
		if __NoClip.value != null:
			return true
		return false
	func get_NoClip() -> bool:
		return __NoClip.value
	func clear_NoClip() -> void:
		data[7].state = PB_SERVICE_STATE.UNFILLED
		__NoClip.value = DEFAULT_VALUES_2[PB_DATA_TYPE.BOOL]
	func set_NoClip(value: bool) -> void:
		__NoClip.value = value
	
	var __Viewdistance: PBField
	func has_Viewdistance() -> bool:
		if __Viewdistance.value != null:
			return true
		return false
	func get_Viewdistance() -> int:
		return __Viewdistance.value
	func clear_Viewdistance() -> void:
		data[8].state = PB_SERVICE_STATE.UNFILLED
		__Viewdistance.value = DEFAULT_VALUES_2[PB_DATA_TYPE.INT32]
	func set_Viewdistance(value: int) -> void:
		__Viewdistance.value = value
	
	var __selectedHotbarslot: PBField
	func has_selectedHotbarslot() -> bool:
		if __selectedHotbarslot.value != null:
			return true
		return false
	func get_selectedHotbarslot() -> int:
		return __selectedHotbarslot.value
	func clear_selectedHotbarslot() -> void:
		data[9].state = PB_SERVICE_STATE.UNFILLED
		__selectedHotbarslot.value = DEFAULT_VALUES_2[PB_DATA_TYPE.INT32]
	func set_selectedHotbarslot(value: int) -> void:
		__selectedHotbarslot.value = value
	
	var __freeMovePlaneLock: PBField
	func has_freeMovePlaneLock() -> bool:
		if __freeMovePlaneLock.value != null:
			return true
		return false
	func get_freeMovePlaneLock():
		return __freeMovePlaneLock.value
	func clear_freeMovePlaneLock() -> void:
		data[10].state = PB_SERVICE_STATE.UNFILLED
		__freeMovePlaneLock.value = DEFAULT_VALUES_2[PB_DATA_TYPE.ENUM]
	func set_freeMovePlaneLock(value) -> void:
		__freeMovePlaneLock.value = value
	
	var __PickingRange: PBField
	func has_PickingRange() -> bool:
		if __PickingRange.value != null:
			return true
		return false
	func get_PickingRange() -> float:
		return __PickingRange.value
	func clear_PickingRange() -> void:
		data[11].state = PB_SERVICE_STATE.UNFILLED
		__PickingRange.value = DEFAULT_VALUES_2[PB_DATA_TYPE.FLOAT]
	func set_PickingRange(value: float) -> void:
		__PickingRange.value = value
	
	var __areaSelectionMode: PBField
	func has_areaSelectionMode() -> bool:
		if __areaSelectionMode.value != null:
			return true
		return false
	func get_areaSelectionMode() -> bool:
		return __areaSelectionMode.value
	func clear_areaSelectionMode() -> void:
		data[12].state = PB_SERVICE_STATE.UNFILLED
		__areaSelectionMode.value = DEFAULT_VALUES_2[PB_DATA_TYPE.BOOL]
	func set_areaSelectionMode(value: bool) -> void:
		__areaSelectionMode.value = value
	
	var __didSelectSkin: PBField
	func has_didSelectSkin() -> bool:
		if __didSelectSkin.value != null:
			return true
		return false
	func get_didSelectSkin() -> bool:
		return __didSelectSkin.value
	func clear_didSelectSkin() -> void:
		data[13].state = PB_SERVICE_STATE.UNFILLED
		__didSelectSkin.value = DEFAULT_VALUES_2[PB_DATA_TYPE.BOOL]
	func set_didSelectSkin(value: bool) -> void:
		__didSelectSkin.value = value
	
	var __spawnPosition: PBField
	func has_spawnPosition() -> bool:
		if __spawnPosition.value != null:
			return true
		return false
	func get_spawnPosition() -> PlayerSpawnPos:
		return __spawnPosition.value
	func clear_spawnPosition() -> void:
		data[14].state = PB_SERVICE_STATE.UNFILLED
		__spawnPosition.value = DEFAULT_VALUES_2[PB_DATA_TYPE.MESSAGE]
	func new_spawnPosition() -> PlayerSpawnPos:
		__spawnPosition.value = PlayerSpawnPos.new()
		return __spawnPosition.value
	
	var __ModData: PBField
	func get_raw_ModData():
		return __ModData.value
	func get_ModData():
		return PBPacker.construct_map(__ModData.value)
	func clear_ModData():
		data[15].state = PB_SERVICE_STATE.UNFILLED
		__ModData.value = DEFAULT_VALUES_2[PB_DATA_TYPE.MAP]
	func add_empty_ModData() -> ServerWorldPlayerData.map_type_ModData:
		var element = ServerWorldPlayerData.map_type_ModData.new()
		__ModData.value.append(element)
		return element
	func add_ModData(a_key, a_value) -> void:
		var idx = -1
		for i in range(__ModData.value.size()):
			if __ModData.value[i].get_key() == a_key:
				idx = i
				break
		var element = ServerWorldPlayerData.map_type_ModData.new()
		element.set_key(a_key)
		element.set_value(a_value)
		if idx != -1:
			__ModData.value[idx] = element
		else:
			__ModData.value.append(element)
	
	var __PreviousPickingRange: PBField
	func has_PreviousPickingRange() -> bool:
		if __PreviousPickingRange.value != null:
			return true
		return false
	func get_PreviousPickingRange() -> float:
		return __PreviousPickingRange.value
	func clear_PreviousPickingRange() -> void:
		data[16].state = PB_SERVICE_STATE.UNFILLED
		__PreviousPickingRange.value = DEFAULT_VALUES_2[PB_DATA_TYPE.FLOAT]
	func set_PreviousPickingRange(value: float) -> void:
		__PreviousPickingRange.value = value
	
	var __Deaths: PBField
	func has_Deaths() -> bool:
		if __Deaths.value != null:
			return true
		return false
	func get_Deaths() -> int:
		return __Deaths.value
	func clear_Deaths() -> void:
		data[17].state = PB_SERVICE_STATE.UNFILLED
		__Deaths.value = DEFAULT_VALUES_2[PB_DATA_TYPE.INT32]
	func set_Deaths(value: int) -> void:
		__Deaths.value = value
	
	var __RenderMetaBlocks: PBField
	func has_RenderMetaBlocks() -> bool:
		if __RenderMetaBlocks.value != null:
			return true
		return false
	func get_RenderMetaBlocks() -> bool:
		return __RenderMetaBlocks.value
	func clear_RenderMetaBlocks() -> void:
		data[18].state = PB_SERVICE_STATE.UNFILLED
		__RenderMetaBlocks.value = DEFAULT_VALUES_2[PB_DATA_TYPE.BOOL]
	func set_RenderMetaBlocks(value: bool) -> void:
		__RenderMetaBlocks.value = value
	
	class map_type_inventoriesSerialized:
		func _init():
			var service
			
			__key = PBField.new("key", PB_DATA_TYPE.STRING, PB_RULE.OPTIONAL, 1, false, DEFAULT_VALUES_2[PB_DATA_TYPE.STRING])
			__key.is_map_field = true
			service = PBServiceField.new()
			service.field = __key
			data[__key.tag] = service
			
			__value = PBField.new("value", PB_DATA_TYPE.BYTES, PB_RULE.OPTIONAL, 2, false, DEFAULT_VALUES_2[PB_DATA_TYPE.BYTES])
			__value.is_map_field = true
			service = PBServiceField.new()
			service.field = __value
			data[__value.tag] = service
			
		var data = {}
		
		var __key: PBField
		func has_key() -> bool:
			if __key.value != null:
				return true
			return false
		func get_key() -> String:
			return __key.value
		func clear_key() -> void:
			data[1].state = PB_SERVICE_STATE.UNFILLED
			__key.value = DEFAULT_VALUES_2[PB_DATA_TYPE.STRING]
		func set_key(value: String) -> void:
			__key.value = value
		
		var __value: PBField
		func has_value() -> bool:
			if __value.value != null:
				return true
			return false
		func get_value() -> PackedByteArray:
			return __value.value
		func clear_value() -> void:
			data[2].state = PB_SERVICE_STATE.UNFILLED
			__value.value = DEFAULT_VALUES_2[PB_DATA_TYPE.BYTES]
		func set_value(value: PackedByteArray) -> void:
			__value.value = value
		
		func _to_string() -> String:
			return PBPacker.message_to_string(data)
			
		func to_bytes() -> PackedByteArray:
			return PBPacker.pack_message(data)
			
		func from_bytes(bytes: PackedByteArray, offset: int = 0, limit: int = -1) -> int:
			var cur_limit = bytes.size()
			if limit != -1:
				cur_limit = limit
			var result = PBPacker.unpack_message(data, bytes, offset, cur_limit)
			if result == cur_limit:
				if PBPacker.check_required(data):
					if limit == -1:
						return PB_ERR.NO_ERRORS
				else:
					return PB_ERR.REQUIRED_FIELDS
			elif limit == -1 && result > 0:
				return PB_ERR.PARSE_INCOMPLETE
			return result
		
	class map_type_ModData:
		func _init():
			var service
			
			__key = PBField.new("key", PB_DATA_TYPE.STRING, PB_RULE.OPTIONAL, 1, false, DEFAULT_VALUES_2[PB_DATA_TYPE.STRING])
			__key.is_map_field = true
			service = PBServiceField.new()
			service.field = __key
			data[__key.tag] = service
			
			__value = PBField.new("value", PB_DATA_TYPE.BYTES, PB_RULE.OPTIONAL, 2, false, DEFAULT_VALUES_2[PB_DATA_TYPE.BYTES])
			__value.is_map_field = true
			service = PBServiceField.new()
			service.field = __value
			data[__value.tag] = service
			
		var data = {}
		
		var __key: PBField
		func has_key() -> bool:
			if __key.value != null:
				return true
			return false
		func get_key() -> String:
			return __key.value
		func clear_key() -> void:
			data[1].state = PB_SERVICE_STATE.UNFILLED
			__key.value = DEFAULT_VALUES_2[PB_DATA_TYPE.STRING]
		func set_key(value: String) -> void:
			__key.value = value
		
		var __value: PBField
		func has_value() -> bool:
			if __value.value != null:
				return true
			return false
		func get_value() -> PackedByteArray:
			return __value.value
		func clear_value() -> void:
			data[2].state = PB_SERVICE_STATE.UNFILLED
			__value.value = DEFAULT_VALUES_2[PB_DATA_TYPE.BYTES]
		func set_value(value: PackedByteArray) -> void:
			__value.value = value
		
		func _to_string() -> String:
			return PBPacker.message_to_string(data)
			
		func to_bytes() -> PackedByteArray:
			return PBPacker.pack_message(data)
			
		func from_bytes(bytes: PackedByteArray, offset: int = 0, limit: int = -1) -> int:
			var cur_limit = bytes.size()
			if limit != -1:
				cur_limit = limit
			var result = PBPacker.unpack_message(data, bytes, offset, cur_limit)
			if result == cur_limit:
				if PBPacker.check_required(data):
					if limit == -1:
						return PB_ERR.NO_ERRORS
				else:
					return PB_ERR.REQUIRED_FIELDS
			elif limit == -1 && result > 0:
				return PB_ERR.PARSE_INCOMPLETE
			return result
		
	func _to_string() -> String:
		return PBPacker.message_to_string(data)
		
	func to_bytes() -> PackedByteArray:
		return PBPacker.pack_message(data)
		
	func from_bytes(bytes: PackedByteArray, offset: int = 0, limit: int = -1) -> int:
		var cur_limit = bytes.size()
		if limit != -1:
			cur_limit = limit
		var result = PBPacker.unpack_message(data, bytes, offset, cur_limit)
		if result == cur_limit:
			if PBPacker.check_required(data):
				if limit == -1:
					return PB_ERR.NO_ERRORS
			else:
				return PB_ERR.REQUIRED_FIELDS
		elif limit == -1 && result > 0:
			return PB_ERR.PARSE_INCOMPLETE
		return result
	
################ USER DATA END #################
