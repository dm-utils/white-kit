extends RefCounted

const Screen := preload("res://addons/white_kit/tests/fixtures/fixture_screen.gd")

var _check: Callable
var _node: Node
var _events := []
var _solved := []


func _clean() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Screen.SAVE))


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


func _key(code: Key) -> InputEventKey:
	var e := InputEventKey.new()
	e.keycode = code
	e.pressed = true
	return e


func run(check: Callable, node: Node) -> void:
	_check = check
	_node = node
	WhiteText.lang = "nl"
	_clean()
	_day_flow()
	_extras_and_share()
	_no_puzzle()
	_practice_and_count_modes()
	_play_message_hook()
	_keys_and_language()
	WhiteText.register({})
	WhiteText.lang = "nl"
	_clean()


func _day_flow() -> void:
	var s := _open("2026-11-17")
	_check.call(s.attempts.size() == 3 and s.level == 0 and not s.practice, "a day opens with three attempts on level 0")
	_check.call(s.title.text == "FIXTURE" and s.subtitle.text == "Dagpuzzel #1", "title and puzzle number")
	_check.call(s.message.text == WhiteText.t("hint"), "start hint before the first move")
	_check.call(s.counter.text == "Zetten: 0" and s.par_label.text == "Par: 3", "counter and par")
	_check.call(s.tabs.size() == 3 and s.tabs[0].button_pressed and s.tabs[0].text == "Makkelijk", "tabs")
	_check.call(s.undo_btn.visible and s.undo_btn.disabled and s.restart_btn.disabled, "undo and restart disabled at the start")
	_check.call(not s.share_btn.visible and not s.next_btn.visible, "share and next hidden before solving")
	_check.call(s.shown.size() == 1, "view_show is called when a level is shown")
	s.progress_saved.connect(func() -> void: _events.append("saved"))
	s.attempt_solved.connect(func(l: int, c: int) -> void: _solved.append([l, c]))
	s._on_move(1)
	_check.call(s.counter.text == "Zetten: 1" and s.message.text == "", "a move updates the counter and clears the hint")
	_check.call(s.updates == 1 and _events == ["saved"], "view_update and progress_saved after a move")
	_check.call(FileAccess.file_exists(Screen.SAVE), "the progress file is written")
	s._on_move(-1)
	s._on_move(-1)
	_check.call(s.attempts[0].record == "UD", "a rejected move is not recorded")
	s._on_undo()
	_check.call(s.attempts[0].state == 1 and s.counter.text == "Zetten: 2", "undo keeps the every-move count")
	s._on_restart()
	_check.call(s.attempts[0].state == 0 and s.restart_btn.visible, "restart goes back to the start")
	s._on_move(1)
	s._on_move(1)
	_check.call(not s.next_btn.visible, "next hidden while unsolved")
	s._on_move(1)
	_check.call(s.attempts[0].solved() and s.attempts[0].record == "UDzrUUU", "solved record")
	_check.call(s.message.text.begins_with("Opgelost in 5 zetten (par 3) · "), "solved message: " + s.message.text)
	_check.call(s.tabs[0].text == "Makkelijk · 5", "solved tab shows the count")
	_check.call(s.share_btn.visible and s.next_btn.visible and not s.undo_btn.visible, "buttons after solving")
	_check.call(_solved == [[0, 5]], "attempt_solved reports level and count")
	s._on_move(1)
	_check.call(s.attempts[0].record == "UDzrUUU", "input after solving is ignored")
	var saved := FileAccess.get_file_as_string(Screen.SAVE)
	s._next()
	_check.call(s.level == 1, "next goes to the next level")
	s._on_move(1)
	_check.call(s._save.days["2026-11-17"][1].record == "U", "the second level is saved")
	_close(s)

	var r := _open("2026-11-17")
	_check.call(r.level == 1 and r.attempts[0].solved() and r.attempts[0].record == "UDzrUUU", "reload opens on the first unsolved level with the same state")
	_check.call(r.attempts[1].record == "U" and r.attempts[1].state == 1, "reload restores a running level")
	_check.call(r.tabs[0].text == "Makkelijk · 5", "reload shows the solved tab")
	r._pick_level(0)
	_check.call(r.level == 0 and r.message.text.begins_with("Opgelost"), "a solved level can be viewed again")
	r._pick_level(7)
	_check.call(r.level == 0, "a level beyond the puzzles only refreshes")
	_close(r)
	_check.call(saved.begins_with("{") and saved.contains("UDzrUUU"), "the saved file holds the record")


func _extras_and_share() -> void:
	var s := _open("2026-11-17")
	var seen := [0]
	s.refreshed.connect(func() -> void: seen[0] += 1)
	var extra: Button = s._extra[0]
	_check.call(not extra.visible, "extra button hidden on an unsolved level")
	s._pick_level(0)
	_check.call(extra.visible, "extra button visible on a solved level")
	_check.call(seen[0] > 0, "refreshed is emitted")
	var row: Node = s.undo_btn.get_parent()
	_check.call(row.get_child(2) == extra and row.get_child(3) == s.share_btn, "extra buttons sit after restart")
	s._share()
	_check.call(s.message.text.begins_with("White #1 · 5/-/- zetten (par 3/3/3)"), "share line: " + s.message.text)
	_close(s)
	_clean()


func _no_puzzle() -> void:
	var s := _open("2027-02-01")
	_check.call(s.puzzles.is_empty() and s.attempts.is_empty() and s.cleared >= 1, "a day without puzzles is empty and clears the view")
	_check.call(s.message.text == WhiteText.t("no_puzzle") and s.counter.text == "", "no-puzzle message")
	_check.call(not s.undo_btn.visible and not s.next_btn.visible and not s._extra[0].visible, "action buttons hidden without puzzles")
	s._on_move(1)
	s._on_undo()
	s._on_restart()
	s._unhandled_input(_key(KEY_UP))
	s._next()
	s._pick_level(1)
	s._share()
	_check.call(s.attempts.is_empty(), "input without puzzles does nothing")
	s._toggle_mode()
	_check.call(s.practice and s.puzzles.size() == 3, "practice works on a day without puzzles")
	_close(s)
	_clean()


func _practice_and_count_modes() -> void:
	var s := _open("2026-11-17")
	s._toggle_mode()
	_clean()
	_check.call(s.practice and s.attempts.size() == 3 and s.subtitle.text.begins_with("Oefenen "), "practice opens")
	_check.call(s.mode_btn.text == "Vandaag", "the mode button leads back to the day")
	s._on_move(1)
	_check.call(not FileAccess.file_exists(Screen.SAVE), "practice is not saved")
	s._toggle_mode()
	_check.call(not s.practice and s.attempts[0].moves_made == 0, "back to the day")
	s._toggle_mode()
	var idx := s.practice_index
	s._on_move(1)
	s._on_move(1)
	s._on_move(1)
	s._next()
	s._on_move(1)
	s._on_move(1)
	s._on_move(1)
	s._next()
	s._on_move(1)
	s._on_move(1)
	s._on_move(1)
	_check.call(s.next_btn.visible and not s.share_btn.visible, "next shown in practice, share hidden")
	s._next()
	_check.call(s.practice_index == idx + 1 and s.level == 0 and s.attempts[0].moves_made == 0, "next on the last practice level opens the next set")
	_close(s)

	var f := _open("2026-11-17", func(x: Screen) -> void: x.final_practice = true)
	_check.call(f.attempts[0].mode == WhiteAttempt.CountMode.EVERY_MOVE, "daily attempts count every move")
	f._toggle_mode()
	f._on_move(1)
	f._on_move(1)
	f._on_undo()
	_check.call(f.attempts[0].mode == WhiteAttempt.CountMode.FINAL_ONLY and f.counter.text == "Zetten: 1", "final-only practice shows the line length without a count_final text")
	f._on_move(1)
	f._on_move(1)
	_check.call(f.message.text.begins_with("Opgelost in 3 zetten (par 3)") and f.message.text.contains("Precies par!"), "perfect in final-only: " + f.message.text)
	_close(f)

	var g := _open("2026-11-17", func(x: Screen) -> void:
		x.final_practice = true
		x.count_final_text = "Zetten in je oplossing: %d")
	g._on_move(1)
	_check.call(g.counter.text == "Zetten: 1", "an every-move attempt always uses count")
	g._toggle_mode()
	g._on_move(1)
	_check.call(g.counter.text == "Zetten in je oplossing: 1", "a final-only attempt uses count_final when defined")
	_close(g)
	_clean()


func _play_message_hook() -> void:
	var d := _open("2026-11-17")
	_check.call(d.message.text == WhiteText.t("hint"), "default hook: hint before the first move")
	d._on_move(1)
	_check.call(d.message.text == "", "default hook: empty after a move")
	_close(d)
	_clean()
	var s := _open("2026-11-17", func(x: Screen) -> void: x.play_message_state = 2)
	s._on_move(1)
	_check.call(s.message.text == "", "play message not shown at another state")
	s._on_move(1)
	_check.call(s.message.text == "NOMOVE", "play message shown at its state")
	s._on_undo()
	_check.call(s.message.text == "", "an empty play message falls back to the standard text")
	s._on_move(1)
	s._on_move(1)
	_check.call(s.attempts[0].solved() and s.message.text.begins_with("Opgelost"), "the solved message wins over the play message")
	_close(s)
	_clean()
	var z := _open("2026-11-17", func(x: Screen) -> void: x.play_message_state = 0)
	_check.call(z.message.text == "NOMOVE", "the play message also replaces the hint before any move")
	_close(z)
	_clean()


func _keys_and_language() -> void:
	var s := _open("2026-11-17")
	s._unhandled_input(_key(KEY_UP))
	_check.call(s.attempts[0].record == "U", "a game key gives a move")
	s._unhandled_input(_key(KEY_Z))
	_check.call(s.attempts[0].record == "Uz", "Z is undo")
	s._unhandled_input(_key(KEY_UP))
	s._unhandled_input(_key(KEY_R))
	_check.call(s.attempts[0].record == "UzUr", "R is restart")
	s._unhandled_input(_key(KEY_BACKSPACE))
	s._unhandled_input(_key(KEY_Q))
	_check.call(s.attempts[0].record == "UzUr", "other keys and undo at the start do nothing")
	var echo := _key(KEY_UP)
	echo.echo = true
	s._unhandled_input(echo)
	_check.call(s.attempts[0].record == "UzUr", "key echo is ignored")
	s._toggle_lang()
	_check.call(WhiteText.lang == "en" and s.lang_btn.text == "NL" and s.mode_btn.text == "Practice", "the language toggles to English")
	var on_disk: Variant = JSON.parse_string(FileAccess.get_file_as_string(Screen.SAVE))
	_check.call(on_disk is Dictionary and on_disk.lang == "en", "the language is saved")
	_close(s)
	var r := _open("2026-11-17")
	_check.call(WhiteText.lang == "en" and r.lang_btn.text == "NL", "the saved language is used at start")
	r._toggle_lang()
	_check.call(WhiteText.lang == "nl" and r._save.lang == "nl", "the language toggles back")
	_close(r)
	var e := _open("2026-11-17", func(x: Screen) -> void: x._debug["lang"] = "en")
	_check.call(WhiteText.lang == "en", "--lang overrides the saved language")
	_close(e)
	WhiteText.lang = "nl"
	_clean()
