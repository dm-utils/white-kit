extends RefCounted
## Retest of 0.2.0 (independent): practice-only edge cases, runner child processes, range_int equivalence with the
## 0.1.0 formula, date handling against own calendar maths, threshold files.

const Screen := preload("res://addons/white_kit/tests/fixtures/fixture_screen.gd")
const FIX := "res://addons/white_kit/tests/fixtures/"
const MAX_I := 9223372036854775807
const MIN_I := -9223372036854775808

var _check: Callable
var _node: Node


func run(check: Callable, node: Node) -> void:
	_check = check
	_node = node
	WhiteText.lang = "nl"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Screen.SAVE))
	_practice_only_edges()
	_runner_edges()
	_range_equivalence()
	_dates_independent()
	_dates_no_engine_output()
	_thresholds()
	WhiteText.lang = "nl"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Screen.SAVE))


func _exec(scene: String, args: Array = []) -> Dictionary:
	var out := []
	var full := ["--headless", "--path", ProjectSettings.globalize_path("res://"), FIX + scene, "--"]
	full.append_array(args)
	var code := OS.execute(OS.get_executable_path(), full, out, true)
	return {"code": code, "out": "".join(out)}


# --- R3 -------------------------------------------------------------------------------------------------------------

func _open(practice_only: bool, debug := {}, store: WhitePuzzleStore = null) -> Screen:
	var s := Screen.new()
	s.practice_only = practice_only
	s._debug.merge(debug)
	s._debug["date"] = "2026-11-18"
	if store != null:
		s.store = store
	_node.add_child(s)
	return s


func _close(s: Screen) -> void:
	_node.remove_child(s)
	s.free()


func _practice_only_edges() -> void:
	# random practice index stays inside the set count, day never opened
	var seen := {}
	for i in 25:
		var s := _open(true)
		seen[s.practice_index] = true
		_check.call(s.practice and s.practice_index >= 0 and s.practice_index < s.store.practice_count(),
			"retest R3: practice index in range (run %d)" % i)
		_check.call(not s.mode_btn.visible, "retest R3: button hidden on open (run %d)" % i)
		_close(s)
	# no practice sets: no crash, button still hidden, no_puzzle shown
	var empty := WhitePuzzleStore.new(FIX + "does_not_exist.json", FIX + "does_not_exist.json", Callable())
	var e := _open(true, {}, empty)
	_check.call(e.practice and e.puzzles.is_empty() and not e.mode_btn.visible, "retest R3: no sets, button hidden")
	_check.call(e.message.text == WhiteText.t("no_puzzle"), "retest R3: no sets shows no_puzzle")
	e._toggle_mode()
	_check.call(e.practice and not e.mode_btn.visible, "retest R3: no sets, toggle ignored")
	_close(e)
	# hook flips at runtime: follows the hook
	var f := _open(true)
	f.practice_only = false
	f._refresh()
	_check.call(f.mode_btn.visible, "retest R3: hook false again shows button")
	f._toggle_mode()
	_check.call(not f.practice, "retest R3: hook false again allows toggle")
	f._toggle_mode()
	_check.call(f.practice and f.mode_btn.visible, "retest R3: toggle back to practice")
	_close(f)
	# default screen: toggle both ways, button text
	var d := _open(false)
	d._toggle_mode()
	_check.call(d.practice and d.mode_btn.visible, "retest R3: default toggles to practice")
	d._toggle_mode()
	_check.call(not d.practice and d.mode_btn.visible, "retest R3: default toggles back to the day")
	_close(d)
	# practice-only with --date far away and a saved day entry: save untouched
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Screen.SAVE))
	var p := _open(true)
	for lvl in 3:
		p._pick_level(lvl)
		for m in 3:
			p._on_move(1)
	p._toggle_lang()
	var txt := FileAccess.get_file_as_string(Screen.SAVE)
	_check.call(not txt.contains("2026-11-18") and not txt.contains("rec"), "retest R3: only language in save file")
	_close(p)
	WhiteText.lang = "nl"


# --- B1 -------------------------------------------------------------------------------------------------------------

func _runner_edges() -> void:
	var r := _exec("runner_await_error.tscn")
	_check.call(r.code == 1 and r.out.contains("tests: 2 passed, 2 failed"), "retest B1: errors after await counted (2)")
	_check.call(r.out.count("FAIL: script error:") == 2, "retest B1: two script error lines")

	var bad_values := ["", "abc", "-1", "1.5", "1e3", "0x10", " 5", "--", "5a"]
	for v in bad_values:
		r = _exec("runner_push_error.tscn", ["--min-checks=" + v])
		_check.call(r.code == 1 and r.out.contains("bad --min-checks value"), "retest B1: --min-checks='%s' fails" % v)
		_check.call(not r.out.contains("tests: 1 passed"), "retest B1: bad value '%s' runs no tests" % v)
	for v in ["0", "1", "00001"]:
		r = _exec("runner_push_error.tscn", ["--min-checks=" + v])
		_check.call(r.code == 0 and r.out.contains("tests: 1 passed, 0 failed"), "retest B1: --min-checks=%s ok" % v)
	# overflowing value saturates: not accepted as a threshold the run can meet
	r = _exec("runner_push_error.tscn", ["--min-checks=99999999999999999999"])
	_check.call(r.code == 1, "retest B1: overflowing --min-checks fails the run")
	r = _exec("runner_push_error.tscn", ["--min-checks"])
	_check.call(r.code == 0, "retest B1: bare --min-checks ignored")
	r = _exec("runner_push_error.tscn", ["--min-checks=1", "--min-checks=5"])
	_check.call(r.code == 1, "retest B1: later --min-checks=5 applies")
	# script error plus too few checks: both reported
	r = _exec("runner_script_error.tscn", ["--min-checks=50"])
	_check.call(r.code == 1 and r.out.contains("FAIL: script error:") and r.out.contains("only 3 checks ran"),
		"retest B1: script error and min-checks both reported")


# --- B2 -------------------------------------------------------------------------------------------------------------

func _old_range(r: WhiteRng, from: int, to: int) -> int:
	var n := to - from + 1
	if from > to or n > 4294967296:
		return from
	var limit := 4294967296 - (4294967296 % n)
	var v := r.next_u32()
	while v >= limit:
		v = r.next_u32()
	return from + v % n


func _range_equivalence() -> void:
	var w := 4294967295
	var ranges := [[0, 0], [0, 1], [-5, 5], [3, 9], [0, 99], [0, w - 1], [0, w], [1, w + 1], [-2147483648, 2147483647],
		[MAX_I - w, MAX_I], [MIN_I, MIN_I + w], [0, 3000000000], [4000000000, 4000001000], [-1, 0], [7, 7],
		[MAX_I, MAX_I], [MIN_I, MIN_I], [MAX_I - 1, MAX_I], [0, 2147483648], [0, 2863311530]]
	var same := true
	var draws := 0
	for seed in range(0, 40):
		var a := WhiteRng.new(seed)
		var b := WhiteRng.new(seed)
		for rg in ranges:
			for k in 3:
				var x := a.range_int(rg[0], rg[1])
				var y := _old_range(b, rg[0], rg[1])
				draws += 1
				if x != y or a.get_state() != b.get_state():
					same = false
	_check.call(same, "retest B2: valid ranges bit-identical to the 0.1.0 formula (%d draws, values and state)" % draws)
	# rejected ranges: same as before where 0.1.0 was defined, state untouched
	var rej := [[1, 0], [0, w + 1], [5, 4], [0, 4294967296], [MAX_I - 4294967296, MAX_I]]
	for rg in rej:
		var r := WhiteRng.new(9)
		var st := r.get_state()
		_check.call(r.range_int(rg[0], rg[1]) == rg[0] and r.get_state() == st, "retest B2: rejected %s untouched" % str(rg))
	# overflow variants must return fast (a hang would time the whole suite out)
	var o := WhiteRng.new(1)
	var t0 := Time.get_ticks_msec()
	for rg in [[0, MAX_I], [MIN_I, 0], [MIN_I, MAX_I], [-1, MAX_I], [MIN_I, MAX_I - 1], [MIN_I + 1, MAX_I], [-4611686018427387904, 4611686018427387904]]:
		_check.call(o.range_int(rg[0], rg[1]) == rg[0], "retest B2: overflow %s returns from" % str(rg))
	_check.call(Time.get_ticks_msec() - t0 < 2000, "retest B2: overflow ranges return immediately")


# --- B3 -------------------------------------------------------------------------------------------------------------

## Days since 1970-01-01 (civil-from-days algorithm, own maths, no engine time functions)
func _days_from_civil(y: int, m: int, d: int) -> int:
	y -= 1 if m <= 2 else 0
	var era := (y if y >= 0 else y - 399) / 400
	var yoe := y - era * 400
	var doy := (153 * (m + (-3 if m > 2 else 9)) + 2) / 5 + d - 1
	var doe := yoe * 365 + yoe / 4 - yoe / 100 + doy
	return era * 146097 + doe - 719468


func _dates_independent() -> void:
	var bad_is_date := 0
	var bad_number := 0
	var bad_add := 0
	var first := "1970-01-01"
	var base := _days_from_civil(1970, 1, 1)
	var prev := ""
	for y in range(1970, 2101):
		for m in range(1, 13):
			var last := _days_from_civil(y + (1 if m == 12 else 0), 1 if m == 12 else m + 1, 1) - _days_from_civil(y, m, 1)
			for d in range(1, last + 1):
				var s := "%04d-%02d-%02d" % [y, m, d]
				if not WhiteDaily.is_date(s):
					bad_is_date += 1
				if WhiteDaily.number(s, first) != _days_from_civil(y, m, d) - base + 1:
					bad_number += 1
				if prev != "" and WhiteDaily.add_days(prev, 1) != s:
					bad_add += 1
				prev = s
			# one past the last day of the month is no date
			if WhiteDaily.is_date("%04d-%02d-%02d" % [y, m, last + 1]):
				bad_is_date += 1
	_check.call(bad_is_date == 0, "retest B3: is_date exact over 1970..2100 (%d wrong)" % bad_is_date)
	_check.call(bad_number == 0, "retest B3: number matches own day count over 1970..2100 (%d wrong)" % bad_number)
	_check.call(bad_add == 0, "retest B3: add_days(+1) walks every day 1970..2100 (%d wrong)" % bad_add)
	_check.call(WhiteDaily.is_date("9999-12-31") and WhiteDaily.is_date("1970-01-01"), "retest B3: range ends valid")
	_check.call(not WhiteDaily.is_date("1969-12-31") and not WhiteDaily.is_date("0000-01-01"), "retest B3: before 1970 invalid")


func _dates_no_engine_output() -> void:
	var r := _exec("runner_invalid_dates.tscn")
	_check.call(r.code == 0 and r.out.contains("DONE-MARK"), "retest B3: invalid dates run to the end, exit 0")
	_check.call(r.out.contains("tests: 48 passed, 0 failed"), "retest B3: 48 invalid-date checks pass")
	_check.call(not r.out.contains("Invalid ISO") and not r.out.contains("Invalid month")
			and not r.out.contains("Invalid day") and not r.out.contains("Invalid"), "retest B3: no engine date error text")
	# every error line is a kit push_error
	var foreign := 0
	for line in r.out.split("\n"):
		if line.begins_with("ERROR:") and not line.begins_with("ERROR: WhiteDaily."):
			foreign += 1
	_check.call(foreign == 0, "retest B3: only WhiteDaily push_error lines (%d foreign)" % foreign)
	_check.call(r.out.count("ERROR: WhiteDaily.number") == 24 and r.out.count("ERROR: WhiteDaily.add_days") == 12,
		"retest B3: one push_error per rejected call (number 24, add_days 12)")


# --- B7 -------------------------------------------------------------------------------------------------------------

func _thresholds() -> void:
	var root := "res://addons/white_kit/"
	var thresholds := {}
	for f in [".github/workflows/ci.yml", "templates/ci.yml"]:
		var txt := FileAccess.get_file_as_string(root + f)
		var rx := RegEx.create_from_string("run_kit_tests\\.tscn -- --min-checks=(\\d+)")
		var m := rx.search(txt)
		thresholds[f] = int(m.get_string(1)) if m != null else -1
	_check.call(thresholds[".github/workflows/ci.yml"] >= 522, "retest B7: kit CI threshold >= 522")
	_check.call(thresholds["templates/ci.yml"] == thresholds[".github/workflows/ci.yml"], "retest B7: template equals kit CI")
	_check.call(FileAccess.get_file_as_string(root + "VERSION").strip_edges() == WhiteKit.VERSION, "retest B7: VERSION file equals constant")
