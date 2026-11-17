class_name WhiteAttempt
extends RefCounted
## One player's go at one puzzle: state, undo history, the record and the counts. The record is also the replay a
## server can check later. Record: move tokens, z = undo, r = restart.

enum CountMode { EVERY_MOVE, FINAL_ONLY }

const UNDO := "z"
const RESTART := "r"

var rules: WhiteRules
var mode: int
var state: Variant
var history: Array = [] ## states before each move of the current line
var record := ""
var moves_made := 0 ## every effective move, including undone and restarted ones
var time_ms := 0 ## informational; the screen keeps its own clock


func _init(r: WhiteRules, count_mode: int = CountMode.EVERY_MOVE) -> void:
	rules = r
	mode = count_mode
	state = r.start_state()


func solved() -> bool:
	return rules.is_solved(state)


## True when the move was effective (counted and recorded).
func play(move: Variant) -> bool:
	if solved():
		return false
	var next: Variant = rules.apply(state, move)
	if next == null:
		return false
	history.append(state)
	state = next
	moves_made += 1
	record += rules.encode_move(move)
	return true


func undo() -> bool:
	if not can_undo():
		return false
	state = history.pop_back()
	record += UNDO
	return true


func restart() -> bool:
	if history.is_empty() or solved():
		return false
	history.clear()
	state = rules.start_state()
	record += RESTART
	return true


func can_undo() -> bool:
	return not history.is_empty() and not solved()


func count() -> int:
	return moves_made if mode == CountMode.EVERY_MOVE else line_length()


## Moves from the start position to the current state.
func line_length() -> int:
	return history.size()


## Replays a record onto this attempt (normally a fresh one). Junk is skipped.
func apply_record(rec: String) -> void:
	var n := rules.move_len()
	var i := 0
	while i < rec.length():
		var ch := rec[i]
		if ch == UNDO:
			undo()
			i += 1
		elif ch == RESTART:
			restart()
			i += 1
		elif ch >= "a" and ch <= "z":
			i += 1 # reserved
		else:
			var move: Variant = rules.decode_move(rec.substr(i, n))
			if move != null:
				play(move)
				i += n
			else:
				i += 1
