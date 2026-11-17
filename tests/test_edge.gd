extends RefCounted
## Edge cases and properties: attempt replay with random action sequences in both modes and both token widths,
## damaged progress input, text registration with other languages, damaged progress files on the shared screen.

const Counter := preload("res://addons/white_kit/tests/fixtures/counter_rules.gd")
const Wide := preload("res://addons/white_kit/tests/fixtures/wide_rules.gd")
const Screen := preload("res://addons/white_kit/tests/fixtures/fixture_screen.gd")

var _check: Callable
var _node: Node
var LANGS := PackedStringArray(["nl", "en"])


func run(check: Callable, node: Node) -> void:
	_check = check
	_node = node
	_attempt_properties()
	_attempt_edges()
	_progress_input()
	_text_languages()
	_screen_with_damaged_progress()


# --- attempt ------------------------------------------------------------------------------------------------------

func _random_session(rng: WhiteRng, rules: WhiteRules, mode: int) -> WhiteAttempt:
	var a := WhiteAttempt.new(rules, mode)
	for step in 40:
		var roll := rng.range_int(0, 9)
		if roll < 5:
			a.play(1)
		elif roll < 7:
			a.play(-1)
		elif roll < 9:
			a.undo()
		else:
			a.restart()
	return a


@warning_ignore("integer_division")
func _attempt_properties() -> void:
	var rng := WhiteRng.new(2027)
	var bad := ""
	var runs := 0
	for mode in [WhiteAttempt.CountMode.EVERY_MOVE, WhiteAttempt.CountMode.FINAL_ONLY]:
		for wide in [false, true]:
			for k in 150:
				var rules: WhiteRules = Wide.new() if wide else Counter.new()
				var a := _random_session(rng, rules, mode)
				var b := WhiteAttempt.new(Wide.new() if wide else Counter.new(), mode)
				b.apply_record(a.record)
				runs += 1
				if a.state != b.state or a.record != b.record or a.moves_made != b.moves_made or a.count() != b.count() \
						or a.history != b.history:
					bad = "replay differs for record " + a.record
					break
				var tokens := a.record.length()
				var undo_restart := a.record.count("z") + a.record.count("r")
				var moves: int = (tokens - undo_restart) / rules.move_len()
				if moves != a.moves_made:
					bad = "moves_made is not the number of move tokens in " + a.record
					break
				if mode == WhiteAttempt.CountMode.FINAL_ONLY and a.count() != a.history.size():
					bad = "final-only count is not the line length in " + a.record
					break
				if mode == WhiteAttempt.CountMode.EVERY_MOVE and a.count() != a.moves_made:
					bad = "every-move count is not moves_made in " + a.record
					break
				if a.solved() and (a.can_undo() or a.undo() or a.restart() or a.play(1)):
					bad = "something works after solving in " + a.record
					break
		if bad != "":
			break
	_check.call(bad == "", "random sessions replay identically and keep their counts (%d runs): %s" % [runs, bad])


func _attempt_edges() -> void:
	# the same record in both modes: same state and record, only count() differs
	var e := WhiteAttempt.new(Counter.new(), WhiteAttempt.CountMode.EVERY_MOVE)
	var f := WhiteAttempt.new(Counter.new(), WhiteAttempt.CountMode.FINAL_ONLY)
	e.apply_record("UUzUrUUDU")
	f.apply_record("UUzUrUUDU")
	_check.call(e.state == f.state and e.record == f.record and e.moves_made == f.moves_made, "the record does not depend on the count mode")
	_check.call(e.count() == 7 and f.count() == 4, "count per mode for the same record")

	# multi-character tokens with undo, restart and both modes
	var w := WhiteAttempt.new(Wide.new(), WhiteAttempt.CountMode.FINAL_ONLY)
	w.apply_record("A1UA1UzA1UrA1UA1D")
	_check.call(w.record == "A1UA1UzA1UrA1UA1D" and w.moves_made == 5 and w.count() == 2 and w.state == 0, "wide: undo and restart in final-only: " + w.record)
	w.apply_record("A1UA1UA1U")
	_check.call(w.solved() and w.count() == 5 and w.moves_made == 8, "wide: final-only count after solving")

	# a record that continues after the solved state is cut off there
	var s := WhiteAttempt.new(Counter.new())
	s.apply_record("UUUUUDzr")
	_check.call(s.record == "UUU" and s.moves_made == 3, "tokens after the solved state are ignored")

	# junk only, empty, non-ASCII, trailing partial token
	var j := WhiteAttempt.new(Counter.new())
	j.apply_record("?!  xyz é日\n\t09QW")
	_check.call(j.record == "" and j.moves_made == 0 and j.state == 0, "junk-only record changes nothing")
	var p := WhiteAttempt.new(Wide.new())
	p.apply_record("A1UA1")
	_check.call(p.record == "A1U" and p.moves_made == 1, "a trailing partial token is ignored")
	p.apply_record("é日A1U")
	_check.call(p.record == "A1UA1U", "multi-byte characters between tokens are skipped")
	p.apply_record("A1DA1DA1D")
	_check.call(p.record == "A1UA1UA1DA1D" and p.state == 0, "a rejected move inside a record is skipped, valid ones go on")

	# replaying an attempt's own record is stable (idempotent): record of the replay equals the input
	var rng := WhiteRng.new(8)
	var ok := true
	for k in 50:
		var a := _random_session(rng, Wide.new(), WhiteAttempt.CountMode.EVERY_MOVE)
		var b := WhiteAttempt.new(Wide.new())
		b.apply_record(a.record)
		var c := WhiteAttempt.new(Wide.new())
		c.apply_record(b.record)
		ok = ok and b.record == a.record and c.record == a.record
	_check.call(ok, "replaying a replayed record gives the same record")

	# a long record
	var long := WhiteAttempt.new(Counter.new())
	long.apply_record("UD".repeat(3000))
	_check.call(long.moves_made == 6000 and long.state == 0 and long.count() == 6000, "a long record replays")
	var long_f := WhiteAttempt.new(Counter.new(), WhiteAttempt.CountMode.FINAL_ONLY)
	long_f.apply_record("UD".repeat(3000))
	_check.call(long_f.count() == 6000 and long_f.state == 0, "final-only: a move back is a move, not an undo")


# --- progress -----------------------------------------------------------------------------------------------------

func _progress_input() -> void:
	var weird := {"lang": "nl", "days": {
		"a": [[], {}, "s", true, 1.5, null, {"record": ["U"], "time_ms": [1]}, {"record": "U", "time_ms": 123.9, "extra": 1}],
		"b": [],
		"c": {"x": 1},
		"d": 3,
	}}
	var s := WhiteProgress.sanitize(weird, LANGS, "nl")
	_check.call(s.days.keys() == ["a", "b"], "only list days survive")
	_check.call(s.days.a.size() == 8, "every element of a kept day becomes an entry")
	_check.call(s.days.a[7] == {"record": "U", "time_ms": 123, "solved": false}, "fractional time is cut, extra fields dropped")
	_check.call(s.days.a[6] == {"record": "", "time_ms": 0, "solved": false}, "list-typed fields are replaced")
	_check.call(s.days.b == [], "an empty day stays empty")
	# in memory the times are ints; only the file form (floats) is trusted, so idempotence holds through the file
	var through_file: Variant = JSON.parse_string(JSON.stringify(s))
	_check.call(WhiteProgress.sanitize(through_file, LANGS, "nl") == s, "sanitize is idempotent through the file form")

	var huge := WhiteProgress.sanitize({"days": {"a": [{"record": "U", "time_ms": 1e300}, {"record": "U", "time_ms": -1e300}]}}, LANGS, "nl")
	_check.call(huge.days.a[0].time_ms >= 0 and huge.days.a[1].time_ms == 0, "absurd times never become negative")
	var long_rec := "U".repeat(100000)
	_check.call(WhiteProgress.sanitize({"days": {"a": [{"record": long_rec}]}}, LANGS, "nl").days.a[0].record == long_rec, "a long record is kept whole")
	var many := {}
	for i in 2000:
		many["2027-01-%d" % i] = [{"record": "U", "time_ms": 1.0}]
	_check.call(WhiteProgress.sanitize({"days": many}, LANGS, "nl").days.size() == 2000, "many days are kept")

	var path := "user://white_kit_test_progress_edge.json"
	var cases := {"": "an empty file", "  \n": "a blank file", "null": "JSON null", "\"text\"": "a JSON string", "123": "a JSON number",
		"{\"days\":{\"a\":[{\"rec": "a truncated file", "{\"days\":{\"a\":[]}}garbage": "trailing garbage", "﻿{}": "a byte order mark",
		"[".repeat(2000): "very deep nesting", "{\"lang\":\"en\"}": "only a language"}
	for text in cases:
		var f := FileAccess.open(path, FileAccess.WRITE)
		f.store_string(text)
		f.close()
		var r := WhiteProgress.read(path, LANGS, "nl")
		_check.call(r.has("lang") and r.days is Dictionary and LANGS.has(r.lang), "read survives " + cases[text])
	var g := FileAccess.open(path, FileAccess.WRITE)
	g.store_string("{\"lang\":\"en\"}")
	g.close()
	_check.call(WhiteProgress.read(path, LANGS, "nl") == {"lang": "en", "days": {}}, "a file with only a language keeps it")

	# save, load, save again: stable bytes
	var data := WhiteProgress.empty("en")
	data.days["2027-01-01"] = [WhiteProgress.entry("UUzr", 4500, false), WhiteProgress.entry("", 0, false)]
	WhiteProgress.write(path, data)
	var first := FileAccess.get_file_as_string(path)
	WhiteProgress.write(path, WhiteProgress.read(path, LANGS, "nl"))
	_check.call(FileAccess.get_file_as_string(path) == first, "write, read, write gives the same file")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


# --- text ---------------------------------------------------------------------------------------------------------

func _text_languages() -> void:
	WhiteText.register({"fr": {"undo": "Annuler"}, "nl": {"count_final": "Regel: %d"}})
	WhiteText.lang = "nl"
	_check.call(WhiteText.languages() == PackedStringArray(["nl", "en", "fr"]), "a third language is listed after nl and en")
	_check.call(WhiteText.next_lang() == "en", "nl is followed by en")
	WhiteText.lang = "en"
	_check.call(WhiteText.next_lang() == "fr", "en is followed by fr")
	WhiteText.lang = "fr"
	_check.call(WhiteText.next_lang() == "nl" and WhiteText.t("undo") == "Annuler", "fr wraps to nl")
	_check.call(not WhiteText.has_key("restart"), "a new language has only its own keys")
	WhiteText.lang = "nl"
	_check.call(WhiteText.has_key("count_final"), "count_final in one language is found there")
	WhiteText.lang = "en"
	_check.call(not WhiteText.has_key("count_final"), "count_final is not found in a language that lacks it")
	WhiteText.lang = "xx"
	_check.call(not WhiteText.has_key("undo") and WhiteText.next_lang() == "nl", "an unknown current language gives no keys and goes on with nl")
	WhiteText.register({})
	WhiteText.lang = "nl"
	_check.call(WhiteText.languages() == PackedStringArray(["nl", "en"]), "register({}) goes back to the base languages")
	_check.call(WhiteText.BASE.keys() == ["nl", "en"], "BASE has no extra language after registrations")


# --- shared screen with damaged progress files ---------------------------------------------------------------------

func _write_save(text: String) -> void:
	var f := FileAccess.open(Screen.SAVE, FileAccess.WRITE)
	f.store_string(text)
	f.close()


func _open(date: String, setup: Callable = Callable()) -> Screen:
	var s := Screen.new()
	s._debug["date"] = date
	if setup.is_valid():
		setup.call(s)
	_node.add_child(s)
	return s


func _close(s: Screen) -> void:
	_node.remove_child(s)
	s.free()


func _screen_with_damaged_progress() -> void:
	WhiteText.register({})
	WhiteText.lang = "nl"
	var day := "2026-11-17"
	var cases := {
		"not json": "garbage",
		"empty": "",
		"list": "[1,2]",
		"day is a number": "{\"days\":{\"%s\":5}}" % day,
		"levels are junk": "{\"days\":{\"%s\":[7,null,\"x\"]}}" % day,
		"extra levels": "{\"days\":{\"%s\":[{\"record\":\"U\",\"time_ms\":10},{\"record\":\"\"},{\"record\":\"\"},{\"record\":\"UUU\"},{\"record\":\"UUU\"}]}}" % day,
		"one level": "{\"days\":{\"%s\":[{\"record\":\"UU\",\"time_ms\":10}]}}" % day,
		"record with junk": "{\"days\":{\"%s\":[{\"record\":\"x?UQUzzzUU9 UUU\",\"time_ms\":10}]}}" % day,
		"wrong types": "{\"days\":{\"%s\":[{\"record\":5,\"time_ms\":\"x\"}]},\"lang\":7}" % day,
	}
	for name in cases:
		_write_save(cases[name])
		var s := _open(day)
		_check.call(s.attempts.size() == 3 and s.puzzles.size() == 3, "screen opens with a damaged progress file: " + name)
		_check.call(s.level >= 0 and s.level < 3 and s.counter.text.begins_with("Zetten: "), "screen shows a level after: " + name)
		s._on_move(1)
		_check.call(JSON.parse_string(FileAccess.get_file_as_string(Screen.SAVE)) is Dictionary, "the progress file is valid JSON again after a move: " + name)
		_close(s)
	_write_save(cases["extra levels"])
	var x := _open(day)
	_check.call(x.attempts[0].record == "U" and x.attempts[1].record == "" and x.attempts[2].record == "", "extra levels in the file are ignored")
	_close(x)
	_write_save(cases["one level"])
	var o := _open(day)
	_check.call(o.attempts[0].record == "UU" and o.attempts[1].record == "" and o.times[0] == 10, "missing levels are filled, time is restored")
	_close(o)
	_write_save(cases["record with junk"])
	var j := _open(day)
	_check.call(j.attempts[0].record == "UUzzUUU" and j.attempts[0].solved() and j.level == 1, "junk in a saved record is skipped on replay")
	_close(j)
	# a solved level written by hand is derived as solved by replay, the stored flag is not trusted
	_write_save("{\"days\":{\"%s\":[{\"record\":\"UU\",\"solved\":true}]}}" % day)
	var t := _open(day)
	_check.call(not t.attempts[0].solved() and t.level == 0, "the stored solved flag is not trusted")
	_close(t)

	# count_final in one language only: used there, not in the other
	_write_save("")
	var c := _open(day, func(x: Screen) -> void: x.final_practice = true)
	c._toggle_mode()
	c._on_move(1)
	WhiteText.register({"nl": {"count_final": "Regel: %d"}})
	c._refresh()
	_check.call(c.counter.text == "Regel: 1", "count_final is used in the language that has it: " + c.counter.text)
	c._toggle_lang()
	_check.call(c.counter.text == "Moves: 1", "the other language falls back to count: " + c.counter.text)
	_close(c)
	WhiteText.register({})
	WhiteText.lang = "nl"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Screen.SAVE))
