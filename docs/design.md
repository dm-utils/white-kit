# White Kit - design

Status: version 0.1.0 built and tagged; White Shift migrated onto it (section 10). Next release: 0.2.0, planned
(section 13).
Decisions with their trade-offs are in `docs/adr/`; terms are defined in `docs/glossary.md`; code and release rules
are in `docs/conventions.md`.

## 1. Purpose

White Kit is the shared base of the White daily puzzle games (Godot 4.7.2, GDScript, web first, Android later). It
holds everything that is the same in every game of the series, so each game repository only contains its own rules,
solver, generator, board drawing and texts.

The first two users are White Shift (published, `dm-utils/white-shift`) and White Tally (being designed,
`dm-utils/white-tally`). White Shift is migrated onto the kit without any change in behaviour (section 10).

Goals:

1. One implementation of the Dutch puzzle day, the seed hash, the random generator, puzzle loading, the attempt record,
   the progress file and the shared screen, tested once.
2. Bit-exact determinism: a seed gives the same random sequence on every platform and every Godot version.
3. A clear seam for later: accounts, leaderboards, friends and competitions come through st33f-engine; the kit's
   puzzle store, attempt record and progress file are the places where that connects (section 11). Nothing of that is
   built now.

Out of scope: game rules, solvers, generators, board drawing, sound, statistics, tutorial, any network code.

## 2. Assumptions

| # | Assumption | Consequence if wrong |
|---|---|---|
| A1 | Every game and the kit use the same Godot version (4.7.2 now). The kit pins it for CI (section 7.3). | A game on another version passes its own inputs to the CI action. |
| A2 | Every game has a daily set of three levels (easy, medium, hard) and a practice mode, like White Shift. White Tally has confirmed this; in its phase 1 it uses practice only (section 13.1). | `WhiteDayScreen` supports another level count through a hook, but the layout is designed for three. |
| A3 | The puzzle day is the Dutch calendar day (White Shift ADR 0003) for every game. | `WhiteDaily` would need a time zone parameter. |
| A4 | All repositories are public on GitHub; the kit is fetched over HTTPS without credentials. | Private repositories need a deploy key or token in CI. |
| A5 | The kit is always installed at `res://addons/white_kit/` (fixed path). | Kit tests and the CI template refer to this path. |
| A6 | Godot's editor file scan skips every folder that contains a `project.godot` (nested project) and every folder with a `.gdignore`. The kit repository therefore has no `project.godot` at its root. | Verified in step 1 of section 10, in the kit host and in White Shift: `.godot/global_script_class_cache.cfg` lists only the kit classes. |
| A7 | White Tally's moves can be written as fixed-width tokens of upper-case letters and digits (for example cell plus direction). Confirmed by White Tally's design. | The record grammar (section 6.1) gets a separator; a major version. |
| A8 | Puzzles shown by the shared screen are dictionaries with at least an integer `par`. | Games without par set `par` to their reference score. |
| A9 | Puzzle data written by the precompute tool contains no whole-valued floats that must stay floats, and no integers of 2^53 or more (section 5.14). | A merge would rewrite such values; the game stores them as strings instead. |
| A10 | Godot's `Logger` class (`OS.add_logger`, available since Godot 4.5) reports GDScript runtime errors with error type `ERROR_TYPE_SCRIPT` and `push_error` with `ERROR_TYPE_ERROR`. Basis of the test runner change in 0.2.0 (ADR 0005). | Verified by the acceptance test in section 13.2; if wrong, the developer reports it and the runner falls back to the alternative in ADR 0005. |

## 3. Scope: what is in the kit

Every candidate was checked against two questions: is it the same in both games, and is it stable enough that sharing
it does not slow down either game.

| Candidate | In kit | Kit class | Where it was in White Shift | Reason |
|---|---|---|---|---|
| Dutch calendar day and puzzle number | Yes | `WhiteDaily` | `sim/daily.gd` (`ShiftDaily`) | Identical in every game; only the first day differs (parameter). |
| Seed hash (FNV-1a 64-bit) and seed texts | Yes | `WhiteSeed` | `sim/generator.gd` (`ShiftGenerator.seed_for`), seed texts in `tools/build_puzzles.gd` | Identical; one exact implementation without integer overflow. |
| Deterministic integer PRNG | Yes | `WhiteRng` | not present (used `RandomNumberGenerator`) | Needed for portable seeds; ADR 0002. |
| Loading precomputed puzzles | Yes, generic | `WhitePuzzleStore` | `sim/puzzles.gd` (`ShiftPuzzles`) | File layout `{"<key>": [puzzle per level]}` is generic; converting one puzzle is game code (a callable). |
| Rules interface | Yes | `WhiteRules` | implicit in `ShiftBoard` | Lets the attempt work for any game. |
| Attempt with record, undo, restart, count modes | Yes | `WhiteAttempt` | `sim/attempt.gd` (`ShiftAttempt`) | Same mechanics; White Tally needs two count modes; ADR 0003. |
| Robust progress file | Yes | `WhiteProgress` | `ui/main.gd` `_load_save`, `_write_save`, `_store` | Same file format and the same robustness (fix ce16f44). |
| Clock and share line formatting | Yes | `WhiteFormat` | `ui/strings.gd` `clock`, `share_line` | Identical apart from the text template. |
| NL/EN text mechanism | Yes | `WhiteText` | `ui/strings.gd` (`Strings`) | Mechanism (language, lookup, table merge) is shared; the texts themselves stay in the game. |
| Theme constants and widget factory | Yes | `WhiteTheme`, `WhiteUi` | `ui/main.gd` constants, `_label`, `_button` | Same look across the series. |
| Shared screen (tabs, counter, par, clock, buttons, practice, language) | Yes | `WhiteDayScreen` | `ui/main.gd` | Both games have the same screen flow (A2); ADR 0004. |
| Debug screenshot mode | Yes, in the screen | `WhiteDayScreen` | `ui/main.gd` `_debug_shot` | Generic apart from `--best` (game hook). |
| Test runner base | Yes | `WhiteTestRunner` | `tests/run_tests.gd` | Same `check(ok, what)` contract and exit code. |
| Precompute tool skeleton | Yes | `WhitePrecompute` | `tools/build_puzzles.gd` | Argument parsing, key/seed loop, output and a safe merge are generic; generation is game code. |
| CI workflow | Yes, as template plus composite action | `templates/ci.yml`, `ci/setup-godot/` | `.github/workflows/ci.yml` | Godot download/verify/cache is identical; the game workflow stays a short file. |
| Rules, solver, generator, level parameters | No | - | `sim/board.gd`, `sim/solver.gd`, `sim/generator.gd` | Game-specific. |
| Board drawing and touch input | No | - | `ui/board_view.gd` | Game-specific (swipes versus swaps). |
| Game texts (hints, rules, units) | No | - | `ui/strings.gd` `TEXT` | Game-specific; the kit only has generic default texts. |
| Generator measuring tool | No | - | `tools/measure.gd` | Depends on the generator's level parameters. |
| Best route animation | No (hook) | - | `ui/main.gd` `_show_best` | Depends on the board view. |
| Accounts, leaderboards, engine client | No (later) | - | - | Phase 4 of the games; section 11. |

## 4. Repository layout and installation

The repository root is the addon root. A game includes the repository as a git submodule at `addons/white_kit`
(ADR 0001). There is no `plugin.cfg`: the kit has no editor plugin; its global classes (`class_name`) are available as
soon as the folder is in the project.

There is no licence file: the code is public to read but all rights are reserved. The README says so. This is final;
no licence is planned.

```
white-kit/                     (= res://addons/white_kit/ in a game)
  README.md  VERSION  CHANGELOG.md
  core/
    kit.gd              WhiteKit           version constant
    daily.gd            WhiteDaily
    seed.gd             WhiteSeed
    rng.gd              WhiteRng
    puzzle_store.gd     WhitePuzzleStore
    rules.gd            WhiteRules
    attempt.gd          WhiteAttempt
    progress.gd         WhiteProgress
    text.gd             WhiteText
    format.gd           WhiteFormat
  ui/
    theme.gd            WhiteTheme
    ui.gd               WhiteUi
    day_screen.gd       WhiteDayScreen
  tools/
    precompute.gd       WhitePrecompute    (extends SceneTree)
    rng_vectors.gd      prints reference vectors (extends SceneTree, no class_name)
    kit_host.sh         creates the local host project and runs the kit tests
    reference/white_rng.py   independent Python reference of WhiteSeed and WhiteRng
  tests/
    test_runner.gd      WhiteTestRunner    (the only class_name under tests/)
    run_kit_tests.tscn, run_kit_tests.gd   (extends WhiteTestRunner)
    test_*.gd           test suites (no class_name)
    fixtures/           test-only scripts, scenes and data, loaded with preload or by path (no class_name)
  ci/                   (.gdignore)
    setup-godot/action.yml
  templates/            (.gdignore)
    ci.yml              game workflow template
    host/project.godot  host project for the kit's own tests
  docs/                 (.gdignore)  design, conventions, glossary, adr/
  .github/workflows/ci.yml
```

Every `.gd` file outside the `.gdignore` folders has a committed `<file>.gd.uid` next to it (Godot 4.4 and later
writes these on import).

Rules for this layout:

- `core/` contains no scenes, no nodes, no input and no rendering. Only `WhiteProgress` touches `user://`, and only the
  path it is given.
- `ui/` may use everything; it depends on `core/`, never the other way round.
- Test and fixture scripts never declare a `class_name` (they would become global classes in every game), except
  `WhiteTestRunner`.
- `docs/`, `ci/` and `templates/` contain a `.gdignore` so Godot does not scan them.
- Fixture data uses the extension `.json` but lives under `tests/`, which every game excludes from its export
  (section 10, step 1).
- The `.uid` files are committed together with their script. Without them, the first import in a game writes them
  into `addons/white_kit/` and the submodule shows as modified. A new script is therefore committed only after an
  import (`tools/kit_host.sh` imports first) has created its `.uid`.

## 5. Components and API

All public classes extend `RefCounted` unless noted, and are statically typed. Names starting with `_` are internal,
except the virtual hooks of `WhiteDayScreen`, `WhiteRules`, `WhitePrecompute` and `WhiteTestRunner`, which games
override.

### 5.1 WhiteKit (`core/kit.gd`)

```gdscript
class_name WhiteKit
const VERSION := "0.1.0"        # always equal to the VERSION file
const INSTALL_PATH := "res://addons/white_kit/"
```

Acceptance: a kit test reads `res://addons/white_kit/VERSION` and checks that it equals `WhiteKit.VERSION` (trimmed).

### 5.2 WhiteDaily (`core/daily.gd`)

The puzzle day in the Netherlands (CET/CEST) from the device clock, without network. Moved unchanged from
`ShiftDaily`; the first day becomes a parameter.

```gdscript
class_name WhiteDaily
static func nl_offset(unix: int) -> int            # 7200 from last Sunday of March 01:00 UTC to last Sunday of October 01:00 UTC, else 3600
static func date_at(unix: int) -> String           # "YYYY-MM-DD" in the Netherlands
static func today() -> String                      # date_at(system time)
static func number(date: String, first_day: String) -> int   # first_day is #1; the day before is 0
static func add_days(date: String, days: int) -> String      # calendar arithmetic via 12:00 UTC of the date
static func is_date(text: String) -> bool          # exactly "YYYY-MM-DD", a real calendar date, year 1970 or later
```

The formulas are those of `sim/daily.gd` (copy, do not rewrite). `add_days` returns
`Time.get_date_string_from_unix_time(Time.get_unix_time_from_datetime_string(date + "T12:00:00") + days * 86400)`.

`is_date(text)`, in this order, false at the first failing step:

1. `text` has length 10, characters 4 and 7 are `-`, all others are ASCII digits.
2. Year, month and day parsed from the parts: year at least 1970, month 1 to 12, day 1 to the length of that month
   (February 29 days in a Gregorian leap year: divisible by 4 and not by 100, or divisible by 400).
3. `add_days(text, 0) == text`.

Step 2 exists because `Time.get_unix_time_from_datetime_string` prints an engine error for an impossible date
(30 February, month 13); with step 2 first, `is_date` never produces engine output. The result is the same as the
round-trip alone would give for every year from 1970 on.

Acceptance: all date checks of White Shift (`test_daily_dates`, `test_dates`) pass against `WhiteDaily` with
`first_day = "2026-11-17"`; `add_days("2028-02-28", 1) == "2028-02-29"`; `add_days("2026-12-31", 1) == "2027-01-01"`;
`is_date("2026-02-30") == false`; `is_date("2026-13-01") == false`; `is_date("2028-02-29") == true`;
`is_date("2100-02-29") == false`; `is_date("2026-11-17") == true`; `is_date("2026-11-7") == false`; none of these
calls produces engine error output.

### 5.3 WhiteSeed (`core/seed.gd`)

FNV-1a 64-bit over the UTF-8 bytes of a text, and the fixed seed texts. The implementation must not rely on int64
overflow (ADR 0002):

- Keep the hash as two non-negative 32-bit halves `hi`, `lo` (start `hi = 0xCBF29CE4`, `lo = 0x84222325`).
- Per byte `b`: `lo ^= b`; then multiply by the prime `0x100000001B3` (`P_HI = 0x100`, `P_LO = 0x1B3`):
  `p = lo * P_LO`; `new_lo = p & 0xFFFFFFFF`; `new_hi = (hi * P_LO + lo * P_HI + (p >> 32)) & 0xFFFFFFFF`.
  Every intermediate stays below 2^43.
- Return the signed 64-bit value with the same bit pattern: `top = hi - 4294967296 if hi >= 2147483648 else hi`;
  `return top * 4294967296 + lo` (no shift into the sign bit, no overflow).

```gdscript
class_name WhiteSeed
static func fnv1a64(text: String) -> int
static func fnv1a64_bytes(bytes: PackedByteArray) -> int
static func daily_text(game_id: String, date: String, level: int) -> String        # "<game_id>|<date>|<level>"
static func practice_text(game_id: String, index: int, level: int) -> String      # "<game_id>-practice|<index>|<level>"
static func daily(game_id: String, date: String, level: int) -> int               # fnv1a64(daily_text(...))
static func practice(game_id: String, index: int, level: int) -> int              # fnv1a64(practice_text(...))
```

`game_id` is the repository name: `white-shift`, `white-tally`.

Acceptance:
- `String.num_uint64(WhiteSeed.fnv1a64(""), 16) == "cbf29ce484222325"`; for `"a"`: `"af63dc4c8601ec8c"`; for
  `"foobar"`: `"85944171f73967e8"` (published FNV test vectors).
- For at least 1000 texts (including `white-shift|<date>|<level>` for 60 dates, the empty text and multi-byte UTF-8
  such as `"ë€𝄞"`), `fnv1a64` equals the former White Shift implementation, copied into the test as a local function.
- `daily_text("white-shift", "2026-11-17", 2) == "white-shift|2026-11-17|2"`;
  `practice_text("white-shift", 3, 0) == "white-shift-practice|3|0"`.
- The Python reference (`tools/reference/white_rng.py`) gives the same hashes.

### 5.4 WhiteRng (`core/rng.gd`)

A deterministic 32-bit generator: xoshiro128** (Blackman and Vigna, public domain), seeded from a 64-bit seed through a
fixed mixing step. All state words are non-negative ints below 2^32; no operation may exceed int64 (ADR 0002).

Internal helpers (`M = 0xFFFFFFFF`):

```
mul32(a, b)  = (a * (b & 0xFFFF) + (((a * (b >> 16)) & 0xFFFF) << 16)) & M     # a, b < 2^32
rotl32(x, k) = ((x << k) & M) | (x >> (32 - k))
fmix32(h):  h ^= h >> 16; h = mul32(h, 0x85EBCA6B); h ^= h >> 13; h = mul32(h, 0xC2B2AE35); h ^= h >> 16; return h
```

Seeding, `reseed(seed_value)`:

```
lo = seed_value & M
hi = (seed_value >> 32) & M
k  = fmix32(hi ^ 0x85EBCA6B)
w  = lo
for i in 0..3:
    w = (w + 0x9E3779B9) & M
    s[i] = fmix32(w ^ k)
if s0 == s1 == s2 == s3 == 0: s0 = 1
```

Next value, `next_u32()` (xoshiro128**):

```
result = mul32(rotl32((s1 * 5) & M, 7), 9)
t  = (s1 << 9) & M
s2 ^= s0; s3 ^= s1; s1 ^= s2; s0 ^= s3; s2 ^= t; s3 = rotl32(s3, 11)
return result
```

```gdscript
class_name WhiteRng
func _init(seed_value: int = 0) -> void            # reseed(seed_value)
static func from_text(text: String) -> WhiteRng    # WhiteRng.new(WhiteSeed.fnv1a64(text))
func reseed(seed_value: int) -> void
func set_state(s0: int, s1: int, s2: int, s3: int) -> void   # raw state, masked to 32 bits; all zero: push_error, state unchanged
func get_state() -> PackedInt64Array               # [s0, s1, s2, s3]
func next_u32() -> int                             # 0 .. 2^32 - 1
func range_int(from: int, to: int) -> int          # inclusive, unbiased
func next_float() -> float                         # next_u32() / 4294967296.0, in [0, 1), exact
func pick(items: Array) -> Variant                 # items[range_int(0, size - 1)]; empty: null without drawing
func shuffle(items: Array) -> void                 # in place
```

- `range_int`: `n = to - from + 1`; `from > to` or `n > 2^32` is a `push_error` and returns `from` without drawing.
  Otherwise `limit = 4294967296 - (4294967296 % n)`; draw `r = next_u32()` until `r < limit`; return `from + r % n`.
  It always draws at least once, also when `n == 1`.
- `shuffle`: Fisher-Yates from the end: for `i` from `size - 1` down to `1`: `j = range_int(0, i)`; swap items `i` and
  `j`.
- Method names deliberately differ from `RandomNumberGenerator` and from the global functions (`randf`, `seed`), to
  avoid shadowing warnings and accidental mixing.

Acceptance:
- Published reference: after `set_state(1, 2, 3, 4)` the first four `next_u32()` values are `11520`, `0`, `5927040`,
  `70819200`.
- For the seeds `0`, `1`, `-1` and `WhiteSeed.fnv1a64("white-kit")`: the state after `reseed`, the first 8 values of
  `next_u32()`, then 8 values of `range_int(0, 6)` and 4 values of `next_float()` equal the Python reference. The
  vectors are stored as constants in `tests/test_rng.gd`; CI also runs `tools/rng_vectors.gd` and
  `tools/reference/white_rng.py` and compares their output line by line.
- `range_int(3, 3)` returns 3 and advances the state; `range_int(0, 6)` over 70000 draws hits every value between 9000
  and 11000 times.
- Two generators with the same seed give identical sequences; `shuffle` of the same array with the same seed gives the
  same order.
- No kit file in `core/` or `tools/` (except `tools/reference/`) uses `RandomNumberGenerator`, `randi(`, `randf(` or
  `randomize(` (grep step in kit CI). `ui/` uses one `randi()` for the random practice start (section 5.12).

### 5.5 WhitePuzzleStore (`core/puzzle_store.gd`)

Precomputed puzzles shipped with a game: a daily file keyed by date and a practice file keyed `"0"`, `"1"`, ...
Both have the shape `{"<key>": [puzzle_level_0, puzzle_level_1, ...]}`. The kit does not know the puzzle contents; a
game passes a converter that turns one raw puzzle dictionary into its own form.

```gdscript
class_name WhitePuzzleStore
func _init(daily_path: String, practice_path: String, convert: Callable) -> void
func has_day(date: String) -> bool
func day(date: String) -> Array                    # converted puzzles of that day; [] when missing
func days() -> PackedStringArray                   # sorted dates in the daily file
func practice_count() -> int
func practice_set(index: int) -> Array             # converted puzzles of set posmod(index, count); [] when there are none
func practice(index: int, level: int) -> Dictionary  # practice_set(index)[level]
static func load_json(path: String) -> Dictionary  # cached per path; {} when missing, unreadable, not JSON or not a Dictionary
static func clear_cache() -> void                  # for tests
```

- The practice set is chosen by position in the file's key order (as White Shift does), not by numeric key.
- `load_json` uses `JSON.new().parse()` (no engine error output on bad input) and caches by path in a static
  dictionary, as `ShiftPuzzles._load` did.
- An invalid `convert` callable means identity.

Acceptance (with fixture files in `tests/fixtures/`): present and missing days; `day` of a missing date is `[]`;
practice index `-1` equals the last set and index `count` equals set 0; a non-JSON file and a JSON list both load as
`{}` without error output; the converter is applied to every returned puzzle.

### 5.6 WhiteRules (`core/rules.gd`)

The interface a game implements so `WhiteAttempt` can play it. A game class extends `WhiteRules` (White Shift:
`ShiftBoard extends WhiteRules`). State and move types are the game's choice (White Shift: `PackedInt32Array` state,
integer direction).

```gdscript
class_name WhiteRules
func start_state() -> Variant
func apply(state: Variant, move: Variant) -> Variant   # new state, or null when the move is illegal or changes nothing
func is_solved(state: Variant) -> bool
func move_len() -> int                                 # characters per move token in the record; default 1
func encode_move(move: Variant) -> String              # exactly move_len() characters, only [A-Z0-9]
func decode_move(token: String) -> Variant             # the move, or null when the token is not a move
```

The base implementations `push_error` and return `null` / `false` / `""`, except `move_len`, which returns 1.

What "changes nothing" means is the game's decision: `apply` returning `null` is the only way to reject a move.
`WhiteAttempt` never compares states. `apply` must not modify its `state` argument.

### 5.7 WhiteAttempt (`core/attempt.gd`)

One player's go at one puzzle: current state, undo history, the record and the counts. Generalised from
`ShiftAttempt`, with two count modes (ADR 0003).

```gdscript
class_name WhiteAttempt
enum CountMode { EVERY_MOVE, FINAL_ONLY }
const UNDO := "z"
const RESTART := "r"

var rules: WhiteRules
var mode: int                 # a CountMode
var state: Variant
var history: Array = []       # states before each move of the current line
var record := ""
var moves_made := 0           # every effective move in the attempt, including undone and restarted ones
var time_ms := 0              # informational; the screen keeps its own clock (section 5.12)

func _init(r: WhiteRules, count_mode: int = CountMode.EVERY_MOVE) -> void   # state = r.start_state()
func solved() -> bool                     # rules.is_solved(state)
func play(move: Variant) -> bool          # true when effective
func undo() -> bool
func restart() -> bool
func can_undo() -> bool                   # not history.is_empty() and not solved()
func count() -> int                       # EVERY_MOVE: moves_made; FINAL_ONLY: line_length()
func line_length() -> int                 # history.size(): moves from the start position to the current state
func apply_record(rec: String) -> void    # replays a record onto this attempt (normally a fresh one)
```

Behaviour (identical to the former `ShiftAttempt` in `EVERY_MOVE`):

- `play(move)`: when solved, return false. `next = rules.apply(state, move)`; when `null`, return false (not counted,
  not recorded). Otherwise append `state` to `history`, set `state = next`, `moves_made += 1`,
  `record += rules.encode_move(move)`, return true.
- `undo()`: when `history` is empty or solved, return false (not recorded). Otherwise `state = history.pop_back()`,
  `record += "z"`, return true.
- `restart()`: when `history` is empty or solved, return false. Otherwise clear `history`,
  `state = rules.start_state()`, `record += "r"`, return true.
- After solving, `play`, `undo` and `restart` all return false.
- `apply_record(rec)`: walk the record with index `i` from 0. `"z"` calls `undo()` and `"r"` calls `restart()`, both
  then `i += 1`. Any other lower-case letter: `i += 1` (reserved, ignored). Otherwise
  `token = rec.substr(i, rules.move_len())` and `move = rules.decode_move(token)`: when `move != null`, call
  `play(move)` and `i += rules.move_len()`; else `i += 1`. With `move_len() == 1` this is exactly the former
  `ShiftAttempt.replay`.
- The record is the same in both modes; the mode only changes `count()`. A server re-derives the count from the record
  and the mode.

Acceptance (with the fixture rules of section 5.13 and with White Shift's example board):
- `EVERY_MOVE`: an undone move still counts; restart keeps the count; a rejected move changes neither count nor record;
  undo/restart at the start or after solving return false and record nothing.
- `FINAL_ONLY`: undo lowers `count()` by one, restart sets it to 0, `moves_made` still counts everything; after solving,
  `count()` equals the number of moves from the start position to the solved state.
- `apply_record(a.record)` on a fresh attempt in the same mode reproduces `state`, `record`, `moves_made` and `count()`
  of `a`, for records with undo and restart, in both modes.
- Junk is ignored: with move length 1, `"zzrx?DD9 R"` on White Shift's example board gives record `"DR"`, 2 moves,
  solved; with move length 3, a record with a broken token in the middle still replays the valid tokens after it.

### 5.8 WhiteProgress (`core/progress.gd`)

The progress file, read so that a damaged file never stops the game and whatever is usable is kept. The logic is moved
unchanged from White Shift's former `ui/main.gd` `_load_save` (after fix ce16f44).

File format (unchanged from White Shift):

```json
{"lang": "nl", "days": {"2026-11-17": [{"record": "DRzUR", "time_ms": 41250, "solved": true}, ...]}}
```

```gdscript
class_name WhiteProgress
const DEFAULT_PATH := "user://progress.json"
static func empty(default_lang: String) -> Dictionary                       # {"lang": default_lang, "days": {}}
static func sanitize(data: Variant, languages: PackedStringArray, default_lang: String) -> Dictionary
static func read(path: String, languages: PackedStringArray, default_lang: String) -> Dictionary
static func write(path: String, data: Dictionary) -> bool                   # JSON.stringify(data); false when the file cannot be opened
static func entry(record: String, time_ms: int, solved: bool) -> Dictionary # {"record", "time_ms", "solved"}
```

`sanitize` rules (exactly the White Shift behaviour):

- Start from `empty(default_lang)`. When `data` is not a Dictionary, return that.
- `lang` is kept when it is a String contained in `languages`.
- `days` must be a Dictionary, else there are no days. A day is kept only when its key is a String and its value an
  Array.
- Per element of a kept day: a Dictionary gives `record` (when a String, else `""`) and `time_ms`
  (`maxi(0, int(value))` when the value is a float, else 0); anything else gives an empty entry. `solved` is always
  stored as `false` (it is derived again by replay).
- The list length is kept as it is; the screen ignores extra levels and fills missing ones.

`read` returns `empty(default_lang)` when the file is missing or not valid JSON (parsed with `JSON.new().parse()`, so
without error output), else `sanitize(parsed)`.

Acceptance: every damaged-file case of White Shift's `test_ui_progress` and `test_damaged_progress` gives the same
result through `sanitize` directly (kit test, no scene needed); `read` of a missing file and of `"not json"` gives the
empty structure; `write` followed by `read` round-trips a valid structure. Kit tests use their own file names under
`user://` (prefix `white_kit_test_`) and delete them afterwards.

### 5.9 WhiteText (`core/text.gd`)

Language choice and text lookup. The kit ships default texts for the shared screen; a game registers its own table,
which overrides keys per language and may add keys.

```gdscript
class_name WhiteText
const BASE := {"nl": {...}, "en": {...}}           # kit default texts; keys and values in section 5.12
static var lang := "nl"
static func register(table: Dictionary) -> void    # merged = BASE overridden per language by table; replaces earlier registrations
static func t(key: String) -> Variant              # merged[lang][key]; unknown key: push_error and return the key
static func has_key(key: String) -> bool           # key exists in merged[lang]; no error output
static func languages() -> PackedStringArray       # languages of the merged table, "nl" first
static func has_lang(code: String) -> bool
static func next_lang() -> String                  # the language after `lang` in languages(), wrapping
```

Acceptance: `BASE["nl"].keys() == BASE["en"].keys()`; after `register` a game key overrides a base key in both
languages, a new game key is found by `has_key`, and the base keys the game does not define remain; `has_key` of an
unknown key is false without error output; `next_lang()` alternates between `nl` and `en`; `t` of an unknown key
returns the key; no value in `BASE` mentions a game name, a game-specific piece or a game-specific move (the default
`hint` is generic, section 5.12).

### 5.10 WhiteFormat (`core/format.gd`)

```gdscript
class_name WhiteFormat
static func clock(ms: int) -> String                                   # "m:ss", minutes not wrapped; negative gives "0:00"
static func slash_list(values: Array, missing: String = "-") -> String  # null -> missing, others str(); joined by "/"
static func day_line(template: String, number: int, counts: Array, pars: Array) -> String
	# template % [number, slash_list(counts), slash_list(pars)]
```

White Shift's share line is `day_line(t("share_line"), number, counts, pars)` with the template
`"White Shift #%d · %s vegen (par %s)"`. A share line never contains moves.

Acceptance: `clock(0) == "0:00"`, `clock(61999) == "1:01"`, `clock(3600000) == "60:00"`; every share line check of
White Shift passes through `day_line`.

### 5.11 WhiteTheme and WhiteUi (`ui/theme.gd`, `ui/ui.gd`)

The look of the series: dark, flat, no image assets. Values taken from White Shift's former `ui/main.gd`.

```gdscript
class_name WhiteTheme
const BG := Color("1B1F26")
const TEXT := Color("E6E9EF")
const DIM := Color("8A94A6")
const ACCENT := Color("FFFFFF")
const BUTTON := {"normal": Color("2A303B"), "hover": Color("343B48"), "pressed": Color("4A5363"),
	"hover_pressed": Color("4A5363"), "disabled": Color("20252D")}
const BUTTON_DISABLED_TEXT := Color("4A5363")
const MARGIN := 24
const SPACING := 14
const ROW_SPACING := 8
const BUTTON_HEIGHT := 64
const BUTTON_RADIUS := 10
const BUTTON_PADDING := 14
const FONT_TITLE := 34
const FONT_SUBTITLE := 22
const FONT_INFO := 26
const FONT_MESSAGE := 20
const FONT_BUTTON := 22
```

```gdscript
class_name WhiteUi
static func label(text: String, font_size: int, color: Color) -> Label
static func button(text: String, action: Callable) -> Button   # exactly White Shift's former _button
```

### 5.12 WhiteDayScreen (`ui/day_screen.gd`)

`class_name WhiteDayScreen extends Control`. The whole daily/practice screen of White Shift, with the game-specific
parts as hooks (ADR 0004). A game's main scene script extends it. Behaviour reference: White Shift `ui/main.gd` as of
commit ce16f44; the base class reproduces it exactly when the hooks keep their defaults (verified in section 10).

Members (names kept from White Shift, whose tests use them):

```gdscript
var date := ""
var practice := false
var practice_index := 0
var level := 0
var puzzles: Array = []        # puzzles on screen (Dictionaries with at least "par")
var attempts: Array = []       # a WhiteAttempt per level
var times: Array = []          # ms per level before the current run of the clock
var view: Control              # the game's board view (from _make_view)
var title: Label
var subtitle: Label
var tabs: Array[Button] = []
var counter: Label
var par_label: Label
var clock_label: Label
var message: Label
var undo_btn: Button
var restart_btn: Button
var share_btn: Button
var next_btn: Button
var mode_btn: Button
var lang_btn: Button
var _clock_from := -1          # ticks when the clock started on the current level; -1 = stopped
var _replaying := false        # true while a game animation runs; input is then ignored
var _save := WhiteProgress.empty("nl")
var _debug := {}               # parsed user arguments
var _extra: Array[Button] = [] # the buttons returned by _extra_buttons()

signal level_shown(level: int)
signal attempt_solved(level: int, count: int)
signal progress_saved()
signal refreshed()             # emitted as the last action of every _refresh(), in both branches
```

`refreshed` exists so a game can update what the screen does not know about after every refresh, in particular the
text of its extra buttons after a language change (White Shift: the Best route button). A game connects to it in
`_extra_buttons()` or later; it must not change the members the screen sets in `_refresh()` (ADR 0004, amendment).

Hooks (override in the game; defaults in brackets):

| Hook | Purpose |
|---|---|
| `_game_id() -> String` | Seed namespace, e.g. `"white-shift"`. [push_error] |
| `_game_title() -> String` | Title label, e.g. `"WHITE SHIFT"`. [push_error] |
| `_first_day() -> String` | Date of puzzle #1. [push_error] |
| `_save_path() -> String` | Progress file. [`WhiteProgress.DEFAULT_PATH`] |
| `_texts() -> Dictionary` | The game's text table, registered with `WhiteText.register`. [{}] |
| `_level_count() -> int` | Levels per day. [3] |
| `_load_day(date: String) -> Array` | Puzzles of a day; [] when none. [push_error] |
| `_load_practice(index: int) -> Array` | Puzzles of a practice set. [push_error] |
| `_practice_count() -> int` | Number of practice sets. [0] |
| `_count_mode(is_practice: bool) -> int` | Count mode of new attempts. [`EVERY_MOVE`] |
| `_new_attempt(puzzle: Dictionary, count_mode: int) -> WhiteAttempt` | A fresh attempt for a puzzle. [push_error] |
| `_make_view() -> Control` | Creates the board view; the screen puts it in the expanding slot. The game connects its own input signals. [push_error] |
| `_view_show(a: WhiteAttempt) -> void` | Show an attempt without animation (level change). [no-op] |
| `_view_clear() -> void` | Show no board (no puzzle for the day). [no-op] |
| `_view_update(a: WhiteAttempt) -> void` | Show the new state after a move, undo or restart. [no-op] |
| `_extra_buttons() -> Array[Button]` | Buttons placed after Restart and shown only when solved (White Shift: Best route). Called once while building. [[]] |
| `_hint_text() -> String` | Message before the first move. [`t("hint")`] |
| `_play_message(a: WhiteAttempt) -> String` | Message line while the attempt is not solved; a non-empty result replaces the standard text (White Tally: "no move left"). [`""`] |
| `_key_move(event: InputEventKey) -> Variant` | The move for a key press, or null. [null] |
| `_on_debug_extra() -> void` | Extra debug action after `--keys` (White Shift: `--best`). [no-op] |
| `_practice_only() -> bool` | From 0.2.0 (section 13.1): open practice instead of the day and hide the mode button. [false] |

Flow (same as White Shift):

- `_ready`, in this order: (1) parse user arguments into `_debug` (`--name=value`; a bare `--name` is `"1"`);
  (2) `WhiteText.register(_texts())`; (3) unless `--shot`: `_save = WhiteProgress.read(_save_path(),
  WhiteText.languages(), "nl")`; (4) `WhiteText.lang = _debug.lang` when given, else `_save.lang`; (5) build the screen;
  (6) `date = _debug.date` when given, else `WhiteDaily.today()`; (7) `practice_index = randi() % maxi(1,
  _practice_count())`; (8) with `--practice`: `practice_index = 0` and open practice, else open the day; (9) with
  `--shot`: run the debug shot. Subclasses do not override `_ready`.
- Build: background (`WhiteTheme.BG`, full rect); margin container (24 on every side); column with spacing 14: top row
  (title expanding, mode button, language button), subtitle, tab row (spacing 8, one toggle button per level,
  expanding), info row (counter left, par centred, clock right, each expanding), the view (expands vertically,
  minimum height 300), message (autowrap word-smart, centred, minimum height 84), button row (spacing 8: Undo, Restart,
  extra buttons, Share, Next, each expanding). Fonts and colours from `WhiteTheme` (title accent, subtitle dim,
  counter text, par and clock dim, message dim). `_extra_buttons()` is called once, during the build, and its result
  kept in `_extra`.
- `_open_day()`: stop the clock; `practice = false`; `puzzles = _load_day(date)`; `attempts = []`; `times` = one 0 per
  level; for every puzzle: `a = _new_attempt(puzzle, _count_mode(false))`, `a.apply_record(saved record or "")`,
  restore `times[i]` from the saved `time_ms`; select the first unsolved level (level 0 when all are solved or there are
  no puzzles); show the level.
- `_open_practice()`: stop the clock; `practice = true`; `puzzles = _load_practice(practice_index)`; fresh attempts with
  `_count_mode(true)`; times 0; show the level.
- `_show_level()`: `_replaying = false`; `_view_clear()` without puzzles, else `_view_show(attempts[level])`;
  `_refresh()`; emit `level_shown`.
- `_refresh()`: subtitle (practice: `t("practice") + " %d" % (practice_index + 1)`, else
  `t("today") % WhiteDaily.number(date, _first_day())`); mode button `t("daily")` in practice, else `t("practice")`;
  language button `t("lang")`; button texts; tab text `t("levels")[i]` plus `" · %d" % count` when that level is solved,
  and the tab of the current level pressed. Without puzzles: empty counter, par and clock, message `t("no_puzzle")`,
  all action buttons (Undo, Restart, extra, Share, Next) hidden, emit `refreshed`, done. Otherwise:
  - Counter: `t(key) % a.count()`, where `key` is `"count_final"` when `a.mode == FINAL_ONLY` and
    `WhiteText.has_key("count_final")`, else `"count"`. `count_final` is optional and not part of `WhiteText.BASE`; a
    game that wants a different label in final-only mode defines it in its own table (for example "Zetten in je
    oplossing: %d").
  - Par `t("par") % p.par`; clock.
  - Undo and Restart visible while not solved and disabled when `history` is empty; extra buttons visible when solved;
    Share visible when solved and not practice; Next visible when solved and (practice or level < last level).
  - Message, first match wins: solved -> `t("solved") % [count, par, clock]`, plus two spaces and `t("perfect")` when
    count equals par; `_play_message(a)` is not empty -> that text; no move made yet (`a.moves_made == 0`) ->
    `_hint_text()`; else empty.
  - Emit `refreshed`.
- `_on_move(move)`: ignored without puzzles or while `_replaying`; `attempt.play(move)`; when effective: start the clock
  if stopped, `_view_update(a)`; when solved stop the clock and emit `attempt_solved(level, a.count())`; `_store()`;
  `_refresh()`.
- `_on_undo()`, `_on_restart()`: ignored while `_replaying` or without puzzles; on success `_view_update`, `_store`,
  `_refresh`.
- `_pick_level(i)` (beyond the puzzles: only refresh; else stop the clock, store, switch, show), `_next()` (practice on
  the last level: next practice set from level 0; else the next level), `_toggle_mode()`, `_toggle_lang()` (uses
  `WhiteText.next_lang()`, stores the language in `_save` and writes the file unless `--shot`, then refreshes),
  `_share()` (clipboard, message `line + "\n" + t("copied")`, line =
  `WhiteFormat.day_line(t("share_line"), number, counts, pars)` with `null` for unsolved levels), `_store()` (nothing
  in practice or with `--shot`; else one `WhiteProgress.entry` per level - the running level with its live clock -
  into `_save.days[date]`, `WhiteProgress.write`, emit `progress_saved`), `_elapsed()`, `_stop_clock()`, `_process()`
  (updates the clock label while it runs): as in White Shift.
- `_unhandled_input`: a key press without echo: Z or Backspace -> `_on_undo()`; R -> `_on_restart()`; otherwise
  `_key_move(event)`, and when that gives a move, `_on_move(move)`. When something was handled, mark the input as
  handled.
- Debug shot (`--shot=<png>`): `--level=N` picks a level; `--keys=<record>` is walked like `apply_record` but through
  `_on_undo`, `_on_restart` and `_on_move`, so the screen updates; then `_on_debug_extra()`; wait 1.5 s and one drawn
  frame; save the viewport as PNG; quit. `--date`, `--practice` and `--lang` as in White Shift. Nothing is read or
  saved.

Default texts in `WhiteText.BASE` (keys used by the screen), Dutch / English:

| Key | Dutch | English |
|---|---|---|
| `levels` | `["Makkelijk", "Middel", "Moeilijk"]` | `["Easy", "Medium", "Hard"]` |
| `today` | `Dagpuzzel #%d` | `Daily puzzle #%d` |
| `practice` | `Oefenen` | `Practice` |
| `daily` | `Vandaag` | `Today` |
| `count` | `Zetten: %d` | `Moves: %d` |
| `par` | `Par: %d` | `Par: %d` |
| `undo` | `Terug` | `Undo` |
| `restart` | `Opnieuw` | `Restart` |
| `next` | `Volgende` | `Next` |
| `solved` | `Opgelost in %d zetten (par %d) · %s` | `Solved in %d moves (par %d) · %s` |
| `perfect` | `Precies par!` | `Exactly par!` |
| `share` | `Deel uitslag` | `Share result` |
| `copied` | `Gekopieerd` | `Copied` |
| `no_puzzle` | `Voor vandaag is er nog geen puzzel. Kies Oefenen.` | `There is no puzzle for today yet. Choose Practice.` |
| `hint` | `Los de puzzel op in zo min mogelijk zetten.` | `Solve the puzzle in as few moves as you can.` |
| `share_line` | `White #%d · %s zetten (par %s)` | `White #%d · %s moves (par %s)` |
| `lang` | `EN` | `NL` |

`lang` is the label of the language button, i.e. the other language. The default `hint` is deliberately generic: the
kit knows no game rules, and White Shift's own hint (swipe rule, colours) lives in its table. Every game overrides
`share_line` with its own name and normally `hint` with its own rule. Optional key read by the screen when a game
defines it: `count_final` (`%d`).

Acceptance:
- Kit test with the fixture game (section 5.13): open a day, play, undo, solve, reload from the written file (same
  state, opens on the first unsolved level), practice is not saved, a no-puzzle day shows `t("no_puzzle")` and survives
  input, a `FINAL_ONLY` practice shows the line length in the counter, the language toggle alternates and is saved.
- `count_final`: without the key, a `FINAL_ONLY` attempt uses the `count` text; with the key registered, it uses
  `count_final`; an `EVERY_MOVE` attempt always uses `count`.
- `_play_message`: with the default hook the message equals White Shift's (hint before the first move, empty after);
  with a fixture override returning a fixed text while the state is 2, that text is shown at state 2 (also before any
  move if the start state were 2), the solved message still wins after solving, and an empty result falls back to the
  standard text.
- `refreshed`: a handler connected on the fixture screen is called once per `_refresh()`, both with puzzles and on a
  no-puzzle day, and after a language toggle it sees the new `WhiteText.lang`.
- White Shift's UI tests pass unchanged after its `main.gd` extends `WhiteDayScreen` (section 10, step 9).

### 5.13 WhiteTestRunner and kit tests

`class_name WhiteTestRunner extends Node` (file `tests/test_runner.gd`, the only script under `tests/` with a
`class_name`, because games extend it).

```gdscript
var passed := 0
var failed := 0
func check(ok: bool, what: String) -> void   # counts; on failure printerr("FAIL: " + what)
func _run() -> void                          # override; may await
```

`_ready` awaits `_run()`, prints `tests: <passed> passed, <failed> failed` and quits with exit code 1 when anything
failed. Optional user argument `--min-checks=N`: when fewer than N checks ran, it also prints
`FAIL: only <n> checks ran, expected at least <N>` and exits with 1 (guards against silently skipped tests).

Known limitation in 0.1.0: a GDScript runtime error (for example a call on `null`) inside a test function aborts that
function; the caller continues, so the checks after the error never run and nothing is counted as failed. The run can
still end with exit code 0. `--min-checks` catches this only when enough checks are lost (kit CI: 250, White Shift:
177). Version 0.2.0 counts every script error as a failure (section 13.2, ADR 0005).

Because games exclude `addons/white_kit/tests/*` from their export, `WhiteTestRunner` is never exported; it must
therefore not be referenced from game code outside `tests/`.

Kit tests: `tests/run_kit_tests.tscn` (root `Node` with `run_kit_tests.gd`, which extends `WhiteTestRunner`) runs the
suites `test_kit.gd`, `test_daily.gd`, `test_seed.gd`, `test_rng.gd`, `test_puzzle_store.gd`, `test_attempt.gd`,
`test_progress.gd`, `test_text_format.gd`, `test_day_screen.gd` and `test_precompute.gd`, loaded by path; a suite that
does not load is a failed check `suite loads: <path>`. Each suite has
`func run(check: Callable, node: Node) -> void` (may await), like White Shift's `extra_tests.gd`. Version 0.1.0 has 258
checks; the kit CI and the game template run the kit tests with `--min-checks=250`.

Fixture game (`tests/fixtures/`, no `class_name`, loaded with `preload`):
- `counter_rules.gd`: state is an int starting at 0; move `"U"` (+1) and `"D"` (-1, rejected at 0); solved at 3;
  `move_len() == 1`.
- `wide_rules.gd`: the same game with three-character tokens (`"A1U"`, `"A1D"`), `move_len() == 3`, to test
  multi-character records.
- `fixture_screen.gd`: a `WhiteDayScreen` subclass with a plain `Control` as view, the counter rules, its own save path
  (`user://white_kit_test_progress.json`) and fixture puzzle files `daily.json` (two dates) and `practice.json`
  (two sets), each puzzle `{"par": 3}`. Variants for the `_play_message` and `count_final` tests are set through
  member flags on the fixture.
- `generator.gd`: a `WhitePrecompute` subclass with game id `white-fixture` whose `_generate` returns
  `{"seed": "<hex of seed>", "level": level, "par": level + 1}`, so the default `_summary` is exercised.

`test_precompute.gd` runs the fixture generator as a child Godot process:
`OS.execute(OS.get_executable_path(), ["--headless", "--path", <globalized res://>, "-s", <generator>, "--", ...args],
output, true)`, so exit codes and printed lines are the real ones of a command-line run. Its files are under `user://`
with the prefix `white_kit_test_`. This works unchanged inside a game, where the kit tests also run.

### 5.14 WhitePrecompute (`tools/precompute.gd`)

`class_name WhitePrecompute extends SceneTree`. Skeleton for a game's `tools/build_puzzles.gd`.

Hooks:

```gdscript
func _game_id() -> String                                       # "white-shift"
func _level_count() -> int                                      # default 3
func _generate(seed_value: int, level: int) -> Dictionary       # one puzzle, JSON-ready
func _summary(puzzles: Array) -> String                         # printed after the key; default " par " + str(list of par)
```

Entry points (not hooks; games do not override them):

```gdscript
func _init() -> void                                   # quit(_run(OS.get_cmdline_user_args()))
func _run(user_args: PackedStringArray) -> int         # runs one command, returns the exit code (0 or 1)
```

`_run` holds the whole command so it can be called without quitting; the kit tests use the child process of 5.13
instead, because only that gives real exit codes and output.

Commands (user arguments after `--`):

```
--from=YYYY-MM-DD [--days=N] --out=<file>         daily keys from..from+N-1 (N default 1); seed WhiteSeed.daily(game_id, date, level)
--practice=N [--start=S] --out=<file>             practice keys "S".."S+N-1" (S default 0); seed WhiteSeed.practice(game_id, i, level)
--merge=<built file> --into=<data file>           add new keys to the data file, never change existing ones
```

- Build mode writes a fresh file with `JSON.stringify(out, "", false) + "\n"`, keys in build order, and prints
  `<key><summary>` per key. White Shift's former output line was `print(key, " par ", pars)`; the default `_summary`
  reproduces it character for character.
- Merge mode:
  - Reading: both files are parsed with `JSON.new().parse()`. A missing data file counts as `{}`. A missing built file,
    or either file present but not a JSON dictionary, prints `cannot read <path>` to stderr and returns 1 without
    writing.
  - Numbers: JSON parsing yields floats for every number. Every float that is whole and below 2^53 in absolute value
    is turned back into an int, recursively through arrays and dictionaries, in both files. Without this, a rewrite
    would turn `4` into `4.0` in already published data. Assumption A9 makes this safe.
  - Per key of the built file, in its order: absent from the data file -> to be added; present and equal (compared as
    `JSON.stringify(value, "", true)`, so key order inside a puzzle does not matter) -> skipped; present and different
    -> print `refused: <key> differs from the published puzzle` and return 1 without writing anything.
  - Then, for every added key in built order: append it to the data dictionary and print `<key><summary>`. Skipped keys
    print nothing.
  - When at least one key was added, the data file is rewritten as `JSON.stringify(data, "", false) + "\n"`; existing
    keys keep their order and, for a file the tool wrote itself, their exact bytes. When nothing was added, the file is
    not touched.
  - Finally print `merged: <added> added, <skipped> unchanged` and return 0.
- Invalid arguments (`--from` not a date, missing or empty `--out`/`--into`, `--days` or `--practice` below 1, no
  command) print the usage line to stderr and return 1.
- A game script only overrides hooks.

Acceptance: build with the fixture generator gives the expected keys and the expected seeds; merge adds new keys, skips
equal ones and refuses a changed published key with exit code 1 and an unchanged data file; after a merge that adds
keys to a file the tool wrote, the old file up to (not including) its final `}` is a byte-for-byte prefix of the new
file; a merge that adds nothing leaves the file's modification untouched and prints `merged: 0 added, <n> unchanged`;
a data file holding a JSON list gives `cannot read` and exit code 1; for White Shift, `build_puzzles.gd` writes
byte-identical output to the old tool for the same arguments while the generator is unchanged (section 10, step 8).

## 6. Formats

### 6.1 Record grammar

A record is a string with one entry per action, in order:

| Entry | Meaning |
|---|---|
| `z` | Undo (only written when possible). |
| `r` | Restart (only written when possible). |
| other lower-case letters | Reserved for future kit-level actions; ignored on replay today. |
| move token | Exactly `move_len()` characters from `[A-Z0-9]`, defined by the game. Only effective moves are written. |

White Shift: move length 1, tokens `R L D U`. White Tally chooses its own tokens; a natural form is cell plus
direction (for example `C3R`, move length 3), which covers both a swap with a neighbour and a slide into an empty
neighbouring cell - its rules decide which of the two applies.

### 6.2 Puzzle files

`{"<key>": [puzzle per level]}`; daily keys `YYYY-MM-DD`, practice keys `"0"`, `"1"`, ... The content of a puzzle is
defined by the game; the shared screen only needs `par`. Numbers that are whole are written as JSON integers;
integers of 2^53 or more (for example raw seeds) are stored as strings (A9).

### 6.3 Progress file

Section 5.8. Games share the format; each game has its own file because each is a separate web origin
(`play.<game>.steefbeest.nl`) and a separate app.

## 7. Tools and CI

### 7.1 Kit host project

The kit has no `project.godot`. For its own tests:

- Local: `tools/kit_host.sh [dir]` (default `build/host`): creates `build/.gdignore` when the directory is under
  `build/`, creates the host directory, copies `templates/host/project.godot`, links `addons/white_kit` to the
  repository root, runs `godot --headless --path <dir> --import` and then
  `timeout 300 godot --headless --path <dir> res://addons/white_kit/tests/run_kit_tests.tscn`. The exit code of the
  tests is the exit code of the script. The nested `project.godot` and `build/.gdignore` stop Godot from scanning the
  link recursively. The import also creates the `.uid` file of a new script (section 4).
- CI: the repository is checked out at `host/addons/white_kit` and the template copied to `host/project.godot`.

`templates/host/project.godot`: `config_version=5`, name `White Kit host`, features `4.7` and `GL Compatibility`, GL
Compatibility renderer, no main scene, default GDScript warnings (so kit code must be free of warnings with default
settings; intended integer divisions carry `@warning_ignore("integer_division")`).

### 7.2 Kit CI (`.github/workflows/ci.yml`)

Triggers: pushes to `develop` and `main`, pull requests to `main`, tags `v*`, manual runs. One job on `ubuntu-24.04`:

1. Checkout to `host/addons/white_kit`; copy the host template to `host/project.godot`.
2. `uses: ./host/addons/white_kit/ci/setup-godot` (section 7.3).
3. Import the host project; run the kit tests with `--min-checks=250`.
4. Reference vectors: run `tools/rng_vectors.gd` in the host and `python3 -I tools/reference/white_rng.py`; `diff`
   their outputs.
5. Determinism grep (section 5.4).
6. On a tag: the tag must equal `v` followed by the content of `VERSION`.

### 7.3 Composite action `ci/setup-godot/action.yml`

Inputs with defaults (the kit pins the engine for the series): `version` (`4.7.2`), `sha512-editor`,
`sha512-templates` (the values formerly in White Shift's CI). Steps: cache `~/godot` keyed on version and editor hash;
on a cache miss download the editor and export templates, verify both SHA-512 sums, unzip, remove the archives; link
`/usr/local/bin/godot` and the export templates folder; print `godot --version`. This is White Shift's former CI code,
moved.

### 7.4 Game workflow template (`templates/ci.yml`)

A game copies this file to `.github/workflows/ci.yml` and adapts the header comment (play domain) and the minimum
number of checks. Triggers, concurrency and permissions as in White Shift. Steps:

1. `actions/checkout` with `submodules: true`.
2. Kit pin check: `v=$(cat addons/white_kit/VERSION)`;
   `git -C addons/white_kit fetch --depth=1 origin "refs/tags/v$v:refs/tags/v$v"`; fail unless
   `git -C addons/white_kit rev-parse "v$v^{commit}"` equals `git -C addons/white_kit rev-parse HEAD`. Write
   `White Kit v<version>` to the step summary.
3. `uses: ./addons/white_kit/ci/setup-godot`.
4. Import; kit tests (`res://addons/white_kit/tests/run_kit_tests.tscn` with `-- --min-checks=250`); game tests
   (`res://tests/run_tests.tscn` with `-- --min-checks=<N>`).
5. Puzzles left (only when `data/daily.json` exists): days from today on, warning below 14 - White Shift's step.
6. Export Web (release), upload artifact, Pages artifact and deploy on `develop` (not on pull requests) - White Shift's
   steps and Pages job.

## 8. Branches, versioning and release

- Branch model as in the games: `develop` is the working branch; `main` is protected and only updated through pull
  requests; releases are tags.
- Semantic versions `MAJOR.MINOR.PATCH` in `VERSION` and `WhiteKit.VERSION`; git tag `v<version>`. `CHANGELOG.md` has
  one section per version.
- A release tag is set on the commit that is merged to `main`. Exception: `v0.1.0` was tagged on `develop` before the
  first pull request to `main`, so White Shift could be migrated; that pull request must be a merge (not a squash or
  rebase), so the tagged commit becomes part of `main`. Tags are never moved or deleted once a game pins them.
- MAJOR: a breaking change to a public API, the record grammar, the progress format, or the output of `WhiteSeed` or
  `WhiteRng` for a given seed. MINOR: new API (including a new hook or signal), backward compatible. PATCH: fixes
  without API change. While the version is 0.x a MINOR may break; the changelog then says so explicitly.
- The output of `WhiteSeed` and `WhiteRng` is frozen: changing it is always MAJOR (also in 0.x), and the reference
  vectors in the tests may only change together with such a bump.
- Games pin a tagged release; the CI check in 7.4 enforces it. Updating a game: `git -C addons/white_kit fetch --tags`,
  `git -C addons/white_kit checkout v<new>`, `git add addons/white_kit`, run the game's tests, commit
  `chore: update White Kit to v<new>`.

## 9. What White Tally gets

Only the API; the rules belong to White Tally's own design. White Tally's architect has confirmed that this section
covers its needs, including the additions R1, R2 and R3 below.

- A `WhiteRules` subclass for its board: its own state type, `move_len()` and tokens for a swap of two neighbouring
  stones and a slide into an empty neighbouring cell; `apply` returns `null` for an illegal move (and for a move that
  changes nothing, if its rules say so).
- Daily attempts in `EVERY_MOVE`, practice in `FINAL_ONLY`, through the screen hook
  `_count_mode(is_practice)` returning `FINAL_ONLY` when `is_practice`, else `EVERY_MOVE`. One record format for both.
- R1 (0.1.0): the hook `_play_message(a)` for its own message during play (for example when no move is left); empty
  means the standard text.
- R2 (0.1.0): the optional text key `count_final` for the counter label in `FINAL_ONLY`, falling back to `count`.
- R3 (planned, 0.2.0): the hook `_practice_only()` to open directly in practice and hide the mode button, for White
  Tally's phase 1, which has no daily puzzles (section 13.1). Until then White Tally uses the interim overrides in its
  own design (section 7.1 there) and removes them when it updates to 0.2.0.
- The signal `refreshed()` for texts of its own extra buttons (for example Best route).
- `WhiteRng` and `WhiteSeed` for generation (on device or precomputed), with seed texts `white-tally|<date>|<level>`.
- `WhitePuzzleStore` and `WhitePrecompute` (with merge) when its puzzles are precomputed.
- `WhiteDayScreen` with its own board view, texts and share template; a game may override `_share()` when the
  three-level line does not fit (for example a line with the clock).
- `WhiteProgress`, `WhiteText`, `WhiteFormat`, `WhiteTestRunner`, the CI template.

## 10. Migration plan for White Shift

Status: done (2026-11-17). White Shift `develop` at 530b879 pins `v0.1.0`; CI green including the Pages deploy.

Requirements: no change in behaviour, identical puzzles (data files byte-identical), all existing 177 checks green
after every step. One commit per step on a `chore/white-kit` branch in White Shift; tests run after every step. The kit
is tagged `v0.1.0` (kit CI green) before step 1.

| Step | Change | Files |
|---|---|---|
| 1 | Add the kit as submodule at `v0.1.0`: `git submodule add https://github.com/dm-utils/white-kit.git addons/white_kit`, then check out the tag. Export preset: `exclude_filter="tests/*,tools/*,addons/white_kit/tests/*,addons/white_kit/tools/*"`. README: clone with `--recurse-submodules`, or run `git submodule update --init` after a plain clone. CI from `templates/ci.yml` with `--min-checks=177`; keep White Shift's header comment. Verify assumption A6 (after re-import, `.godot/global_script_class_cache.cfg` lists the kit classes and no fixture or template scripts). | `.gitmodules` (new), `addons/white_kit` (gitlink, new), `export_presets.cfg`, `README.md`, `.github/workflows/ci.yml` |
| 2 | `ShiftDaily` becomes a wrapper: keeps `FIRST_DAY`; `nl_offset`, `date_at`, `today` call `WhiteDaily`; `number(date)` calls `WhiteDaily.number(date, FIRST_DAY)`. | `sim/daily.gd` |
| 3 | `ShiftGenerator.seed_for(text)` returns `WhiteSeed.fnv1a64(text)`. | `sim/generator.gd` |
| 4 | `ShiftPuzzles` keeps `DAILY`, `PRACTICE`, `_puzzle` and its public functions; they delegate to one lazily created `WhitePuzzleStore.new(DAILY, PRACTICE, _puzzle)`. | `sim/puzzles.gd` |
| 5 | `ShiftBoard extends WhiteRules`: `start_state()` returns `start`; `apply(s, dir)` returns `null` when `swipe(s, dir) == s`, else the new state; `is_solved(s)` returns `is_won(s)`; `encode_move(dir)` returns `LETTERS[dir]`; `decode_move(t)` returns the index in `LETTERS`, or `null` when not found. `ShiftAttempt extends WhiteAttempt`: `var board: ShiftBoard`; `_init(b)` calls `super(b)` and sets `board`; `swipe(dir)` returns `play(dir)`; `var swipes: int` with a getter returning `count()`; `static func replay(b, rec) -> ShiftAttempt` creates an attempt and calls `apply_record(rec)`. | `sim/board.gd`, `sim/attempt.gd` |
| 6 | `Strings` keeps `TEXT` with all current keys, except `swipes`, renamed to `count`; `static var lang` gets a getter and setter that read and write `WhiteText.lang`; `t(key)` reads `TEXT[WhiteText.lang][key]` (so it works without registration; the tests call it directly); `clock` calls `WhiteFormat.clock`; `share_line` calls `WhiteFormat.day_line(t("share_line"), number, swipes, pars)`. White Shift defines no `count_final`. The former `main.gd` reads `count` from this step on. | `ui/strings.gd`, `ui/main.gd` |
| 7 | `run_tests.gd extends WhiteTestRunner`; its `_ready` becomes `_run`; `check` and the counters come from the base. The output line stays `tests: 177 passed, 0 failed`. | `tests/run_tests.gd` |
| 8 | `build_puzzles.gd extends WhitePrecompute` with `_game_id()` = `"white-shift"` and `_generate` (calls `ShiftGenerator.generate`, returns `{board, par, solutions, path}` as before). Verify: `--from=2026-11-17 --days=3` and `--practice=2` give byte-identical files to the old tool (run the old tool from the commit before this step). `measure.gd` unchanged. New days are from now on merged with `--merge`. | `tools/build_puzzles.gd` |
| 9 | `main.gd extends WhiteDayScreen` and implements the hooks: `_game_id`, `_game_title` (`"WHITE SHIFT"`), `_first_day` (`ShiftDaily.FIRST_DAY`), `_texts` (`Strings.TEXT`), `_load_day` (`ShiftPuzzles.day`), `_load_practice` (three `ShiftPuzzles.practice(i, level)`), `_practice_count`, `_new_attempt` (`ShiftAttempt.new(puzzle.board)`; count mode ignored, always every move), `_make_view` (a `BoardView` with `swiped` connected to `_on_swipe`), `_view_show` (`view.show_board`), `_view_clear` (`view.board = null`, redraw), `_view_update` (`view.set_state`), `_extra_buttons` (`[best_btn]`, its text set from the `refreshed` signal), `_hint_text` (`t("hint") + "\n" + t("rule_more")`), `_key_move` (arrows and WASD), `_on_debug_extra` (`--best`). `_play_message` keeps its default. It keeps `best_btn`, `_on_swipe(dir)` (calls `_on_move(dir)`), `_show_best` and `_on_swipe_all_best`. Everything else is removed from `main.gd`. `ui/main.tscn` unchanged. | `ui/main.gd` |
| 10 | Generator on `WhiteRng` (ADR 0002): `generate` uses `WhiteRng.new(seed_value)`; `random_board(rng: WhiteRng, cfg)` and `_free_cell(rng: WhiteRng, ...)`; `randi_range` -> `range_int`, `randf` -> `next_float`. Tests: in `test_fast_swipe_matches_reference` and `test_swipe_properties` only the generator construction (`WhiteRng.new(7)`, `WhiteRng.new(99)`) and `randi_range` -> `range_int` change; no assertion changes. Run `measure.gd -- --days=30` and log the fit rate per level. `data/` is not regenerated. | `sim/generator.gd`, `tests/run_tests.gd`, `tests/extra_tests.gd` |

No file is deleted: `sim/daily.gd`, `sim/puzzles.gd`, `sim/attempt.gd` and `ui/strings.gd` stay as thin wrappers
because the existing tests call `ShiftDaily`, `ShiftPuzzles`, `ShiftAttempt` and `Strings` directly. They can be
removed later together with an update of the tests (not part of this migration). Unchanged: `sim/solver.gd`,
`ui/board_view.gd`, `ui/main.tscn`, `tests/run_tests.tscn`, `tools/measure.gd`, `project.godot`, `data/*`.

White Shift's own documentation (design, conventions, glossary, ADR 0005 "Adopt White Kit") is updated in the White
Shift repository.

Acceptance for the migration (all met, see White Shift's ADR 0005 for the measured results):
- After every step: `tests: 177 passed, 0 failed`, exit code 0; from step 1 the kit tests are also green in White
  Shift's CI.
- `git diff <start>..HEAD -- data/` is empty.
- Steps 1-9: `ShiftGenerator.generate(seed_for("white-shift|<date>|<l>"), l)` gives the same board, par and path as
  before (3 dates x 3 levels against the old commit). Step 10 changes this on purpose (ADR 0002).
- Debug screenshots before and after for `--date=2026-11-17`, `--practice`, `--date=2027-02-01` (no puzzle),
  `--date=2026-11-17 --lang=en` and `--date=2026-11-17 --level=2` are pixel-identical. A shot with `--keys` may differ
  only in the clock.
- A `progress.json` written by the old version loads with the same position, count and record in the new version, and
  the other way round.
- The play version on `develop` loads and plays after the CI deploy.
- Step 10: `measure.gd -- --days=30` shows each level fitting its band without fallback on at least 27 of 30 seeds;
  otherwise the developer reports the numbers and the architect adjusts the tries per level. Measured: 30/30 on every
  level.

## 11. Later: st33f-engine

Not designed now; the kit leaves these seams:

- Puzzle delivery: the screen gets puzzles only through `_load_day`; a server-delivered day replaces the file source
  behind that hook.
- Verification: the record (section 6.1) plus the count mode is the submission; the server replays it with the same
  rules code and derives the count.
- Profile sync: the progress file is a small JSON document that fits a per-game cloud profile.
- Seeds: `WhiteSeed` and `WhiteRng` are portable (Python reference), so a server can compute or check the same seeds.

## 12. Build order and acceptance summary (0.1.0, done)

1. `core/` classes with their tests; Python reference and vector comparison; `tools/kit_host.sh`; kit CI green.
2. `ui/` classes with the fixture screen test.
3. `tools/precompute.gd` with its tests; `ci/setup-godot`; `templates/ci.yml`.
4. README (installation, update, local tests, "all rights reserved"), `CHANGELOG.md` for `0.1.0`; no licence file
   (decided: all rights reserved, no `LICENSE`); tag `v0.1.0` (section 8 on where the tag sits).
5. White Shift migration (section 10).

The kit is done when: kit CI is green on `main` and on the tag; every acceptance criterion in section 5 has a test;
the acceptance of section 10 holds. Open for 0.1.0: the pull request `develop` -> `main` (merge commit, section 8)
and kit CI green on `main`.

## 13. Next release: 0.2.0 (planned)

Two additions, both backward compatible. A new hook is new API, so the version is MINOR: `0.2.0` (section 8).
White Shift needs no code change for either and updates by the procedure in section 8; its 177 checks must stay green
and its screenshots pixel-identical.

### 13.1 R3: practice-only screen (`_practice_only`)

Requested by White Tally (its design, section 7.1 R3): its phase 1 has no daily puzzles, so the day view would only
show "no puzzle". Decision and alternatives: ADR 0004, amendment 2.

```gdscript
func _practice_only() -> bool      # hook on WhiteDayScreen; default false
```

When the hook returns true:

- `_ready` step 8 always opens practice: `practice_index = 0` with `--practice`, else the random index of step 7, then
  `_open_practice()`. `_open_day()` is not called. Steps 3 and 4 (reading the progress file for the language) are
  unchanged; step 6 still sets `date` (unused by the screen in this mode).
- Build: `mode_btn` is still created (the member stays valid for game code and tests) and is hidden.
- `_refresh()`: `mode_btn.visible = not _practice_only()`, set in both branches before `refreshed` is emitted.
- `_toggle_mode()`: returns at once when `_practice_only()` is true.
- Everything else follows practice behaviour: attempts are not saved, Share is hidden, Next after the last level opens
  the next set, the language toggle is still saved.
- A practice-only game must ship at least one practice set; without one the screen shows `t("no_puzzle")`, which the
  game overrides with a fitting text.
- `--date` has no effect in this mode; `--practice` still selects set 0 (deterministic screenshots).

When the hook returns false (default) nothing changes: `mode_btn.visible` is true as before.

Acceptance (fixture screen with a member flag `practice_only`):
- With the flag: after `_ready`, `practice == true`, `mode_btn.visible == false`, the subtitle is the practice text;
  `_toggle_mode()` leaves `practice` true and `puzzles` unchanged; after moves and a solve no progress file entry for
  any date is written (the file holds only the language after a language toggle); after the last level, Next opens the
  next set; `mode_btn` stays hidden after a language toggle and after Next.
- Without the flag: `mode_btn.visible == true` and every existing screen test passes unchanged.
- White Shift on 0.2.0: 177 checks green; the screenshots of section 10 pixel-identical.

### 13.2 Test runner counts script errors

Decision and alternatives: ADR 0005.

`tests/test_runner.gd` gets an inner class (no `class_name`) that extends `Logger`:

```gdscript
class _ScriptErrors extends Logger:
	var lines: PackedStringArray = []
	var _lock := Mutex.new()
	func _log_error(function: String, file: String, line: int, code: String, rationale: String,
			editor_notify: bool, error_type: int, script_backtrace: Array[ScriptBacktrace]) -> void
		# when error_type == ERROR_TYPE_SCRIPT: under _lock, append "%s:%d %s" % [file, line, rationale or code]
	func _log_message(message: String, error: bool) -> void
		# nothing
```

- `_ready`: create the logger, `OS.add_logger(logger)`, `await _run()`, `OS.remove_logger(logger)`; then for every
  collected line: `failed += 1` and `printerr("FAIL: script error: " + line)`; then the existing `--min-checks` check,
  summary line and exit code (1 when `failed > 0`).
- The logger callback only appends under the mutex; it never prints and never calls `check` (callbacks may come from
  other threads and printing inside a logger callback recurses into the logger).
- Only `ERROR_TYPE_SCRIPT` counts. `push_error` (type `ERROR_TYPE_ERROR`), warnings and shader errors do not, so tests
  that deliberately call kit functions that `push_error` keep passing.
- The summary line keeps its format; `failed` now includes script errors.
- Games get this through `extends WhiteTestRunner` without changes.

Acceptance (two fixture scenes under `tests/fixtures/`, each a root `Node` with a script that extends
`WhiteTestRunner`, no `class_name`, run as child processes like `test_precompute.gd`):
- `runner_script_error.tscn`: `_run` does `check(true, ...)`, calls a helper that calls a method on a `null` Object
  variable and then `check(true, ...)` (never reached), then `check(true, ...)` after the helper. Expected: exit code 1,
  output contains `tests: 2 passed, 1 failed` and `FAIL: script error:`.
- `runner_push_error.tscn`: `_run` does `check(true, ...)` and `push_error("expected")`. Expected: exit code 0, output
  `tests: 1 passed, 0 failed`.
- Kit tests and White Shift's tests stay green on 0.2.0 (no hidden script errors). If a hidden script error surfaces in
  White Shift, that is a finding for White Shift, not a reason to weaken the runner.
- If `runner_push_error` fails because `push_error` is reported as a script error (assumption A10 wrong), the developer
  stops and reports; the fallback in ADR 0005 is then chosen by the architect.

`--min-checks` stays: it also guards against a suite that is not called at all.

### 13.3 Release

`VERSION` and `WhiteKit.VERSION` `0.2.0`; `CHANGELOG.md` section `0.2.0` listing `_practice_only()`, the runner change
and the documentation of 0.1.0 behaviour that this design now describes (`refreshed`, `is_date`, merge details); tag
`v0.2.0` on the commit merged to `main`.
