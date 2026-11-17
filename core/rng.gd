class_name WhiteRng
extends RefCounted
## Deterministic 32-bit generator (xoshiro128**), seeded from a 64-bit seed. All state words are non-negative ints
## below 2^32 and no operation exceeds int64, so a seed gives the same sequence on every platform and Godot version.

const _M := 0xFFFFFFFF

var _s0 := 1
var _s1 := 0
var _s2 := 0
var _s3 := 0


func _init(seed_value: int = 0) -> void:
	reseed(seed_value)


static func from_text(text: String) -> WhiteRng:
	return WhiteRng.new(WhiteSeed.fnv1a64(text))


static func _mul32(a: int, b: int) -> int:
	return (a * (b & 0xFFFF) + (((a * (b >> 16)) & 0xFFFF) << 16)) & _M


static func _rotl32(x: int, k: int) -> int:
	return ((x << k) & _M) | (x >> (32 - k))


static func _fmix32(value: int) -> int:
	var h := value
	h ^= h >> 16
	h = _mul32(h, 0x85EBCA6B)
	h ^= h >> 13
	h = _mul32(h, 0xC2B2AE35)
	h ^= h >> 16
	return h


func reseed(seed_value: int) -> void:
	var lo := seed_value & _M
	var hi := (seed_value >> 32) & _M
	var k := _fmix32(hi ^ 0x85EBCA6B)
	var w := lo
	var s := [0, 0, 0, 0]
	for i in 4:
		w = (w + 0x9E3779B9) & _M
		s[i] = _fmix32(w ^ k)
	if s[0] == 0 and s[1] == 0 and s[2] == 0 and s[3] == 0:
		s[0] = 1
	_s0 = s[0]
	_s1 = s[1]
	_s2 = s[2]
	_s3 = s[3]


## Raw state, masked to 32 bits. All zero is invalid: error, state unchanged.
func set_state(s0: int, s1: int, s2: int, s3: int) -> void:
	if (s0 | s1 | s2 | s3) & _M == 0:
		push_error("WhiteRng.set_state: all-zero state")
		return
	_s0 = s0 & _M
	_s1 = s1 & _M
	_s2 = s2 & _M
	_s3 = s3 & _M


func get_state() -> PackedInt64Array:
	return PackedInt64Array([_s0, _s1, _s2, _s3])


## 0 .. 2^32 - 1
func next_u32() -> int:
	var result := _mul32(_rotl32((_s1 * 5) & _M, 7), 9)
	var t := (_s1 << 9) & _M
	_s2 ^= _s0
	_s3 ^= _s1
	_s1 ^= _s2
	_s0 ^= _s3
	_s2 ^= t
	_s3 = _rotl32(_s3, 11)
	return result


## Inclusive and unbiased (rejection sampling). Always draws at least once.
func range_int(from: int, to: int) -> int:
	var n := to - from + 1
	if from > to or n > 4294967296:
		push_error("WhiteRng.range_int: bad range %d..%d" % [from, to])
		return from
	var limit := 4294967296 - (4294967296 % n)
	var r := next_u32()
	while r >= limit:
		r = next_u32()
	return from + r % n


## In [0, 1), exact.
func next_float() -> float:
	return next_u32() / 4294967296.0


## Random item; null for an empty array, without drawing.
func pick(items: Array) -> Variant:
	if items.is_empty():
		return null
	return items[range_int(0, items.size() - 1)]


## In place, Fisher-Yates from the end.
func shuffle(items: Array) -> void:
	for i in range(items.size() - 1, 0, -1):
		var j := range_int(0, i)
		var tmp: Variant = items[i]
		items[i] = items[j]
		items[j] = tmp
