extends SceneTree
## Prints reference vectors of WhiteSeed and WhiteRng; same lines as tools/reference/white_rng.py.
##   godot --headless --path <host> -s res://addons/white_kit/tools/rng_vectors.gd

const SEEDS := [0, 1, -1, null] # null = fnv1a64("white-kit")
const TEXTS := ["", "a", "foobar", "white-shift|2026-11-17|2", "ë€\U01d11e"]


func _init() -> void:
	for t in TEXTS:
		print("fnv %s %s" % [_escape(t), String.num_uint64(WhiteSeed.fnv1a64(t), 16).lpad(16, "0")])
	for s in SEEDS:
		var seed_value: int = WhiteSeed.fnv1a64("white-kit") if s == null else s
		var r := WhiteRng.new(seed_value)
		print("seed %d" % seed_value)
		print("state " + " ".join(Array(r.get_state()).map(str)))
		print("u32 " + " ".join(_draw(8, func() -> int: return r.next_u32())))
		print("int " + " ".join(_draw(8, func() -> int: return r.range_int(0, 6))))
		# next_float scaled back by 2^32 gives the exact u32, so the line has no float formatting
		print("float " + " ".join(_draw(4, func() -> int: return int(r.next_float() * 4294967296.0))))
	quit()


func _draw(n: int, f: Callable) -> PackedStringArray:
	var out := PackedStringArray()
	for i in n:
		out.append(str(f.call()))
	return out


# python's unicode_escape form: non-ASCII as \xNN, \uNNNN or \UNNNNNNNN
func _escape(text: String) -> String:
	var out := ""
	for i in text.length():
		var c := text.unicode_at(i)
		if c < 128:
			out += char(c)
		elif c < 256:
			out += "\\x%02x" % c
		elif c < 65536:
			out += "\\u%04x" % c
		else:
			out += "\\U%08x" % c
	return out
