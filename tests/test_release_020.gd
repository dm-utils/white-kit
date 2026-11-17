extends RefCounted
## 0.2.0: practice-only hook, runner counting script errors, range_int overflow, invalid dates.

const Screen := preload("res://addons/white_kit/tests/fixtures/fixture_screen.gd")
const FIX := "res://addons/white_kit/tests/fixtures/"

var _check: Callable
var _node: Node


func run(check: Callable, node: Node) -> void:
	_check = check
	_node = node
	WhiteText.lang = "nl"
	_clean()
	_practice_only()
	_runner()
	_range_overflow()
	_invalid_dates()
	WhiteText.lang = "nl"
	_clean()


func _clean() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Screen.SAVE))


func _open(practice_only: bool, debug := {}) -> Screen:
	var s := Screen.new()
	s.practice_only = practice_only
	s._debug.merge(debug)
	s._debug["date"] = "2026-11-17"
	_node.add_child(s)
	return s


func _close(s: Screen) -> void:
	_node.remove_child(s)
	s.free()


# --- R3 -------------------------------------------------------------------------------------------------------------

func _practice_only() -> void:
	var d := _open(false)
	_check.call(d.mode_btn.visible and not d.practice, "default: mode button visible, day open")
	_close(d)

	var s := _open(true)
	_check.call(s.practice and not s.mode_btn.visible, "practice only: opens practice, mode button hidden")
	_check.call(s.subtitle.text.begins_with(WhiteText.t("practice")), "practice only: practice subtitle")
	var before: Array = s.puzzles
	s._toggle_mode()
	_check.call(s.practice and s.puzzles == before, "practice only: toggle ignored")
	_check.call(not s.share_btn.visible, "practice only: share hidden")
	for i in 3:
		s._pick_level(i)
		for m in 3:
			s._on_move(1)
	_check.call(s.attempts[2].solved(), "practice only: levels solvable")
	_check.call(not FileAccess.file_exists(Screen.SAVE), "practice only: nothing saved")
	var idx: int = s.practice_index
	s._next()
	_check.call(s.practice_index == idx + 1 and s.level == 0, "practice only: next opens the next set")
	_check.call(not s.mode_btn.visible, "practice only: button hidden after next")
	s._toggle_lang()
	_check.call(not s.mode_btn.visible, "practice only: button hidden after language toggle")
	_check.call(FileAccess.file_exists(Screen.SAVE) and not FileAccess.get_file_as_string(Screen.SAVE).contains("2026-11-17"),
		"practice only: language saved, no day entry")
	_close(s)

	var p := _open(true, {"practice": "1"})
	_check.call(p.practice and p.practice_index == 0, "practice only with --practice: set 0")
	_close(p)
	WhiteText.lang = "nl"


# --- B1 -------------------------------------------------------------------------------------------------------------

func _exec(scene: String, args: Array = []) -> Dictionary:
	var out := []
	var full := ["--headless", "--path", ProjectSettings.globalize_path("res://"), FIX + scene, "--"]
	full.append_array(args)
	var code := OS.execute(OS.get_executable_path(), full, out, true)
	return {"code": code, "out": "".join(out)}


func _runner() -> void:
	var r := _exec("runner_script_error.tscn")
	_check.call(r.code == 1, "runner: script error gives exit 1")
	_check.call(r.out.contains("tests: 2 passed, 1 failed"), "runner: script error counted as failed")
	_check.call(r.out.contains("FAIL: script error:"), "runner: script error line printed")

	r = _exec("runner_push_error.tscn")
	_check.call(r.code == 0 and r.out.contains("tests: 1 passed, 0 failed"), "runner: push_error not counted")

	r = _exec("runner_parse_error.tscn")
	_check.call(r.code == 1 and r.out.contains("FAIL: script error:"), "runner: parse error fails the run")

	r = _exec("runner_push_error.tscn", ["--min-checks=abc"])
	_check.call(r.code == 1 and r.out.contains("bad --min-checks value"), "runner: non-numeric --min-checks fails")
	r = _exec("runner_push_error.tscn", ["--min-checks=-3"])
	_check.call(r.code == 1, "runner: negative --min-checks fails")
	r = _exec("runner_push_error.tscn", ["--min-checks=1"])
	_check.call(r.code == 0, "runner: --min-checks met")
	r = _exec("runner_push_error.tscn", ["--min-checks=2"])
	_check.call(r.code == 1 and r.out.contains("only 1 checks ran"), "runner: --min-checks not met fails")


# --- B2 -------------------------------------------------------------------------------------------------------------

func _range_overflow() -> void:
	var max_i := 9223372036854775807
	var min_i := -9223372036854775808
	var rng := WhiteRng.new(5)
	var before := rng.get_state()
	_check.call(rng.range_int(0, max_i) == 0, "range_int: 0..int64 max returns from")
	_check.call(rng.range_int(min_i, 0) == min_i, "range_int: int64 min..0 returns from")
	_check.call(rng.range_int(min_i, max_i) == min_i, "range_int: full int64 range returns from")
	_check.call(rng.range_int(-1, max_i) == -1, "range_int: span 2^63 returns from")
	_check.call(rng.get_state() == before, "range_int: overflow draws nothing")
	var v := rng.range_int(max_i - 4294967295, max_i)
	_check.call(v >= max_i - 4294967295 and v <= max_i, "range_int: widest valid range next to int64 max")
	v = rng.range_int(min_i, min_i + 4294967295)
	_check.call(v >= min_i and v <= min_i + 4294967295, "range_int: widest valid range at int64 min")
	_check.call(rng.range_int(max_i - 4294967296, max_i) == max_i - 4294967296, "range_int: 2^32 + 1 values rejected")


# --- B3 -------------------------------------------------------------------------------------------------------------

func _invalid_dates() -> void:
	for bad in ["garbage", "2026-13-45", "", "2026-02-30", "1969-12-31", "2026-1-1"]:
		_check.call(WhiteDaily.number(bad, "2026-11-17") == 0, "number: invalid date '%s' gives 0" % bad)
		_check.call(WhiteDaily.number("2026-11-17", bad) == 0, "number: invalid first day '%s' gives 0" % bad)
		_check.call(WhiteDaily.add_days(bad, 3) == bad, "add_days: invalid date '%s' returned unchanged" % bad)
	_check.call(WhiteDaily.number("2026-11-17", "2026-11-17") == 1, "number: valid dates unchanged")
	_check.call(WhiteDaily.number("2026-11-16", "2026-11-17") == 0, "number: day before is 0")
	_check.call(WhiteDaily.add_days("2026-02-28", 1) == "2026-03-01", "add_days: valid date unchanged")
	_check.call(WhiteDaily.is_date("2000-02-29") and not WhiteDaily.is_date("2100-02-29"), "is_date: leap years")
