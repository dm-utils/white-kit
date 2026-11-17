extends "res://addons/white_kit/tests/fixtures/counter_rules.gd"
## Same game with three-character tokens ("A1U", "A1D").


func move_len() -> int:
	return 3


func encode_move(move: Variant) -> String:
	return "A1U" if move == 1 else "A1D"


func decode_move(token: String) -> Variant:
	return {"A1U": 1, "A1D": -1}.get(token)
