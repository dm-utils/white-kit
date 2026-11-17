extends RefCounted
## Cross-checks against a second, independent implementation (plain Python big ints, written from the design text, not
## from the kit code): boundary seeds, bulk streams as md5, DST switch moments, calendar properties.

# per seed: [state after reseed, 6 x next_u32, 6 x range_int(-3, 10), 3 x range_int(0, 3000000000), shuffle of 0..9]
const VECTORS := {
	2: [[1256838402, 3664041913, 4206920466, 110983139], [3707093929, 3487914705, 3520842046, 2478787808, 119300646, 1591460034], [1, 9, 4, 0, 1, 9], [1955179513, 2749093932, 240191716], [8, 7, 5, 9, 3, 4, 1, 2, 6, 0]],
	4294967295: [[2439815749, 3012286633, 3206674403, 1887719820], [3398098112, 4083536346, 3770166815, 3127512271, 2752205194, 2601870993], [8, 0, 7, 8, 0, 7], [1142997260, 1599380626, 722208178], [8, 5, 0, 1, 9, 7, 6, 4, 2, 3]],
	4294967296: [[1392396977, 2199022573, 280207263, 8699713], [511465215, 3930334971, 951490920, 2196117381, 1743028273, 3498966453], [10, -3, 7, 8, 8, 2], [2578082134, 1382706791, 316803207], [6, 1, 3, 5, 2, 7, 8, 0, 4, 9]],
	-4294967296: [[2172767615, 2191804063, 1399701849, 822309994], [1882520566, 1519469832, 1566530636, 2899445147, 2626827005, 3138580148], [3, 3, 5, 1, 5, 1], [265672554, 719030587, 1356165366], [0, 3, 7, 8, 4, 6, 2, 9, 1, 5]],
	9223372036854775807: [[1702552630, 1504769775, 3393160335, 4151902726], [229901536, 2511770289, 1878014825, 2168281926, 1666164972, 3011076007], [10, -3, 0, 4, -1, 10], [2488707235, 2885391012, 2991856070], [0, 4, 1, 5, 8, 9, 3, 7, 6, 2]],
	-9223372036854775807 - 1: [[1576158530, 1617671677, 2345902457, 1738667352], [2004795513, 2284841343, 1921207257, 4047082175, 1788272356, 2095720808], [-2, 0, -2, -2, 8, 3], [2317660425, 2606285684, 2051885802], [4, 1, 7, 9, 0, 6, 3, 8, 5, 2]],
	123456789012345: [[1404502027, 1657808399, 164301429, 1269433328], [1264080303, 568848117, 555913772, 3733179625, 3899257135, 2028559851], [5, 4, 1, 7, 5, 9], [1529663016, 1241244645, 853364085], [0, 6, 8, 4, 2, 1, 3, 9, 7, 5]],
	-987654321098765: [[2792280359, 1518417527, 2667199624, 3653697715], [1531541746, 3956441117, 3591799818, 615605125, 1678608367, 366150398], [5, 1, 10, 6, -2, 8], [2559056538, 936527171, 954898015], [1, 0, 9, 6, 4, 5, 8, 2, 3, 7]],
}

# [year, last Sunday of March 01:00 UTC, last Sunday of October 01:00 UTC] as unix times
const DST := [
	[2026, 1774746000, 1792890000], [2027, 1806195600, 1824944400], [2028, 1837645200, 1856394000],
	[2029, 1869094800, 1887843600], [2030, 1901149200, 1919293200], [2031, 1932598800, 1950742800],
	[2032, 1964048400, 1982797200], [2033, 1995498000, 2014246800], [2034, 2026947600, 2045696400],
	[2035, 2058397200, 2077146000], [2036, 2090451600, 2108595600], [2037, 2121901200, 2140045200],
	[2038, 2153350800, 2172099600], [2039, 2184800400, 2203549200], [2040, 2216250000, 2234998800],
]


func run(check: Callable, _node: Node) -> void:
	_seed_vectors(check)
	_bulk(check)
	_hash_texts(check)
	_dst(check)
	_calendar(check)


func _seed_vectors(check: Callable) -> void:
	for s in VECTORS:
		var want: Array = VECTORS[s]
		var r := WhiteRng.new(s)
		check.call(Array(r.get_state()) == want[0], "seed %d: state after reseed" % s)
		var u := []
		for i in 6:
			u.append(r.next_u32())
		check.call(u == want[1], "seed %d: next_u32 values" % s)
		var n := []
		for i in 6:
			n.append(r.range_int(-3, 10))
		check.call(n == want[2], "seed %d: range_int with a negative lower bound" % s)
		var b := []
		for i in 3:
			b.append(r.range_int(0, 3000000000))
		check.call(b == want[3], "seed %d: range_int wider than 2^31" % s)
		var a := range(10)
		r.shuffle(a)
		check.call(a == want[4], "seed %d: shuffle" % s)


func _md5(values: Array, sep: String) -> String:
	return sep.join(values.map(str)).md5_text()


func _bulk(check: Callable) -> void:
	var seeds := []
	for i in 200:
		seeds.append(WhiteSeed.fnv1a64("probe|%d" % i))
	check.call(_md5(seeds, "|") == "55e78e672440f9b7d4bdbf2f397795ce", "200 hashes match the independent implementation")
	var r := WhiteRng.new(seeds[0])
	var u := []
	for i in 1000:
		u.append(r.next_u32())
	check.call(_md5(u, ",") == "88e2ae0bb2ea177dc0d8f85ebb4e452b", "1000 next_u32 values match")
	r = WhiteRng.new(seeds[1])
	var d := []
	for i in 1000:
		d.append(r.range_int(0, 6))
	check.call(_md5(d, ",") == "918e2d3abc4b03790fefcffe9ae39827", "1000 range_int(0, 6) values match")
	r = WhiteRng.new(seeds[2])
	var deck := range(52)
	r.shuffle(deck)
	check.call(_md5(deck, ",") == "4ee2c97a411d6e7be36cba281590cccd", "a shuffled deck matches")
	r = WhiteRng.new(seeds[3])
	var w := []
	for i in 200:
		w.append(r.range_int(-1000000000000, -1000000000000 + 4000000000))
	check.call(_md5(w, ",") == "1aa25116a239cb368e0f98a1d52bdd82", "range_int far from zero, span just under 2^32, matches")
	var full := WhiteRng.new(1)
	var top := 0
	var low := 0
	for i in 200:
		var v := full.range_int(0, 4294967295)
		top = maxi(top, v)
		low = mini(low, v)
	check.call(low >= 0 and top <= 4294967295, "range_int over the full 32-bit span stays in range")
	check.call(WhiteRng.new(5).range_int(9223372036854775800, 9223372036854775807) >= 9223372036854775800, "range_int next to the int64 maximum")


func _hash_texts(check: Callable) -> void:
	check.call(WhiteSeed.fnv1a64("white-tally|2026-11-17|0") == -3491732791651030195, "hash of a white-tally seed text")
	check.call(WhiteSeed.daily("white-tally", "2026-11-17", 0) == -3491732791651030195, "daily seed of white-tally")
	check.call(WhiteSeed.practice("white-tally", 12, 1) == -5124477826036167557, "practice seed of white-tally")
	check.call(WhiteSeed.fnv1a64("ë€𝄞") == -1178445255966914680, "multi-byte hash")
	check.call(WhiteSeed.fnv1a64("日本語テキスト") == 7185811779928051721, "Japanese text hash")
	check.call(WhiteSeed.fnv1a64_bytes(PackedByteArray()) == WhiteSeed.fnv1a64(""), "empty bytes equal the empty text")
	check.call(WhiteSeed.fnv1a64_bytes(PackedByteArray([255, 0, 128])) != WhiteSeed.fnv1a64_bytes(PackedByteArray([255, 0])), "bytes beyond ASCII and NUL count")


func _dst(check: Callable) -> void:
	for e in DST:
		var start: int = e[1]
		var end: int = e[2]
		check.call(WhiteDaily.nl_offset(start - 1) == 3600 and WhiteDaily.nl_offset(start) == 7200, "%d: summer time starts at the independent moment" % e[0])
		check.call(WhiteDaily.nl_offset(end - 1) == 7200 and WhiteDaily.nl_offset(end) == 3600, "%d: summer time ends at the independent moment" % e[0])


func _calendar(check: Callable) -> void:
	# every Dutch date of 2027 shows up, in order, and consecutive hours never skip a date
	var t0 := Time.get_unix_time_from_datetime_string("2026-12-31T00:00:00")
	var seen := {}
	var prev := WhiteDaily.date_at(t0)
	var jumps_ok := true
	for h in range(1, 24 * 370):
		var cur := WhiteDaily.date_at(t0 + h * 3600)
		seen[cur] = true
		if cur != prev and cur != WhiteDaily.add_days(prev, 1):
			jumps_ok = false
		prev = cur
	check.call(jumps_ok, "hourly over a year the Dutch date never skips or goes back")
	var in_2027 := 0
	for k in seen:
		if k.begins_with("2027-"):
			in_2027 += 1
	check.call(in_2027 == 365, "all 365 dates of 2027 occur")

	var first := "2026-11-17"
	var ok := true
	for k in range(-400, 800, 7):
		var d := WhiteDaily.add_days(first, k)
		if WhiteDaily.number(d, first) != k + 1 or WhiteDaily.add_days(d, -k) != first or not WhiteDaily.is_date(d):
			ok = false
	check.call(ok, "add_days, number and is_date agree over -400..800 days")
	check.call(WhiteDaily.add_days(first, 0) == first, "add_days with 0")
	for s in ["1969-12-31", "2026-00-10", "2026-04-31", "2100-02-29", "2026-11-17T", " 2026-11-17", "2026-11-17 ", "+026-11-17",
			"abcd-ef-gh", "２０２６-11-17", "2026.11.17", "2026-11-1", "2026-1-17", "20261117", "0000-00-00", "2026-11-00"]:
		check.call(not WhiteDaily.is_date(s), "'%s' is no date" % s)
	for s in ["1970-01-01", "2000-02-29", "2024-02-29", "9999-12-31", "2026-12-31"]:
		check.call(WhiteDaily.is_date(s), "'%s' is a date" % s)
