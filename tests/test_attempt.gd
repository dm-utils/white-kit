extends RefCounted

const Counter := preload("res://addons/white_kit/tests/fixtures/counter_rules.gd")
const Wide := preload("res://addons/white_kit/tests/fixtures/wide_rules.gd")


func _make(record: String, mode: int, rules: WhiteRules = null) -> WhiteAttempt:
	var a := WhiteAttempt.new(rules if rules != null else Counter.new(), mode)
	a.apply_record(record)
	return a


func run(check: Callable, _node: Node) -> void:
	_every_move(check)
	_final_only(check)
	_replay(check)
	_junk(check)


func _every_move(check: Callable) -> void:
	var a := WhiteAttempt.new(Counter.new())
	check.call(a.mode == WhiteAttempt.CountMode.EVERY_MOVE, "default mode is every move")
	check.call(not a.undo() and not a.restart() and a.record == "", "undo and restart at the start do nothing")
	check.call(not a.play(-1) and a.record == "" and a.count() == 0, "a rejected move changes neither count nor record")
	check.call(a.play(1) and a.play(1), "effective moves return true")
	check.call(a.undo() and a.state == 1 and a.count() == 2, "an undone move still counts")
	check.call(a.can_undo(), "can undo with history")
	check.call(a.restart() and a.state == 0 and a.count() == 2, "restart keeps the count")
	check.call(not a.can_undo(), "no undo after restart")
	check.call(a.record == "UUzr", "record has moves, undo and restart")
	a.play(1)
	a.play(1)
	check.call(not a.solved(), "not solved at 2")
	a.play(1)
	check.call(a.solved() and a.count() == 5, "solved at 3 with count 5")
	var rec := a.record
	check.call(not a.play(1) and not a.undo() and not a.restart() and not a.can_undo(), "nothing works after solving")
	check.call(a.record == rec, "nothing is recorded after solving")


func _final_only(check: Callable) -> void:
	var a := WhiteAttempt.new(Counter.new(), WhiteAttempt.CountMode.FINAL_ONLY)
	a.play(1)
	a.play(1)
	check.call(a.count() == 2 and a.line_length() == 2, "final-only counts the line")
	a.undo()
	check.call(a.count() == 1 and a.moves_made == 2, "undo lowers the count, moves_made keeps everything")
	a.restart()
	check.call(a.count() == 0 and a.moves_made == 2, "restart sets the count to 0")
	a.play(1)
	a.play(1)
	a.play(1)
	check.call(a.solved() and a.count() == 3 and a.moves_made == 5, "after solving the count is the line length")


func _replay(check: Callable) -> void:
	for mode in [WhiteAttempt.CountMode.EVERY_MOVE, WhiteAttempt.CountMode.FINAL_ONLY]:
		for rec in ["", "UU", "UUzUDrUU", "UUUzzU", "UDDUUrUUzU"]:
			var a := _make(rec, mode)
			var b := _make(a.record, mode)
			check.call(a.state == b.state and a.record == b.record and a.moves_made == b.moves_made and a.count() == b.count(),
				"replay of '%s' reproduces the attempt (mode %d)" % [rec, mode])
		var w := _make("A1UA1UzA1UrA1UA1UA1U", mode, Wide.new())
		var w2 := _make(w.record, mode, Wide.new())
		check.call(w.solved() and w2.solved() and w.record == w2.record and w.count() == w2.count(),
			"wide records replay (mode %d)" % mode)


func _junk(check: Callable) -> void:
	var a := _make("zzrx?UU9 RU", WhiteAttempt.CountMode.EVERY_MOVE)
	check.call(a.record == "UUU" and a.moves_made == 3 and a.solved(), "junk is ignored with move length 1")
	var w := _make("A1UA1UXXXA1U", WhiteAttempt.CountMode.EVERY_MOVE, Wide.new())
	check.call(w.moves_made == 3 and w.solved(), "a broken token in the middle still replays the valid tokens after it")
	var w2 := _make("A1Ux", WhiteAttempt.CountMode.EVERY_MOVE, Wide.new())
	check.call(w2.record == "A1U" and w2.moves_made == 1, "a trailing lower-case letter is ignored")
	var rules := Counter.new()
	check.call(rules.move_len() == 1, "default move length is 1")
