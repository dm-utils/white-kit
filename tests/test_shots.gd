extends RefCounted
## tools/compare_shots.gd and tools/shots.sh as child processes (design 14.5)

const TOOL := "res://addons/white_kit/tools/compare_shots.gd"

var _check: Callable


func _dir(name: String) -> String:
	var d := ProjectSettings.globalize_path("user://white_kit_test_shots_" + name)
	DirAccess.make_dir_recursive_absolute(d)
	return d


func _wipe(d: String) -> void:
	for f in DirAccess.get_files_at(d):
		DirAccess.remove_absolute(d.path_join(f))
	DirAccess.remove_absolute(d)


func _png(d: String, name: String, w: int, h: int, dot := Vector2i(-1, -1)) -> void:
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.2, 0.4, 0.6, 1.0))
	if dot.x >= 0:
		img.set_pixelv(dot, Color.WHITE)
	img.save_png(d.path_join(name))


func _compare(args: Array) -> Dictionary:
	var out := []
	var full := ["--headless", "--path", ProjectSettings.globalize_path("res://"), "-s", TOOL, "--"]
	full.append_array(args)
	var code := OS.execute(OS.get_executable_path(), full, out, true)
	return {"code": code, "out": "".join(out)}


func run(check: Callable, _node: Node) -> void:
	_check = check
	var a := _dir("a")
	var b := _dir("b")
	var diff := _dir("diff")
	for d in [a, b, diff]:
		for f in DirAccess.get_files_at(d):
			DirAccess.remove_absolute(d.path_join(f))
	_compare_cases(a, b, diff)
	_script_cases()
	for d in [a, b, diff]:
		_wipe(d)


func _compare_cases(a: String, b: String, diff: String) -> void:
	_png(a, "one.png", 8, 6)
	_png(b, "one.png", 8, 6)
	_png(a, "two.png", 4, 4)
	_png(b, "two.png", 4, 4)
	var r := _compare(["--a=" + a, "--b=" + b])
	_check.call(r.code == 0 and r.out.contains("same one.png") and r.out.contains("same two.png") and r.out.contains("shots: 2 same, 0 different"),
			"compare: equal folders exit 0 with same lines: " + r.out)
	_png(b, "one.png", 8, 6, Vector2i(3, 2))
	r = _compare(["--a=" + a, "--b=" + b, "--diff=" + diff])
	_check.call(r.code == 1 and r.out.contains("differs one.png 1 pixels box 3,2,1,1") and r.out.contains("same two.png")
			and r.out.contains("shots: 1 same, 1 different"), "compare: one changed pixel exits 1 with its box: " + r.out)
	var d := Image.load_from_file(diff.path_join("one.png"))
	_check.call(d != null and d.get_pixel(3, 2) == Color.RED and d.get_pixel(0, 0) != Color.RED and not FileAccess.file_exists(diff.path_join("two.png")),
			"compare: the diff image has the red pixel at the changed position, none for same files")
	_png(b, "one.png", 9, 6)
	r = _compare(["--a=" + a, "--b=" + b])
	_check.call(r.code == 1 and r.out.contains("differs one.png size 8x6 9x6"), "compare: a size difference is reported: " + r.out)
	_png(b, "one.png", 8, 6)
	_png(a, "only_a.png", 2, 2)
	_png(b, "only_b.png", 2, 2)
	r = _compare(["--a=" + a, "--b=" + b])
	_check.call(r.code == 1 and r.out.contains("missing only_a.png in b") and r.out.contains("missing only_b.png in a"), "compare: missing files in either folder: " + r.out)
	DirAccess.remove_absolute(a.path_join("only_a.png"))
	DirAccess.remove_absolute(b.path_join("only_b.png"))
	var f := FileAccess.open(b.path_join("two.png"), FileAccess.WRITE)
	f.store_string("not a png")
	f.close()
	r = _compare(["--a=" + a, "--b=" + b])
	_check.call(r.code == 1 and r.out.contains("unreadable two.png"), "compare: an unreadable file is reported: " + r.out)
	r = _compare(["--b=" + b])
	_check.call(r.code == 2, "compare: missing --a exits 2")
	r = _compare(["--a=" + a + "_nope", "--b=" + b])
	_check.call(r.code == 2, "compare: a folder that cannot be opened exits 2")


func _script_cases() -> void:
	var sh := ProjectSettings.globalize_path("res://addons/white_kit/tools/shots.sh")
	var scen := ProjectSettings.globalize_path("user://white_kit_test_shots_scenarios.txt")
	var out_dir := ProjectSettings.globalize_path("user://white_kit_test_shots_out")
	var project := ProjectSettings.globalize_path("res://")
	var cases := {
		"Bad_Name 720x1280 --practice\n": true,
		"name 720x\n": true,
		"wide 2000x900 --practice\n": true,
		"dupe 720x1280\ndupe 720x1280\n": true,
	}
	for text in cases:
		var f := FileAccess.open(scen, FileAccess.WRITE)
		f.store_string(text)
		f.close()
		var out := []
		var code := OS.execute("bash", [sh, "run", project, scen, out_dir], out, true)
		_check.call(code == 1 and "".join(out).contains("bad scenario line"), "shots.sh: a malformed scenario line exits 1 (%s)" % text.strip_edges().replace("\n", " / "))
	var f := FileAccess.open(scen, FileAccess.WRITE)
	f.store_string("# comment\n\n   \n")
	f.close()
	var out2 := []
	_check.call(OS.execute("bash", [sh, "run", project, scen, out_dir], out2, true) == 0, "shots.sh: comments and empty lines are ignored")
	var out3 := []
	_check.call(OS.execute("bash", [sh, "nope"], out3, true) == 2, "shots.sh: an unknown command exits 2")
	DirAccess.remove_absolute(scen)
	_wipe(out_dir)
