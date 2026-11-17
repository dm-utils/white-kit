class_name WhiteRules
extends RefCounted
## Interface a game implements so WhiteAttempt can play it. State and move types are the game's choice.
## apply returning null is the only way to reject a move; it must not modify its state argument.


func start_state() -> Variant:
	push_error("WhiteRules.start_state not implemented")
	return null


## New state, or null when the move is illegal or changes nothing.
func apply(_state: Variant, _move: Variant) -> Variant:
	push_error("WhiteRules.apply not implemented")
	return null


func is_solved(_state: Variant) -> bool:
	push_error("WhiteRules.is_solved not implemented")
	return false


## Characters per move token in the record.
func move_len() -> int:
	return 1


## Exactly move_len() characters from [A-Z0-9].
func encode_move(_move: Variant) -> String:
	push_error("WhiteRules.encode_move not implemented")
	return ""


## The move, or null when the token is not a move.
func decode_move(_token: String) -> Variant:
	push_error("WhiteRules.decode_move not implemented")
	return null
