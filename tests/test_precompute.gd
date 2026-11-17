extends RefCounted
## Runs the fixture generator as a child Godot process, like a game's build script, and checks files and exit codes.

const GEN := "res://addons/white_kit/tests/fixtures/generator.gd"

var _check: Callable


func _path(name: String) -> String:
	return ProjectSettings.globalize_path("user://white_kit_test_" + name)


func _exec(args: Array) -> Dictionary:
	var out := []
	var full := ["--headless", "--path", ProjectSettings.globalize_path("res://"), "-s", GEN, "--"]
	full.append_array(args)
	var code := OS.execute(OS.get_executable_path(), full, out, true)
	return {"code": code, "out": "".join(out)}


func _read(name: String) -> String:
	return FileAccess.get_file_as_string(_path(name)) if FileAccess.file_exists(_path(name)) else ""


func _clean() -> void:
	for n in ["built.json", "data.json", "more.json", "bad.json"]:
		DirAccess.remove_absolute(_path(n))


func _seed_hex(game: String, key: Variant, level: int, practice: bool) -> String:
	var s := WhiteSeed.practice(game, int(key), level) if practice else WhiteSeed.daily(game, str(key), level)
	return String.num_uint64(s, 16)


func run(check: Callable, _node: Node) -> void:
	_check = check
	_clean()
	_build()
	_merge()
	_bad_arguments()
	_clean()


func _build() -> void:
	var r := _exec(["--from=2026-11-30", "--days=3", "--out=" + _path("built.json")])
	_check.call(r.code == 0, "daily build exits 0")
	_check.call(r.out.contains("2026-12-02 par [1, 2, 3]"), "daily build prints key and default summary: " + r.out)
	var text := _read("built.json")
	_check.call(text.ends_with("}\n") and not text.contains("\n}\n"), "build output is one line plus a newline")
	var d: Variant = JSON.parse_string(text)
	_check.call(d is Dictionary and d.keys() == ["2026-11-30", "2026-12-01", "2026-12-02"], "daily keys run over the month end in build order")
	_check.call(d["2026-12-01"][2].seed == _seed_hex("white-fixture", "2026-12-01", 2, false), "daily seed is WhiteSeed.daily")
	_check.call(d["2026-12-01"][2].level == 2 and d["2026-12-01"].size() == 3, "three levels per key")

	r = _exec(["--practice=2", "--start=5", "--out=" + _path("built.json")])
	d = JSON.parse_string(_read("built.json"))
	_check.call(r.code == 0 and d.keys() == ["5", "6"], "practice keys from --start")
	_check.call(d["6"][1].seed == _seed_hex("white-fixture", 6, 1, true), "practice seed is WhiteSeed.practice")


func _merge() -> void:
	_exec(["--from=2026-11-30", "--days=2", "--out=" + _path("data.json")])
	var before := _read("data.json")
	_exec(["--from=2026-12-01", "--days=3", "--out=" + _path("more.json")])
	var r := _exec(["--merge=" + _path("more.json"), "--into=" + _path("data.json")])
	_check.call(r.code == 0 and r.out.contains("merged: 2 added, 1 unchanged"), "merge adds the new keys and skips the equal one: " + r.out)
	var after := _read("data.json")
	var d: Dictionary = JSON.parse_string(after)
	_check.call(d.keys() == ["2026-11-30", "2026-12-01", "2026-12-02", "2026-12-03"], "merge keeps the order and appends new keys")
	_check.call(after.begins_with(before.trim_suffix("}\n")), "existing text is kept byte for byte")

	var again := _exec(["--merge=" + _path("more.json"), "--into=" + _path("data.json")])
	_check.call(again.code == 0 and again.out.contains("merged: 0 added, 3 unchanged") and _read("data.json") == after, "merging twice changes nothing")

	# a changed published key is refused and nothing is written
	var changed: Dictionary = JSON.parse_string(_read("more.json"))
	changed["2026-12-01"][0].seed = "ffff"
	changed["2026-12-09"] = [{"seed": "1", "level": 0}]
	var f := FileAccess.open(_path("bad.json"), FileAccess.WRITE)
	f.store_string(JSON.stringify(changed))
	f.close()
	var bad := _exec(["--merge=" + _path("bad.json"), "--into=" + _path("data.json")])
	_check.call(bad.code == 1 and bad.out.contains("refused: 2026-12-01 differs from the published puzzle"), "a changed key is refused with exit 1: " + bad.out)
	_check.call(_read("data.json") == after, "the data file is unchanged after a refusal")

	DirAccess.remove_absolute(_path("data.json"))
	var fresh := _exec(["--merge=" + _path("more.json"), "--into=" + _path("data.json")])
	_check.call(fresh.code == 0 and fresh.out.contains("merged: 3 added, 0 unchanged"), "merge into a missing data file starts empty")


func _bad_arguments() -> void:
	var out := _path("built.json")
	_check.call(_exec(["--from=2026-13-01", "--out=" + out]).code == 1, "an invalid --from exits 1")
	_check.call(_exec(["--from=2026-11-30"]).code == 1, "a missing --out exits 1")
	_check.call(_exec(["--from=2026-11-30", "--days=0", "--out=" + out]).code == 1, "--days below 1 exits 1")
	_check.call(_exec(["--practice=0", "--out=" + out]).code == 1, "--practice below 1 exits 1")
	_check.call(_exec(["--merge=" + out]).code == 1, "a missing --into exits 1")
	_check.call(_exec([]).code == 1, "no command exits 1")
