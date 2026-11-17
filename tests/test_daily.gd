extends RefCounted

const FIRST := "2026-11-17"


func run(check: Callable, _node: Node) -> void:
	# winter: UTC+1, summer: UTC+2; switch at 01:00 UTC on the last Sunday of March and October
	var t := Time.get_unix_time_from_datetime_string("2027-01-15T23:30:00")
	check.call(WhiteDaily.date_at(t) == "2027-01-16", "23:30 UTC in winter is already the next Dutch day")
	t = Time.get_unix_time_from_datetime_string("2027-07-15T21:30:00")
	check.call(WhiteDaily.date_at(t) == "2027-07-15", "21:30 UTC in summer is still the same Dutch day")
	t = Time.get_unix_time_from_datetime_string("2027-07-15T22:00:00")
	check.call(WhiteDaily.date_at(t) == "2027-07-16", "22:00 UTC in summer is the next Dutch day")
	# 2027: DST starts Sunday 28 March, ends Sunday 31 October
	var before := Time.get_unix_time_from_datetime_string("2027-03-28T00:59:59")
	var after := Time.get_unix_time_from_datetime_string("2027-03-28T01:00:00")
	check.call(WhiteDaily.nl_offset(before) == 3600 and WhiteDaily.nl_offset(after) == 7200, "DST starts at 01:00 UTC")
	before = Time.get_unix_time_from_datetime_string("2027-10-31T00:59:59")
	after = Time.get_unix_time_from_datetime_string("2027-10-31T01:00:00")
	check.call(WhiteDaily.nl_offset(before) == 7200 and WhiteDaily.nl_offset(after) == 3600, "DST ends at 01:00 UTC")
	t = Time.get_unix_time_from_datetime_string("2027-03-27T23:00:00")
	check.call(WhiteDaily.date_at(t) == "2027-03-28", "midnight before the spring switch is 23:00 UTC")
	t = Time.get_unix_time_from_datetime_string("2027-03-28T22:00:00")
	check.call(WhiteDaily.date_at(t) == "2027-03-29", "midnight after the spring switch is 22:00 UTC")
	t = Time.get_unix_time_from_datetime_string("2027-10-30T22:00:00")
	check.call(WhiteDaily.date_at(t) == "2027-10-31", "midnight before the autumn switch is 22:00 UTC")
	t = Time.get_unix_time_from_datetime_string("2027-10-31T23:00:00")
	check.call(WhiteDaily.date_at(t) == "2027-11-01", "midnight after the autumn switch is 23:00 UTC")
	check.call(WhiteDaily.is_date(WhiteDaily.today()), "today is a valid date")

	check.call(WhiteDaily.number(FIRST, FIRST) == 1, "first day is number 1")
	check.call(WhiteDaily.number("2026-11-18", FIRST) == 2, "next day is number 2")
	check.call(WhiteDaily.number("2026-11-16", FIRST) == 0, "day before the first is 0")
	check.call(WhiteDaily.number("2027-11-17", FIRST) == 366, "a year later is number 366")
	check.call(WhiteDaily.number("2027-03-29", "2027-03-27") == 3, "number counts calendar days over a DST switch")

	check.call(WhiteDaily.add_days("2028-02-28", 1) == "2028-02-29", "leap day exists")
	check.call(WhiteDaily.add_days("2026-12-31", 1) == "2027-01-01", "year rolls over")
	check.call(WhiteDaily.add_days("2027-03-01", -1) == "2027-02-28", "going back over a month end")
	check.call(WhiteDaily.add_days("2027-03-28", 1) == "2027-03-29", "add_days over the spring switch")
	check.call(WhiteDaily.add_days("2027-10-31", 1) == "2027-11-01", "add_days over the autumn switch")
	check.call(WhiteDaily.is_date("2026-02-30") == false, "30 February is no date")
	check.call(WhiteDaily.is_date("2026-11-17") == true, "a real date")
	check.call(WhiteDaily.is_date("2026-11-7") == false, "day needs two digits")
	check.call(WhiteDaily.is_date("2026/11/17") == false, "wrong separator")
	check.call(WhiteDaily.is_date("") == false, "empty text is no date")
	check.call(WhiteDaily.is_date("2026-13-01") == false, "month 13 is no date")
