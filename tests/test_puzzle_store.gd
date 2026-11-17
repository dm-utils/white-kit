extends RefCounted

const DIR := "res://addons/white_kit/tests/fixtures/"


func _tag(d: Dictionary) -> Dictionary:
	return {"par": d.par, "tag": d.tag, "converted": true}


func run(check: Callable, _node: Node) -> void:
	WhitePuzzleStore.clear_cache()
	var store := WhitePuzzleStore.new(DIR + "daily.json", DIR + "practice.json", _tag)
	check.call(store.has_day("2026-11-17") and store.has_day("2026-11-18"), "present days are found")
	check.call(not store.has_day("2026-11-19"), "a missing day is not found")
	check.call(store.day("2026-11-19") == [], "day of a missing date is []")
	var d := store.day("2026-11-18")
	check.call(d.size() == 3 and d[1].tag == "d18b", "day returns the puzzles of that date in level order")
	check.call(d.all(func(p: Dictionary) -> bool: return p.converted), "the converter is applied to every day puzzle")
	check.call(store.days() == PackedStringArray(["2026-11-17", "2026-11-18"]), "days are sorted dates")
	check.call(store.practice_count() == 2, "practice count")
	check.call(store.practice_set(0)[0].tag == "p0a", "practice set 0")
	check.call(store.practice_set(-1)[0].tag == "p1a", "practice index -1 is the last set")
	check.call(store.practice_set(2)[0].tag == "p0a", "practice index count wraps to set 0")
	check.call(store.practice_set(3)[2].tag == "p1c", "practice index wraps further")
	check.call(store.practice(1, 2).tag == "p1c" and store.practice(1, 2).converted, "practice by index and level, converted")
	check.call(store.practice(1, 9) == {}, "practice level out of range is {}")

	var raw := WhitePuzzleStore.new(DIR + "daily.json", DIR + "practice.json", Callable())
	check.call(raw.day("2026-11-17")[0].tag == "d17a" and not raw.day("2026-11-17")[0].has("converted"), "an invalid converter means identity")

	var broken := WhitePuzzleStore.new(DIR + "not_json.json", DIR + "list.json", _tag)
	check.call(broken.day("2026-11-17") == [] and not broken.has_day("2026-11-17"), "a non-JSON file loads as {}")
	check.call(broken.practice_count() == 0 and broken.practice_set(0) == [], "a JSON list loads as {}")
	check.call(broken.practice(0, 0) == {}, "practice without sets is {}")
	var missing := WhitePuzzleStore.new(DIR + "nope.json", DIR + "nope2.json", _tag)
	check.call(missing.days().is_empty() and missing.day("x") == [], "missing files load as {}")
	check.call(WhitePuzzleStore.load_json(DIR + "list.json") == {}, "load_json of a list is {}")
	WhitePuzzleStore.clear_cache()
