class_name WhitePrecompute
extends SceneTree
## Skeleton of a game's tools/build_puzzles.gd: a game script extends it and overrides the hooks.
##   godot --headless --path . -s res://tools/build_puzzles.gd -- --from=YYYY-MM-DD --days=N --out=<file>
##   godot --headless --path . -s res://tools/build_puzzles.gd -- --practice=N [--start=S] --out=<file>
##   godot --headless --path . -s res://tools/build_puzzles.gd -- --merge=<built file> --into=<data file>
## Output: {"<key>": [puzzle per level]}. Merge adds new keys and refuses to change an existing one.

const USAGE := "usage: --from=YYYY-MM-DD [--days=N] --out=<file> | --practice=N [--start=S] --out=<file> | --merge=<built file> --into=<data file>"


# --- hooks -------------------------------------------------------------------------------------------------------

func _game_id() -> String:
	push_error("WhitePrecompute._game_id not implemented")
	return ""


func _level_count() -> int:
	return 3


## One puzzle, JSON-ready.
func _generate(_seed_value: int, _level: int) -> Dictionary:
	push_error("WhitePrecompute._generate not implemented")
	return {}


## Printed after the key of every built day or set.
func _summary(puzzles: Array) -> String:
	return " par " + str(puzzles.map(func(p: Dictionary) -> Variant: return p.get("par")))


# --- commands ----------------------------------------------------------------------------------------------------

func _init() -> void:
	quit(_run(OS.get_cmdline_user_args()))


func _run(user_args: PackedStringArray) -> int:
	var args := {}
	for a in user_args:
		args[a.get_slice("=", 0).trim_prefix("--")] = a.get_slice("=", 1)
	if args.has("merge"):
		if not args.has("into") or str(args.merge).is_empty() or str(args.into).is_empty():
			return _usage()
		return _merge(str(args.merge), str(args.into))
	if not args.has("out") or str(args.out).is_empty():
		return _usage()
	var keys := [] # [key, seed texts builder args]
	if args.has("practice"):
		var count := int(args.practice)
		var start := int(args.get("start", "0"))
		if count < 1:
			return _usage()
		for i in range(start, start + count):
			keys.append([str(i), i, true])
	elif args.has("from"):
		var days := int(args.get("days", "1"))
		if not WhiteDaily.is_date(str(args.from)) or days < 1:
			return _usage()
		for d in days:
			var date := WhiteDaily.add_days(str(args.from), d)
			keys.append([date, date, false])
	else:
		return _usage()
	var out := {}
	for k in keys:
		var puzzles := []
		for level in _level_count():
			var s := WhiteSeed.practice(_game_id(), k[1], level) if k[2] else WhiteSeed.daily(_game_id(), k[1], level)
			puzzles.append(_generate(s, level))
		out[k[0]] = puzzles
		print(str(k[0]) + _summary(puzzles))
	return 0 if _write(str(args.out), out) else 1


func _usage() -> int:
	printerr(USAGE)
	return 1


func _write(path: String, data: Dictionary) -> bool:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		printerr("cannot write " + path)
		return false
	f.store_string(JSON.stringify(data, "", false) + "\n")
	f.close()
	return true


# JSON parsing gives floats for every number; whole ones go back to int so a rewrite keeps the original text
func _intify(v: Variant) -> Variant:
	if v is float and v == floorf(v) and absf(v) < 9007199254740992.0:
		return int(v)
	if v is Array:
		return (v as Array).map(_intify)
	if v is Dictionary:
		var out := {}
		for k in v:
			out[k] = _intify(v[k])
		return out
	return v


# json files: {} when missing; null when present but not a dictionary
func _read(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		return {}
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(path)) != OK or not json.data is Dictionary:
		return null
	return _intify(json.data)


func _merge(built_path: String, data_path: String) -> int:
	var built: Variant = _read(built_path)
	var data: Variant = _read(data_path)
	if built == null or not FileAccess.file_exists(built_path) or data == null:
		printerr("cannot read " + (built_path if built == null or not FileAccess.file_exists(built_path) else data_path))
		return 1
	var added := []
	var skipped := 0
	for key in built:
		if not data.has(key):
			added.append(key)
		elif JSON.stringify(data[key], "", true) == JSON.stringify(built[key], "", true):
			skipped += 1
		else:
			print("refused: %s differs from the published puzzle" % key)
			return 1
	for key in added:
		data[key] = built[key]
		print(str(key) + _summary(built[key]))
	if not added.is_empty() and not _write(data_path, data):
		return 1
	print("merged: %d added, %d unchanged" % [added.size(), skipped])
	return 0
