extends RefCounted
## Release 0.3.0: screen hooks, frozen shot clock, versions and thresholds (design 14.2, 14.6)

const Screen := preload("res://addons/white_kit/tests/fixtures/fixture_screen.gd")

var _check: Callable
var _node: Node


func _open(setup: Callable = Callable()) -> Screen:
	var s := Screen.new()
	s._debug["date"] = "2026-11-17"
	if setup.is_valid():
		setup.call(s)
	_node.add_child(s)
	return s


func _close(s: Screen) -> void:
	_node.remove_child(s)
	s.free()


func _clean() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Screen.SAVE))


func run(check: Callable, node: Node) -> void:
	_check = check
	_node = node
	WhiteText.lang = "nl"
	_clean()
	_insets()
	_margins()
	await _frozen_clock()
	_versions()
	WhiteText.register({})
	_clean()


func _is(d: Dictionary, l: int, t: int, r: int, b: int) -> bool:
	return d.left == l and d.top == t and d.right == r and d.bottom == b


func _insets() -> void:
	var s := _open()
	_check.call(_is(s._insets_for(Vector2(720, 1280)), 24, 24, 24, 24), "insets: default hooks give 24 on every side (phone)")
	_check.call(_is(s._insets_for(Vector2(2400, 1080)), 24, 24, 24, 24), "insets: default hooks give 24 on every side (desktop)")
	_close(s)
	s = _open(func(x: Screen) -> void: x.max_width = 720)
	_check.call(_is(s._insets_for(Vector2(2276, 1280)), 778, 24, 778, 24), "insets: max width centres the column")
	_check.call(_is(s._insets_for(Vector2(720, 1280)), 24, 24, 24, 24), "insets: max width leaves a narrow viewport alone")
	_check.call(_is(s._insets_for(Vector2(760, 1280)), 24, 24, 24, 24), "insets: a viewport only just wider than the column adds no extra")
	_close(s)
	s = _open(func(x: Screen) -> void:
		x.safe_area = true
		x._debug["safe"] = "40,80,40,60")
	_check.call(_is(s._insets_for(Vector2(720, 1280)), 64, 104, 64, 84), "insets: safe area adds to the margins")
	_close(s)
	s = _open(func(x: Screen) -> void:
		x._debug["safe"] = "40,80,40,60")
	_check.call(_is(s._insets_for(Vector2(720, 1280)), 24, 24, 24, 24), "insets: --safe has no effect when the hook is false")
	_close(s)
	s = _open(func(x: Screen) -> void:
		x.safe_area = true
		x.max_width = 720
		x._debug["safe"] = "40,80,40,60")
	var vp := Vector2(2276, 1280)
	@warning_ignore("integer_division")
	var side := 64 + (int(vp.x) - 128 - 720) / 2
	_check.call(_is(s._insets_for(vp), side, 104, side, 84), "insets: safe area and max width combine")
	_close(s)


func _margins() -> void:
	var s := _open(func(x: Screen) -> void: x.max_width = 720)
	var vp := s.get_viewport_rect().size
	var ins: Dictionary = s._insets_for(vp)
	_check.call(s.margin is MarginContainer and s.margin.get_theme_constant("margin_left") == ins.left
			and s.margin.get_theme_constant("margin_right") == ins.right
			and s.margin.get_theme_constant("margin_top") == ins.top
			and s.margin.get_theme_constant("margin_bottom") == ins.bottom, "margins equal _insets_for after _ready")
	s.max_width = 100
	s._apply_insets()
	_check.call(s.margin.get_theme_constant("margin_left") == s._insets_for(vp).left, "_apply_insets sets the margins again")
	_close(s)
	s = _open()
	_check.call(s.margin.get_theme_constant("margin_left") == WhiteTheme.MARGIN
			and s.margin.get_theme_constant("margin_bottom") == WhiteTheme.MARGIN, "default screen keeps the margin of 0.2.0")
	_close(s)


func _frozen_clock() -> void:
	var s := _open()
	s._debug["shot"] = "x.png" # after _ready: a shot in _ready would quit the tree
	s._on_move(1)
	await _node.get_tree().create_timer(1.2).timeout
	s._refresh()
	_check.call(s.clock_label.text == "0:00", "frozen clock: shot mode shows 0:00 after a move and a wait (%s)" % s.clock_label.text)
	s._debug.erase("shot")
	s._refresh()
	_check.call(s.clock_label.text != "0:00" and s.clock_label.text != "", "frozen clock: without shot the clock runs (%s)" % s.clock_label.text)
	_close(s)


func _versions() -> void:
	_check.call(WhiteKit.VERSION == "0.3.0", "kit version is 0.3.0")
	var root := "res://addons/white_kit/"
	var rx := RegEx.create_from_string("run_kit_tests\\.tscn -- --min-checks=(\\d+)")
	var kit := rx.search(FileAccess.get_file_as_string(root + ".github/workflows/ci.yml"))
	var tpl := rx.search(FileAccess.get_file_as_string(root + "templates/ci.yml"))
	_check.call(kit != null and tpl != null and int(kit.get_string(1)) >= 635, "kit CI threshold is at least 635")
	_check.call(tpl != null and kit != null and int(tpl.get_string(1)) <= int(kit.get_string(1)), "template threshold does not exceed kit CI")
	var ci := FileAccess.get_file_as_string(root + "templates/ci.yml")
	_check.call(ci.contains("tools/shots.sh run . tools/shots.txt build/shots"), "template CI has the screenshot step")
	var host := FileAccess.get_file_as_string(root + "templates/host/project.godot")
	_check.call(host.contains("fixture_main.tscn") and host.contains("canvas_items") and host.contains("\"expand\""), "host template has main scene and series display settings")
