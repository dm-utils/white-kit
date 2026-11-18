extends WhiteTileView
## Fixture view: 0 empty, 1 static block, 2 and 3 tiles. Records hook calls for tests.

var board_moves := false
var calls: Array = []


func _is_tile(value: int) -> bool:
	return value >= 2


func _resolve_cell_move(cell: int, dir: int) -> int:
	var x := cell % grid_w
	@warning_ignore("integer_division")
	var y: int = cell / grid_w
	match dir:
		Dir.R:
			x += 1
		Dir.L:
			x -= 1
		Dir.U:
			y += 1
		_:
			y -= 1
	if x < 0 or y < 0 or x >= grid_w or y >= grid_h:
		return -1
	var target := _state[y * grid_w + x]
	if target == 1 or target == _state[cell]:
		return -1
	return cell * 4 + dir


func _resolve_board_swipe(dir: int) -> int:
	return dir if board_moves else -1


func _draw_static(rect: Rect2, value: int) -> void:
	calls.append("static %d" % value)
	draw_rect(rect, WhiteTheme.DIM)


func _draw_tile_body(rect: Rect2, value: int, alpha: float) -> void:
	calls.append("body %d" % value)
	var col := Color("4C7FD6") if value == 2 else Color("E3943A")
	col.a = alpha
	draw_rect(rect, col)


func _draw_links(tiles: Array) -> void:
	calls.append("links %d" % tiles.size())


func _draw_tile_face(rect: Rect2, value: int, alpha: float, _scale_f: float) -> void:
	calls.append("face %d" % value)
	var col := WhiteTheme.BG
	col.a = alpha
	draw_circle(rect.get_center(), rect.size.x * 0.12, col)
