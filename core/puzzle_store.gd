class_name WhitePuzzleStore
extends RefCounted
## Precomputed puzzles shipped with a game: a daily file keyed by date and a practice file keyed "0", "1", ...
## Both are {"<key>": [puzzle per level]}. The game passes a callable that converts one raw puzzle dictionary.

static var _cache := {}

var _daily_path: String
var _practice_path: String
var _convert: Callable


func _init(daily_path: String, practice_path: String, convert: Callable) -> void:
	_daily_path = daily_path
	_practice_path = practice_path
	_convert = convert


## Parsed JSON file by path, cached; {} when missing, unreadable, not JSON or not a dictionary.
static func load_json(path: String) -> Dictionary:
	if not _cache.has(path):
		var data := {}
		if FileAccess.file_exists(path):
			var json := JSON.new()
			# parse() returns an error code, unlike parse_string() it logs nothing
			if json.parse(FileAccess.get_file_as_string(path)) == OK and json.data is Dictionary:
				data = json.data
		_cache[path] = data
	return _cache[path]


static func clear_cache() -> void:
	_cache.clear()


func _convert_list(list: Variant) -> Array:
	if not list is Array:
		return []
	if not _convert.is_valid():
		return (list as Array).duplicate()
	return (list as Array).map(_convert)


func has_day(date: String) -> bool:
	return load_json(_daily_path).has(date)


## Converted puzzles of a day; [] when missing.
func day(date: String) -> Array:
	return _convert_list(load_json(_daily_path).get(date))


## Sorted dates of the daily file.
func days() -> PackedStringArray:
	var out := PackedStringArray()
	for k in load_json(_daily_path).keys():
		out.append(str(k))
	out.sort()
	return out


func practice_count() -> int:
	return load_json(_practice_path).size()


## Set at position posmod(index, count) in the file's key order; [] when there are none.
func practice_set(index: int) -> Array:
	var pool := load_json(_practice_path)
	if pool.is_empty():
		return []
	var keys := pool.keys()
	return _convert_list(pool[keys[posmod(index, keys.size())]])


func practice(index: int, level: int) -> Dictionary:
	var set := practice_set(index)
	if level < 0 or level >= set.size() or not set[level] is Dictionary:
		return {}
	return set[level]
