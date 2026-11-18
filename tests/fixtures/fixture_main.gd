extends "res://addons/white_kit/tests/fixtures/fixture_screen.gd"
## Main scene of the host project: the fixture screen with the tile view, for the screenshot smoke test.


func _init() -> void:
	super()
	use_tile_view = true
	max_width = 720
	safe_area = true
