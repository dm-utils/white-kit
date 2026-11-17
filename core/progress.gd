class_name WhiteProgress
extends RefCounted
## The progress file, read so that a damaged file never stops the game and whatever is usable is kept.
## Format: {"lang": "nl", "days": {"2026-11-17": [{"record": "DRzUR", "time_ms": 41250, "solved": true}, ...]}}

const DEFAULT_PATH := "user://progress.json"


static func empty(default_lang: String) -> Dictionary:
	return {"lang": default_lang, "days": {}}


## Keeps what is usable per day and per level, drops the rest. "solved" is always false: replay derives it.
static func sanitize(data: Variant, languages: PackedStringArray, default_lang: String) -> Dictionary:
	var out := empty(default_lang)
	if not data is Dictionary:
		return out
	var d: Dictionary = data
	var lang: Variant = d.get("lang")
	if lang is String and languages.has(lang):
		out.lang = lang
	var days: Variant = d.get("days")
	if not days is Dictionary:
		return out
	for key in days:
		if key is String and days[key] is Array:
			var list := []
			for e in days[key]:
				var rec := ""
				var ms := 0
				if e is Dictionary:
					rec = e["record"] if e.get("record") is String else ""
					ms = maxi(0, int(e["time_ms"])) if e.get("time_ms") is float else 0
				list.append({"record": rec, "time_ms": ms, "solved": false})
			out.days[key] = list
	return out


## Empty structure when the file is missing or not JSON.
static func read(path: String, languages: PackedStringArray, default_lang: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return empty(default_lang)
	var json := JSON.new()
	# parse() returns an error code, unlike parse_string() it logs nothing
	if json.parse(FileAccess.get_file_as_string(path)) != OK:
		return empty(default_lang)
	return sanitize(json.data, languages, default_lang)


## False when the file cannot be opened.
static func write(path: String, data: Dictionary) -> bool:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(JSON.stringify(data))
	return true


static func entry(record: String, time_ms: int, solved: bool) -> Dictionary:
	return {"record": record, "time_ms": time_ms, "solved": solved}
