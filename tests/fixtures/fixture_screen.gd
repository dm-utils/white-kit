extends WhiteDayScreen
## Fixture game screen: counter rules, a plain Control as view, fixture puzzle files, its own save file.
## Flags are set before the node enters the tree.

const Counter := preload("res://addons/white_kit/tests/fixtures/counter_rules.gd")
const DIR := "res://addons/white_kit/tests/fixtures/"
const SAVE := "user://white_kit_test_progress.json"

var final_practice := false
var count_final_text := ""
var play_message_state := -1 ## state that shows "NOMOVE"; -1 = hook not overridden
var shown: Array = []
var updates := 0
var cleared := 0
var store: WhitePuzzleStore


func _init() -> void:
	store = WhitePuzzleStore.new(DIR + "daily.json", DIR + "practice.json", Callable())


func _game_id() -> String:
	return "white-fixture"


func _game_title() -> String:
	return "FIXTURE"


func _first_day() -> String:
	return "2026-11-17"


func _save_path() -> String:
	return SAVE


func _texts() -> Dictionary:
	if count_final_text.is_empty():
		return {}
	return {"nl": {"count_final": count_final_text}, "en": {"count_final": count_final_text}}


func _load_day(d: String) -> Array:
	return store.day(d)


func _load_practice(index: int) -> Array:
	return store.practice_set(index)


func _practice_count() -> int:
	return store.practice_count()


func _count_mode(is_practice: bool) -> int:
	if is_practice and final_practice:
		return WhiteAttempt.CountMode.FINAL_ONLY
	return WhiteAttempt.CountMode.EVERY_MOVE


func _new_attempt(_puzzle: Dictionary, count_mode: int) -> WhiteAttempt:
	return WhiteAttempt.new(Counter.new(), count_mode)


func _make_view() -> Control:
	return Control.new()


func _view_show(a: WhiteAttempt) -> void:
	shown.append(a.state)


func _view_clear() -> void:
	cleared += 1


func _view_update(_a: WhiteAttempt) -> void:
	updates += 1


func _extra_buttons() -> Array[Button]:
	return [WhiteUi.button("Extra", func() -> void: pass)]


func _play_message(a: WhiteAttempt) -> String:
	if play_message_state >= 0 and a.state == play_message_state:
		return "NOMOVE"
	return ""


func _key_move(event: InputEventKey) -> Variant:
	if event.keycode == KEY_UP:
		return 1
	if event.keycode == KEY_DOWN:
		return -1
	return null
