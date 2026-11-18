extends SceneTree
## Compares two folders of screenshots by name.
## godot --headless --path <project> -s res://addons/white_kit/tools/compare_shots.gd -- --a=<dir> --b=<dir> [--diff=<dir>]
## Exit 0 when every name is the same, 1 when any differs, 2 on bad arguments.


func _init() -> void:
	quit(_run(OS.get_cmdline_user_args()))


func _run(args: PackedStringArray) -> int:
	var a := ""
	var b := ""
	var diff := ""
	for arg in args:
		if arg.begins_with("--a="):
			a = arg.substr(4)
		elif arg.begins_with("--b="):
			b = arg.substr(4)
		elif arg.begins_with("--diff="):
			diff = arg.substr(7)
	if a.is_empty() or b.is_empty():
		printerr("usage: compare_shots.gd -- --a=<dir> --b=<dir> [--diff=<dir>]")
		return 2
	var names_a := _names(a)
	var names_b := _names(b)
	if names_a == null or names_b == null:
		printerr("cannot open %s" % (a if names_a == null else b))
		return 2
	var names: Array = []
	for n in names_a + names_b:
		if not names.has(n):
			names.append(n)
	names.sort()
	if not diff.is_empty():
		DirAccess.make_dir_recursive_absolute(diff)
	var same := 0
	var other := 0
	for n in names:
		var line := _compare(n, a, b, diff, n in names_a, n in names_b)
		print(line)
		if line.begins_with("same "):
			same += 1
		else:
			other += 1
	print("shots: %d same, %d different" % [same, other])
	return 0 if other == 0 else 1


func _names(dir: String) -> Variant:
	var d := DirAccess.open(dir)
	if d == null:
		return null
	var out: Array = []
	for f in d.get_files():
		if f.get_extension().to_lower() == "png":
			out.append(f)
	return out


func _compare(n: String, a: String, b: String, diff: String, in_a: bool, in_b: bool) -> String:
	if not in_a:
		return "missing %s in a" % n
	if not in_b:
		return "missing %s in b" % n
	var ia := Image.load_from_file(a.path_join(n))
	var ib := Image.load_from_file(b.path_join(n))
	if ia == null or ib == null:
		return "unreadable %s" % n
	if ia.get_size() != ib.get_size():
		return "differs %s size %dx%d %dx%d" % [n, ia.get_width(), ia.get_height(), ib.get_width(), ib.get_height()]
	ia.convert(Image.FORMAT_RGBA8)
	ib.convert(Image.FORMAT_RGBA8)
	if ia.get_data() == ib.get_data():
		return "same %s" % n
	var out := Image.create(ia.get_width(), ia.get_height(), false, Image.FORMAT_RGBA8)
	var count := 0
	var lo := Vector2i(ia.get_width(), ia.get_height())
	var hi := Vector2i(-1, -1)
	for y in ia.get_height():
		for x in ia.get_width():
			var pa := ia.get_pixel(x, y)
			if pa == ib.get_pixel(x, y):
				var g := 0.5 * pa.get_luminance()
				out.set_pixel(x, y, Color(g, g, g, 1.0))
			else:
				count += 1
				lo = Vector2i(mini(lo.x, x), mini(lo.y, y))
				hi = Vector2i(maxi(hi.x, x), maxi(hi.y, y))
				out.set_pixel(x, y, Color.RED)
	if not diff.is_empty():
		out.save_png(diff.path_join(n))
	return "differs %s %d pixels box %d,%d,%d,%d" % [n, count, lo.x, lo.y, hi.x - lo.x + 1, hi.y - lo.y + 1]
