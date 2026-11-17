class_name WhiteFormat
extends RefCounted
## Clock and share line formatting.


## "m:ss", minutes not wrapped; negative gives "0:00".
@warning_ignore("integer_division")
static func clock(ms: int) -> String:
	var s := maxi(0, ms) / 1000
	return "%d:%02d" % [s / 60, s % 60]


## null shows as `missing`, other values via str(), joined by "/".
static func slash_list(values: Array, missing: String = "-") -> String:
	var a := PackedStringArray()
	for v in values:
		a.append(missing if v == null else str(v))
	return "/".join(a)


## One line for all puzzles of a day, without the solution: template % [number, counts, pars].
static func day_line(template: String, number: int, counts: Array, pars: Array) -> String:
	return template % [number, slash_list(counts), slash_list(pars)]
