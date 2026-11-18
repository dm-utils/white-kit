# Glossary

Terms used in the code, the design (`docs/design.md`) and the ADRs. Code names in brackets. Game-specific terms
(swipe, white stone, stone values, ...) are defined in each game's own glossary.

| Term | Meaning |
|---|---|
| Addon root | The repository root of White Kit, installed in a game at `res://addons/white_kit/`. |
| Attempt (`WhiteAttempt`) | One player's go at one puzzle: current state, undo history, record, counts. |
| Bad range | Arguments of `WhiteRng.range_int` with no valid result: `from > to`, a span that overflows int64, or more than 2^32 values. Gives a `push_error` and returns `from` without drawing (ADR 0006). |
| Child process test | A kit test that starts a second Godot process (`OS.execute`) to check real exit codes and output, for the precompute tool and the test runner. |
| Count | The score of an attempt as shown and shared: `moves_made` in every-move mode, the line length in final-only mode (`count()`). |
| Count label | The counter text on the screen: text key `count`, or the optional key `count_final` in final-only mode when the game defines it. |
| Count mode (`CountMode`) | How an attempt is scored: `EVERY_MOVE` or `FINAL_ONLY`. Fixed when the attempt is created. |
| Daily set | The puzzles (one per level) of one Dutch calendar day, the same for everyone. |
| Day screen (`WhiteDayScreen`) | The shared screen with level tabs, counter, par, clock, board slot, message and buttons. |
| Defined fallback | The value a public function returns, together with a `push_error`, for invalid input: `from` for `range_int`, 0 for `WhiteDaily.number`, the unchanged date for `add_days`. Not a validity signal, because it can also be a valid result (ADR 0006). |
| Dutch calendar day | The date in the Netherlands (CET/CEST); decides which daily set is current (`WhiteDaily`). |
| Effective move | A move the rules accept (`apply` returns a state, not `null`). Only effective moves count and are recorded. |
| Every move counts (`EVERY_MOVE`) | Count mode in which every effective move in the attempt counts, including undone and restarted ones. Daily puzzles. |
| Extra button | A game's own button in the screen's button row, shown only when solved (`_extra_buttons`; White Shift: Best route). |
| Final solution only (`FINAL_ONLY`) | Count mode in which only the moves from the start position to the current state count; undo gives a move back, restart resets to zero. White Tally practice. |
| First day | The date of puzzle #1 of a game; parameter of the puzzle number. |
| FNV-1a | The 64-bit hash that turns a seed text into a seed (`WhiteSeed.fnv1a64`). |
| Game id | The repository name of a game (`white-shift`, `white-tally`); first part of its seed texts. |
| Hook | A virtual function of a kit base class that a game overrides (`_load_day`, `_generate`, ...). |
| Host project | A throw-away Godot project that contains the kit at `addons/white_kit`, used to run the kit's own tests. |
| Kit version | The semantic version in `VERSION` and `WhiteKit.VERSION`; released as tag `v<version>`. |
| Level | One of the puzzles of a daily or practice set: easy (0), medium (1), hard (2). |
| Line length | The number of moves from the start position to the current state, i.e. the size of the undo history (`line_length()`). |
| Merge | Adding newly built days or sets to a published puzzle file without changing existing keys (`WhitePrecompute --merge`). |
| Minimum checks (`--min-checks`) | Runner argument: the run fails when fewer checks ran. Must be a non-negative integer, else the run fails at once. Kit threshold 522 at tag `v0.2.0` (design 13.4). |
| Move token | The fixed-width text of one move in a record, defined by the game (`encode_move`, `decode_move`, `move_len`). |
| Moves made | The number of effective moves in the whole attempt (`moves_made`). |
| Par | The reference score of a puzzle (the minimum number of moves where the game can compute it). |
| Pinned version | The kit tag a game's submodule points at; the game's CI checks it. |
| Play message | A game-specific text on the message line while an attempt is not solved (`_play_message`); empty means the standard text. |
| Practice-only screen | The day screen opened directly in practice, on a random set (set 0 with `--practice`), without a mode button and without daily puzzles (`_practice_only`, kit 0.2.0). White Tally phase 1. |
| Practice set | Puzzles (one per level) from a game's practice file, not tied to a date and not saved. |
| Precomputed puzzles | Puzzles generated ahead of time with the precompute tool and shipped as JSON in the game. |
| Progress file | `user://progress.json`: language and, per day, the record, time and solved flag of every level (`WhiteProgress`). |
| Puzzle number | Day count of a daily set; `#1` is the game's first day, the day before is 0, earlier days are negative. |
| Puzzle store (`WhitePuzzleStore`) | Loader for a game's daily and practice puzzle files, with a game-supplied converter. |
| Record | The action string of an attempt: move tokens, `z` undo, `r` restart. Save format and replay format. |
| Reference vectors | Fixed input/output pairs of `WhiteSeed` and `WhiteRng`, checked against the Python reference. |
| Refresh signal (`refreshed`) | Signal of the day screen, emitted at the end of every refresh; lets a game update its own texts, such as extra button labels. |
| Rejected move | A move the rules refuse (`apply` returns `null`): not counted, not recorded. |
| Replay | Rebuilding an attempt by applying its record to the start position (`apply_record`). |
| Restart | Back to the start position; clears the undo history; recorded as `r`. |
| Rules (`WhiteRules`) | The interface a game implements: start state, apply a move, solved check, move token codec. |
| Script error | A GDScript runtime or parse error (for example a call on `null`); a runtime error aborts the current function. Counted as a failed check by the test runner from kit 0.2.0 (ADR 0005); `push_error` is not a script error. |
| Seed | The 64-bit integer that initialises `WhiteRng`. |
| Seed text | The text hashed into a seed: `<game id>\|<date>\|<level>` for daily puzzles, `<game id>-practice\|<index>\|<level>` for practice sets. |
| Share line | One line with the day's counts and pars, without moves (`WhiteFormat.day_line`). |
| Undo | Back to the state before the last move of the current line; recorded as `z`. |
| Valid date | Text of exactly the form `YYYY-MM-DD` that is a real calendar date in 1970 or later (`WhiteDaily.is_date`, internally `_valid`); checked without calling `Time`. |
| xoshiro128** | The 32-bit random generator algorithm behind `WhiteRng`. |
