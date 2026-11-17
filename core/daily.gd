class_name WhiteDaily
extends RefCounted
## The puzzle day: the date in the Netherlands (CET/CEST), worked out from the device clock without network, so
## everyone gets the new puzzles at the same moment.


## Offset of Dutch time from UTC at a unix time: +2 h from the last Sunday of March 01:00 UTC to the last Sunday of
## October 01:00 UTC (EU rule), +1 h otherwise.
static func nl_offset(unix: int) -> int:
	var year: int = Time.get_datetime_dict_from_unix_time(unix).year
	var start := _last_sunday(year, 3) + 3600
	var end := _last_sunday(year, 10) + 3600
	return 7200 if unix >= start and unix < end else 3600


static func _last_sunday(year: int, month: int) -> int:
	var t := Time.get_unix_time_from_datetime_dict(
		{"year": year, "month": month, "day": 31, "hour": 0, "minute": 0, "second": 0})
	var wd: int = Time.get_datetime_dict_from_unix_time(t).weekday # 0 = Sunday
	return t - wd * 86400


## "YYYY-MM-DD" in the Netherlands at a unix time.
static func date_at(unix: int) -> String:
	return Time.get_date_string_from_unix_time(unix + nl_offset(unix))


static func today() -> String:
	return date_at(int(Time.get_unix_time_from_system()))


## Puzzle number of a date; first_day is #1, the day before is 0.
static func number(date: String, first_day: String) -> int:
	var a := Time.get_unix_time_from_datetime_string(first_day + "T00:00:00")
	var b := Time.get_unix_time_from_datetime_string(date + "T00:00:00")
	return int(round((b - a) / 86400.0)) + 1


## Calendar arithmetic via 12:00 UTC of the date, so no day is skipped or doubled.
static func add_days(date: String, days: int) -> String:
	var noon := Time.get_unix_time_from_datetime_string(date + "T12:00:00")
	return Time.get_date_string_from_unix_time(noon + days * 86400)


## Exactly "YYYY-MM-DD" and a real calendar date.
static func is_date(text: String) -> bool:
	if text.length() != 10:
		return false
	for i in 10:
		var c := text.unicode_at(i)
		if i == 4 or i == 7:
			if c != 45:
				return false
		elif c < 48 or c > 57:
			return false
	# check the parts first: Time prints an engine error for an impossible date
	var year := int(text.substr(0, 4))
	var month := int(text.substr(5, 2))
	var day := int(text.substr(8, 2))
	if year < 1970 or month < 1 or month > 12 or day < 1:
		return false
	var leap := year % 4 == 0 and (year % 100 != 0 or year % 400 == 0)
	var last: int = [31, 29 if leap else 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31][month - 1]
	return day <= last and add_days(text, 0) == text
