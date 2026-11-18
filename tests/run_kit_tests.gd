extends WhiteTestRunner
## Kit tests: godot --headless --path <host> res://addons/white_kit/tests/run_kit_tests.tscn

const SUITES := [
	"res://addons/white_kit/tests/test_kit.gd",
	"res://addons/white_kit/tests/test_daily.gd",
	"res://addons/white_kit/tests/test_seed.gd",
	"res://addons/white_kit/tests/test_rng.gd",
	"res://addons/white_kit/tests/test_puzzle_store.gd",
	"res://addons/white_kit/tests/test_attempt.gd",
	"res://addons/white_kit/tests/test_progress.gd",
	"res://addons/white_kit/tests/test_text_format.gd",
	"res://addons/white_kit/tests/test_day_screen.gd",
	"res://addons/white_kit/tests/test_precompute.gd",
	"res://addons/white_kit/tests/test_independent.gd",
	"res://addons/white_kit/tests/test_edge.gd",
	"res://addons/white_kit/tests/test_precompute_edge.gd",
	"res://addons/white_kit/tests/test_release_020.gd",
	"res://addons/white_kit/tests/test_retest_020.gd",
	"res://addons/white_kit/tests/test_safe_area.gd",
	"res://addons/white_kit/tests/test_tile_view.gd",
	"res://addons/white_kit/tests/test_shots.gd",
	"res://addons/white_kit/tests/test_release_030.gd",
]


func _run() -> void:
	for path in SUITES:
		var suite: Variant = load(path)
		if suite == null:
			check(false, "suite loads: " + path)
			continue
		await suite.new().run(check, self)
