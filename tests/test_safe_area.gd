extends RefCounted
## WhiteSafeArea (design 14.3)

var _check: Callable


func _same(a: Dictionary, l: float, t: float, r: float, b: float) -> bool:
	return is_equal_approx(a.left, l) and is_equal_approx(a.top, t) and is_equal_approx(a.right, r) and is_equal_approx(a.bottom, b)


func run(check: Callable, _node: Node) -> void:
	_check = check
	var ins := WhiteSafeArea.from_rects(Rect2(10, 20, 380, 800), Vector2(400, 840), Vector2(800, 1680))
	_check.call(_same(ins, 20, 40, 20, 40), "safe area: from_rects scales to viewport units")
	_check.call(_same(WhiteSafeArea.from_rects(Rect2(-50, -50, 600, 900), Vector2(400, 800), Vector2(400, 800)), 0, 0, 0, 0),
			"safe area: a safe rect larger than the window gives zero")
	_check.call(_same(WhiteSafeArea.from_rects(Rect2(0, 0, 400, 800), Vector2(400, 800), Vector2(400, 800)), 0, 0, 0, 0),
			"safe area: a safe rect equal to the window gives zero")
	_check.call(_same(WhiteSafeArea.from_rects(Rect2(0, 0, 0, 0), Vector2(400, 800), Vector2(400, 800)), 0, 0, 0, 0),
			"safe area: an empty safe rect gives zero")
	_check.call(_same(WhiteSafeArea.from_rects(Rect2(0, 0, 100, 0), Vector2(400, 800), Vector2(400, 800)), 0, 0, 0, 0),
			"safe area: a safe rect without height gives zero")
	_check.call(_same(WhiteSafeArea.parse("40,80,40,60"), 40, 80, 40, 60), "safe area: parse four values")
	_check.call(_same(WhiteSafeArea.parse("1,2"), 1, 2, 0, 0), "safe area: parse fills missing values with 0")
	_check.call(_same(WhiteSafeArea.parse("a,b,c,d"), 0, 0, 0, 0), "safe area: parse of junk is zero")
	_check.call(_same(WhiteSafeArea.insets(Vector2(720, 1280), "5,6,7,8"), 5, 6, 7, 8), "safe area: override is returned as parsed")
	var live := WhiteSafeArea.insets(Vector2(720, 1280))
	_check.call(live.has("left") and live.has("bottom") and live.left >= 0.0 and live.top >= 0.0 and live.right >= 0.0 and live.bottom >= 0.0,
			"safe area: measured insets are four non-negative values")
