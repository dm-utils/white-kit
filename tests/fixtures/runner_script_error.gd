extends WhiteTestRunner
## Fixture: a script error in a helper must fail the run (expected: 2 passed, 1 failed, exit 1)


func _run() -> void:
	check(true, "before the helper")
	_helper()
	check(true, "after the helper")


func _helper() -> void:
	var x: Object = null
	x.call("nothing")
	check(true, "never reached")
