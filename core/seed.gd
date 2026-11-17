class_name WhiteSeed
extends RefCounted
## FNV-1a 64-bit seed hash and the fixed seed texts. Two 32-bit halves, so nothing relies on int64 overflow.

const _M := 0xFFFFFFFF
const _P_HI := 0x100
const _P_LO := 0x1B3


static func fnv1a64(text: String) -> int:
	return fnv1a64_bytes(text.to_utf8_buffer())


static func fnv1a64_bytes(bytes: PackedByteArray) -> int:
	var hi := 0xCBF29CE4
	var lo := 0x84222325
	for b in bytes:
		lo ^= b
		var p := lo * _P_LO
		var new_hi := (hi * _P_LO + lo * _P_HI + (p >> 32)) & _M
		lo = p & _M
		hi = new_hi
	# same bit pattern as signed int64, no shift into the sign bit
	var top := hi - 4294967296 if hi >= 2147483648 else hi
	return top * 4294967296 + lo


## "<game_id>|<date>|<level>"
static func daily_text(game_id: String, date: String, level: int) -> String:
	return "%s|%s|%d" % [game_id, date, level]


## "<game_id>-practice|<index>|<level>"
static func practice_text(game_id: String, index: int, level: int) -> String:
	return "%s-practice|%d|%d" % [game_id, index, level]


static func daily(game_id: String, date: String, level: int) -> int:
	return fnv1a64(daily_text(game_id, date, level))


static func practice(game_id: String, index: int, level: int) -> int:
	return fnv1a64(practice_text(game_id, index, level))
