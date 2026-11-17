extends RefCounted

const PATH := "user://white_kit_test_progress_file.json"
var LANGS := PackedStringArray(["nl", "en"])


func _write(text: String) -> void:
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	f.store_string(text)
	f.close()


func run(check: Callable, _node: Node) -> void:
	var empty := WhiteProgress.empty("nl")
	check.call(empty == {"lang": "nl", "days": {}}, "empty structure")
	check.call(WhiteProgress.sanitize(null, LANGS, "nl") == empty, "null is the empty structure")
	check.call(WhiteProgress.sanitize([1, 2], LANGS, "nl") == empty, "a list is the empty structure")
	check.call(WhiteProgress.sanitize("x", LANGS, "nl") == empty, "a string is the empty structure")
	check.call(WhiteProgress.sanitize({"lang": "en"}, LANGS, "nl").lang == "en", "a known language is kept")
	check.call(WhiteProgress.sanitize({"lang": "xx"}, LANGS, "nl").lang == "nl", "an unknown language is dropped")
	check.call(WhiteProgress.sanitize({"lang": 5}, LANGS, "nl").lang == "nl", "a non-string language is dropped")
	check.call(WhiteProgress.sanitize({"days": 5}, LANGS, "nl") == empty, "days of the wrong type are dropped")
	check.call(WhiteProgress.sanitize({"days": null}, LANGS, "nl") == empty, "null days are dropped")

	var good := {"lang": "en", "days": {"2026-11-17": [
		{"record": "DRzUR", "time_ms": 41250.0, "solved": true}, {"record": "", "time_ms": 0.0, "solved": false}]}}
	var s := WhiteProgress.sanitize(good, LANGS, "nl")
	check.call(s.days["2026-11-17"][0] == {"record": "DRzUR", "time_ms": 41250, "solved": false}, "solved is always false after sanitize")
	check.call(s.days["2026-11-17"].size() == 2, "list length is kept")

	var mixed := {"days": {"a": [{"record": "UU", "time_ms": 5.0}], "b": "nope", "c": [7, null, {"record": 3, "time_ms": "x"}, {"record": "R", "time_ms": -9.0}]}}
	var m := WhiteProgress.sanitize(mixed, LANGS, "nl")
	check.call(m.days.has("a") and not m.days.has("b"), "a day that is not a list is dropped, the rest is kept")
	check.call(m.days.c.size() == 4, "non-dictionary levels become empty entries")
	check.call(m.days.c[0] == {"record": "", "time_ms": 0, "solved": false} and m.days.c[1] == m.days.c[0], "junk levels are empty entries")
	check.call(m.days.c[2] == {"record": "", "time_ms": 0, "solved": false}, "wrong field types are replaced")
	check.call(m.days.c[3] == {"record": "R", "time_ms": 0, "solved": false}, "negative time becomes 0")
	check.call(WhiteProgress.sanitize({"days": {"a": [{"record": "U", "time_ms": 12}]}}, LANGS, "nl").days.a[0].time_ms == 0, "integer-typed time is not trusted")

	check.call(WhiteProgress.read("user://white_kit_test_missing.json", LANGS, "nl") == empty, "a missing file is the empty structure")
	_write("not json")
	check.call(WhiteProgress.read(PATH, LANGS, "nl") == empty, "a non-JSON file is the empty structure")
	_write("[1]")
	check.call(WhiteProgress.read(PATH, LANGS, "nl") == empty, "a JSON list file is the empty structure")
	var data := WhiteProgress.empty("en")
	data.days["2026-11-17"] = [WhiteProgress.entry("UUz", 1234, false)]
	check.call(WhiteProgress.write(PATH, data), "write succeeds")
	var back := WhiteProgress.read(PATH, LANGS, "nl")
	check.call(back == data, "write then read round-trips")
	check.call(WhiteProgress.entry("U", 5, true) == {"record": "U", "time_ms": 5, "solved": true}, "entry fields")
	check.call(not WhiteProgress.write("user://white_kit_no_such_dir/x.json", data), "write to an impossible path is false")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))
