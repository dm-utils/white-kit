extends RefCounted


func run(check: Callable, _node: Node) -> void:
	_text(check)
	_format(check)


func _text(check: Callable) -> void:
	WhiteText.register({})
	WhiteText.lang = "nl"
	check.call(WhiteText.BASE["nl"].keys() == WhiteText.BASE["en"].keys(), "base texts have the same keys in both languages")
	check.call(WhiteText.languages() == PackedStringArray(["nl", "en"]), "languages, nl first")
	check.call(WhiteText.has_lang("en") and not WhiteText.has_lang("fr"), "has_lang")
	check.call(WhiteText.t("undo") == "Terug", "base text in Dutch")
	check.call(WhiteText.next_lang() == "en", "next language after nl")
	WhiteText.lang = "en"
	check.call(WhiteText.next_lang() == "nl", "next language wraps")
	check.call(not WhiteText.has_key("nope"), "unknown key is not found")
	check.call(WhiteText.t("nope") == "nope", "t of an unknown key returns the key")

	WhiteText.register({"nl": {"undo": "Herstel", "custom": "Eigen"}, "en": {"undo": "Revert", "custom": "Own"}})
	check.call(WhiteText.t("undo") == "Revert", "game text overrides a base key (en)")
	WhiteText.lang = "nl"
	check.call(WhiteText.t("undo") == "Herstel", "game text overrides a base key (nl)")
	check.call(WhiteText.has_key("custom") and WhiteText.t("custom") == "Eigen", "a new game key is found")
	check.call(WhiteText.t("restart") == "Opnieuw", "base keys the game does not define remain")
	check.call(WhiteText.BASE["nl"]["undo"] == "Terug", "BASE itself is not changed")
	WhiteText.register({"nl": {"other": "x"}})
	check.call(not WhiteText.has_key("custom"), "register replaces earlier registrations")
	check.call(WhiteText.languages() == PackedStringArray(["nl", "en"]), "languages from the merged table")
	WhiteText.register({})
	WhiteText.lang = "nl"


func _format(check: Callable) -> void:
	check.call(WhiteFormat.clock(0) == "0:00", "clock 0")
	check.call(WhiteFormat.clock(61999) == "1:01", "clock 61999")
	check.call(WhiteFormat.clock(3600000) == "60:00", "minutes are not wrapped")
	check.call(WhiteFormat.clock(-5) == "0:00", "negative clock is 0:00")
	check.call(WhiteFormat.slash_list([3, null, 5]) == "3/-/5", "slash list with a missing value")
	check.call(WhiteFormat.slash_list([null], "?") == "?", "custom missing text")
	var line := WhiteFormat.day_line("White Shift #%d · %s vegen (par %s)", 4, [5, null, 12], [5, 9, 14])
	check.call(line == "White Shift #4 · 5/-/12 vegen (par 5/9/14)", "day line")
	check.call(WhiteFormat.day_line(WhiteText.BASE["en"]["share_line"], 1, [null, null, null], [4, 8, 13]) == "White #1 · -/-/- moves (par 4/8/13)", "day line with nothing solved")
