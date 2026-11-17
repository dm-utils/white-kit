class_name WhiteTestRunner
extends Node
## Base of a test scene: override _run() (may await) and call check(). Prints "tests: N passed, M failed" and exits
## with 1 on any failure. GDScript script errors during _run() count as failed checks. User argument --min-checks=N
## also fails when fewer than N checks ran; a value that is not a number fails the run.

var passed := 0
var failed := 0


## Collects script errors; callbacks may come from other threads, so no printing or check() in here
class _ScriptErrors extends Logger:
	var lines: PackedStringArray = []
	var _lock := Mutex.new()

	func _log_error(function: String, file: String, line: int, code: String, rationale: String,
			_editor_notify: bool, error_type: int, _script_backtrace: Array[ScriptBacktrace]) -> void:
		if error_type != Logger.ERROR_TYPE_SCRIPT:
			return
		var text := rationale if not rationale.is_empty() else code
		if text.is_empty():
			text = function
		_lock.lock()
		lines.append("%s:%d %s" % [file, line, text])
		_lock.unlock()

	func _log_message(_message: String, _error: bool) -> void:
		pass


func _ready() -> void:
	var min_checks := 0
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--min-checks="):
			var value := a.get_slice("=", 1)
			if not value.is_valid_int() or int(value) < 0:
				printerr("FAIL: bad --min-checks value '%s'" % value)
				get_tree().quit(1)
				return
			min_checks = int(value)
	var errors := _ScriptErrors.new()
	OS.add_logger(errors)
	await _run()
	OS.remove_logger(errors)
	for line in errors.lines:
		failed += 1
		printerr("FAIL: script error: " + line)
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
