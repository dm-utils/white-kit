extends WhiteTestRunner
## Fixture: a suite that does not parse must fail the run (expected: exit 1, a script error line)


func _run() -> void:
	check(true, "before the bad suite")
	var bad := GDScript.new()
	bad.source_code = "extends RefCounted\nfunc run(:\n\tpass\n"
	bad.reload()
	check(bad.can_instantiate(), "bad suite instantiates")
