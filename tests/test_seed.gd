extends RefCounted


# the White Shift implementation: relies on int64 wrap-around
func _old_seed_for(text: String) -> int:
	var hash_value := -3750763034362895579 # 0xcbf29ce484222325 as a signed 64-bit int
	for b in text.to_utf8_buffer():
		hash_value = (hash_value ^ b) * 1099511628211
	return hash_value


func run(check: Callable, _node: Node) -> void:
	check.call(String.num_uint64(WhiteSeed.fnv1a64(""), 16) == "cbf29ce484222325", "FNV-1a of the empty text")
	check.call(String.num_uint64(WhiteSeed.fnv1a64("a"), 16) == "af63dc4c8601ec8c", "FNV-1a of 'a'")
	check.call(String.num_uint64(WhiteSeed.fnv1a64("foobar"), 16) == "85944171f73967e8", "FNV-1a of 'foobar'")

	var texts: Array[String] = ["", "a", "foobar", "ë€\U01d11e"]
	for d in 60:
		var date := WhiteDaily.add_days("2026-11-17", d)
		for level in 3:
			texts.append("white-shift|%s|%d" % [date, level])
	for i in 840:
		texts.append("sample text %d %s" % [i, "x".repeat(i % 37)])
	var same := 0
	for t in texts:
		if WhiteSeed.fnv1a64(t) == _old_seed_for(t):
			same += 1
	check.call(texts.size() >= 1000, "at least 1000 hash texts (%d)" % texts.size())
	check.call(same == texts.size(), "fnv1a64 equals the overflow implementation for all texts (%d of %d)" % [same, texts.size()])
	check.call(WhiteSeed.fnv1a64_bytes("foobar".to_utf8_buffer()) == WhiteSeed.fnv1a64("foobar"), "bytes and text variants agree")

	check.call(WhiteSeed.daily_text("white-shift", "2026-11-17", 2) == "white-shift|2026-11-17|2", "daily seed text")
	check.call(WhiteSeed.practice_text("white-shift", 3, 0) == "white-shift-practice|3|0", "practice seed text")
	check.call(WhiteSeed.daily("white-shift", "2026-11-17", 2) == WhiteSeed.fnv1a64("white-shift|2026-11-17|2"), "daily seed")
	check.call(WhiteSeed.practice("white-shift", 3, 0) == WhiteSeed.fnv1a64("white-shift-practice|3|0"), "practice seed")
	var hex := String.num_uint64(WhiteSeed.fnv1a64("white-shift|2026-11-17|2"), 16)
	check.call(hex == "d4a330e8cc614db1", "seed of the first White Shift day matches the Python reference")
	hex = String.num_uint64(WhiteSeed.fnv1a64("ë€\U01d11e"), 16)
	check.call(hex == "efa552488ad90788", "multi-byte UTF-8 hash matches the Python reference")
