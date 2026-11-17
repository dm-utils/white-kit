extends WhiteRules
## Fixture game: state is an int from 0; move 1 ("U") adds one, move -1 ("D") subtracts one, rejected at 0; solved at 3.


func start_state() -> Variant:
	return 0


func apply(state: Variant, move: Variant) -> Variant:
	var next: int = state + move
	return null if next < 0 else next


func is_solved(state: Variant) -> bool:
	return state == 3


func encode_move(move: Variant) -> String:
	return "U" if move == 1 else "D"


func decode_move(token: String) -> Variant:
	return {"U": 1, "D": -1}.get(token)
