extends RefCounted
## WhiteTileView (design 14.4). Board 4x3, y up: values 0 empty, 1 block, 2 and 3 tiles.
## cell:  8  9 10 11 / 4  5  6  7 / 0  1  2  3

const View := preload("res://addons/white_kit/tests/fixtures/tile_view_fixture.gd")
const VALUES := [2, 0, 3, 0, 0, 1, 0, 2, 3, 3, 0, 1]
const CELL := 90.0 ## in a view of 400x300 with fit 0.3
const ORIGIN := Vector2(20, 15)

var _check: Callable
var _node: Node
var _chosen: Array = []
var _finished := 0


func _values(a: Array = VALUES) -> PackedByteArray:
	return PackedByteArray(a)


func _view() -> View:
	var v := View.new()
	v.size = Vector2(400, 300)
	v.show_cells(4, 3, _values())
	_chosen = []
	_finished = 0
	v.move_chosen.connect(func(c: int) -> void: _chosen.append(c))
	v.finished.connect(func() -> void: _finished += 1)
	return v


func _centre(cell: int) -> Vector2:
	return ORIGIN + Vector2(cell % 4 + 0.5, 2 - cell / 4 + 0.5) * CELL


func _mouse(v: View, p: Vector2, pressed: bool, button: int = MOUSE_BUTTON_LEFT) -> void:
	var e := InputEventMouseButton.new()
	e.position = p
	e.button_index = button
	e.pressed = pressed
	v._gui_input(e)


func _motion(v: View, p: Vector2) -> void:
	var e := InputEventMouseMotion.new()
	e.position = p
	v._gui_input(e)


func _key(code: Key) -> InputEventKey:
	var e := InputEventKey.new()
	e.keycode = code
	e.pressed = true
	return e


func run(check: Callable, node: Node) -> void:
	_check = check
	_node = node
	_statics()
	_phases()
	_animate()
	_state()
	await _drawing()
	_cell_input()
	_cell_keys()
	_board_swipes()
	_feedback()


func _statics() -> void:
	var lay := WhiteTileView.layout(Vector2(400, 300), 4, 3, 0.3)
	_check.call(lay.cell == CELL and lay.origin == ORIGIN, "view: layout cell and origin")
	_check.call(WhiteTileView.layout(Vector2(2, 2), 4, 3, 0.3).cell == 1.0, "view: layout cell is at least 1")
	_check.call(WhiteTileView.cell_at(_centre(0), lay, 4, 3) == 0 and WhiteTileView.cell_at(_centre(3), lay, 4, 3) == 3
			and WhiteTileView.cell_at(_centre(8), lay, 4, 3) == 8 and WhiteTileView.cell_at(_centre(11), lay, 4, 3) == 11,
			"view: cell_at at the four board corners")
	_check.call(WhiteTileView.cell_at(Vector2(19.9, 60), lay, 4, 3) == -1 and WhiteTileView.cell_at(Vector2(380.1, 60), lay, 4, 3) == -1
			and WhiteTileView.cell_at(Vector2(65, 14.9), lay, 4, 3) == -1 and WhiteTileView.cell_at(Vector2(65, 285.1), lay, 4, 3) == -1,
			"view: cell_at just outside the board")
	_check.call(WhiteTileView.drag_dir(Vector2(10, 2)) == WhiteTileView.Dir.R and WhiteTileView.drag_dir(Vector2(-10, 2)) == WhiteTileView.Dir.L
			and WhiteTileView.drag_dir(Vector2(2, 10)) == WhiteTileView.Dir.D and WhiteTileView.drag_dir(Vector2(2, -10)) == WhiteTileView.Dir.U,
			"view: drag_dir on both axes, screen down is D")
	_check.call(WhiteTileView.drag_dir(Vector2(10, 10)) == WhiteTileView.Dir.D and WhiteTileView.drag_dir(Vector2(-10, -10)) == WhiteTileView.Dir.U,
			"view: drag_dir diagonal ties go vertical")
	_check.call(WhiteTileView.neighbour_dir(0, 1, 4) == 0 and WhiteTileView.neighbour_dir(1, 0, 4) == 1
			and WhiteTileView.neighbour_dir(4, 0, 4) == 2 and WhiteTileView.neighbour_dir(0, 4, 4) == 3,
			"view: neighbour_dir for the four directions")
	_check.call(WhiteTileView.neighbour_dir(0, 5, 4) == -1 and WhiteTileView.neighbour_dir(3, 4, 4) == -1
			and WhiteTileView.neighbour_dir(2, 2, 4) == -1 and WhiteTileView.neighbour_dir(0, 2, 4) == -1,
			"view: neighbour_dir is -1 for diagonals, row wraps, itself and distance 2")
	_check.call(WhiteTileView.key_dir(KEY_RIGHT) == 0 and WhiteTileView.key_dir(KEY_D) == 0 and WhiteTileView.key_dir(KEY_LEFT) == 1
			and WhiteTileView.key_dir(KEY_A) == 1 and WhiteTileView.key_dir(KEY_DOWN) == 2 and WhiteTileView.key_dir(KEY_S) == 2
			and WhiteTileView.key_dir(KEY_UP) == 3 and WhiteTileView.key_dir(KEY_W) == 3 and WhiteTileView.key_dir(KEY_X) == -1,
			"view: key_dir arrows and WASD")
	_check.call(WhiteTileView.step_cell(0, 1, 4, 3) == 0 and WhiteTileView.step_cell(3, 0, 4, 3) == 3
			and WhiteTileView.step_cell(8, 3, 4, 3) == 8 and WhiteTileView.step_cell(0, 2, 4, 3) == 0
			and WhiteTileView.step_cell(5, 0, 4, 3) == 6 and WhiteTileView.step_cell(5, 3, 4, 3) == 9,
			"view: step_cell clamps at the edges")


func _ids16(tiles: Array) -> PackedInt32Array:
	var ids := PackedInt32Array()
	ids.resize(16)
	ids.fill(-1)
	for c in tiles:
		ids[c] = c
	return ids


func _phases() -> void:
	var ids := _ids16([0, 2])
	var r := WhiteTileView.build_phases(4, ids, [{"kind": "move", "moves": [[0, 2], [2, 0]], "time": 0.12, "ease": true}], 0.24)
	_check.call(r.ids[0] == 2 and r.ids[2] == 0 and r.phases.size() == 1 and r.phases[0].dur == 0.12 and r.phases[0].ease,
			"phases: a swap exchanges the two ids, time and ease are kept")
	_check.call(ids[0] == 0 and ids[2] == 2, "phases: the input ids are not changed")
	r = WhiteTileView.build_phases(4, _ids16([0]), [{"kind": "move", "moves": [[0, 1]], "time": 0.1}], 0.24)
	_check.call(r.ids[0] == -1 and r.ids[1] == 0 and not r.phases[0].ease, "phases: a move to an empty cell leaves -1 at the source")
	_check.call(r.phases[0].from == [Vector2(0, 0)] and r.phases[0].to == [Vector2(1, 0)], "phases: positions are in cells, y up")
	r = WhiteTileView.build_phases(4, _ids16([8, 12]), [{"kind": "move", "moves": [[8, 4], [12, 0]], "speed": 16.0}], 0.24)
	_check.call(is_equal_approx(r.phases[0].dur, 3.0 / 16.0), "phases: a fall with distances 1 and 3 at speed 16 lasts 3/16")
	r = WhiteTileView.build_phases(4, _ids16([8]), [{"kind": "move", "moves": [[8, 8]], "speed": 16.0}], 0.24)
	_check.call(is_equal_approx(r.phases[0].dur, 1.0 / 16.0), "phases: a move of distance below 1 lasts 1/speed")
	r = WhiteTileView.build_phases(4, _ids16([0]), [{"kind": "move", "moves": [[0, 3]], "speed": 8.0}], 0.24)
	_check.call(is_equal_approx(r.phases[0].dur, 3.0 / 8.0), "phases: a horizontal move counts its width")
	r = WhiteTileView.build_phases(4, _ids16([0, 2]), [{"kind": "vanish", "cells": [0]}], 0.24)
	_check.call(r.ids[0] == -1 and r.ids[2] == 2 and r.phases[0].kind == "vanish" and r.phases[0].dur == 0.24 and r.phases[0].ids == [0],
			"phases: vanish removes the ids and lasts the vanish total")
	r = WhiteTileView.build_phases(4, _ids16([0]), [{"kind": "spin"}, {"kind": "move", "moves": [[0, 1]], "time": 0.1}], 0.24)
	_check.call(r.phases.size() == 1 and r.ids[1] == 0, "phases: an unknown kind is skipped")
	r = WhiteTileView.build_phases(4, _ids16([0]), [{"kind": "move", "moves": [[5, 6], [0, 1]], "time": 0.1}], 0.24)
	_check.call(r.phases[0].ids == [0] and r.ids[1] == 0 and r.ids[6] == -1, "phases: a move from an empty cell is skipped, the rest runs")
	r = WhiteTileView.build_phases(4, _ids16([0]), [], 0.24)
	_check.call(r.phases.is_empty() and r.ids == _ids16([0]), "phases: no steps, no phases")
	r = WhiteTileView.build_phases(4, _ids16([0, 1, 2]), [
			{"kind": "move", "moves": [[0, 4], [1, 5]], "time": 0.1}, {"kind": "vanish", "cells": [4, 5]},
			{"kind": "move", "moves": [[2, 1]], "speed": 16.0}], 0.24)
	_check.call(r.phases.size() == 3 and r.ids[1] == 2 and r.ids[4] == -1 and r.ids[5] == -1 and r.ids[0] == -1, "phases: steps chain on the ids of the step before")


func _animate() -> void:
	var v := _view()
	v.animate([{"kind": "move", "moves": [[0, 1]], "time": 0.1}])
	_check.call(v.shown()[1] == 2 and v.shown()[0] == 0 and v.busy(), "animate: shown() is the end state at once and the view is busy")
	v._process(0.05)
	_check.call(v.busy() and _finished == 0, "animate: halfway the view is still busy")
	v.finish_animation()
	_check.call(not v.busy() and _finished == 1, "animate: finish_animation ends it and emits finished once")
	v.finish_animation()
	_check.call(_finished == 1, "animate: finish_animation on an idle view emits nothing")
	v.animate([{"kind": "move", "moves": [[1, 0]], "time": 0.1}])
	v._process(1.0)
	_check.call(not v.busy() and _finished == 2 and v.shown()[0] == 2, "animate: running the phases to the end emits finished")
	v.animate([])
	_check.call(not v.busy() and _finished == 2, "animate: no steps emit nothing")
	v.animate([{"kind": "vanish", "cells": [0, 2]}])
	_check.call(v.shown()[0] == 0 and v.shown()[2] == 0 and v.shown()[5] == 1 and v.shown()[11] == 1, "animate: vanish clears the cells, blocks stay")
	v.finish_animation()
	_check.call(v._alive[0] == 0 and v._alive[2] == 0 and v._alive[7] == 1, "animate: vanished tiles are gone after the phase")
	v.free()
	v = _view()
	var before := _values([0, 0, 3, 0, 0, 1, 0, 2, 3, 3, 0, 1])
	v.animate([{"kind": "vanish", "cells": [8]}], before)
	_check.call(v.shown()[0] == 0 and v.shown()[8] == 0 and v.shown()[9] == 3, "animate: a differing before is shown first")
	v.free()
	v = _view()
	v.animate([{"kind": "move", "moves": [[0, 1], [1, 0]], "time": 0.1}])
	_check.call(v.shown()[1] == 2 and v.shown()[0] == 0, "animate: a move from an empty cell is skipped, the rest runs")
	v.free()
	v = _view()
	v.animate([{"kind": "move", "moves": [[0, 1]], "time": 0.1}, {"kind": "move", "moves": [[1, 4]], "time": 0.1}, {"kind": "move", "moves": [[9, 10]], "time": 0.1}])
	_check.call(v.shown()[5] == 1 and v.shown()[11] == 1 and v.shown()[4] == 2 and v.shown()[10] == 3 and v.shown()[9] == 0, "animate: several steps, static cells keep their place")
	v.free()
	v = _view()
	v.animate([{"kind": "move", "moves": [[2, 3]], "time": 0.1}])
	v.animate([{"kind": "move", "moves": [[3, 2]], "time": 0.1}])
	_check.call(_finished == 1 and v.shown()[2] == 3, "animate: a new animation finishes the running one first")
	v.free()


func _state() -> void:
	var v := View.new()
	_check.call(not v.has_board() and v.shown().is_empty() and v.selected() == -1 and not v.busy(), "state: a new view has no board")
	v.size = Vector2(400, 300)
	v.show_cells(4, 3, _values())
	v.debug_select(0)
	v._cursor = 3
	v._cursor_on = true
	v.show_values(_values())
	_check.call(v.has_board() and v.grid_w == 4 and v.grid_h == 3 and v.selected() == -1 and v.cursor() == 3 and v.cursor_visible(),
			"state: show_values resets the selection and keeps the cursor")
	v.show_cells(4, 3, _values())
	_check.call(v.cursor() == 0 and not v.cursor_visible(), "state: show_cells resets the cursor")
	_check.call(v.shown() == _values(), "state: shown() returns the values")
	v.clear()
	_check.call(not v.has_board(), "state: clear removes the board")
	var p := InputEventMouseButton.new()
	p.position = Vector2(65, 240)
	p.button_index = MOUSE_BUTTON_LEFT
	p.pressed = true
	var seen := []
	v.move_chosen.connect(func(c: int) -> void: seen.append(c))
	v._gui_input(p)
	p.pressed = false
	v._gui_input(p)
	_check.call(seen.is_empty() and v.selected() == -1, "state: input is ignored without a board")
	v.free()


func _drawing() -> void:
	var v := _view()
	_node.add_child(v)
	v.size = Vector2(400, 300)
	v.queue_redraw()
	await _node.get_tree().process_frame
	await _node.get_tree().process_frame
	var want := ["static 1", "static 1", "body 2", "body 3", "body 2", "body 3", "body 3", "links 5",
			"face 2", "face 3", "face 2", "face 3", "face 3"]
	_check.call(v.calls.slice(0, want.size()) == want, "drawing: statics, bodies, links once, faces; ids ascending (%s)" % str(v.calls))
	_check.call(v.cell_px == CELL, "drawing: cell_px is the cell size")
	v.calls.clear()
	v.clear()
	await _node.get_tree().process_frame
	await _node.get_tree().process_frame
	_check.call(v.calls.is_empty(), "drawing: nothing is drawn without a board")
	_node.remove_child(v)
	v.free()


func _cell_input() -> void:
	var v := _view()
	var p := _centre(0)
	_mouse(v, p, true)
	_motion(v, p + Vector2(0.4 * CELL - 1.0, 0))
	_check.call(_chosen.is_empty(), "input: a drag just under 0.4 cell does not fire")
	_motion(v, p + Vector2(0.4 * CELL, 0))
	_check.call(_chosen == [0], "input: a drag of 0.4 cell on a tile fires during the motion")
	_motion(v, p + Vector2(80, 0))
	_mouse(v, p + Vector2(80, 0), false)
	_check.call(_chosen == [0], "input: a swipe fires once")
	v.free()
	v = _view()
	_mouse(v, p, true)
	_mouse(v, p + Vector2(23, 0), false)
	_check.call(_chosen.is_empty() and v.selected() == 0, "input: a release within 23 px is a tap")
	v.free()
	v = _view()
	_mouse(v, p, true)
	_mouse(v, p + Vector2(24, 0), false)
	_check.call(_chosen == [0], "input: a release at 24 px is a swipe")
	v.free()
	v = _view()
	var e := _centre(1) # empty cell
	_mouse(v, e, true)
	_motion(v, e + Vector2(60, 0))
	_mouse(v, e + Vector2(60, 0), false)
	_check.call(_chosen.is_empty() and v.selected() == -1, "input: a press on an empty cell never swipes")
	_mouse(v, Vector2(2, 2), true)
	_mouse(v, Vector2(80, 2), false)
	_check.call(_chosen.is_empty(), "input: a press outside the board never swipes")
	v.free()
	v = _view()
	_mouse(v, p, true)
	_mouse(v, p, false)
	_check.call(v.selected() == 0, "input: tap selects a tile")
	_mouse(v, p, true)
	_mouse(v, p, false)
	_check.call(v.selected() == -1, "input: tap on the selected cell deselects")
	_mouse(v, p, true)
	_mouse(v, p, false)
	_mouse(v, _centre(1), true)
	_mouse(v, _centre(1), false)
	_check.call(_chosen == [0] and v.selected() == -1, "input: tap-tap on an empty neighbour emits the move code")
	v.free()
	v = _view()
	_mouse(v, p, true)
	_mouse(v, p, false)
	_mouse(v, _centre(2), true)
	_mouse(v, _centre(2), false)
	_check.call(_chosen.is_empty() and v.selected() == 2, "input: tap on another tile selects it instead")
	_mouse(v, _centre(1), true)
	_mouse(v, _centre(1), false)
	_check.call(_chosen == [2 * 4 + WhiteTileView.Dir.L], "input: the selected tile moves to the neighbour (towards L)")
	v.free()
	v = _view()
	_mouse(v, p, true)
	_mouse(v, p, false)
	_mouse(v, _centre(6), true)
	_mouse(v, _centre(6), false)
	_check.call(v.selected() == -1 and _chosen.is_empty(), "input: tap on another empty cell or far away deselects")
	_mouse(v, p, true)
	_mouse(v, p, false)
	_mouse(v, Vector2(1, 1), true)
	_mouse(v, Vector2(1, 1), false)
	_check.call(v.selected() == -1, "input: tap outside the board deselects")
	v.free()
	v = _view()
	var t := _centre(9) # tile above a block
	_mouse(v, t, true)
	_motion(v, t + Vector2(0, 60))
	_check.call(_chosen.is_empty() and v._shake_id == 9, "input: a move that the resolve hook ignores shakes the tile and emits nothing")
	v.free()
	v = _view()
	_mouse(v, p, true, MOUSE_BUTTON_RIGHT)
	_mouse(v, p, false, MOUSE_BUTTON_RIGHT)
	_check.call(v.selected() == -1 and _chosen.is_empty(), "input: the right mouse button does nothing")
	v.input_enabled = false
	_mouse(v, p, true)
	_mouse(v, p, false)
	_check.call(v.selected() == -1 and v.key_move(_key(KEY_RIGHT)) == null and not v.cursor_visible(), "input: nothing happens when input is disabled")
	v.free()
	v = _view()
	_mouse(v, p, true)
	v.animate([{"kind": "move", "moves": [[2, 3]], "time": 0.1}])
	_mouse(v, p, false)
	_check.call(v.selected() == 0 and not v.busy(), "input: a tap finishes the running animation")
	v.free()


func _cell_keys() -> void:
	var v := _view()
	_check.call(v.key_move(_key(KEY_RIGHT)) == null and v.cursor_visible() and v.cursor() == 0, "keys: the first arrow only shows the cursor")
	v.key_move(_key(KEY_RIGHT))
	_check.call(v.cursor() == 1, "keys: an arrow moves the cursor")
	v.key_move(_key(KEY_LEFT))
	v.key_move(_key(KEY_LEFT))
	v.key_move(_key(KEY_DOWN))
	_check.call(v.cursor() == 0, "keys: the cursor clamps at the edge")
	v.key_move(_key(KEY_UP))
	v.key_move(_key(KEY_DOWN))
	v.key_move(_key(KEY_RIGHT))
	_check.call(v.key_move(_key(KEY_SPACE)) == null and v.selected() == -1, "keys: space on an empty cell does not grab")
	v.key_move(_key(KEY_LEFT))
	_check.call(v.key_move(_key(KEY_SPACE)) == null and v.selected() == 0, "keys: space on a tile grabs it")
	_check.call(v.key_move(_key(KEY_KP_ENTER)) == null and v.selected() == -1, "keys: enter releases the grab")
	v.key_move(_key(KEY_ENTER))
	_check.call(v.key_move(_key(KEY_ESCAPE)) == null and v.selected() == -1, "keys: escape releases the grab")
	v.key_move(_key(KEY_ENTER))
	var code: Variant = v.key_move(_key(KEY_RIGHT))
	_check.call(code == 0 and v.selected() == -1, "keys: an arrow with a grab returns the move code and releases")
	_check.call(_chosen.is_empty(), "keys: a keyboard move does not emit move_chosen")
	v.animate([{"kind": "move", "moves": [[0, 1]], "time": 0.1}])
	_check.call(v.cursor() == 1, "keys: after animate the cursor follows the grabbed tile")
	v.free()
	v = _view()
	v._cursor = 9
	v._cursor_on = true
	v.key_move(_key(KEY_SPACE))
	_check.call(v.key_move(_key(KEY_DOWN)) == null and v.selected() == 9 and v._shake_id == 9, "keys: an ignored move shakes the tile and keeps the grab")
	v.free()
	v = _view()
	v._cursor_on = true
	v.key_move(_key(KEY_SPACE))
	v.key_move(_key(KEY_RIGHT))
	v.animate([{"kind": "vanish", "cells": [0]}])
	_check.call(v.cursor() == 0 and v.shown()[0] == 0, "keys: the cursor stays when the grabbed tile vanished")
	_check.call(v.key_move(_key(KEY_X)) == null, "keys: other keys do nothing")
	v.free()


func _board_swipes() -> void:
	var v := _view()
	v.input_mode = WhiteTileView.InputMode.BOARD_SWIPES
	v.board_moves = true
	var off := Vector2(5, 5) # outside the board, inside the view
	_mouse(v, off, true)
	_motion(v, off + Vector2(0.4 * CELL, 0))
	_check.call(_chosen == [WhiteTileView.Dir.R], "swipes: a drag anywhere emits the direction code, also off the board")
	_mouse(v, off, false)
	_mouse(v, _centre(1), true)
	_mouse(v, _centre(1) + Vector2(0, 30), false)
	_check.call(_chosen == [WhiteTileView.Dir.R, WhiteTileView.Dir.D], "swipes: a release at the minimum fires on an empty cell")
	_mouse(v, _centre(0), true)
	_mouse(v, _centre(0), false)
	_check.call(_chosen.size() == 2 and v.selected() == -1, "swipes: a tap does nothing")
	_check.call(v.key_move(_key(KEY_LEFT)) == WhiteTileView.Dir.L and v.key_move(_key(KEY_UP)) == WhiteTileView.Dir.U, "swipes: arrows return the code")
	_check.call(v.key_move(_key(KEY_SPACE)) == null and v.key_move(_key(KEY_ENTER)) == null and v.key_move(_key(KEY_ESCAPE)) == null
			and not v.cursor_visible() and v.selected() == -1, "swipes: space, enter and escape do nothing")
	v.board_moves = false
	_chosen = []
	_mouse(v, off, true)
	_motion(v, off + Vector2(0, 50))
	_check.call(_chosen.is_empty() and v._nudge_dir == WhiteTileView.Dir.D, "swipes: an ignored swipe nudges and emits nothing")
	v._nudge_dir = -1
	_check.call(v.key_move(_key(KEY_RIGHT)) == null and v._nudge_dir == WhiteTileView.Dir.R, "swipes: an ignored arrow nudges and returns null")
	v.free()


func _feedback() -> void:
	var v := _view()
	v.shake_cell(1)
	_check.call(v._shake_id == -1, "feedback: shaking an empty cell does nothing")
	v.shake_cell(0)
	_check.call(v._shake_id == 0, "feedback: shake_cell shakes the tile")
	v._process(v.shake_time + 0.01)
	_check.call(v._shake_id == -1, "feedback: the shake ends after shake_time")
	v.nudge(WhiteTileView.Dir.U)
	_check.call(v._nudge_offset().is_equal_approx(Vector2.ZERO), "feedback: a nudge starts at rest")
	v._process(v.nudge_time / 2.0)
	_check.call(is_equal_approx(v._nudge_offset().y, -v.nudge_px) and v._nudge_offset().x == 0.0, "feedback: halfway the board is shifted by nudge_px (up is -y)")
	v._process(v.nudge_time)
	_check.call(v._nudge_dir == -1 and v._nudge_offset() == Vector2.ZERO, "feedback: the nudge ends")
	v.free()
