extends WhiteTestRunner
## Fixture: invalid dates through WhiteDaily; output is inspected for engine errors by the caller


func _run() -> void:
	for bad in ["garbage", "2026-13-45", "", "2026-02-30", "1969-12-31", "2026-1-1", "0000-00-00", "9999-99-99",
			"2026-11-17T00:00:00", "٢٠٢٦-١١-١٧", "2026/11/17", "2026-11-17 "]:
		check(WhiteDaily.number(bad, "2026-11-17") == 0, "number " + bad)
		check(WhiteDaily.number("2026-11-17", bad) == 0, "number first " + bad)
		check(WhiteDaily.add_days(bad, -7) == bad, "add_days " + bad)
		check(not WhiteDaily.is_date(bad), "is_date " + bad)
	print("DONE-MARK")
