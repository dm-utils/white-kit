class_name WhiteTestRunner
extends Node
## Base of a test scene: override _run() (may await) and call check(). Prints "tests: N passed, M failed" and exits
## with 1 on any failure. User argument --min-checks=N also fails when fewer than N checks ran.

var passed := 0
var failed := 0


func _ready() -> void:
	await _run()
	var min_checks := 0
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--min-checks="):
			min_checks = int(a.get_slice("=", 1))
	var too_few := passed + failed < min_checks
	if too_few:
		printerr("FAIL: only %d checks ran, expected at least %d" % [passed + failed, min_checks])
	print("tests: %d passed, %d failed" % [passed, failed])
	get_tree().quit(1 if failed > 0 or too_few else 0)


func check(ok: bool, what: String) -> void:
	if ok:
		passed += 1
	else:
		failed += 1
		printerr("FAIL: " + what)


func _run() -> void:
	pass
