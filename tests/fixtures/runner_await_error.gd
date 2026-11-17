extends WhiteTestRunner
## Fixture: script errors after an await and in two helpers (expected: 2 passed, 2 failed, exit 1)


func _run() -> void:
	check(true, "before await")
	await get_tree().process_frame
	_boom_a()
	await get_tree().process_frame
	_boom_b()
	check(true, "after helpers")


func _boom_a() -> void:
	var x: Object = null
	x.call("a")


func _boom_b() -> void:
	var y: Object = null
	y.call("b")
