extends RefCounted
## Merge edge cases of the precompute tool, run as a child Godot process like a game's build script: a published day
## is never changed, damaged inputs leave the data file alone.

const GEN := "res://addons/white_kit/tests/fixtures/generator.gd"

var _check: Callable


func _path(name: String) -> String:
	return ProjectSettings.globalize_path("user://white_kit_test_edge_" + name)


func _exec(args: Array) -> Dictionary:
	var out := []
	var full := ["--headless", "--path", ProjectSettings.globalize_path("res://"), "-s", GEN, "--"]
	full.append_array(args)
	var code := OS.execute(OS.get_executable_path(), full, out, true)
	return {"code": code, "out": "".join(out)}


func _put(name: String, text: String) -> void:
	var f := FileAccess.open(_path(name), FileAccess.WRITE)
	f.store_string(text)
	f.close()


func _read(name: String) -> String:
	return FileAccess.get_file_as_string(_path(name)) if FileAccess.file_exists(_path(name)) else "<missing>"


func _merge(built: String, data: String) -> Dictionary:
	return _exec(["--merge=" + _path(built), "--into=" + _path(data)])


func _clean() -> void:
	for n in ["built.json", "data.json", "list.json", "junk.json"]:
		DirAccess.remove_absolute(_path(n))


func run(check: Callable, _node: Node) -> void:
	_check = check
	_clean()
	_published_days()
	_damaged_files()
	_order_and_bytes()
	_clean()


func _published_days() -> void:
	var day := "{\"seed\":\"ab\",\"level\":0,\"par\":4}"
	_put("data.json", "{\"2026-12-01\":[" + day + "]}\n")
	var before := _read("data.json")

	# a changed value, a changed list length, a missing level and an extra key all count as different
	var variants := {
		"changed value": "{\"2026-12-01\":[{\"seed\":\"ab\",\"level\":0,\"par\":5}]}",
		"shorter list": "{\"2026-12-01\":[]}",
		"longer list": "{\"2026-12-01\":[" + day + "," + day + "]}",
		"extra field": "{\"2026-12-01\":[{\"seed\":\"ab\",\"level\":0,\"par\":4,\"x\":1}]}",
		"changed type": "{\"2026-12-01\":[{\"seed\":\"ab\",\"level\":0,\"par\":\"4\"}]}",
		"not a list": "{\"2026-12-01\":null}",
	}
	for name in variants:
		_put("built.json", variants[name])
		var r := _merge("built.json", "data.json")
		_check.call(r.code == 1 and r.out.contains("refused: 2026-12-01"), "refused: " + name)
		_check.call(_read("data.json") == before, "data file untouched after refusing: " + name)

	# a refusal anywhere stops everything, also when new days come first in the built file
	_put("built.json", "{\"2026-11-30\":[" + day + "],\"2026-12-01\":[{\"seed\":\"ab\",\"level\":0,\"par\":9}]}")
	var r2 := _merge("built.json", "data.json")
	_check.call(r2.code == 1 and _read("data.json") == before, "nothing is added when a later key is refused")

	# int and float spellings of the same number are the same puzzle
	_put("built.json", "{\"2026-12-01\":[{\"seed\":\"ab\",\"level\":0,\"par\":4.0}]}")
	var r3 := _merge("built.json", "data.json")
	_check.call(r3.code == 0 and r3.out.contains("0 added, 1 unchanged") and _read("data.json") == before, "4 and 4.0 are equal and nothing is written")


func _damaged_files() -> void:
	_put("data.json", "{\"2026-12-01\":[]}")
	var before := _read("data.json")
	_put("built.json", "{\"2026-12-02\":[]}")
	_put("list.json", "[1,2]")
	_put("junk.json", "not json")

	var r := _merge("built.json", "list.json")
	_check.call(r.code == 1 and _read("list.json") == "[1,2]", "a data file that is a list is refused and untouched")
	r = _merge("built.json", "junk.json")
	_check.call(r.code == 1 and _read("junk.json") == "not json", "a data file that is not JSON is refused and untouched")
	r = _merge("list.json", "data.json")
	_check.call(r.code == 1 and _read("data.json") == before, "a built file that is a list is refused")
	r = _merge("junk.json", "data.json")
	_check.call(r.code == 1 and _read("data.json") == before, "a built file that is not JSON is refused")
	r = _merge("nope.json", "data.json")
	_check.call(r.code == 1 and _read("data.json") == before, "a missing built file is refused and the data file is untouched")
	_check.call(_read("nope.json") == "<missing>", "a missing built file is not created")
	r = _exec(["--merge=", "--into=" + _path("data.json")])
	_check.call(r.code == 1 and _read("data.json") == before, "an empty --merge value is refused")
	r = _exec(["--merge=" + _path("built.json"), "--into="])
	_check.call(r.code == 1 and _read("data.json") == before, "an empty --into value is refused")


func _order_and_bytes() -> void:
	# existing days keep position and bytes; new days follow in the built file's order
	var a := "{\"seed\":\"a\",\"level\":0,\"par\":1}"
	_put("data.json", "{\"2026-12-05\":[" + a + "],\"2026-12-01\":[" + a + "]}\n")
	_put("built.json", "{\"2026-12-03\":[" + a + "],\"2026-12-01\":[" + a + "],\"2026-12-02\":[" + a + "],\"2026-12-05\":[" + a + "]}")
	var r := _merge("built.json", "data.json")
	var d: Variant = JSON.parse_string(_read("data.json"))
	_check.call(r.code == 0 and r.out.contains("merged: 2 added, 2 unchanged"), "merge counts: " + r.out)
	_check.call(d is Dictionary and d.keys() == ["2026-12-05", "2026-12-01", "2026-12-03", "2026-12-02"], "existing order kept, new days in built order")
	_check.call(_read("data.json").begins_with("{\"2026-12-05\":[" + a + "],\"2026-12-01\":[" + a + "],"), "the bytes of existing days are kept")

	# nothing to add: a hand-formatted data file is not rewritten
	var spaced := "{ \"2026-12-01\" : [ " + a + " ] }\n"
	_put("data.json", spaced)
	_put("built.json", "{\"2026-12-01\":[" + a + "]}")
	r = _merge("built.json", "data.json")
	_check.call(r.code == 0 and _read("data.json") == spaced, "no new days: the data file is not rewritten")

	# merge twice with the same built file: the second run changes nothing
	_put("data.json", "{}\n")
	_put("built.json", "{\"2026-12-01\":[" + a + "],\"2026-12-02\":[" + a + "]}")
	_merge("built.json", "data.json")
	var once := _read("data.json")
	r = _merge("built.json", "data.json")
	_check.call(r.code == 0 and _read("data.json") == once and r.out.contains("0 added, 2 unchanged"), "merging twice is idempotent")
