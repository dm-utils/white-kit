extends WhitePrecompute
## Fixture generator: the puzzle is its own seed (hex) and level, so a test can check what the skeleton passed.


func _game_id() -> String:
	return "white-fixture"


func _generate(seed_value: int, level: int) -> Dictionary:
	return {"seed": String.num_uint64(seed_value, 16), "level": level, "par": level + 1}
