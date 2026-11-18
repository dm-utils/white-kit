class_name WhiteTileView
extends Control
## Board of w x h square cells with animated tiles. Layout, tile registry with stable ids, phase animation, shake and
## nudge, input (cell moves or board swipes). Games override the draw and resolve hooks; rules stay in the game.
## Coordinates: cell i = y * w + x, y up, (0, 0) bottom-left; screen down is Dir.D.

enum Dir { R, L, D, U }
enum InputMode { CELL_MOVES, BOARD_SWIPES }

signal move_chosen(code: int) ## game move code from a resolve hook, never -1
signal finished ## an animation reached its end (normally or by finish_animation)

# look and timing: defaults are White Tally's; a game changes them in _init()
var board_color := Color("232933")
var grid_color := Color("2C333F")
var fit := 0.3 ## board margin in cells, added to w and h when sizing
var tile_gap := 0.08 ## gap between tiles, in cells
var tile_radius := 0.18 ## corner radius, in cells
var mark_color := WhiteTheme.ACCENT
var mark_px := 4.0
var vanish_time := 0.18
var vanish_pause := 0.06
var vanish_scale := 0.7
var shake_time := 0.15
var shake_cycles := 3
var shake_px := 4.0
var nudge_time := 0.15
var nudge_px := 6.0
var swipe_frac := 0.4 ## drag as part of a cell that fires a swipe during the drag
var swipe_min_px := 24.0 ## drag in px that still counts as a swipe on release

var input_mode := InputMode.CELL_MOVES
var input_enabled := true
var grid_w := 0
var grid_h := 0
var cell_px := 0.0 ## cell size of the last draw, for hooks

var _state := PackedByteArray()
var _ids := PackedInt32Array() ## cell -> tile id, -1 none (after the running animation)
var _val := PackedByteArray() ## by id
var _pos := PackedVector2Array() ## by id, cells, y up
var _scale := PackedFloat32Array()
var _alpha := PackedFloat32Array()
var _alive := PackedByteArray()
var _phases: Array = []
var _pi := 0
var _pt := 0.0
var _sel := -1
var _grab := false
var _cursor := 0
var _cursor_on := false
var _follow := -1
var _shake_id := -1
var _shake_t := 0.0
var _nudge_dir := -1
var _nudge_t := 0.0
var _press := -2 ## cell under the press, -1 outside the board, -2 no press
var _press_pos := Vector2.ZERO
var _fired := false
var _box := StyleBoxFlat.new()


# --- hooks -------------------------------------------------------------------------------------------------------

## Non-zero cell values that are tiles (move, animate, can be selected); others are static cells.
func _is_tile(value: int) -> bool:
	return value != 0


## CELL_MOVES: game move code for "tile in cell moves towards dir", -1 = ignored.
func _resolve_cell_move(_cell: int, _dir: int) -> int:
	return -1


## BOARD_SWIPES: game move code for a swipe or arrow key towards dir, -1 = ignored.
func _resolve_board_swipe(_dir: int) -> int:
	return -1


func _draw_static(_rect: Rect2, _value: int) -> void:
	pass


func _draw_tile_body(rect: Rect2, _value: int, alpha: float) -> void:
	var col := WhiteTheme.DIM
	col.a = alpha
	_box.bg_color = col
	_box.set_corner_radius_all(int(cell_px * tile_radius))
	draw_style_box(_box, rect)


## tiles: dictionaries in ascending id order: id, value, pos (cells), center (px), rect, scale, alpha, cell (px).
func _draw_links(_tiles: Array) -> void:
	pass


func _draw_tile_face(_rect: Rect2, _value: int, _alpha: float, _scale_f: float) -> void:
	pass


# --- pure helpers (tested) ---------------------------------------------------------------------------------------

## {cell, origin} in px for a board of w x h in an area.
static func layout(area: Vector2, w: int, h: int, fit_cells: float) -> Dictionary:
	var cell := maxf(floorf(minf(area.x / (w + fit_cells), area.y / (h + fit_cells))), 1.0)
	return {"cell": cell, "origin": (area - Vector2(w, h) * cell) / 2.0}


## Cell index under a point, -1 outside the board.
@warning_ignore("integer_division")
static func cell_at(p: Vector2, lay: Dictionary, w: int, h: int) -> int:
	var q: Vector2 = (p - lay.origin) / lay.cell
	var x := floori(q.x)
	var y := h - 1 - floori(q.y)
	if q.x < 0.0 or q.y < 0.0 or x >= w or y < 0 or y >= h:
		return -1
	return y * w + x


## Direction of a drag (dominant axis, ties go vertical); screen down is D.
static func drag_dir(d: Vector2) -> int:
	if absf(d.x) > absf(d.y):
		return Dir.R if d.x > 0.0 else Dir.L
	return Dir.D if d.y > 0.0 else Dir.U


## Direction from cell a to an orthogonal neighbour b, -1 when they are not neighbours.
@warning_ignore("integer_division")
static func neighbour_dir(a: int, b: int, w: int) -> int:
	var dx := (b % w) - (a % w)
	var dy := (b / w) - (a / w)
	if dy == 0 and dx == 1:
		return Dir.R
	if dy == 0 and dx == -1:
		return Dir.L
	if dx == 0 and dy == 1:
		return Dir.U
	if dx == 0 and dy == -1:
		return Dir.D
	return -1


## Direction for an arrow or WASD key, -1 for other keys.
static func key_dir(keycode: int) -> int:
	match keycode:
		KEY_RIGHT, KEY_D:
			return Dir.R
		KEY_LEFT, KEY_A:
			return Dir.L
		KEY_DOWN, KEY_S:
			return Dir.D
		KEY_UP, KEY_W:
			return Dir.U
	return -1


## Cell after a cursor step, unchanged at the edge.
@warning_ignore("integer_division")
static func step_cell(i: int, d: int, w: int, h: int) -> int:
	var x := i % w
	var y := i / w
	match d:
		Dir.R:
			x = mini(x + 1, w - 1)
		Dir.L:
			x = maxi(x - 1, 0)
		Dir.U:
			y = mini(y + 1, h - 1)
		_:
			y = maxi(y - 1, 0)
	return y * w + x


## Phases for generic steps. ids: cell -> tile id before. Returns {"phases", "ids" (after)}.
## Phase: {kind, dur, ids, from, to, ease}; positions in cells.
@warning_ignore("integer_division")
static func build_phases(w: int, ids: PackedInt32Array, steps: Array, vanish_total: float) -> Dictionary:
	var cur := ids.duplicate()
	var phases: Array = []
	for s in steps:
		match str(s.get("kind", "")):
			"move":
				var pid: Array = []
				var pf: Array = []
				var pt: Array = []
				var dest: Array = []
				var longest := 0.0
				for m in s.moves:
					var f: int = m[0]
					var t: int = m[1]
					if f < 0 or f >= cur.size() or cur[f] < 0:
						push_error("WhiteTileView: move from a cell without a tile: %d" % f)
						continue
					pid.append(cur[f])
					pf.append(Vector2(f % w, f / w))
					pt.append(Vector2(t % w, t / w))
					dest.append(t)
					longest = maxf(longest, maxf(absf(float(t % w - f % w)), absf(float(t / w - f / w))))
				# simultaneous: clear every source, then fill every target
				for k in pid.size():
					cur[int((pf[k] as Vector2).y) * w + int((pf[k] as Vector2).x)] = -1
				for k in pid.size():
					cur[dest[k]] = pid[k]
				var dur: float = float(s.time) if s.has("time") else maxf(1.0, longest) / float(s.speed)
				phases.append({"kind": "move", "dur": dur, "ids": pid, "from": pf, "to": pt, "ease": bool(s.get("ease", false))})
			"vanish":
				var vid: Array = []
				for c in s.cells:
					if cur[c] >= 0:
						vid.append(cur[c])
						cur[c] = -1
				phases.append({"kind": "vanish", "dur": vanish_total, "ids": vid, "from": [], "to": [], "ease": false})
			_:
				push_error("WhiteTileView: unknown step kind '%s'" % str(s.get("kind", "")))
	return {"phases": phases, "ids": cur}


# --- state -------------------------------------------------------------------------------------------------------

## New board, no animation; resets selection, grab and cursor.
func show_cells(w: int, h: int, values: PackedByteArray) -> void:
	grid_w = w
	grid_h = h
	_load(values)
	_cursor = 0
	_cursor_on = false


## Same board, no animation; resets selection and grab, keeps the cursor.
func show_values(values: PackedByteArray) -> void:
	_load(values)


func clear() -> void:
	grid_w = 0
	grid_h = 0
	_state = PackedByteArray()
	_ids.resize(0)
	_alive.resize(0)
	_phases.clear()
	_sel = -1
	_grab = false
	_press = -2
	queue_redraw()


func has_board() -> bool:
	return grid_w > 0 and grid_h > 0


func busy() -> bool:
	return not _phases.is_empty()


## Cell values after the current animation.
func shown() -> PackedByteArray:
	return _state


func selected() -> int:
	return _sel


func cursor() -> int:
	return _cursor


func cursor_visible() -> bool:
	return _cursor_on


func debug_select(cell: int) -> void:
	_sel = cell
	queue_redraw()


func _load(values: PackedByteArray) -> void:
	_phases.clear()
	_pi = 0
	_pt = 0.0
	_state = values.duplicate()
	var n := _state.size()
	_ids.resize(n)
	_val.resize(n)
	_pos.resize(n)
	_scale.resize(n)
	_alpha.resize(n)
	_alive.resize(n)
	_alive.fill(0)
	for i in n:
		_ids[i] = -1
		if _state[i] != 0 and _is_tile(_state[i]):
			_ids[i] = i
			_val[i] = _state[i]
			_pos[i] = _cell_pos(i)
			_scale[i] = 1.0
			_alpha[i] = 1.0
			_alive[i] = 1
	_sel = -1
	_grab = false
	queue_redraw()


@warning_ignore("integer_division")
func _cell_pos(i: int) -> Vector2:
	return Vector2(i % grid_w, i / grid_w)


# --- animation ---------------------------------------------------------------------------------------------------

## Plays steps from the shown state (or from `before` when that differs). shown() is the end state at once.
func animate(steps: Array, before: PackedByteArray = PackedByteArray()) -> void:
	finish_animation()
	_sel = -1
	_grab = false
	if not before.is_empty() and before != _state:
		show_values(before)
	var follow := _follow
	_follow = -1
	var built := build_phases(grid_w, _ids, steps, vanish_time + vanish_pause)
	if built.phases.is_empty():
		return
	_ids = built.ids
	for i in _state.size():
		if _ids[i] >= 0:
			_state[i] = _val[_ids[i]]
		elif _is_tile(_state[i]):
			_state[i] = 0
	_phases = built.phases
	_pi = 0
	_pt = 0.0
	if follow >= 0 and _cursor_on:
		var at := _ids.find(follow)
		if at >= 0:
			_cursor = at
	set_process(true)
	queue_redraw()


func finish_animation() -> void:
	if _phases.is_empty():
		return
	while _pi < _phases.size():
		var p: Dictionary = _phases[_pi]
		_apply(p, maxf(float(p.dur), 0.001))
		_pi += 1
	_phases.clear()
	_pt = 0.0
	queue_redraw()
	finished.emit()


func shake_cell(cell: int) -> void:
	if cell < 0 or cell >= _ids.size() or _ids[cell] < 0:
		return
	_shake_id = _ids[cell]
	_shake_t = 0.0
	set_process(true)
	queue_redraw()


## Shifts the whole board a little towards dir and back.
func nudge(dir: int) -> void:
	_nudge_dir = dir
	_nudge_t = 0.0
	set_process(true)
	queue_redraw()


func _process(delta: float) -> void:
	var redraw := false
	if _shake_id >= 0:
		_shake_t += delta
		if _shake_t >= shake_time:
			_shake_id = -1
		redraw = true
	if _nudge_dir >= 0:
		_nudge_t += delta
		if _nudge_t >= nudge_time:
			_nudge_dir = -1
		redraw = true
	if not _phases.is_empty():
		_advance(delta)
		redraw = true
	if redraw:
		queue_redraw()
	else:
		set_process(false)


func _advance(delta: float) -> void:
	while delta > 0.0 and _pi < _phases.size():
		var p: Dictionary = _phases[_pi]
		var dur := maxf(float(p.dur), 0.001)
		var left := dur - _pt
		if delta >= left:
			_apply(p, dur)
			delta -= left
			_pi += 1
			_pt = 0.0
		else:
			_pt += delta
			_apply(p, _pt)
			delta = 0.0
	if _pi >= _phases.size():
		_phases.clear()
		finished.emit()


## Tile positions or fade of phase p after sec seconds.
func _apply(p: Dictionary, sec: float) -> void:
	var dur := maxf(float(p.dur), 0.001)
	var ids: Array = p.ids
	if p.kind == "vanish":
		var f := clampf(sec / maxf(vanish_time, 0.001), 0.0, 1.0)
		for id in ids:
			_scale[id] = lerpf(1.0, vanish_scale, f)
			_alpha[id] = 1.0 - f
			if sec >= dur:
				_alive[id] = 0
		return
	var t := clampf(sec / dur, 0.0, 1.0)
	if p.ease:
		t = 1.0 - (1.0 - t) * (1.0 - t)
	for k in ids.size():
		_pos[ids[k]] = (p.from[k] as Vector2).lerp(p.to[k], t)


# --- drawing -----------------------------------------------------------------------------------------------------

func _draw() -> void:
	if not has_board():
		return
	var lay := layout(size, grid_w, grid_h, fit)
	var cell: float = lay.cell
	cell_px = cell
	var o: Vector2 = lay.origin + _nudge_offset()
	var grid := Vector2(grid_w, grid_h) * cell
	var rim := cell * 0.1
	_box.bg_color = board_color
	_box.set_corner_radius_all(int(cell * tile_radius))
	draw_style_box(_box, Rect2(o - Vector2(rim, rim), grid + Vector2(rim, rim) * 2.0))
	for x in range(1, grid_w):
		draw_line(o + Vector2(x * cell, 0), o + Vector2(x * cell, grid.y), grid_color, 2.0)
	for y in range(1, grid_h):
		draw_line(o + Vector2(0, y * cell), o + Vector2(grid.x, y * cell), grid_color, 2.0)
	for i in _state.size():
		if _state[i] != 0 and not _is_tile(_state[i]):
			_draw_static(_cell_rect(i, o, cell), _state[i])
	var tiles: Array = []
	for id in _alive.size():
		if _alive[id] == 1:
			var r := _tile_rect(id, o, cell)
			tiles.append({"id": id, "value": _val[id], "pos": _pos[id], "center": r.get_center(), "rect": r,
					"scale": _scale[id], "alpha": _alpha[id], "cell": cell})
	_box.set_corner_radius_all(int(cell * tile_radius))
	for t in tiles:
		_draw_tile_body(t.rect, t.value, t.alpha)
	_draw_links(tiles)
	for t in tiles:
		_draw_tile_face(t.rect, t.value, t.alpha, t.scale)
	_draw_marks(o, cell)


func _nudge_offset() -> Vector2:
	if _nudge_dir < 0:
		return Vector2.ZERO
	var unit := Vector2.ZERO
	match _nudge_dir:
		Dir.R:
			unit = Vector2.RIGHT
		Dir.L:
			unit = Vector2.LEFT
		Dir.U:
			unit = Vector2.UP
		_:
			unit = Vector2.DOWN
	return unit * nudge_px * sin(PI * clampf(_nudge_t / maxf(nudge_time, 0.001), 0.0, 1.0))


func _center(p: Vector2, o: Vector2, cell: float) -> Vector2:
	return o + Vector2(p.x + 0.5, grid_h - 1.0 - p.y + 0.5) * cell


func _tile_rect(id: int, o: Vector2, cell: float) -> Rect2:
	var c := _center(_pos[id], o, cell)
	if id == _shake_id:
		var k := _shake_t / maxf(shake_time, 0.001)
		c.x += sin(k * TAU * shake_cycles) * shake_px * (1.0 - k)
	var side := cell * (1.0 - tile_gap) * _scale[id]
	return Rect2(c - Vector2(side, side) / 2.0, Vector2(side, side))


func _cell_rect(i: int, o: Vector2, cell: float) -> Rect2:
	var c := _center(_cell_pos(i), o, cell)
	var side := cell * (1.0 - tile_gap)
	return Rect2(c - Vector2(side, side) / 2.0, Vector2(side, side))


func _draw_marks(o: Vector2, cell: float) -> void:
	_box.draw_center = false
	_box.border_color = mark_color
	_box.set_border_width_all(int(mark_px))
	_box.set_corner_radius_all(int(cell * tile_radius))
	if _sel >= 0:
		draw_style_box(_box, _cell_rect(_sel, o, cell))
	_box.draw_center = true
	_box.set_border_width_all(0)
	if _cursor_on and _sel != _cursor:
		var r := _cell_rect(_cursor, o, cell)
		var tl := r.position
		var tr := Vector2(r.end.x, r.position.y)
		var br := r.end
		var bl := Vector2(r.position.x, r.end.y)
		for e in [[tl, tr], [tr, br], [br, bl], [bl, tl]]:
			draw_dashed_line(e[0], e[1], mark_color, mark_px, 10.0)


# --- input -------------------------------------------------------------------------------------------------------

func _gui_input(event: InputEvent) -> void:
	if not has_board() or not input_enabled:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_press = _cell_under(event.position)
			_press_pos = event.position
			_fired = false
			_cursor_on = false
		elif _press != -2:
			_release(event.position)
		accept_event()
	elif event is InputEventMouseMotion and _press != -2 and not _fired:
		if input_mode == InputMode.CELL_MOVES and not _press_has_tile():
			return
		var d: Vector2 = event.position - _press_pos
		if d.length() >= layout(size, grid_w, grid_h, fit).cell * swipe_frac:
			_fire_swipe(d)
		accept_event()


func _cell_under(p: Vector2) -> int:
	return cell_at(p, layout(size, grid_w, grid_h, fit), grid_w, grid_h)


func _press_has_tile() -> bool:
	return _press >= 0 and _ids[_press] >= 0


func _release(p: Vector2) -> void:
	var from := _press
	_press = -2
	if _fired:
		return
	var d := p - _press_pos
	if d.length() >= swipe_min_px:
		_press = from
		if input_mode == InputMode.BOARD_SWIPES or _press_has_tile():
			_fire_swipe(d)
		_press = -2
		return
	if input_mode == InputMode.CELL_MOVES:
		_tap(from)


func _fire_swipe(d: Vector2) -> void:
	_fired = true
	var dir := drag_dir(d)
	var code := _board_swipe(dir) if input_mode == InputMode.BOARD_SWIPES else _cell_move(_press, dir)
	if code >= 0:
		move_chosen.emit(code)


## Tap-tap selection.
func _tap(i: int) -> void:
	finish_animation()
	if i < 0 or _sel == i:
		_sel = -1
	elif _sel < 0:
		_sel = i if _ids[i] >= 0 else -1
	else:
		var d := neighbour_dir(_sel, i, grid_w)
		if d >= 0:
			var c := _cell_move(_sel, d)
			_sel = -1
			if c >= 0:
				move_chosen.emit(c)
		else:
			_sel = i if _ids[i] >= 0 else -1
	queue_redraw()


## Game code for a cell move; -1 and a shake of the tile when ignored.
func _cell_move(cell: int, dir: int) -> int:
	finish_animation()
	var code := _resolve_cell_move(cell, dir)
	if code < 0:
		shake_cell(cell)
		return -1
	_sel = -1
	_grab = false
	return code


func _board_swipe(dir: int) -> int:
	finish_animation()
	var code := _resolve_board_swipe(dir)
	if code < 0:
		nudge(dir)
	return code


## Keyboard: returns a game move code or null; cursor and grab are drawn by the view.
func key_move(event: InputEventKey) -> Variant:
	if not has_board() or not input_enabled:
		return null
	var d := key_dir(event.keycode)
	if input_mode == InputMode.BOARD_SWIPES:
		if d < 0:
			return null
		var c := _board_swipe(d)
		return c if c >= 0 else null
	if event.keycode == KEY_SPACE or event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER:
		finish_animation()
		_cursor_on = true
		if _grab:
			_grab = false
			_sel = -1
		elif _ids[_cursor] >= 0:
			_grab = true
			_sel = _cursor
		queue_redraw()
		return null
	if event.keycode == KEY_ESCAPE:
		_grab = false
		_sel = -1
		queue_redraw()
		return null
	if d < 0:
		return null
	finish_animation()
	if not _cursor_on:
		_cursor_on = true
		queue_redraw()
		return null
	if not _grab:
		_cursor = step_cell(_cursor, d, grid_w, grid_h)
		queue_redraw()
		return null
	var follow_id := _ids[_cursor]
	var c := _cell_move(_cursor, d)
	if c >= 0:
		_follow = follow_id
	return c if c >= 0 else null


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()
