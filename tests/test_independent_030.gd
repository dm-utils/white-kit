extends RefCounted
## Independent checks for 0.3.0, written from design 14 and not from the kit code: tile view statics, phase maths,
## animation timing, input edge cases, safe area, screen insets and frozen clock, shots.sh failure paths.
## Board 4x3 in a view of 400x300 (cell 90, origin 20,15), y up: cell 8 9 10 11 / 4 5 6 7 / 0 1 2 3.
## Values: 0 empty, 1 block, 2 and 3 tiles.

const View := preload("res://addons/white_kit/tests/fixtures/tile_view_fixture.gd")
const Screen := preload("res://addons/white_kit/tests/fixtures/fixture_screen.gd")
const BOARD := [2, 2, 0, 0, 0, 3, 1, 0, 0, 0, 0, 3]
const CELL := 90.0
const ORIGIN := Vector2(20, 15)

var _check: Callable
var _node: Node
var _chosen: Array = []
var _fin := 0


func run(check: Callable, node: Node) -> void:
	_check = check
	_node = node
	_statics()
	_phase_maths()
	_animation_timing()
	_animation_state()
	_state_resets()
	_feedback()
	_cell_input()
	_board_input()
	_keyboard()
	await _drawing()
	_safe_area()
	await _screen()
	_shots_script()


func _view(values: Array = BOARD, w := 4, h := 3) -> View:
	var v := View.new()
	v.size = Vector2(400, 300)
	v.show_cells(w, h, PackedByteArray(values))
	_chosen = []
	_fin = 0
	v.move_chosen.connect(func(c: int) -> void: _chosen.append(c))
	v.finished.connect(func() -> void: _fin += 1)
	return v


func _ids(a: Array) -> PackedInt32Array:
	return PackedInt32Array(a)


func _at(cell: int) -> Vector2:
	return ORIGIN + Vector2(cell % 4 + 0.5, 2 - cell / 4 + 0.5) * CELL


func _btn(v: View, p: Vector2, pressed: bool, button: int = MOUSE_BUTTON_LEFT) -> void:
	var e := InputEventMouseButton.new()
	e.position = p
	e.button_index = button
	e.pressed = pressed
	v._gui_input(e)


func _drag(v: View, p: Vector2) -> void:
	var e := InputEventMouseMotion.new()
	e.position = p
	v._gui_input(e)


func _key(code: Key) -> InputEventKey:
	var e := InputEventKey.new()
	e.keycode = code
	e.pressed = true
	return e


# --- statics -----------------------------------------------------------------------------------------------------

func _statics() -> void:
	_check.call(View.Dir.R == 0 and View.Dir.L == 1 and View.Dir.D == 2 and View.Dir.U == 3, "ind030 dir enum values are R 0, L 1, D 2, U 3")
	_check.call(View.InputMode.CELL_MOVES == 0 and View.InputMode.BOARD_SWIPES == 1, "ind030 input mode enum values")
	var l := WhiteTileView.layout(Vector2(720, 1000), 4, 4, 0.3)
	_check.call(l.cell == 167.0 and l.origin == Vector2(26, 166), "ind030 layout portrait area limited by width: %s" % str(l))
	l = WhiteTileView.layout(Vector2(1000, 720), 4, 4, 0.3)
	_check.call(l.cell == 167.0 and l.origin == Vector2(166, 26), "ind030 layout landscape area limited by height")
	l = WhiteTileView.layout(Vector2(400, 300), 4, 3, 0.3)
	_check.call(l.cell == CELL and l.origin == ORIGIN, "ind030 layout 400x300: floor(min(93.0, 90.9)) = 90")
	l = WhiteTileView.layout(Vector2(400, 300), 4, 3, 0.0)
	_check.call(l.cell == 100.0, "ind030 layout with fit 0 fills the area")
	l = WhiteTileView.layout(Vector2(2, 2), 8, 8, 0.3)
	_check.call(l.cell == 1.0, "ind030 layout never goes below one pixel")
	l = WhiteTileView.layout(Vector2(0, 0), 4, 3, 0.3)
	_check.call(l.cell == 1.0 and l.origin == Vector2(-2, -1.5), "ind030 layout of an empty area keeps cell 1")
	l = WhiteTileView.layout(Vector2(400, 300), 4, 3, 0.3)
	# corners of the board in px: every cell index once, y flipped
	var seen := {}
	for y in 3:
		for x in 4:
			var p := ORIGIN + Vector2(x + 0.5, y + 0.5) * CELL
			seen[WhiteTileView.cell_at(p, l, 4, 3)] = true
	_check.call(seen.size() == 12 and seen.has(0) and seen.has(11), "ind030 cell_at maps 12 cell centres to 12 distinct cells")
	_check.call(WhiteTileView.cell_at(ORIGIN + Vector2(1, 1), l, 4, 3) == 8, "ind030 cell_at top-left corner is the highest row, first column")
	_check.call(WhiteTileView.cell_at(ORIGIN + Vector2(4 * CELL - 1, 3 * CELL - 1), l, 4, 3) == 3, "ind030 cell_at bottom-right corner is cell w-1")
	_check.call(WhiteTileView.cell_at(ORIGIN, l, 4, 3) == 8, "ind030 cell_at origin pixel belongs to the board")
	_check.call(WhiteTileView.cell_at(ORIGIN + Vector2(4 * CELL, 10), l, 4, 3) == -1, "ind030 cell_at far edge is outside")
	_check.call(WhiteTileView.cell_at(ORIGIN + Vector2(10, 3 * CELL), l, 4, 3) == -1, "ind030 cell_at bottom edge is outside")
	_check.call(WhiteTileView.cell_at(ORIGIN + Vector2(-0.01, 10), l, 4, 3) == -1, "ind030 cell_at just left of the board")
	_check.call(WhiteTileView.cell_at(ORIGIN + Vector2(10, -0.01), l, 4, 3) == -1, "ind030 cell_at just above the board")
	_check.call(WhiteTileView.cell_at(Vector2(-1000, 5000), l, 4, 3) == -1, "ind030 cell_at far away")
	_check.call(WhiteTileView.cell_at(Vector2(5, 5), WhiteTileView.layout(Vector2(100, 100), 0, 0, 0.3), 0, 0) == -1, "ind030 cell_at on a 0x0 board")
	_check.call(WhiteTileView.drag_dir(Vector2(9, 1)) == View.Dir.R and WhiteTileView.drag_dir(Vector2(-9, 1)) == View.Dir.L, "ind030 drag_dir horizontal")
	_check.call(WhiteTileView.drag_dir(Vector2(1, 9)) == View.Dir.D and WhiteTileView.drag_dir(Vector2(1, -9)) == View.Dir.U, "ind030 drag_dir vertical, screen down is D")
	_check.call(WhiteTileView.drag_dir(Vector2(5, 5)) == View.Dir.D and WhiteTileView.drag_dir(Vector2(-5, -5)) == View.Dir.U
			and WhiteTileView.drag_dir(Vector2(5, -5)) == View.Dir.U and WhiteTileView.drag_dir(Vector2(-5, 5)) == View.Dir.D, "ind030 drag_dir ties go vertical")
	_check.call(WhiteTileView.neighbour_dir(5, 6, 4) == View.Dir.R and WhiteTileView.neighbour_dir(6, 5, 4) == View.Dir.L
			and WhiteTileView.neighbour_dir(5, 9, 4) == View.Dir.U and WhiteTileView.neighbour_dir(9, 5, 4) == View.Dir.D, "ind030 neighbour_dir four ways")
	_check.call(WhiteTileView.neighbour_dir(3, 4, 4) == -1, "ind030 neighbour_dir does not wrap around a row end")
	_check.call(WhiteTileView.neighbour_dir(4, 3, 4) == -1, "ind030 neighbour_dir does not wrap around a row start")
	_check.call(WhiteTileView.neighbour_dir(5, 5, 4) == -1 and WhiteTileView.neighbour_dir(0, 5, 4) == -1 and WhiteTileView.neighbour_dir(0, 2, 4) == -1,
			"ind030 neighbour_dir same cell, diagonal and distance two are -1")
	for pair in [[KEY_RIGHT, 0], [KEY_D, 0], [KEY_LEFT, 1], [KEY_A, 1], [KEY_DOWN, 2], [KEY_S, 2], [KEY_UP, 3], [KEY_W, 3], [KEY_SPACE, -1], [KEY_Q, -1], [KEY_NONE, -1], [KEY_ESCAPE, -1]]:
		_check.call(WhiteTileView.key_dir(pair[0]) == pair[1], "ind030 key_dir %d" % pair[0])
	_check.call(WhiteTileView.step_cell(0, View.Dir.L, 4, 3) == 0 and WhiteTileView.step_cell(0, View.Dir.D, 4, 3) == 0, "ind030 step_cell clamps at bottom-left")
	_check.call(WhiteTileView.step_cell(11, View.Dir.R, 4, 3) == 11 and WhiteTileView.step_cell(11, View.Dir.U, 4, 3) == 11, "ind030 step_cell clamps at top-right")
	_check.call(WhiteTileView.step_cell(3, View.Dir.R, 4, 3) == 3 and WhiteTileView.step_cell(4, View.Dir.L, 4, 3) == 4, "ind030 step_cell does not wrap rows")
	_check.call(WhiteTileView.step_cell(5, View.Dir.U, 4, 3) == 9 and WhiteTileView.step_cell(5, View.Dir.D, 4, 3) == 1
			and WhiteTileView.step_cell(5, View.Dir.R, 4, 3) == 6 and WhiteTileView.step_cell(5, View.Dir.L, 4, 3) == 4, "ind030 step_cell inside the board")
	_check.call(WhiteTileView.step_cell(0, View.Dir.U, 1, 1) == 0, "ind030 step_cell on a 1x1 board")


# --- build_phases ------------------------------------------------------------------------------------------------

func _phase_maths() -> void:
	var ids := _ids([0, 1, -1, -1, -1, 5, -1, -1])
	var r := WhiteTileView.build_phases(4, ids, [{"kind": "move", "moves": [[0, 1], [1, 0]], "time": 0.1}], 0.24)
	_check.call(r.ids == _ids([1, 0, -1, -1, -1, 5, -1, -1]) and r.phases.size() == 1, "ind030 swap exchanges the two ids")
	_check.call(ids == _ids([0, 1, -1, -1, -1, 5, -1, -1]), "ind030 build_phases does not change the ids it is given")
	var ring := WhiteTileView.build_phases(4, _ids([0, 1, 2, -1]), [{"kind": "move", "moves": [[0, 1], [1, 2], [2, 0]], "time": 0.1}], 0.24)
	_check.call(ring.ids == _ids([2, 0, 1, -1]), "ind030 a three-way rotation is simultaneous")
	var chain := WhiteTileView.build_phases(4, _ids([7, -1, -1, -1]), [
		{"kind": "move", "moves": [[0, 3]], "time": 0.1}, {"kind": "vanish", "cells": [3]}], 0.24)
	_check.call(chain.ids == _ids([-1, -1, -1, -1]) and chain.phases.size() == 2 and chain.phases[1].ids == [7], "ind030 a tile moved by step 1 can vanish in step 2")
	var back := WhiteTileView.build_phases(4, _ids([7, -1, -1, -1]), [
		{"kind": "move", "moves": [[0, 2]], "time": 0.1}, {"kind": "move", "moves": [[2, 0]], "time": 0.1}], 0.24)
	_check.call(back.ids == _ids([7, -1, -1, -1]) and back.phases[1].from == [Vector2(2, 0)], "ind030 steps use the ids left by the previous step")
	var f := WhiteTileView.build_phases(4, _ids([0, -1, -1, -1, 4, -1, -1, -1, -1, -1, -1, 10]), [{"kind": "move", "moves": [[4, 0], [11, 3]], "speed": 16.0}], 0.24)
	_check.call(is_equal_approx(f.phases[0].dur, 2.0 / 16.0), "ind030 fall of distances 1 and 2 lasts 2/16 (%f)" % f.phases[0].dur)
	var diag := WhiteTileView.build_phases(8, _ids([0, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1]), [{"kind": "move", "moves": [[0, 11]], "speed": 10.0}], 0.24)
	_check.call(is_equal_approx(diag.phases[0].dur, 3.0 / 10.0), "ind030 duration uses the larger of abs(dx) and abs(dy): 3 cells at 10/s")
	var sub := WhiteTileView.build_phases(4, _ids([0, -1, -1, -1]), [{"kind": "move", "moves": [[0, 1]], "speed": 2.0}], 0.24)
	_check.call(is_equal_approx(sub.phases[0].dur, 0.5), "ind030 a distance of one cell at speed 2 lasts 0.5")
	var zero := WhiteTileView.build_phases(4, _ids([0, -1, -1, -1]), [{"kind": "move", "moves": [[0, 0]], "speed": 4.0}], 0.24)
	_check.call(is_equal_approx(zero.phases[0].dur, 0.25) and zero.ids == _ids([0, -1, -1, -1]), "ind030 a move from a cell to itself keeps the tile and lasts 1/speed")
	var timed := WhiteTileView.build_phases(4, _ids([0, -1, -1, -1]), [{"kind": "move", "moves": [[0, 3]], "time": 0.37, "speed": 1.0}], 0.24)
	_check.call(timed.phases[0].dur == 0.37, "ind030 time wins over speed")
	var empty := WhiteTileView.build_phases(4, _ids([0, -1, -1, -1]), [], 0.24)
	_check.call(empty.phases.is_empty() and empty.ids == _ids([0, -1, -1, -1]), "ind030 no steps give no phases")
	var van := WhiteTileView.build_phases(4, _ids([0, 1, -1, -1]), [{"kind": "vanish", "cells": [0, 1, 2]}], 0.24)
	_check.call(van.phases[0].dur == 0.24 and van.phases[0].ids == [0, 1] and van.ids == _ids([-1, -1, -1, -1]), "ind030 vanish of two tiles and an empty cell")
	var twice := WhiteTileView.build_phases(4, _ids([0, 1, -1, -1]), [{"kind": "vanish", "cells": [0]}, {"kind": "vanish", "cells": [0]}], 0.24)
	_check.call(twice.phases.size() == 2 and twice.phases[1].ids.is_empty(), "ind030 vanishing a cell twice affects the tile once")
	var from_empty := WhiteTileView.build_phases(4, _ids([-1, 1, -1, -1]), [{"kind": "move", "moves": [[0, 2], [1, 3]], "time": 0.1}], 0.24)
	_check.call(from_empty.ids == _ids([-1, -1, -1, 1]) and from_empty.phases[0].ids == [1], "ind030 a move from an empty cell is skipped and the rest still runs")
	var unk := WhiteTileView.build_phases(4, _ids([0, -1, -1, -1]), [{"kind": "teleport"}, {"kind": "move", "moves": [[0, 1]], "time": 0.1}], 0.24)
	_check.call(unk.phases.size() == 1 and unk.ids == _ids([-1, 0, -1, -1]), "ind030 an unknown kind is skipped, later steps still run")
	var easy := WhiteTileView.build_phases(4, _ids([0, -1, -1, -1]), [{"kind": "move", "moves": [[0, 1]], "time": 0.1, "ease": true}, {"kind": "move", "moves": [[1, 2]], "time": 0.1}], 0.24)
	_check.call(easy.phases[0].ease == true and easy.phases[1].ease == false, "ind030 ease defaults to false")
	var up := WhiteTileView.build_phases(4, _ids([-1, -1, -1, -1, 4, -1, -1, -1]), [{"kind": "move", "moves": [[4, 0]], "time": 0.1}], 0.24)
	_check.call(up.phases[0].from == [Vector2(0, 1)] and up.phases[0].to == [Vector2(0, 0)], "ind030 phase positions are in cells with y up")


# --- animation timing --------------------------------------------------------------------------------------------

func _animation_timing() -> void:
	var v := _view()
	v.animate([{"kind": "move", "moves": [[0, 3]], "time": 0.1, "ease": true}])
	v._process(0.05)
	var p: Vector2 = v._pos[0]
	_check.call(v.busy() and is_equal_approx(p.x, 2.25) and p.y == 0.0, "ind030 eased move at half time is at 75 percent (%s)" % str(p))
	v._process(0.0)
	_check.call(is_equal_approx(v._pos[0].x, 2.25), "ind030 a zero delta changes nothing")
	v._process(0.06)
	_check.call(not v.busy() and v._pos[0] == Vector2(3, 0) and _fin == 1, "ind030 move ends at its target and emits finished once")
	v._process(0.5)
	_check.call(_fin == 1, "ind030 no second finished after the end")
	v = _view()
	v.animate([{"kind": "move", "moves": [[1, 2]], "time": 0.2}])
	v._process(0.05)
	_check.call(is_equal_approx(v._pos[1].x, 1.25), "ind030 linear move at a quarter of the time")
	v = _view()
	v.animate([{"kind": "vanish", "cells": [0]}])
	v._process(0.09)
	_check.call(is_equal_approx(v._alpha[0], 0.5) and is_equal_approx(v._scale[0], 0.85), "ind030 vanish at half of vanish_time: alpha 0.5, scale 0.85")
	v._process(0.1)
	_check.call(is_equal_approx(v._alpha[0], 0.0) and v.busy() and v._alive[0] == 1, "ind030 faded tile stays during the pause")
	v._process(0.1)
	_check.call(not v.busy() and v._alive[0] == 0 and _fin == 1, "ind030 tile is removed after vanish_time + vanish_pause")
	v = _view()
	v.vanish_time = 0.5
	v.vanish_pause = 0.0
	v.vanish_scale = 0.2
	v.animate([{"kind": "vanish", "cells": [1]}])
	v._process(0.25)
	_check.call(is_equal_approx(v._scale[1], 0.6) and is_equal_approx(v._alpha[1], 0.5), "ind030 vanish honours the look members")
	v = _view()
	v.animate([{"kind": "move", "moves": [[0, 1], [1, 0]], "time": 0.1}, {"kind": "vanish", "cells": [0]}, {"kind": "move", "moves": [[5, 9]], "speed": 16.0}])
	v._process(10.0)
	_check.call(not v.busy() and _fin == 1 and v._alive[0] + v._alive[1] == 1 and v._pos[5] == Vector2(1, 2), "ind030 one huge delta runs all phases and emits finished once")
	_check.call(v.shown() == PackedByteArray([0, 2, 0, 0, 0, 0, 1, 0, 0, 3, 0, 3]), "ind030 end state of swap, vanish, move: %s" % str(v.shown()))
	v = _view()
	v.animate([{"kind": "move", "moves": [[0, 3]], "time": 0.1}])
	v._process(0.03)
	v.animate([{"kind": "move", "moves": [[1, 2]], "time": 0.1}])
	_check.call(_fin == 1 and v._pos[0] == Vector2(3, 0) and v.busy(), "ind030 a new animation finishes the running one first")
	v.finish_animation()
	_check.call(_fin == 2 and not v.busy(), "ind030 finish_animation on the second one")
	v.finish_animation()
	_check.call(_fin == 2, "ind030 finish_animation when idle emits nothing")
	v = _view()
	v.finished.connect(func() -> void:
		if _fin == 1:
			v.animate([{"kind": "move", "moves": [[1, 2]], "time": 0.1}]))
	v.animate([{"kind": "move", "moves": [[0, 3]], "time": 0.1}])
	v._process(1.0)
	_check.call(_fin == 1 and v.busy(), "ind030 animate started from a finished handler runs")
	v._process(1.0)
	_check.call(_fin == 2 and not v.busy() and v._pos[1] == Vector2(2, 0), "ind030 chained animation ends too")
	v = _view()
	v.animate([])
	_check.call(not v.busy() and _fin == 0 and v.shown() == PackedByteArray(BOARD), "ind030 animate with no steps does nothing")
	v.animate([{"kind": "teleport"}])
	_check.call(not v.busy() and _fin == 0, "ind030 animate with only unknown steps does not start")


func _animation_state() -> void:
	var v := _view()
	v.animate([{"kind": "move", "moves": [[0, 4]], "time": 0.1}])
	_check.call(v.shown() == PackedByteArray([0, 2, 0, 0, 2, 3, 1, 0, 0, 0, 0, 3]), "ind030 shown is the end state at once")
	_check.call(v.busy(), "ind030 busy straight after animate")
	var before := PackedByteArray([2, 0, 0, 0, 0, 3, 1, 0, 0, 0, 0, 3])
	v = _view()
	v.animate([{"kind": "move", "moves": [[5, 9]], "time": 0.1}], before)
	_check.call(v.shown() == PackedByteArray([2, 0, 0, 0, 0, 0, 1, 0, 0, 3, 0, 3]), "ind030 a before state replaces the shown state first")
	v = _view()
	v.animate([{"kind": "move", "moves": [[0, 4]], "time": 0.1}], PackedByteArray(BOARD))
	_check.call(v.shown()[4] == 2, "ind030 a before equal to the shown state changes nothing")
	v.finish_animation()
	v = _view()
	v.animate([{"kind": "move", "moves": [[11, 7]], "time": 0.1}, {"kind": "vanish", "cells": [7]}])
	v.finish_animation()
	_check.call(v.shown() == PackedByteArray([2, 2, 0, 0, 0, 3, 1, 0, 0, 0, 0, 0]), "ind030 static cells never move and a vanished tile leaves 0")
	_check.call(v.shown()[6] == 1, "ind030 the block is still there")
	v = _view()
	v.animate([{"kind": "move", "moves": [[5, 9]], "time": 0.1}])
	v.debug_select(0)
	v.animate([])
	_check.call(v.selected() == -1, "ind030 animate clears the selection even without steps")


func _state_resets() -> void:
	var v := _view()
	v.debug_select(5)
	v.show_values(PackedByteArray(BOARD))
	_check.call(v.selected() == -1, "ind030 show_values clears the selection")
	v.key_move(_key(KEY_RIGHT))
	v.key_move(_key(KEY_RIGHT))
	v.show_values(PackedByteArray(BOARD))
	_check.call(v.cursor() == 1 and v.cursor_visible(), "ind030 show_values keeps the cursor")
	v.show_cells(4, 3, PackedByteArray(BOARD))
	_check.call(v.cursor() == 0 and not v.cursor_visible(), "ind030 show_cells resets the cursor")
	v.animate([{"kind": "move", "moves": [[0, 3]], "time": 0.1}])
	v.show_cells(4, 3, PackedByteArray(BOARD))
	_check.call(not v.busy() and v.shown() == PackedByteArray(BOARD) and v._pos[0] == Vector2(0, 0), "ind030 show_cells cancels a running animation without finished")
	_check.call(_fin == 0, "ind030 no finished from a cancelled animation")
	v.show_cells(2, 2, PackedByteArray([2, 0, 0, 3]))
	_check.call(v.has_board() and v.grid_w == 2 and v.shown().size() == 4 and v.cursor() == 0, "ind030 show_cells replaces the board size")
	v.clear()
	_check.call(not v.has_board() and v.shown().is_empty() and not v.busy(), "ind030 clear removes the board")
	v.key_move(_key(KEY_RIGHT))
	_check.call(v.key_move(_key(KEY_SPACE)) == null and not v.cursor_visible(), "ind030 keys without a board do nothing")
	_btn(v, Vector2(100, 100), true)
	_btn(v, Vector2(100, 100), false)
	_check.call(_chosen.is_empty() and v.selected() == -1, "ind030 mouse without a board does nothing")
	v.shake_cell(0)
	v.animate([])
	_check.call(not v.busy(), "ind030 shake and empty animate without a board are harmless")
	v = _view()
	_check.call(v.shown() == PackedByteArray(BOARD) and v.shown() != null, "ind030 shown returns the board values")
	var empty := View.new()
	_check.call(not empty.has_board() and empty.shown().is_empty() and empty.selected() == -1 and empty.cursor() == 0 and not empty.busy(), "ind030 a new view has no board")


# --- shake and nudge ---------------------------------------------------------------------------------------------

func _feedback() -> void:
	var v := _view()
	v.shake_cell(2)
	_check.call(v._shake_id == -1, "ind030 shake on an empty cell does nothing")
	v.shake_cell(6)
	_check.call(v._shake_id == -1, "ind030 shake on a block does nothing")
	v.shake_cell(-1)
	v.shake_cell(99)
	_check.call(v._shake_id == -1, "ind030 shake with an invalid cell does nothing")
	v.shake_cell(5)
	_check.call(v._shake_id == 5, "ind030 shake on a tile starts")
	v._process(0.05)
	_check.call(v._shake_id == 5 and not v.busy(), "ind030 shaking is not busy")
	v._process(0.2)
	_check.call(v._shake_id == -1, "ind030 shake ends after shake_time")
	v.nudge(View.Dir.R)
	v._nudge_t = v.nudge_time / 2.0
	_check.call(v._nudge_offset().is_equal_approx(Vector2(v.nudge_px, 0)), "ind030 nudge right at the middle")
	v.nudge(View.Dir.L)
	v._nudge_t = v.nudge_time / 2.0
	_check.call(v._nudge_offset().is_equal_approx(Vector2(-v.nudge_px, 0)), "ind030 nudge left")
	v.nudge(View.Dir.U)
	v._nudge_t = v.nudge_time / 2.0
	_check.call(v._nudge_offset().is_equal_approx(Vector2(0, -v.nudge_px)), "ind030 nudge up is towards the screen top")
	v.nudge(View.Dir.D)
	v._nudge_t = v.nudge_time / 2.0
	_check.call(v._nudge_offset().is_equal_approx(Vector2(0, v.nudge_px)), "ind030 nudge down")
	v._nudge_t = 0.0
	_check.call(v._nudge_offset().length() < 0.001, "ind030 nudge starts at zero")
	v._process(1.0)
	_check.call(v._nudge_offset() == Vector2.ZERO, "ind030 nudge is over after nudge_time")
	v.nudge_px = 20.0
	v.nudge(View.Dir.R)
	v._nudge_t = v.nudge_time / 2.0
	_check.call(v._nudge_offset().is_equal_approx(Vector2(20, 0)), "ind030 nudge honours nudge_px")
	# feedback does not block input
	v = _view()
	v.shake_cell(5)
	_btn(v, _at(0), true)
	_btn(v, _at(0), false)
	_check.call(v.selected() == 0, "ind030 a tap works while a tile shakes")


# --- input -------------------------------------------------------------------------------------------------------

func _cell_input() -> void:
	var v := _view()
	_btn(v, _at(0), true)
	_drag(v, _at(0) + Vector2(0, -(CELL * 0.4 - 1.0)))
	_check.call(_chosen.is_empty(), "ind030 a drag just under 0.4 cell does not fire")
	_drag(v, _at(0) + Vector2(0, -CELL * 0.4))
	_check.call(_chosen == [0 * 4 + View.Dir.U], "ind030 a drag of exactly 0.4 cell fires during the motion: %s" % str(_chosen))
	_btn(v, _at(0) + Vector2(0, -CELL * 0.4), false)
	_check.call(_chosen.size() == 1, "ind030 the release after a fired swipe adds nothing")
	v = _view()
	_btn(v, _at(1), true)
	_drag(v, _at(1) + Vector2(0, -CELL * 0.5))
	_drag(v, _at(1) + Vector2(0, -CELL * 0.9))
	_btn(v, _at(1) + Vector2(0, -CELL * 0.9), false)
	_check.call(_chosen.size() == 1, "ind030 a swipe fires once even with more motion and the release (%s)" % str(_chosen))
	_btn(v, _at(5), true)
	_btn(v, _at(5) + Vector2(-30, 0), false)
	_check.call(_chosen.size() == 2, "ind030 the next press starts a fresh swipe (%s)" % str(_chosen))
	v = _view()
	_btn(v, Vector2(5, 5), true)
	_drag(v, Vector2(200, 5))
	_btn(v, Vector2(200, 5), false)
	_check.call(_chosen.is_empty() and v.selected() == -1, "ind030 a press outside the board never swipes")
	v = _view()
	_btn(v, _at(2), true)
	_btn(v, _at(2) + Vector2(60, 0), false)
	_check.call(_chosen.is_empty(), "ind030 a long drag from an empty cell is no swipe")
	v = _view()
	_btn(v, _at(0), true)
	_btn(v, _at(0) + Vector2(0, -23), false)
	_check.call(_chosen.is_empty() and v.selected() == 0, "ind030 a 23 px release selects")
	v = _view()
	_btn(v, _at(0), true)
	_btn(v, _at(0) + Vector2(0, -24), false)
	_check.call(_chosen == [0 * 4 + View.Dir.U], "ind030 a 24 px release up swipes up: %s" % str(_chosen))
	v = _view()
	_btn(v, _at(0), true, MOUSE_BUTTON_MIDDLE)
	_btn(v, _at(0), false, MOUSE_BUTTON_MIDDLE)
	_btn(v, _at(0), true, MOUSE_BUTTON_RIGHT)
	_btn(v, _at(0) + Vector2(50, 0), false, MOUSE_BUTTON_RIGHT)
	_check.call(_chosen.is_empty() and v.selected() == -1, "ind030 other buttons are ignored")
	# disabled input: nothing of the gesture counts
	v = _view()
	v.input_enabled = false
	_btn(v, _at(0), true)
	_btn(v, _at(0) + Vector2(60, 0), false)
	v.input_enabled = true
	_check.call(_chosen.is_empty() and v.selected() == -1, "ind030 disabled input swallows the whole gesture")
	# tap logic
	v = _view()
	_btn(v, _at(2), true)
	_btn(v, _at(2), false)
	_check.call(v.selected() == -1, "ind030 tap on an empty cell with no selection selects nothing")
	_btn(v, _at(6), true)
	_btn(v, _at(6), false)
	_check.call(v.selected() == -1, "ind030 tap on a block selects nothing")
	_btn(v, _at(0), true)
	_btn(v, _at(0), false)
	_btn(v, _at(5), true)
	_btn(v, _at(5), false)
	_check.call(v.selected() == 5 and _chosen.is_empty(), "ind030 tap on a non-neighbouring tile moves the selection")
	_btn(v, _at(2), true)
	_btn(v, _at(2), false)
	_check.call(v.selected() == -1, "ind030 tap on a far empty cell deselects")
	_btn(v, _at(0), true)
	_btn(v, _at(0), false)
	_btn(v, _at(1), true)
	_btn(v, _at(1), false)
	_check.call(v.selected() == -1 and _chosen.is_empty() and v._shake_id == 0, "ind030 tap-tap towards a same-value tile is ignored, shakes and deselects")
	v = _view()
	_btn(v, _at(0), true)
	_btn(v, _at(0), false)
	_btn(v, _at(4), true)
	_btn(v, _at(4), false)
	_check.call(_chosen == [0 * 4 + View.Dir.U] and v.selected() == -1, "ind030 tap-tap on an empty neighbour moves and deselects: %s" % str(_chosen))
	v = _view()
	_btn(v, _at(5), true)
	_btn(v, _at(5), false)
	_btn(v, _at(6), true)
	_btn(v, _at(6), false)
	_check.call(_chosen.is_empty() and v.selected() == -1 and v._shake_id == 5, "ind030 tap-tap towards a block is ignored, shakes the tile and deselects")
	v = _view()
	_btn(v, _at(0), true)
	_btn(v, _at(0), false)
	_btn(v, Vector2(2, 2), true)
	_btn(v, Vector2(2, 2), false)
	_check.call(v.selected() == -1, "ind030 tap outside the board deselects")
	v = _view()
	_btn(v, _at(0), true)
	_btn(v, _at(0), false)
	_btn(v, _at(0), true)
	_btn(v, _at(0), false)
	_check.call(v.selected() == -1, "ind030 tap on the selected cell deselects")
	# tap finishes a running animation first
	v = _view()
	v.animate([{"kind": "move", "moves": [[0, 4]], "time": 5.0}])
	_btn(v, _at(5), true)
	_btn(v, _at(5), false)
	_check.call(not v.busy() and _fin == 1, "ind030 a tap finishes the running animation")
	# move_chosen is never -1
	v = _view()
	for cell in [0, 1, 5, 11]:
		for d in [Vector2(40, 0), Vector2(-40, 0), Vector2(0, 40), Vector2(0, -40)]:
			_btn(v, _at(cell), true)
			_btn(v, _at(cell) + d, false)
	_check.call(not _chosen.has(-1), "ind030 move_chosen never carries -1")
	# a press whose board is replaced before the drag
	v = _view()
	_btn(v, _at(11), true)
	v.clear()
	_drag(v, _at(11) + Vector2(50, 0))
	_btn(v, _at(11), false)
	_check.call(_chosen.is_empty(), "ind030 board cleared in the middle of a gesture")


func _board_input() -> void:
	var v := _view()
	v.input_mode = View.InputMode.BOARD_SWIPES
	v.board_moves = true
	_btn(v, Vector2(395, 295), true)
	_btn(v, Vector2(395, 295) + Vector2(-60, 0), false)
	_check.call(_chosen == [View.Dir.L], "ind030 board swipe from a corner of the view, outside the board: %s" % str(_chosen))
	_chosen.clear()
	_btn(v, _at(2), true)
	_drag(v, _at(2) + Vector2(0, 40))
	_btn(v, _at(2) + Vector2(0, 80), false)
	_check.call(_chosen == [View.Dir.D], "ind030 board swipe from an empty cell fires during the drag, once")
	_chosen.clear()
	_btn(v, _at(0), true)
	_btn(v, _at(0) + Vector2(10, 5), false)
	_check.call(_chosen.is_empty() and v.selected() == -1 and v._nudge_dir == -1, "ind030 a tap does nothing in board mode")
	_btn(v, _at(0), true, MOUSE_BUTTON_RIGHT)
	_btn(v, _at(0) + Vector2(60, 0), false, MOUSE_BUTTON_RIGHT)
	_check.call(_chosen.is_empty(), "ind030 right button does nothing in board mode")
	v.board_moves = false
	_btn(v, _at(0), true)
	_btn(v, _at(0) + Vector2(0, -60), false)
	_check.call(_chosen.is_empty() and v._nudge_dir == View.Dir.U, "ind030 a swipe with no move nudges towards the swipe")
	v.input_enabled = false
	v._nudge_dir = -1
	_btn(v, _at(0), true)
	_btn(v, _at(0) + Vector2(0, -60), false)
	_check.call(v._nudge_dir == -1, "ind030 disabled input in board mode")
	v.input_enabled = true
	_check.call(v.key_move(_key(KEY_SPACE)) == null and v.key_move(_key(KEY_ENTER)) == null and v.key_move(_key(KEY_ESCAPE)) == null and v.key_move(_key(KEY_Q)) == null,
			"ind030 board mode: space, enter, esc and other keys return null")
	_check.call(not v.cursor_visible() and v.selected() == -1, "ind030 board mode has no cursor or selection")
	v._nudge_dir = -1
	_check.call(v.key_move(_key(KEY_UP)) == null and v._nudge_dir == View.Dir.U, "ind030 board mode arrow without a move returns null and nudges")
	v.board_moves = true
	_check.call(v.key_move(_key(KEY_A)) == View.Dir.L and v.key_move(_key(KEY_DOWN)) == View.Dir.D and v.key_move(_key(KEY_RIGHT)) == View.Dir.R and v.key_move(_key(KEY_W)) == View.Dir.U,
			"ind030 board mode keys return the move code, also R as 0")
	_check.call(_chosen.is_empty(), "ind030 board mode keys do not emit move_chosen")
	v.animate([{"kind": "move", "moves": [[0, 4]], "time": 5.0}])
	v.key_move(_key(KEY_LEFT))
	_check.call(not v.busy(), "ind030 board key finishes the running animation first")


func _keyboard() -> void:
	var v := _view()
	_check.call(v.key_move(_key(KEY_SPACE)) == null and v.cursor_visible() and v.selected() == 0, "ind030 space as first key shows the cursor and grabs the tile under it")
	v = _view()
	_check.call(v.key_move(_key(KEY_Q)) == null and not v.cursor_visible(), "ind030 a non-direction key does not show the cursor")
	v.key_move(_key(KEY_W))
	_check.call(v.cursor_visible() and v.cursor() == 0, "ind030 WASD shows the cursor too")
	v.key_move(_key(KEY_W))
	v.key_move(_key(KEY_D))
	v.key_move(_key(KEY_D))
	_check.call(v.cursor() == 6, "ind030 WASD moves the cursor (to the block, cells can hold anything): %d" % v.cursor())
	_check.call(v.key_move(_key(KEY_ENTER)) == null and v.selected() == -1, "ind030 enter on a block does not grab")
	v.key_move(_key(KEY_A))
	_check.call(v.cursor() == 5 and v.key_move(_key(KEY_KP_ENTER)) == null and v.selected() == 5, "ind030 keypad enter grabs a tile")
	_check.call(v.key_move(_key(KEY_SPACE)) == null and v.selected() == -1, "ind030 space on a grab releases it")
	v.key_move(_key(KEY_ENTER))
	_check.call(v.key_move(_key(KEY_ESCAPE)) == null and v.selected() == -1, "ind030 esc releases the grab")
	v.key_move(_key(KEY_ENTER))
	v.key_move(_key(KEY_ENTER))
	v.key_move(_key(KEY_ESCAPE))
	_check.call(v.selected() == -1 and v.cursor() == 5, "ind030 esc without a grab keeps the cursor")
	v.key_move(_key(KEY_ENTER))
	_check.call(v.key_move(_key(KEY_RIGHT)) == null and v.selected() == 5 and v._shake_id == 5, "ind030 grab towards a block: null, shake, grab stays")
	var code: Variant = v.key_move(_key(KEY_UP))
	_check.call(code == 5 * 4 + View.Dir.U and v.selected() == -1, "ind030 grab and move up returns the code and releases: %s" % str(code))
	_check.call(_chosen.is_empty(), "ind030 keyboard moves do not emit move_chosen")
	v.animate([{"kind": "move", "moves": [[5, 9]], "time": 0.1}])
	_check.call(v.cursor() == 9, "ind030 the cursor follows the moved tile")
	v.finish_animation()
	v.key_move(_key(KEY_ENTER))
	v.key_move(_key(KEY_UP))
	_check.call(v.cursor() == 9, "ind030 the cursor stays when the grabbed tile cannot go further (ignored move)")
	# follow is cleared when a move came from elsewhere
	v = _view()
	v.key_move(_key(KEY_RIGHT))
	v.key_move(_key(KEY_ENTER))
	v.key_move(_key(KEY_UP))
	v.animate([{"kind": "vanish", "cells": [4]}])
	_check.call(v.cursor() == 0, "ind030 the cursor stays when the grabbed tile vanished")
	v.animate([{"kind": "move", "moves": [[1, 2]], "time": 0.1}])
	_check.call(v.cursor() == 0, "ind030 the follow is used once")
	# arrow at an edge with grab: step_cell clamps, tile cannot move off board
	v = _view()
	v.key_move(_key(KEY_LEFT))
	v.key_move(_key(KEY_ENTER))
	_check.call(v.key_move(_key(KEY_LEFT)) == null and v.selected() == 0, "ind030 grab moving off the board is ignored and keeps the grab")
	v.input_enabled = false
	_check.call(v.key_move(_key(KEY_UP)) == null, "ind030 disabled input ignores keys")
	# mouse press hides the cursor
	v = _view()
	v.key_move(_key(KEY_RIGHT))
	_btn(v, _at(5), true)
	_check.call(not v.cursor_visible(), "ind030 a mouse press hides the keyboard cursor")
	_btn(v, _at(5), false)


# --- drawing -----------------------------------------------------------------------------------------------------

func _drawing() -> void:
	var v := _view()
	v.size = Vector2(400, 300)
	_node.add_child(v)
	await _node.get_tree().process_frame
	await _node.get_tree().process_frame
	var calls: Array = v.calls
	var statics := calls.filter(func(c: String) -> bool: return c.begins_with("static"))
	var bodies := calls.filter(func(c: String) -> bool: return c.begins_with("body"))
	var faces := calls.filter(func(c: String) -> bool: return c.begins_with("face"))
	_check.call(statics.size() >= 1 and statics.all(func(c: String) -> bool: return c == "static 1"), "ind030 only the block is drawn as static")
	_check.call(bodies.size() >= 4 and faces.size() == bodies.size(), "ind030 one body and one face per tile")
	var first_body := calls.find("body 2")
	var first_link := calls.find("links 4")
	var first_face := calls.find("face 2")
	_check.call(first_link > first_body and first_face > first_link, "ind030 order: bodies, links, faces: %s" % str(calls.slice(0, 12)))
	_check.call(calls.count("links 4") >= 1 and v.cell_px == CELL, "ind030 links get all four tiles; cell_px is set (%f)" % v.cell_px)
	var n := calls.size()
	v.animate([{"kind": "vanish", "cells": [0]}])
	v.calls.clear()
	await _node.get_tree().process_frame
	_check.call(v.calls.has("links 4") or v.calls.has("links 3"), "ind030 a vanishing tile is still drawn until removed: %s" % str(v.calls.filter(func(c: String) -> bool: return c.begins_with("links"))))
	v.finish_animation()
	v.calls.clear()
	await _node.get_tree().process_frame
	_check.call(v.calls.has("links 3") and not v.calls.has("links 4"), "ind030 after the vanish three tiles are drawn")
	v.clear()
	v.calls.clear()
	await _node.get_tree().process_frame
	_check.call(v.calls.is_empty(), "ind030 nothing is drawn without a board")
	_node.remove_child(v)
	v.free()
	var drawn := n
	_check.call(drawn > 0, "ind030 the view drew at all")


# --- safe area ---------------------------------------------------------------------------------------------------

func _safe_area() -> void:
	var d := WhiteSafeArea.from_rects(Rect2(10, 20, 380, 800), Vector2(400, 840), Vector2(800, 1680))
	_check.call(d.left == 20 and d.top == 40 and d.right == 20 and d.bottom == 40, "ind030 safe area spec example")
	d = WhiteSafeArea.from_rects(Rect2(0, 0, 400, 840), Vector2(400, 840), Vector2(400, 840))
	_check.call(d.left == 0 and d.top == 0 and d.right == 0 and d.bottom == 0, "ind030 safe rect equal to the window gives zero")
	d = WhiteSafeArea.from_rects(Rect2(-50, -50, 900, 1000), Vector2(400, 840), Vector2(400, 840))
	_check.call(d.left == 0 and d.top == 0 and d.right == 0 and d.bottom == 0, "ind030 safe rect larger than the window gives zero")
	d = WhiteSafeArea.from_rects(Rect2(0, 0, 0, 0), Vector2(400, 840), Vector2(400, 840))
	_check.call(d.left == 0 and d.right == 0, "ind030 an empty safe rect gives zero")
	d = WhiteSafeArea.from_rects(Rect2(0, 0, 100, -5), Vector2(400, 840), Vector2(400, 840))
	_check.call(d.top == 0 and d.bottom == 0, "ind030 a safe rect with negative height gives zero")
	d = WhiteSafeArea.from_rects(Rect2(100, 0, 400, 840), Vector2(400, 840), Vector2(400, 840))
	_check.call(d.left == 100 and d.right == 0, "ind030 a safe rect that sticks out on the right has no right inset")
	d = WhiteSafeArea.from_rects(Rect2(0, 0, 400, 800), Vector2(400, 840), Vector2(200, 420))
	_check.call(d.bottom == 20 and d.left == 0, "ind030 insets scale from window px to viewport units")
	d = WhiteSafeArea.from_rects(Rect2(10, 10, 100, 100), Vector2(400, 800), Vector2(720, 1280))
	_check.call(is_equal_approx(d.left, 18.0) and is_equal_approx(d.top, 16.0) and is_equal_approx(d.right, 522.0) and is_equal_approx(d.bottom, 1104.0),
			"ind030 non-uniform scale: %s" % str(d))
	var p := WhiteSafeArea.parse("40,80,40,60")
	_check.call(p.left == 40 and p.top == 80 and p.right == 40 and p.bottom == 60, "ind030 parse four values")
	p = WhiteSafeArea.parse("1,2")
	_check.call(p.left == 1 and p.top == 2 and p.right == 0 and p.bottom == 0, "ind030 parse two values")
	p = WhiteSafeArea.parse("a,b,c,d")
	_check.call(p.left == 0 and p.top == 0 and p.right == 0 and p.bottom == 0, "ind030 parse junk")
	p = WhiteSafeArea.parse("1,,3")
	_check.call(p.left == 1 and p.top == 0 and p.right == 3 and p.bottom == 0, "ind030 parse an empty part")
	p = WhiteSafeArea.parse("1,2,3,4,5,6")
	_check.call(p.bottom == 4 and p.size() == 4, "ind030 parse ignores extra parts")
	p = WhiteSafeArea.parse(" 4 , 5")
	_check.call(p.left == 4 and p.top == 5, "ind030 parse tolerates spaces")
	p = WhiteSafeArea.parse("0.5,1e1,3,4")
	_check.call(p.left == 0.5 and p.top == 10.0, "ind030 parse reads decimals and exponents")
	p = WhiteSafeArea.parse("")
	_check.call(p.size() == 4 and p.left == 0 and p.bottom == 0, "ind030 parse of the empty string")
	p = WhiteSafeArea.insets(Vector2(720, 1280), "5,6,7,8")
	_check.call(p.left == 5 and p.top == 6 and p.right == 7 and p.bottom == 8, "ind030 insets with an override uses the override")
	p = WhiteSafeArea.insets(Vector2(720, 1280), "x")
	_check.call(p.left == 0 and p.top == 0, "ind030 an override with junk is zero, the display is not read")
	p = WhiteSafeArea.insets(Vector2(720, 1280))
	_check.call(p.size() == 4 and p.left >= 0.0 and p.top >= 0.0 and p.right >= 0.0 and p.bottom >= 0.0, "ind030 insets without override are four non-negative numbers")
	p = WhiteSafeArea.insets(Vector2.ZERO)
	_check.call(p.size() == 4 and not is_nan(p.left) and not is_nan(p.bottom), "ind030 insets of a zero viewport are no NaN")


# --- screen ------------------------------------------------------------------------------------------------------

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


func _screen() -> void:
	WhiteText.lang = "nl"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Screen.SAVE))
	var s := _open(func(x: Screen) -> void: x.max_width = 720)
	for w in [1, 100, 720, 767, 768, 769, 770, 2276, 2277, 5000]:
		var i: Dictionary = s._insets_for(Vector2(w, 1280))
		var inner: int = w - i.left - i.right
		_check.call(i.left == i.right and i.top == 24 and i.bottom == 24 and i.left >= 24, "ind030 insets are symmetric and not below the margin at width %d" % w)
		if w >= 768:
			_check.call(inner == 720 or inner == 721 or w < 768, "ind030 the column is the maximum width, at most 1 px over for odd widths (%d: %d)" % [w, inner])
	s.max_width = 10000
	_check.call(s._insets_for(Vector2(2000, 1000)).left == 24, "ind030 a maximum wider than the viewport leaves the margins")
	s.max_width = -5
	_check.call(s._insets_for(Vector2(2000, 1000)).left == 24, "ind030 a negative maximum means no limit")
	s.max_width = 720
	s._debug["safe"] = "10,20,30,40"
	_check.call(s._insets_for(Vector2(720, 1280)).left == 24, "ind030 --safe is ignored while the hook is false")
	s.safe_area = true
	_check.call(s._insets_for(Vector2(720, 1280)).top == 44, "ind030 --safe counts once the hook is true")
	s._debug["safe"] = ""
	s.safe_area = false
	# margins follow viewport size changes
	s.max_width = 100
	s.get_viewport().size_changed.emit()
	_check.call(s.margin.get_theme_constant("margin_left") == s._insets_for(s.get_viewport_rect().size).left, "ind030 margins follow a viewport size change")
	_close(s)
	# the viewport signal must not call into the freed screen
	_node.get_viewport().size_changed.emit()
	_check.call(true, "ind030 size_changed after the screen is freed is harmless")
	# frozen clock: elapsed stays at the stored time while the clock runs; the clock still accumulates
	s = _open()
	s._debug["shot"] = "x.png"
	s.times[s.level] = 5000
	s._on_move(1)
	await _node.get_tree().create_timer(0.3).timeout
	_check.call(s._elapsed() == 5000, "ind030 _elapsed is the stored time in shot mode while the clock runs")
	s._refresh()
	_check.call(s.clock_label.text == "0:05", "ind030 frozen clock shows the stored time (%s)" % s.clock_label.text)
	s._stop_clock()
	_check.call(s.times[s.level] > 5000, "ind030 the clock still accumulates in shot mode")
	s._debug.erase("shot")
	_check.call(s._elapsed() == s.times[s.level], "ind030 outside shot mode a stopped clock reads the stored time")
	_close(s)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Screen.SAVE))
	WhiteText.register({})


# --- tools/shots.sh ----------------------------------------------------------------------------------------------

func _sh(args: Array, env := "") -> Dictionary:
	var out := []
	var sh := ProjectSettings.globalize_path("res://addons/white_kit/tools/shots.sh")
	var cmd := "%s bash '%s' %s 2>&1" % [env, sh, " ".join(args.map(func(a: String) -> String: return "'" + a + "'"))]
	var code := OS.execute("bash", ["-c", cmd], out, true)
	return {"code": code, "out": "".join(out)}


func _shots_script() -> void:
	var project := ProjectSettings.globalize_path("res://")
	var tmp := ProjectSettings.globalize_path("user://white_kit_ind030")
	DirAccess.make_dir_recursive_absolute(tmp)
	var r := _sh(["run", project, tmp.path_join("missing.txt"), tmp.path_join("out")])
	_check.call(r.code == 2 and r.out.contains("cannot read"), "ind030 shots.sh run: an unreadable scenario file exits 2: %s" % r.out)
	r = _sh(["run", project, tmp])
	_check.call(r.code == 2 and r.out.contains("usage"), "ind030 shots.sh run: too few arguments exit 2")
	r = _sh(["compare", project])
	_check.call(r.code == 2 and r.out.contains("usage"), "ind030 shots.sh compare: too few arguments exit 2")
	r = _sh(["before-after", project])
	_check.call(r.code == 2 and r.out.contains("usage"), "ind030 shots.sh before-after: too few arguments exit 2")
	r = _sh([])
	_check.call(r.code == 2, "ind030 shots.sh without a command exits 2")
	var scen := tmp.path_join("s.txt")
	var f := FileAccess.open(scen, FileAccess.WRITE)
	f.store_string("a-1 720x1280\nb_2 720x1280\n")
	f.close()
	r = _sh(["run", project, scen, tmp.path_join("out")])
	_check.call(r.code == 1 and r.out.contains("bad scenario line 2"), "ind030 shots.sh run: an underscore in a name is a bad line: %s" % r.out)
	f = FileAccess.open(scen, FileAccess.WRITE)
	f.store_string("x 721x\nx 1920x1441 \n\t\n")
	f.close()
	r = _sh(["run", project, scen, tmp.path_join("out")])
	_check.call(r.code == 1 and r.out.contains("bad scenario line 1") and r.out.contains("bad scenario line 2"), "ind030 shots.sh run: bad resolution and height over 1440: %s" % r.out)
	f = FileAccess.open(scen, FileAccess.WRITE)
	f.store_string("x 1920x1440")
	f.close()
	# valid line without a final newline and an unreachable project: the shot is reported missing, exit 1
	r = _sh(["run", tmp.path_join("no_project"), scen, tmp.path_join("out")])
	_check.call(r.code != 0, "ind030 shots.sh run: a project directory that does not exist fails")
	r = _sh(["compare", project, tmp.path_join("nope_a"), tmp.path_join("nope_b")])
	_check.call(r.code != 0, "ind030 shots.sh compare: folders that do not exist fail")
	# before-after refuses a kit with local changes and a missing project
	r = _sh(["before-after", tmp.path_join("no_project"), scen, "v0.2.0"])
	_check.call(r.code != 0, "ind030 shots.sh before-after: a missing project fails")
	for n in DirAccess.get_files_at(tmp):
		DirAccess.remove_absolute(tmp.path_join(n))
	DirAccess.remove_absolute(tmp.path_join("out"))
	DirAccess.remove_absolute(tmp)
