extends RefCounted

# Python reference output (tools/reference/white_rng.py) per seed; changing these needs a MAJOR kit version
const VECTORS := {
	0: [
		"state 1601726536 1248645669 1880968135 3655486469",
		"u32 2423800458 1606251868 4239509598 2561438613 3542933120 4293804133 4047821312 877200174",
		"int 5 6 1 2 5 0 3 6",
		"float 1735552066 379914413 3839204345 998990788",
	],
	1: [
		"state 3649346442 2654640481 653596071 824228933",
		"u32 645596899 428618251 3274879441 4074132307 2803349122 1399455839 4280272609 2826836995",
		"int 2 1 0 3 3 3 6 1",
		"float 1737262171 594459740 3987440300 553894270",
	],
	-1: [
		"state 474740848 4166579564 2584048456 604526623",
		"u32 3516006860 4196033555 1695925400 3603383999 4276071888 1516508440 1106638100 258097539",
		"int 0 2 1 4 0 4 2 6",
		"float 1807770524 474951712 2018702092 240817595",
	],
	-3057146540974185149: [
		"state 512661163 3439948172 2940130800 3959944509",
		"u32 1417334272 1190651759 1541189817 1688868240 3012024071 1676155649 1946151745 2902727067",
		"int 0 2 4 6 1 2 2 4",
		"float 45585808 3125946810 825410126 2266947248",
	],
}


func _join(values: Array) -> String:
	return " ".join(values.map(str))


func run(check: Callable, _node: Node) -> void:
	var r := WhiteRng.new()
	r.set_state(1, 2, 3, 4)
	var first: Array = []
	for i in 4:
		first.append(r.next_u32())
	check.call(first == [11520, 0, 5927040, 70819200], "xoshiro128** published values from state 1 2 3 4: %s" % [first])

	check.call(WhiteSeed.fnv1a64("white-kit") == -3057146540974185149, "seed of the 'white-kit' vector")
	for s in VECTORS:
		var rng := WhiteRng.new(s)
		var lines: Array = VECTORS[s]
		check.call("state " + _join(Array(rng.get_state())) == lines[0], "seed %d: state after reseed" % s)
		var u: Array = []
		for i in 8:
			u.append(rng.next_u32())
		check.call("u32 " + _join(u) == lines[1], "seed %d: first 8 next_u32 values" % s)
		var n: Array = []
		for i in 8:
			n.append(rng.range_int(0, 6))
		check.call("int " + _join(n) == lines[2], "seed %d: 8 range_int(0, 6) values" % s)
		var f: Array = []
		for i in 4:
			f.append(int(rng.next_float() * 4294967296.0))
		check.call("float " + _join(f) == lines[3], "seed %d: 4 next_float values" % s)

	var a := WhiteRng.new(42)
	var before := a.get_state()
	check.call(a.range_int(3, 3) == 3, "range_int(3, 3) returns 3")
	check.call(a.get_state() != before, "range_int(3, 3) still advances the state")
	var hits := [0, 0, 0, 0, 0, 0, 0]
	var d := WhiteRng.new(7)
	for i in 70000:
		hits[d.range_int(0, 6)] += 1
	var ok := true
	for h in hits:
		ok = ok and h >= 9000 and h <= 11000
	check.call(ok, "range_int(0, 6) is evenly spread: %s" % [hits])
	check.call(d.range_int(-5, -5) == -5 and d.range_int(-2, 2) >= -2, "negative ranges work")
	var floats_ok := true
	for i in 1000:
		var x := d.next_float()
		floats_ok = floats_ok and x >= 0.0 and x < 1.0
	check.call(floats_ok, "next_float stays in [0, 1)")

	var x1 := WhiteRng.new(5)
	var x2 := WhiteRng.new(5)
	var same := true
	for i in 100:
		same = same and x1.next_u32() == x2.next_u32()
	check.call(same, "same seed gives the same sequence")
	check.call(WhiteRng.from_text("abc").get_state() == WhiteRng.new(WhiteSeed.fnv1a64("abc")).get_state(), "from_text hashes the text")
	var s1 := range(20)
	var s2 := range(20)
	WhiteRng.new(9).shuffle(s1)
	WhiteRng.new(9).shuffle(s2)
	var sorted := s1.duplicate()
	sorted.sort()
	check.call(s1 == s2 and s1 != range(20), "shuffle is deterministic and reorders")
	check.call(sorted == range(20), "shuffle keeps the items")
	check.call(WhiteRng.new(1).pick([]) == null, "pick of an empty array is null")
	var p := WhiteRng.new(1)
	var pst := p.get_state()
	p.pick([])
	check.call(p.get_state() == pst, "pick of an empty array draws nothing")
	check.call(WhiteRng.new(3).pick([7, 8, 9]) in [7, 8, 9], "pick returns an item")

	var z := WhiteRng.new(0)
	var st := z.get_state()
	z.set_state(0, 0, 0, 0)
	check.call(z.get_state() == st, "all-zero state is refused")
