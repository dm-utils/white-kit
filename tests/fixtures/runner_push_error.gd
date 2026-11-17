extends WhiteTestRunner
## Fixture: push_error is not a script error (expected: 1 passed, 0 failed, exit 0)


func _run() -> void:
	check(true, "before push_error")
	push_error("expected")
