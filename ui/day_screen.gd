class_name WhiteDayScreen
extends Control
## The daily/practice screen of the White games: level tabs, counter, par, clock, board slot, message and buttons.
## A game's main scene script extends it and implements the hooks (never override _ready). Progress of each day is
## saved as attempt records, so a reload continues where the player was.
## Debug (screenshots, nothing saved): -- --shot=<png> [--date=YYYY-MM-DD] [--practice] [--level=N] [--keys=<record>]
## [--lang=en]

signal level_shown(level: int)
signal attempt_solved(level: int, count: int)
signal progress_saved()
signal refreshed() ## end of every refresh; lets a game localise the text of its extra buttons

var date := ""
var practice := false
var practice_index := 0
var level := 0
var puzzles: Array = [] ## puzzles on screen: dictionaries with at least "par"
var attempts: Array = [] ## a WhiteAttempt per level
var times: Array = [] ## ms per level before the current run of the clock
var view: Control
var title: Label
var subtitle: Label
var tabs: Array[Button] = []
var counter: Label
var par_label: Label
var clock_label: Label
var message: Label
var undo_btn: Button
var restart_btn: Button
var share_btn: Button
var next_btn: Button
var mode_btn: Button
var lang_btn: Button

var _clock_from := -1 ## ticks when the clock started on the current level, -1 = stopped
var _replaying := false ## true while a game animation runs; input is then ignored
var _save := WhiteProgress.empty("nl")
var _debug := {}
var _extra: Array[Button] = []


# --- hooks -------------------------------------------------------------------------------------------------------

func _game_id() -> String:
	push_error("WhiteDayScreen._game_id not implemented")
	return ""


func _game_title() -> String:
	push_error("WhiteDayScreen._game_title not implemented")
	return ""


func _first_day() -> String:
	push_error("WhiteDayScreen._first_day not implemented")
	return "1970-01-01"


func _save_path() -> String:
	return WhiteProgress.DEFAULT_PATH


func _texts() -> Dictionary:
	return {}


func _level_count() -> int:
	return 3


func _load_day(_date: String) -> Array:
	push_error("WhiteDayScreen._load_day not implemented")
	return []


func _load_practice(_index: int) -> Array:
	push_error("WhiteDayScreen._load_practice not implemented")
	return []


func _practice_count() -> int:
	return 0


## True: the screen only has practice sets (no daily puzzle, no mode button)
func _practice_only() -> bool:
	return false


func _count_mode(_is_practice: bool) -> int:
	return WhiteAttempt.CountMode.EVERY_MOVE


func _new_attempt(_puzzle: Dictionary, _count_mode: int) -> WhiteAttempt:
	push_error("WhiteDayScreen._new_attempt not implemented")
	return null


func _make_view() -> Control:
	push_error("WhiteDayScreen._make_view not implemented")
	return Control.new()


func _view_show(_a: WhiteAttempt) -> void:
	pass


func _view_clear() -> void:
	pass


func _view_update(_a: WhiteAttempt) -> void:
	pass


func _extra_buttons() -> Array[Button]:
	return []


func _hint_text() -> String:
	return WhiteText.t("hint")


func _play_message(_a: WhiteAttempt) -> String:
	return ""


func _key_move(_event: InputEventKey) -> Variant:
	return null


func _on_debug_extra() -> void:
	pass


# --- setup -------------------------------------------------------------------------------------------------------

func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		_debug[a.get_slice("=", 0).trim_prefix("--")] = a.get_slice("=", 1) if a.contains("=") else "1"
	WhiteText.register(_texts())
	if not _debug.has("shot"):
		_save = WhiteProgress.read(_save_path(), WhiteText.languages(), "nl")
	WhiteText.lang = str(_debug.get("lang", _save.get("lang", "nl")))
	_build()
	date = str(_debug.get("date", WhiteDaily.today()))
	practice_index = randi() % maxi(1, _practice_count())
	if _debug.has("practice"):
		practice_index = 0
		_open_practice()
	elif _practice_only():
		_open_practice()
	else:
		_open_day()
	if _debug.has("shot"):
		_debug_shot()


func _build() -> void:
	var bg := ColorRect.new()
	bg.color = WhiteTheme.BG
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, WhiteTheme.MARGIN)
	add_child(margin)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", WhiteTheme.SPACING)
	margin.add_child(col)

	var top := HBoxContainer.new()
	col.add_child(top)
	title = WhiteUi.label(_game_title(), WhiteTheme.FONT_TITLE, WhiteTheme.ACCENT)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(title)
	mode_btn = WhiteUi.button("", _toggle_mode)
	top.add_child(mode_btn)
	lang_btn = WhiteUi.button("", _toggle_lang)
	top.add_child(lang_btn)

	subtitle = WhiteUi.label("", WhiteTheme.FONT_SUBTITLE, WhiteTheme.DIM)
	col.add_child(subtitle)

	var tab_row := HBoxContainer.new()
	tab_row.add_theme_constant_override("separation", WhiteTheme.ROW_SPACING)
	col.add_child(tab_row)
	for i in _level_count():
		var b := WhiteUi.button("", _pick_level.bind(i))
		b.toggle_mode = true
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tab_row.add_child(b)
		tabs.append(b)

	var info := HBoxContainer.new()
	col.add_child(info)
	counter = WhiteUi.label("", WhiteTheme.FONT_INFO, WhiteTheme.TEXT)
	counter.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_child(counter)
	par_label = WhiteUi.label("", WhiteTheme.FONT_INFO, WhiteTheme.DIM)
	par_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	par_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	info.add_child(par_label)
	clock_label = WhiteUi.label("", WhiteTheme.FONT_INFO, WhiteTheme.DIM)
	clock_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	clock_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	info.add_child(clock_label)

	view = _make_view()
	view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	view.custom_minimum_size = Vector2(0, 300)
	col.add_child(view)

	message = WhiteUi.label("", WhiteTheme.FONT_MESSAGE, WhiteTheme.DIM)
	message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message.custom_minimum_size = Vector2(0, 84)
	col.add_child(message)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", WhiteTheme.ROW_SPACING)
	col.add_child(row)
	undo_btn = WhiteUi.button("", _on_undo)
	restart_btn = WhiteUi.button("", _on_restart)
	share_btn = WhiteUi.button("", _share)
	next_btn = WhiteUi.button("", _next)
	_extra = _extra_buttons()
	var all: Array[Button] = [undo_btn, restart_btn]
	all.append_array(_extra)
	all.append_array([share_btn, next_btn])
	for b in all:
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(b)


# --- puzzles -----------------------------------------------------------------------------------------------------

func _zero_times() -> Array:
	var out := []
	out.resize(_level_count())
	out.fill(0)
	return out


func _open_day() -> void:
	_stop_clock()
	practice = false
	puzzles = _load_day(date)
	attempts = []
	times = _zero_times()
	var saved: Array = _save.days.get(date, [])
	for i in puzzles.size():
		var a := _new_attempt(puzzles[i], _count_mode(false))
		a.apply_record(saved[i].record if i < saved.size() else "")
		attempts.append(a)
		if i < times.size():
			times[i] = int(saved[i].time_ms) if i < saved.size() else 0
	level = 0
	for i in attempts.size():
		if not attempts[i].solved():
			level = i
			break
	_show_level()


func _open_practice() -> void:
	_stop_clock()
	practice = true
	puzzles = _load_practice(practice_index)
	attempts = []
	times = _zero_times()
	for p in puzzles:
		attempts.append(_new_attempt(p, _count_mode(true)))
	_show_level()


func _show_level() -> void:
	_replaying = false
	if puzzles.is_empty():
		_view_clear()
	else:
		_view_show(attempts[level])
	_refresh()
	level_shown.emit(level)


func _refresh() -> void:
	var last := _level_count() - 1
	if practice:
		subtitle.text = WhiteText.t("practice") + " %d" % (practice_index + 1)
	else:
		subtitle.text = WhiteText.t("today") % WhiteDaily.number(date, _first_day())
	mode_btn.text = WhiteText.t("daily") if practice else WhiteText.t("practice")
	mode_btn.visible = not _practice_only()
	lang_btn.text = WhiteText.t("lang")
	undo_btn.text = WhiteText.t("undo")
	restart_btn.text = WhiteText.t("restart")
	share_btn.text = WhiteText.t("share")
	next_btn.text = WhiteText.t("next")
	var names: Array = WhiteText.t("levels")
	for i in tabs.size():
		var done: bool = i < attempts.size() and attempts[i].solved()
		tabs[i].text = names[i] + (" · %d" % attempts[i].count() if done else "")
		tabs[i].button_pressed = i == level
	if puzzles.is_empty():
		counter.text = ""
		par_label.text = ""
		clock_label.text = ""
		message.text = WhiteText.t("no_puzzle")
		for b in [undo_btn, restart_btn, share_btn, next_btn] + _extra:
			b.visible = false
		refreshed.emit()
		return
	var a: WhiteAttempt = attempts[level]
	var p: Dictionary = puzzles[level]
	var key := "count_final" if a.mode == WhiteAttempt.CountMode.FINAL_ONLY and WhiteText.has_key("count_final") else "count"
	counter.text = WhiteText.t(key) % a.count()
	par_label.text = WhiteText.t("par") % int(p.par)
	clock_label.text = WhiteFormat.clock(_elapsed())
	var solved := a.solved()
	undo_btn.visible = not solved
	restart_btn.visible = not solved
	undo_btn.disabled = a.history.is_empty()
	restart_btn.disabled = a.history.is_empty()
	for b in _extra:
		b.visible = solved
	share_btn.visible = solved and not practice
	next_btn.visible = solved and (practice or level < last)
	if solved:
		var line: String = WhiteText.t("solved") % [a.count(), int(p.par), WhiteFormat.clock(_elapsed())]
		if a.count() == int(p.par):
			line += "  " + WhiteText.t("perfect")
		message.text = line
	else:
		var play_msg := _play_message(a)
		if not play_msg.is_empty():
			message.text = play_msg
		elif a.moves_made == 0:
			message.text = _hint_text()
		else:
			message.text = ""
	refreshed.emit()


func _elapsed() -> int:
	var t: int = times[level]
	if _clock_from >= 0:
		t += Time.get_ticks_msec() - _clock_from
	return t


func _stop_clock() -> void:
	if _clock_from >= 0 and level < times.size():
		times[level] += Time.get_ticks_msec() - _clock_from
	_clock_from = -1


func _process(_delta: float) -> void:
	if _clock_from >= 0:
		clock_label.text = WhiteFormat.clock(_elapsed())


# --- input -------------------------------------------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	if event.keycode == KEY_Z or event.keycode == KEY_BACKSPACE:
		_on_undo()
	elif event.keycode == KEY_R:
		_on_restart()
	else:
		var move: Variant = _key_move(event)
		if move == null:
			return
		_on_move(move)
	get_viewport().set_input_as_handled()


func _on_move(move: Variant) -> void:
	if puzzles.is_empty() or _replaying:
		return
	var a: WhiteAttempt = attempts[level]
	if not a.play(move):
		return
	if _clock_from < 0:
		_clock_from = Time.get_ticks_msec()
	_view_update(a)
	if a.solved():
		_stop_clock()
		attempt_solved.emit(level, a.count())
	_store()
	_refresh()


func _on_undo() -> void:
	if _replaying or puzzles.is_empty():
		return
	var a: WhiteAttempt = attempts[level]
	if a.undo():
		_view_update(a)
		_store()
		_refresh()


func _on_restart() -> void:
	if _replaying or puzzles.is_empty():
		return
	var a: WhiteAttempt = attempts[level]
	if a.restart():
		_view_update(a)
		_store()
		_refresh()


func _pick_level(i: int) -> void:
	if i >= puzzles.size():
		_refresh()
		return
	_stop_clock()
	_store()
	level = i
	_show_level()


func _next() -> void:
	if practice and level == _level_count() - 1:
		practice_index += 1
		_open_practice()
		level = 0
		_show_level()
		return
	_pick_level(mini(level + 1, _level_count() - 1))


func _toggle_mode() -> void:
	if _practice_only():
		return
	if practice:
		_open_day()
	else:
		_stop_clock()
		_store()
		level = 0
		_open_practice()


func _toggle_lang() -> void:
	WhiteText.lang = WhiteText.next_lang()
	_save.lang = WhiteText.lang
	if not _debug.has("shot"):
		WhiteProgress.write(_save_path(), _save)
	_refresh()


func _share() -> void:
	var counts := []
	var pars := []
	for i in puzzles.size():
		counts.append(attempts[i].count() if attempts[i].solved() else null)
		pars.append(int(puzzles[i].par))
	var line := WhiteFormat.day_line(WhiteText.t("share_line"), WhiteDaily.number(date, _first_day()), counts, pars)
	DisplayServer.clipboard_set(line)
	message.text = line + "\n" + WhiteText.t("copied")


# --- saving ------------------------------------------------------------------------------------------------------

func _store() -> void:
	if practice or _debug.has("shot"):
		return
	var list := []
	for i in attempts.size():
		var t: int = times[i]
		if i == level and _clock_from >= 0:
			t = _elapsed()
		list.append(WhiteProgress.entry(attempts[i].record, t, attempts[i].solved()))
	_save.days[date] = list
	WhiteProgress.write(_save_path(), _save)
	progress_saved.emit()


# --- debug -------------------------------------------------------------------------------------------------------

func _debug_shot() -> void:
	if _debug.has("level"):
		_pick_level(int(_debug.level))
	var rec := str(_debug.get("keys", ""))
	var i := 0
	while i < rec.length():
		var ch := rec[i]
		if ch == WhiteAttempt.UNDO:
			_on_undo()
			i += 1
		elif ch == WhiteAttempt.RESTART:
			_on_restart()
			i += 1
		elif ch >= "a" and ch <= "z" or puzzles.is_empty():
			i += 1
		else:
			var rules: WhiteRules = attempts[level].rules
			var move: Variant = rules.decode_move(rec.substr(i, rules.move_len()))
			if move != null:
				_on_move(move)
				i += rules.move_len()
			else:
				i += 1
	_on_debug_extra()
	await get_tree().create_timer(1.5).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(str(_debug.shot))
	get_tree().quit()
