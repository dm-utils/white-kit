# White Kit - design

Status: version 0.3.0 designed, not built (section 14); version 0.2.0 built and tagged (section 13); version 0.1.0
built and tagged, White Shift migrated onto it (section 10) and updated to 0.2.0.
Decisions with their trade-offs are in `docs/adr/`; terms are defined in `docs/glossary.md`; code and release rules
are in `docs/conventions.md`.

## 1. Purpose

White Kit is the shared base of the White daily puzzle games (Godot 4.7.2, GDScript, web first, Android later). It
holds everything that is the same in every game of the series, so each game repository only contains its own rules,
solver, generator, board drawing and texts.

The users are White Shift (published, `dm-utils/white-shift`), White Tally (phase 1 built, `dm-utils/white-tally`),
and White Sum and White Drift (designed, `dm-utils/white-sum` and `dm-utils/white-drift`, built on 0.3.0). White Shift
is migrated onto the kit without any change in behaviour (section 10).

Goals:

1. One implementation of the Dutch puzzle day, the seed hash, the random generator, puzzle loading, the attempt record,
   the progress file and the shared screen, tested once.
2. Bit-exact determinism: a seed gives the same random sequence on every platform and every Godot version.
3. A clear seam for later: accounts, leaderboards, friends and competitions come through st33f-engine; the kit's
   puzzle store, attempt record and progress file are the places where that connects (section 11). Nothing of that is
   built now.

Out of scope: game rules, solvers, generators, the drawing of a game's own tiles and pieces, sound, statistics,
tutorial, any network code. From 0.3.0 the kit has a board view base class for square-cell tile games (section 14.4);
what a tile looks like and which move a gesture means stay in the game.

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
| A10 | Godot's `Logger` class (`OS.add_logger`, available since Godot 4.5) reports GDScript runtime errors with error type `ERROR_TYPE_SCRIPT` and `push_error` with `ERROR_TYPE_ERROR`. Basis of the test runner in 0.2.0 (ADR 0005). | Verified in 0.2.0 by the fixtures `runner_script_error` and `runner_push_error` (section 13.2): a call on `null` is counted, `push_error` is not. |
| A11 | The grid games (White Tally, White Sum, White Drift) all use square cells, cell index `y * w + x` with `y` upwards, and direction codes `R = 0, L = 1, D = 2, U = 3`. Basis of `WhiteTileView` (0.3.0). | A game with another convention converts at the view boundary, or does not use the base class. |
| A12 | Godot saves a viewport PNG deterministically: the same frame gives the same pixels on the same machine and driver (CI uses `xvfb` with `opengl3`). Observed in board card #009 (seven White Shift scenarios byte-identical). | The comparison tool (14.5) reports pixel counts and a bounding box, so small driver noise is visible and can be judged. |

## 3. Scope: what is in the kit

Every candidate was checked against two questions: is it the same in both games, and is it stable enough that sharing
it does not slow down either game. The 0.3.0 additions for the grid games were checked the same way against White
Tally, White Sum and White Drift (ADR 0007, section 14.1).

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
| Rules, solver, generator, level parameters | No | - | `sim/board.gd`, `sim/solver.gd`, `sim/generator.gd` | Game-specific. Confirmed for the grid games in 0.3.0 (ADR 0007). |
| Board drawing and touch input | White Shift: no. Grid games: base class from 0.3.0 | `WhiteTileView` (14.4) | `ui/board_view.gd` | White Shift's pieces and swipes stay its own; the grid games share layout, animation and input, and draw their own tiles. |
| Safe area and maximum screen width | From 0.3.0 | `WhiteSafeArea`, screen hooks (14.2, 14.3) | not present (White Tally: `ui/safe_area.gd`) | Same need in every game; defaults keep existing games unchanged. |
| Screenshot scenarios and comparison | From 0.3.0 | `tools/shots.sh`, `tools/compare_shots.gd` (14.5) | CI step in White Tally | One scenario file per game serves CI and kit updates. |
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
    safe_area.gd        WhiteSafeArea      (0.3.0)
    tile_view.gd        WhiteTileView      (0.3.0)
  tools/
    precompute.gd       WhitePrecompute    (extends SceneTree)
    rng_vectors.gd      prints reference vectors (extends SceneTree, no class_name)
    compare_shots.gd    compares two screenshot folders (extends SceneTree, no class_name; 0.3.0)
    shots.sh            runs screenshot scenarios, compares, before/after a kit update (0.3.0)
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
except the virtual hooks of `WhiteDayScreen`, `WhiteRules`, `WhitePrecompute`, `WhiteTestRunner` and (0.3.0)
`WhiteTileView`, which games override.

### 5.1 WhiteKit (`core/kit.gd`)

```gdscript
class_name WhiteKit
const VERSION := "0.2.0"        # always equal to the VERSION file; "0.3.0" from release 0.3.0
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
static func number(date: String, first_day: String) -> int   # first_day is #1; the day before is 0; invalid input: push_error and 0
static func add_days(date: String, days: int) -> String      # calendar arithmetic via 12:00 UTC; invalid date: push_error and date unchanged
static func is_date(text: String) -> bool          # exactly "YYYY-MM-DD", a real calendar date, year 1970 or later
```

The formulas are those of `sim/daily.gd` (copy, do not rewrite). For a valid date, `add_days` returns
`Time.get_date_string_from_unix_time(Time.get_unix_time_from_datetime_string(date + "T12:00:00") + days * 86400)`.

Date validity is one private function `_valid(text) -> bool`, false at the first failing step:

1. `text` has length 10, characters 4 and 7 are `-`, all others are ASCII digits.
2. Year, month and day parsed from the parts: year at least 1970, month 1 to 12, day 1 to the length of that month
   (February 29 days in a Gregorian leap year: divisible by 4 and not by 100, or divisible by 400).

`_valid` never calls `Time`, so it never produces engine output. (`Time.get_unix_time_from_datetime_string` prints an
engine error for an impossible date such as 30 February or month 13.)

- `is_date(text)` returns `_valid(text)`. Since 0.2.0 it has no round trip through `add_days`: the 0.1.0 design had a
  third step `add_days(text, 0) == text`, which gives the same answer as step 2 for every four-digit year from 1970 on
  and is therefore dropped.
- `number(date, first_day)`: when `_valid(date)` or `_valid(first_day)` is false: `push_error` naming both values and
  return 0, without calling `Time`. Otherwise the 0.1.0 formula.
- `add_days(date, days)`: when `_valid(date)` is false: `push_error` naming the value and return `date` unchanged,
  without calling `Time`. Otherwise the formula above.

0 is also a valid result of `number` (the day before the first day), and a returned `date` can equal a valid result
(`days == 0`). The results for invalid input are therefore not a validity signal: the `push_error` marks a programming
error, and a caller that handles untrusted text (a command-line argument, a file, later a server) checks it with
`is_date` first. Decision and alternatives: ADR 0006.

`WhiteDayScreen` does not validate its debug argument `--date`; an invalid value gives the subtitle `#0` with a
`push_error` and no puzzles.

Acceptance: all date checks of White Shift (`test_daily_dates`, `test_dates`) pass against `WhiteDaily` with
`first_day = "2026-11-17"`; `add_days("2028-02-28", 1) == "2028-02-29"`; `add_days("2026-12-31", 1) == "2027-01-01"`;
`is_date("2026-02-30") == false`; `is_date("2026-13-01") == false`; `is_date("2028-02-29") == true`;
`is_date("2100-02-29") == false`; `is_date("2000-02-29") == true`; `is_date("2026-11-17") == true`;
`is_date("2026-11-7") == false`; none of these calls produces engine error output. For each of `"garbage"`,
`"2026-13-45"`, `""`, `"2026-02-30"`, `"1969-12-31"`, `"2026-1-1"`: `number(bad, "2026-11-17") == 0`,
`number("2026-11-17", bad) == 0` and `add_days(bad, 3) == bad`, each with exactly one `push_error` and without engine
error output. Valid input is unchanged: `number("2026-11-17", "2026-11-17") == 1`,
`number("2026-11-16", "2026-11-17") == 0`, `add_days("2026-02-28", 1) == "2026-03-01"`.

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

`game_id` is the repository name: `white-shift`, `white-tally`, `white-sum`, `white-drift`.

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
func range_int(from: int, to: int) -> int          # inclusive, unbiased; bad range: push_error and from, no draw
func next_float() -> float                         # next_u32() / 4294967296.0, in [0, 1), exact
func pick(items: Array) -> Variant                 # items[range_int(0, size - 1)]; empty: null without drawing
func shuffle(items: Array) -> void                 # in place
```

- `range_int` (0.2.0): `span = to - from` (int64 subtraction, which wraps to a negative value when the true span exceeds
  2^63 - 1). The range is bad when `from > to`, `span < 0` (overflow) or `span >= 2^32` (more than 2^32 values); a bad
  range is a `push_error` and returns `from` without drawing, so the state is unchanged. Otherwise `n = span + 1`,
  `limit = 4294967296 - (4294967296 % n)`; draw `r = next_u32()` until `r < limit`; return `from + r % n`. It always
  draws at least once, also when `n == 1`. For every valid range the output is identical to 0.1.0. Decision and
  alternatives: ADR 0006.
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
- Bad ranges (with `MAX = 2^63 - 1`, `MIN = -2^63`): `range_int(0, MAX) == 0`, `range_int(MIN, 0) == MIN`,
  `range_int(MIN, MAX) == MIN`, `range_int(-1, MAX) == -1`, `range_int(MAX - 2^32, MAX) == MAX - 2^32` (2^32 + 1
  values), each returning at once, and the state is unchanged after them. The widest valid ranges at both ends,
  `range_int(MAX - (2^32 - 1), MAX)` and `range_int(MIN, MIN + (2^32 - 1))`, return a value inside the range.
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
var margin: MarginContainer    # 0.3.0: the root margin container (section 14.2)
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
| `_practice_only() -> bool` | Since 0.2.0 (section 13.1): open practice instead of the day, hide the mode button and ignore `_toggle_mode()`. [false] |
| `_max_content_width() -> int` | Since 0.3.0 (section 14.2): maximum width of the screen column in viewport units; 0 = no limit. [0] |
| `_use_safe_area() -> bool` | Since 0.3.0 (section 14.2): add the display safe area to the margins; debug override `--safe=l,t,r,b`. [false] |

Flow (same as White Shift):

- `_ready`, in this order: (1) parse user arguments into `_debug` (`--name=value`; a bare `--name` is `"1"`);
  (2) `WhiteText.register(_texts())`; (3) unless `--shot`: `_save = WhiteProgress.read(_save_path(),
  WhiteText.languages(), "nl")`; (4) `WhiteText.lang = _debug.lang` when given, else `_save.lang`; (5) build the screen;
  (6) `date = _debug.date` when given, else `WhiteDaily.today()`; (7) `practice_index = randi() % maxi(1,
  _practice_count())`; (8) with `--practice`: `practice_index = 0` and open practice; else, when `_practice_only()`:
  open practice with the random index of step 7; else open the day; (9) with `--shot`: run the debug shot. Subclasses
  do not override `_ready`.
- Build: background (`WhiteTheme.BG`, full rect); margin container (24 on every side; from 0.3.0 the margins are set by
  `_apply_insets()`, section 14.2); column with spacing 14: top row
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
  `t("today") % WhiteDaily.number(date, _first_day())`); mode button `t("daily")` in practice, else `t("practice")`,
  and `mode_btn.visible = not _practice_only()`; language button `t("lang")`; button texts; tab text `t("levels")[i]`
  plus `" · %d" % count` when that level is solved, and the tab of the current level pressed. Without puzzles: empty
  counter, par and clock, message `t("no_puzzle")`, all action buttons (Undo, Restart, extra, Share, Next) hidden, emit
  `refreshed`, done. Otherwise:
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
  the last level: next practice set from level 0; else the next level), `_toggle_mode()` (returns at once when
  `_practice_only()`), `_toggle_lang()` (uses `WhiteText.next_lang()`, stores the language in `_save` and writes the
  file unless `--shot`, then refreshes), `_share()` (clipboard, message `line + "\n" + t("copied")`, line =
  `WhiteFormat.day_line(t("share_line"), number, counts, pars)` with `null` for unsolved levels), `_store()` (nothing
  in practice or with `--shot`; else one `WhiteProgress.entry` per level - the running level with its live clock -
  into `_save.days[date]`, `WhiteProgress.write`, emit `progress_saved`), `_elapsed()`, `_stop_clock()`, `_process()`
  (updates the clock label while it runs): as in White Shift. From 0.3.0 `_elapsed()` leaves out the running part
  while `--shot` is given (section 14.2).
- `_unhandled_input`: a key press without echo: Z or Backspace -> `_on_undo()`; R -> `_on_restart()`; otherwise
  `_key_move(event)`, and when that gives a move, `_on_move(move)`. When something was handled, mark the input as
  handled.
- Debug shot (`--shot=<png>`): `--level=N` picks a level; `--keys=<record>` is walked like `apply_record` but through
  `_on_undo`, `_on_restart` and `_on_move`, so the screen updates; then `_on_debug_extra()`; wait 1.5 s and one drawn
  frame; save the viewport as PNG; quit. `--date`, `--practice` and `--lang` as in White Shift. Nothing is read or
  saved. From 0.3.0 also `--safe=l,t,r,b` (only with `_use_safe_area()`).

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
- `_practice_only`: section 13.1. `_max_content_width`, `_use_safe_area`, frozen shot clock: section 14.2.
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

`_ready` (0.2.0), in this order:

1. Optional user argument `--min-checks=N`. The value must be a non-negative integer (`String.is_valid_int()` and at
   least 0); otherwise the runner prints `FAIL: bad --min-checks value '<value>'` and quits with exit code 1 before
   `_run()` is called. A bare `--min-checks` without `=` is ignored; when the argument is repeated, the last one
   counts.
2. Register the script error logger (section 13.2), await `_run()`, remove the logger.
3. Every collected script error: `failed += 1` and `printerr("FAIL: script error: <file>:<line> <message>")`.
4. When `passed + failed < N`: print `FAIL: only <n> checks ran, expected at least <N>`.
5. Print `tests: <passed> passed, <failed> failed`; quit with exit code 1 when `failed > 0` or step 4 failed, else 0.

A GDScript runtime error (for example a call on `null`) inside a test function still aborts that function, and the
checks after it never run, but the run now fails with the file and line of the error (ADR 0005). This also holds after
an `await` and for several errors in one run (each counts once). A parse error in a script that a test compiles at run
time is reported the same way and also fails the run. `push_error` does not count, so tests may call kit functions
that `push_error` on purpose. `--min-checks` stays as a second guard: it catches a suite that is not called at all.
In 0.1.0 the runner did not count script errors and relied on `--min-checks` alone.

Because games exclude `addons/white_kit/tests/*` from their export, `WhiteTestRunner` is never exported; it must
therefore not be referenced from game code outside `tests/`.

Kit tests: `tests/run_kit_tests.tscn` (root `Node` with `run_kit_tests.gd`, which extends `WhiteTestRunner`) runs the
suites `test_kit.gd`, `test_daily.gd`, `test_seed.gd`, `test_rng.gd`, `test_puzzle_store.gd`, `test_attempt.gd`,
`test_progress.gd`, `test_text_format.gd`, `test_day_screen.gd`, `test_precompute.gd`, `test_independent.gd`,
`test_edge.gd`, `test_precompute_edge.gd`, `test_release_020.gd` and (after the tag, section 13.4)
`test_retest_020.gd`, loaded by path; from 0.3.0 also `test_safe_area.gd`, `test_tile_view.gd`, `test_shots.gd` and
`test_release_030.gd` (section 14.8). A suite that does not load is a failed check `suite loads: <path>`. Each suite
has `func run(check: Callable, node: Node) -> void` (may await), like White Shift's `extra_tests.gd`. The tag
`v0.2.0` has 522 checks and the kit CI and the game template run the kit tests with `--min-checks=522`; check counts
per moment are in section 13.4 and, from 0.3.0, section 14.6.

Fixture game (`tests/fixtures/`, no `class_name`, loaded with `preload`):
- `counter_rules.gd`: state is an int starting at 0; move `"U"` (+1) and `"D"` (-1, rejected at 0); solved at 3;
  `move_len() == 1`.
- `wide_rules.gd`: the same game with three-character tokens (`"A1U"`, `"A1D"`), `move_len() == 3`, to test
  multi-character records.
- `fixture_screen.gd`: a `WhiteDayScreen` subclass with a plain `Control` as view, the counter rules, its own save path
  (`user://white_kit_test_progress.json`) and fixture puzzle files `daily.json` (two dates) and `practice.json`
  (two sets), each puzzle `{"par": 3}`. Variants for the `_play_message`, `count_final` and `_practice_only` tests are
  set through member flags on the fixture (`practice_only` for the last; from 0.3.0 also `max_width` and
  `safe_area`, section 14.8).
- `generator.gd`: a `WhitePrecompute` subclass with game id `white-fixture` whose `_generate` returns
  `{"seed": "<hex of seed>", "level": level, "par": level + 1}`, so the default `_summary` is exercised.
- Runner fixtures (`.tscn` plus `.gd`, each a root `Node` whose script extends `WhiteTestRunner`): `runner_script_error`,
  `runner_push_error` and `runner_parse_error` (section 13.2); `runner_await_error` and `runner_invalid_dates` (added
  by the 0.2.0 test round: a script error after an `await`, and invalid dates through `WhiteDaily` in a separate
  process so its engine output can be inspected).
- From 0.3.0: `tile_view_fixture.gd`, `fixture_main.tscn` and `shots.txt` (section 14.8).

`test_precompute.gd` runs the fixture generator as a child Godot process:
`OS.execute(OS.get_executable_path(), ["--headless", "--path", <globalized res://>, "-s", <generator>, "--", ...args],
output, true)`, so exit codes and printed lines are the real ones of a command-line run. Its files are under `user://`
with the prefix `white_kit_test_`. This works unchanged inside a game, where the kit tests also run. The runner
fixtures are run the same way, as scenes instead of `-s` scripts.

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
  command) print the usage line to stderr and return 1. `--from` is checked with `WhiteDaily.is_date` before any date
  arithmetic.
- A game script only overrides hooks.

Acceptance: build with the fixture generator gives the expected keys and the expected seeds; merge adds new keys, skips
equal ones and refuses a changed published key with exit code 1 and an unchanged data file; after a merge that adds
keys to a file the tool wrote, the old file up to (not including) its final `}` is a byte-for-byte prefix of the new
file; a merge that adds nothing leaves the file's modification untouched and prints `merged: 0 added, <n> unchanged`;
a data file holding a JSON list gives `cannot read` and exit code 1; for White Shift, `build_puzzles.gd` writes
byte-identical output to the old tool for the same arguments while the generator is unchanged (section 10, step 8).

Parallel builds: a game builds a large pool in several processes with `--practice=N --start=S` into separate files and
merges them one by one into the data file with `--merge` (practice keys merge like dates). White Tally built its pool
this way; White Sum and White Drift do the same.

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
neighbouring cell - its rules decide which of the two applies. White Tally and White Sum use direction plus cell
(`RB1`, length 3); White Drift uses one letter per tilt (`R L D U`, length 1).

### 6.2 Puzzle files

`{"<key>": [puzzle per level]}`; daily keys `YYYY-MM-DD`, practice keys `"0"`, `"1"`, ... The content of a puzzle is
defined by the game; the shared screen only needs `par`. Numbers that are whole are written as JSON integers;
integers of 2^53 or more (for example raw seeds) are stored as strings (A9).

### 6.3 Progress file

Section 5.8. Games share the format; each game has its own file because each is a separate web origin
(`play.white-<name>.steefbeest.nl`) and a separate app.

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
settings; intended integer divisions carry `@warning_ignore("integer_division")`). From 0.3.0 the main scene is
`res://addons/white_kit/tests/fixtures/fixture_main.tscn` and the window and stretch settings are those of the games
(section 14.6), so the screenshot tool can be tested in the host.

### 7.2 Kit CI (`.github/workflows/ci.yml`)

Triggers: pushes to `develop` and `main`, pull requests to `main`, tags `v*`, manual runs. One job on `ubuntu-24.04`:

1. Checkout to `host/addons/white_kit`; copy the host template to `host/project.godot`.
2. `uses: ./host/addons/white_kit/ci/setup-godot` (section 7.3).
3. Import the host project; run the kit tests with `--min-checks=522` (section 13.4; 635 and then the 0.3.0 count,
   section 14.6).
4. Reference vectors: run `tools/rng_vectors.gd` in the host and `python3 -I tools/reference/white_rng.py`; `diff`
   their outputs.
5. Determinism grep (section 5.4).
6. On a tag: the tag must equal `v` followed by the content of `VERSION`.
7. From 0.3.0: screenshot tool smoke test (section 14.6).

### 7.3 Composite action `ci/setup-godot/action.yml`

Inputs with defaults (the kit pins the engine for the series): `version` (`4.7.2`), `sha512-editor`,
`sha512-templates` (the values formerly in White Shift's CI). Steps: cache `~/godot` keyed on version and editor hash;
on a cache miss download the editor and export templates, verify both SHA-512 sums, unzip, remove the archives; link
`/usr/local/bin/godot` and the export templates folder; print `godot --version`. This is White Shift's former CI code,
moved.

### 7.4 Game workflow template (`templates/ci.yml`)

A game copies this file to `.github/workflows/ci.yml` and adapts the header comment (play domain) and the minimum
number of checks of its own tests (`MIN_CHECKS`). Triggers, concurrency and permissions as in White Shift. Steps:

1. `actions/checkout` with `submodules: true`.
2. Kit pin check: `v=$(cat addons/white_kit/VERSION)`;
   `git -C addons/white_kit fetch --depth=1 origin "refs/tags/v$v:refs/tags/v$v"`; fail unless
   `git -C addons/white_kit rev-parse "v$v^{commit}"` equals `git -C addons/white_kit rev-parse HEAD`. Write
   `White Kit v<version>` to the step summary.
3. `uses: ./addons/white_kit/ci/setup-godot`.
4. Import; kit tests (`res://addons/white_kit/tests/run_kit_tests.tscn` with `-- --min-checks=522`, the kit's check
   count at the pinned tag); game tests (`res://tests/run_tests.tscn` with `-- --min-checks=<N>`).
5. Puzzles left (only when `data/daily.json` exists): days from today on, warning below 14 - White Shift's step.
6. From 0.3.0: debug screenshots from `tools/shots.txt` (only when the file exists) as artifact `shots` (section 14.6).
7. Export Web (release), upload artifact, Pages artifact and deploy on `develop` (not on pull requests) - White Shift's
   steps and Pages job.

When a game updates the kit, it takes the kit threshold from the template of the new version (the changelog names it).

## 8. Branches, versioning and release

- Branch model as in the games: `develop` is the working branch; `main` is protected and only updated through pull
  requests; releases are tags.
- Semantic versions `MAJOR.MINOR.PATCH` in `VERSION` and `WhiteKit.VERSION`; git tag `v<version>`. `CHANGELOG.md` has
  one section per version.
- A release tag is set on the commit that is merged to `main`. Exception: `v0.1.0` and `v0.2.0` were tagged on
  `develop` before a pull request to `main` (`v0.1.0` so White Shift could be migrated, `v0.2.0` so White Shift and
  White Tally could update without waiting for the first merge to `main`). The pull request that brings them to `main`
  must be a merge (not a squash or rebase), so the tagged commits become part of `main`. Tags are never moved or
  deleted once a game pins them.
- MAJOR: a breaking change to a public API, the record grammar, the progress format, or the output of `WhiteSeed` or
  `WhiteRng` for a given seed. MINOR: new API (including a new hook or signal), backward compatible. PATCH: fixes
  without API change. While the version is 0.x a MINOR may break; the changelog then says so explicitly.
- The output of `WhiteSeed` and `WhiteRng` is frozen: changing it is always MAJOR (also in 0.x), and the reference
  vectors in the tests may only change together with such a bump. Defining the result of an input that had no usable
  result before (such as a `range_int` span beyond int64 in 0.2.0) is not a change of output.
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
- R3 (0.2.0, built): the hook `_practice_only()` to open directly in practice and hide the mode button, for White
  Tally's phase 1, which has no daily puzzles (section 13.1). White Tally removes the interim overrides of its own
  design (section 7.1 there) when it updates to `v0.2.0`.
- The signal `refreshed()` for texts of its own extra buttons (for example Best route).
- `WhiteRng` and `WhiteSeed` for generation (on device or precomputed), with seed texts `white-tally|<date>|<level>`.
- `WhitePuzzleStore` and `WhitePrecompute` (with merge) when its puzzles are precomputed.
- `WhiteDayScreen` with its own board view, texts and share template; a game may override `_share()` when the
  three-level line does not fit (for example a line with the clock).
- `WhiteProgress`, `WhiteText`, `WhiteFormat`, `WhiteTestRunner`, the CI template.
- From 0.3.0 (optional for White Tally, used by White Sum and White Drift): `WhiteTileView`, `WhiteSafeArea`, the
  screen hooks `_max_content_width()` and `_use_safe_area()`, and the screenshot tools. White Tally's optional
  migration is in section 14.7.

## 10. Migration plan for White Shift

Status: done (2026-11-17). White Shift `develop` at 530b879 pinned `v0.1.0`; CI green including the Pages deploy.
White Shift has since been updated to `v0.2.0` (section 13).

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
the acceptance of section 10 holds. Still open: the pull request `develop` -> `main` (merge commit, section 8), which
now also brings `v0.2.0`, and kit CI green on `main` (section 13.6).

## 13. Release 0.2.0 (built)

Status: built 2026-11-17 and tagged `v0.2.0` on `develop` (commit 0a58b2e); kit CI green on the branch and on the tag;
`tests: 522 passed, 0 failed` at the tag. Retested: all criteria below met, no blocking or high findings. A new hook is
new API, so the version is MINOR (section 8). Everything is backward compatible for valid input; the only behaviour
changes are for input that 0.1.0 handled badly (section 13.3 and the `--min-checks` check in 13.2).

The release holds White Tally's request R3 and the fixes for the test findings on 0.1.0: B1 (runner did not count
script errors), B2 (`range_int` overflow), B3 (`WhiteDaily.number` and `add_days` on an invalid date) and B7 (check
thresholds far below the real count).

White Shift needed no code change. It pins `v0.2.0` on its `develop` (f540f2a): its 192 checks are green under the new
runner (`MIN_CHECKS` 192), the kit tests inside it give 522 passed, and `data/`, `ui/`, `sim/` and `tools/` are
unchanged against 530b879.

### 13.1 R3: practice-only screen (`_practice_only`)

Requested by White Tally (its design, section 7.1 R3): its phase 1 has no daily puzzles, so the day view would only
show "no puzzle". Decision and alternatives: ADR 0004, amendment 2.

```gdscript
func _practice_only() -> bool      # hook on WhiteDayScreen; default false
```

When the hook returns true:

- `_ready` step 8 always opens practice: with `--practice` the `--practice` branch runs first (`practice_index = 0`,
  `_open_practice()`); otherwise `_open_practice()` with the random index of step 7, unchanged. `_open_day()` is not
  called. Steps 3 and 4 (reading the progress file for the language) are unchanged; step 6 still sets `date` (unused by
  the screen in this mode).
- So a practice-only game opens on a random practice set, exactly like a normal game whose player presses Practice;
  only `--practice` gives set 0. This is intended (deterministic screenshots go through `--practice`); a game that
  wants a fixed first set has no hook for it in 0.2.0 and asks for one.
- Build: `mode_btn` is still created (the member stays valid for game code and tests) and is hidden.
- `_refresh()`: `mode_btn.visible = not _practice_only()`, set in both branches before `refreshed` is emitted. The hook
  is read on every refresh, so a game whose hook changes from true to false at run time gets the mode button back on
  the next refresh.
- `_toggle_mode()`: returns at once when `_practice_only()` is true.
- Everything else follows practice behaviour: attempts are not saved, Share is hidden, Next after the last level opens
  the next set, the language toggle is still saved.
- A practice-only game must ship at least one practice set; without one the screen shows `t("no_puzzle")`, which the
  game overrides with a fitting text. The screen does not crash and the mode button stays hidden.
- `--date` has no effect in this mode.

When the hook returns false (default) nothing changes: `mode_btn.visible` is true as before.

Acceptance (fixture screen with the member flag `practice_only`; tests in `tests/test_release_020.gd` and
`tests/test_retest_020.gd`, all green):
- Without the flag: `mode_btn.visible == true` and the day is open; every existing screen test passes unchanged.
- With the flag: after `_ready`, `practice == true`, `mode_btn.visible == false`, the subtitle is the practice text;
  `practice_index` is within the number of sets; `_toggle_mode()` leaves `practice` true and `puzzles` unchanged; Share
  is hidden; all three levels can be solved; no progress file is written by playing; after the last level, Next opens
  set `practice_index + 1` at level 0; `mode_btn` stays hidden after Next and after a language toggle; after the
  language toggle the progress file exists and holds no day entry.
- With the flag and `--practice`: `practice == true` and `practice_index == 0`.
- With the flag and no practice sets: no crash, `t("no_puzzle")`, mode button hidden, toggle ignored.
- White Shift on 0.2.0: its tests green (met, see the status above). Its debug screenshots of section 10 have not been
  compared on 0.2.0 (open, section 13.6).

### 13.2 Test runner counts script errors

Decision and alternatives: ADR 0005.

`tests/test_runner.gd` has an inner class (no `class_name`) that extends `Logger`:

```gdscript
class _ScriptErrors extends Logger:
	var lines: PackedStringArray = []
	var _lock := Mutex.new()
	func _log_error(function: String, file: String, line: int, code: String, rationale: String,
			_editor_notify: bool, error_type: int, _script_backtrace: Array[ScriptBacktrace]) -> void
		# when error_type == Logger.ERROR_TYPE_SCRIPT: under _lock, append "%s:%d %s" % [file, line, text],
		# text = rationale, else code, else function
	func _log_message(_message: String, _error: bool) -> void
		# nothing
```

- `_ready`: section 5.13, steps 1 to 5.
- The logger callback only appends under the mutex; it never prints and never calls `check` (callbacks may come from
  other threads and printing inside a logger callback recurses into the logger).
- Only `ERROR_TYPE_SCRIPT` counts. `push_error` (type `ERROR_TYPE_ERROR`), warnings and shader errors do not, so tests
  that deliberately call kit functions that `push_error` keep passing. Assumption A10 holds.
- A parse error in a script compiled during `_run()` (for example a suite whose source does not parse) arrives as
  `ERROR_TYPE_SCRIPT` and fails the run too.
- `--min-checks` with a value that is not a non-negative integer (for example `abc`, `-1`, `1.5`, `0x10`, an empty
  value) fails the run before any test runs. In 0.1.0 such a value was read as 0 or a negative number and silently
  disabled the guard. A value too large for int64 saturates and then fails through step 4.
- The summary line keeps its format; `failed` now includes script errors.
- Games get this through `extends WhiteTestRunner` without changes.

Acceptance (runner fixtures under `tests/fixtures/`, run as child processes like `test_precompute.gd`; tests in
`tests/test_release_020.gd` and `tests/test_retest_020.gd`, all green):
- `runner_script_error.tscn`: `_run` does `check(true, ...)`, calls a helper that calls a method on a `null` Object
  variable and then `check(true, ...)` (never reached), then `check(true, ...)` after the helper. Result: exit code 1,
  output contains `tests: 2 passed, 1 failed` and `FAIL: script error:`.
- `runner_push_error.tscn`: `_run` does `check(true, ...)` and `push_error("expected")`. Result: exit code 0, output
  `tests: 1 passed, 0 failed`.
- `runner_parse_error.tscn`: `_run` does `check(true, ...)`, compiles a script source with a syntax error and checks
  that it can be instantiated. Result: exit code 1 and `FAIL: script error:` in the output.
- `runner_await_error.tscn`: a script error after an `await` is counted; two script errors in one run count as two.
- With `runner_push_error.tscn`: `--min-checks=abc` gives exit code 1 and `bad --min-checks value`; `--min-checks=-3`
  gives exit code 1; `--min-checks=1` gives exit code 0; `--min-checks=2` gives exit code 1 and `only 1 checks ran`.
- Kit tests and White Shift's tests stay green on 0.2.0: met, no hidden script errors surfaced.

### 13.3 Defined results for invalid input (B2, B3)

Decision and alternatives: ADR 0006. Specification in sections 5.2 and 5.4; summary:

- `WhiteRng.range_int(from, to)`: a bad range (`from > to`, a span that overflows int64, or more than 2^32 values) is a
  `push_error` and returns `from` at once, without drawing. In 0.1.0 an overflowing span could hang in the rejection
  loop or take a modulo by zero. Valid ranges give the same output as before (retested bit-exact against the 0.1.0
  formula); the frozen output of section 8 is untouched.
- `WhiteDaily.number(date, first_day)`: an invalid `date` or `first_day` (not `_valid`) is a `push_error` and returns
  0. `WhiteDaily.add_days(date, days)`: an invalid `date` is a `push_error` and returns `date` unchanged. Exactly one
  `push_error` per rejected call and no engine output. In 0.1.0 both passed the text to `Time`, which printed an engine
  error and returned a meaningless value.
- 0 is also the valid number of the day before the first day, so a caller with untrusted input checks `is_date` first;
  the result alone does not tell valid from invalid.
- `is_date` returns `_valid(text)` directly; the round trip through `add_days` of the 0.1.0 design is gone (5.2).
  Retested against an independent calendar computation for every day from 1970-01-01 to 2100-12-31.

Acceptance: the B2 and B3 criteria in sections 5.2 and 5.4 (tests in `tests/test_release_020.gd` and
`tests/test_retest_020.gd`, all green).

### 13.4 Check counts and thresholds (B7)

| Moment | Kit checks | Threshold in kit CI and `templates/ci.yml` |
|---|---|---|
| Tag `v0.1.0` | 258 | 250 |
| After the 0.1.0 test round (suites `test_independent.gd`, `test_edge.gd`, `test_precompute_edge.gd`) | 471 | 250 |
| Tag `v0.2.0` (plus 51 checks in `test_release_020.gd`) | 522 | 522 |
| `develop` after the 0.2.0 test round (plus 113 checks in `test_retest_020.gd`, commit 896e395) | 635 | 522 (to be raised, 13.6) |

From 0.2.0 the threshold equals the check count of the tag, so losing a single check of the tagged tests fails the
run. Rule: a commit that adds kit checks raises the threshold in `.github/workflows/ci.yml` and `templates/ci.yml` to
the new count in the same commit; the threshold is only lowered when checks are removed on purpose, and the changelog
says so. The test round's commit 896e395 did not raise it (the tester does not change CI configuration); that is the
first item of 13.6.

The game template's kit threshold must not exceed the check count of the kit tag a game pins. A raise to 635 therefore
only reaches games with the next kit tag that contains those checks.

### 13.5 Release

`VERSION` and `WhiteKit.VERSION` are `0.2.0`; `CHANGELOG.md` has a section `0.2.0` listing `_practice_only()`, the
runner change and the `--min-checks` check, the `range_int` and `WhiteDaily` fixes, the new threshold 522 and the
documentation of 0.1.0 behaviour that this design now describes (`refreshed`, `is_date`, merge details). The tag
`v0.2.0` sits on `develop` (0a58b2e), not on a `main` commit; section 8 lists this as an exception, like `v0.1.0`.

### 13.6 Open after 0.2.0

- Kit CI threshold: raise `--min-checks` in `.github/workflows/ci.yml` to 635 together with the test commit 896e395.
  `templates/ci.yml` stays at 522 until the next tag (13.4). Planned as the first step of 0.3.0 (section 14.6, board
  card #008).
- Pull request `develop` -> `main` as a merge commit (brings `v0.1.0` and `v0.2.0` into `main`); kit CI green on
  `main`.
- White Shift: compare the debug screenshots of section 10 on `v0.2.0` with those on `v0.1.0`. Done (board card #009):
  seven scenarios byte-identical. Repeatable from 0.3.0 with `tools/shots.sh before-after` (section 14.5, card #010).
- White Tally pins `v0.2.0` and removes its interim overrides of `_open_day()` and `_refresh()` in favour of
  `_practice_only()`. Done (White Tally design 7.1).

## 14. Release 0.3.0 (built)

Status: designed 2026-11-18 (board card #011), built 2026-11-18 (card #012), 764 checks; deviations in 14.10. Decision and alternatives: ADR 0007. Everything is new API
and backward compatible (new classes, two new screen hooks with defaults that keep today's behaviour), so the version
is MINOR. The release also contains board cards #008 (kit CI threshold) and #010 (screenshot comparison).

Users: White Sum and White Drift build their phase 1b on it. White Shift needs no change. White Tally may migrate in
optional steps (14.7); its puzzles stay byte-identical whatever it does.

### 14.1 Scope

| Item | Kit 0.3.0 | Stays in each game |
|---|---|---|
| Board view: layout, cell under a point, tile registry with stable ids, animation phases, shake and nudge, swipe, tap-tap and keyboard input | `WhiteTileView` (14.4) | Tile, block and link drawing (hooks); which move a gesture means (hooks); converting the game's traced step into view steps. |
| Safe area | `WhiteSafeArea` (14.3) and screen hook `_use_safe_area()` (14.2) | Whether to use it. |
| Maximum width of the screen column (desktop finding of the White Tally test) | Screen hook `_max_content_width()` (14.2) | The value (720 recommended). |
| Deterministic debug screenshots | Frozen clock in `--shot` mode (14.2) | - |
| Screenshot scenarios, comparison, before/after a kit update (#010) | `tools/shots.sh`, `tools/compare_shots.gd` (14.5) | `tools/shots.txt` (its scenarios). |
| CI | Screenshot step in `templates/ci.yml`; kit threshold 635, then the 0.3.0 count (#008, 14.6) | `MIN_CHECKS`. |
| State, cell names, move tokens, groups or runs, gravity or tilt, waves, traced step | - | The rules class (`TallyBoard`, `SumBoard`, `DriftBoard`). |
| Solver, beam, greedy, generator, measuring and verify tools | - | `sim/`, `tools/`. |

### 14.2 Screen changes (`WhiteDayScreen`)

New member `margin: MarginContainer`: the root margin container that `_build()` creates (in 0.2.0 a local variable).

New hooks (section 5.12 table):

```gdscript
func _max_content_width() -> int    # [0] = no limit; otherwise the column is at most this wide, centred
func _use_safe_area() -> bool       # [false]; true adds the display safe area to the margins
```

New internal functions:

```gdscript
func _insets_for(viewport_size: Vector2) -> Dictionary   # {"left", "top", "right", "bottom"} as ints; pure apart from hooks and _debug
func _apply_insets() -> void                             # sets the four margin_* constants of `margin` from _insets_for
```

`_insets_for(vp)`:

1. `ins` = `WhiteSafeArea.insets(vp, str(_debug.get("safe", "")))` when `_use_safe_area()`, else all four 0.0.
2. `left = WhiteTheme.MARGIN + int(ins.left)`, `top = WhiteTheme.MARGIN + int(ins.top)`,
   `right = WhiteTheme.MARGIN + int(ins.right)`, `bottom = WhiteTheme.MARGIN + int(ins.bottom)`.
3. When `_max_content_width() > 0`: `extra = maxi(0, (int(vp.x) - left - right - _max_content_width()) / 2)` (integer
   division, `@warning_ignore("integer_division")`); `left += extra`; `right += extra`.
4. Return the four values.

`_apply_insets()` calls `_insets_for(get_viewport_rect().size)` and sets `margin_left`, `margin_top`, `margin_right`,
`margin_bottom`. It is called once at the end of `_build()` and on every `get_viewport().size_changed` (connected in
`_build()`). The screen's root `Control` keeps its full-rect layout; only the margins change. With both hooks at their
defaults every margin is 24, as in 0.2.0.

`--safe=l,t,r,b` (viewport units, comma-separated) is parsed like any debug argument; it only has an effect when
`_use_safe_area()` is true. It replaces the measured safe area (White Tally's behaviour).

Frozen clock in debug shots: while `_debug.has("shot")`, `_elapsed()` returns `times[level]` without adding
`Time.get_ticks_msec() - _clock_from`. The clock still starts and stops as before (so `_store()` and `_stop_clock()`
are unchanged), but every clock text in a screenshot is the stored time: `0:00` in practice and on a fresh day.
Outside `--shot` nothing changes. Effect on existing games: a screenshot made with `--keys` shows `0:00` where 0.2.0
could show `0:01`.

Recommended for new games: `_max_content_width()` returns 720 (the design width of the series) and `_use_safe_area()`
returns true. With the project settings of the series (base size 720x1280, stretch `canvas_items`, aspect `expand`)
a 1280x720 desktop window has a viewport of about 2276x1280, so the column becomes a centred portrait column with the
board as large as on a phone.

### 14.3 WhiteSafeArea (`ui/safe_area.gd`)

Moved from White Tally's `ui/safe_area.gd` (`TallySafeArea`, with the window-relative fix for second monitors). The
`apply` function is not moved: the screen does that (14.2).

```gdscript
class_name WhiteSafeArea
static func insets(viewport_size: Vector2, override: String = "") -> Dictionary
	# {"left", "top", "right", "bottom"} as floats in viewport units
static func from_rects(safe: Rect2, win: Vector2, viewport_size: Vector2) -> Dictionary
static func parse(text: String) -> Dictionary
```

- `insets`: a non-empty `override` returns `parse(override)`. Otherwise `win = Vector2(DisplayServer.window_get_size())`;
  when `win.x <= 0` or `win.y <= 0`: all zero. `safe = Rect2(DisplayServer.get_display_safe_area())`; unless
  `OS.has_feature("web")`, `safe.position -= Vector2(DisplayServer.window_get_position())` (the safe area is in desktop
  coordinates; this makes it window-relative). Return `from_rects(safe, win, viewport_size)`.
- `from_rects`: when `safe.size.x <= 0` or `safe.size.y <= 0`: all zero. With `k = viewport_size / win`:
  `left = max(0, safe.position.x) * k.x`, `top = max(0, safe.position.y) * k.y`,
  `right = max(0, win.x - safe.end.x) * k.x`, `bottom = max(0, win.y - safe.end.y) * k.y`.
- `parse`: split on `,`; part `i` is `float(part)` when present, else 0.0 (Godot's `float()` of junk is 0.0); keys in
  the order left, top, right, bottom.

Acceptance:
- `from_rects(Rect2(10, 20, 380, 800), Vector2(400, 840), Vector2(800, 1680))` gives left 20, top 40, right 20,
  bottom 40.
- A safe rect larger than the window gives all zero; a safe rect equal to the window gives all zero; an empty safe rect
  gives all zero.
- `parse("40,80,40,60")` gives 40/80/40/60; `parse("1,2")` gives 1/2/0/0; `parse("a,b,c,d")` gives all zero.
- `insets(Vector2(720, 1280), "5,6,7,8")` returns the parsed override without reading the display.

### 14.4 WhiteTileView (`ui/tile_view.gd`)

`class_name WhiteTileView extends Control`. A board of `w x h` square cells with animated tiles. Generalised from White
Tally's `TallyBoardView` (design 10 there): the mechanics are the kit's, the look of a tile is the game's. Coordinates
follow assumption A11: cell index `i = y * w + x`, `x` to the right, `y` upwards, `(0, 0)` bottom-left; screen down is
direction `D`.

```gdscript
class_name WhiteTileView extends Control
enum Dir { R, L, D, U }                  # 0, 1, 2, 3
enum InputMode { CELL_MOVES, BOARD_SWIPES }

signal move_chosen(code: int)            # a game move code returned by a resolve hook (never -1)
signal finished()                        # an animation reached its end (normally or by finish_animation)

# Look and timing; defaults are White Tally's values. A game changes them in _init().
var board_color := Color("232933")
var grid_color := Color("2C333F")
var fit := 0.3                           # board margin in cells, added to w and h when sizing
var tile_gap := 0.08                     # gap between tiles, in cells
var tile_radius := 0.18                  # corner radius, in cells (board, tiles, marks)
var mark_color := WhiteTheme.ACCENT      # selection and cursor outline
var mark_px := 4.0
var vanish_time := 0.18
var vanish_pause := 0.06
var vanish_scale := 0.7
var shake_time := 0.15
var shake_cycles := 3
var shake_px := 4.0
var nudge_time := 0.15
var nudge_px := 6.0
var swipe_frac := 0.4                    # drag as part of a cell that fires a swipe during the drag
var swipe_min_px := 24.0                 # drag in px that still counts as a swipe on release

var input_mode := InputMode.CELL_MOVES
var input_enabled := true
var grid_w := 0
var grid_h := 0
var cell_px := 0.0                       # cell size of the last draw, for hooks (added in the build)
```

Public functions:

```gdscript
func show_cells(w: int, h: int, values: PackedByteArray) -> void  # new board, no animation; resets selection, grab and cursor
func show_values(values: PackedByteArray) -> void                 # same board, no animation; resets selection and grab, keeps cursor
func clear() -> void                                              # no board; nothing drawn; input ignored
func has_board() -> bool
func animate(steps: Array, before: PackedByteArray = PackedByteArray()) -> void
func finish_animation() -> void
func busy() -> bool                                               # an animation is running
func shown() -> PackedByteArray                                   # cell values after the current animation
func selected() -> int                                            # selected cell, -1 none
func cursor() -> int
func cursor_visible() -> bool
func debug_select(cell: int) -> void
func shake_cell(cell: int) -> void                                # shakes the tile in that cell; nothing when empty
func nudge(dir: int) -> void                                      # shifts the whole board a little towards dir and back
func key_move(event: InputEventKey) -> Variant                    # keyboard; returns a move code or null (below)

static func layout(area: Vector2, w: int, h: int, fit: float) -> Dictionary   # {"cell": float, "origin": Vector2}
static func cell_at(p: Vector2, lay: Dictionary, w: int, h: int) -> int        # -1 outside the board
static func drag_dir(d: Vector2) -> int                                        # dominant axis; ties go vertical; screen down is D
static func neighbour_dir(a: int, b: int, w: int) -> int                       # -1 when not orthogonal neighbours
static func key_dir(keycode: int) -> int                                       # arrows and WASD, else -1
static func step_cell(i: int, d: int, w: int, h: int) -> int                   # clamped at the edge
static func build_phases(w: int, ids: PackedInt32Array, steps: Array, vanish_total: float) -> Dictionary
	# {"phases": [...], "ids": PackedInt32Array}; pure, tested
```

The static helpers are White Tally's (`layout`, `cell_at`, `drag_dir`, `neighbour_dir`, `key_dir`, `step_cell`) with
`fit` as a parameter instead of a constant; their results are identical for `fit = 0.3`:
`cell = max(1, floor(min(area.x / (w + fit), area.y / (h + fit))))`, `origin = (area - Vector2(w, h) * cell) / 2`.

Hooks (games override; defaults in brackets):

| Hook | Purpose |
|---|---|
| `_is_tile(value: int) -> bool` | Which non-zero cell values are tiles (move, animate, can be selected). Others are static cells such as blocks. [`value != 0`] |
| `_resolve_cell_move(cell: int, dir: int) -> int` | `CELL_MOVES`: the game move code for "the tile in `cell` moves towards `dir`", or -1 when ignored. [-1] |
| `_resolve_board_swipe(dir: int) -> int` | `BOARD_SWIPES`: the game move code for a swipe or arrow key towards `dir`, or -1 when ignored. [-1] |
| `_draw_static(rect: Rect2, value: int) -> void` | Draw a static cell. [nothing] |
| `_draw_tile_body(rect: Rect2, value: int, alpha: float) -> void` | Draw a tile's body. [rounded square in `WhiteTheme.DIM` with `alpha`, radius `tile_radius`] |
| `_draw_links(tiles: Array) -> void` | Draw between tiles (White Tally: join bars). `tiles` is described below. [nothing] |
| `_draw_tile_face(rect: Rect2, value: int, alpha: float, scale: float) -> void` | Draw a tile's marks (pips, numerals, dots). [nothing] |

Steps (input of `animate`), each a Dictionary:

| Step | Fields | Phase |
|---|---|---|
| move | `"kind": "move"`, `"moves": [[from, to], ...]`, and either `"time"` (seconds) or `"speed"` (cells per second); optional `"ease"` (bool, default false) | All listed tiles move at once. Duration `time`, or `max(1.0, longest move) / speed`, where a move's length is the larger of its `abs(dx)` and `abs(dy)` in cells. Position `from.lerp(to, t)` with `t = sec / dur` clamped to 0..1; with `ease`: `t = 1 - (1 - t)^2`. |
| vanish | `"kind": "vanish"`, `"cells": [...]` | The tiles fade (alpha 1 to 0) and shrink (scale 1 to `vanish_scale`) over `vanish_time`, then stay invisible for `vanish_pause`; removed at the end. Duration `vanish_time + vanish_pause`. |

- Unknown kinds: `push_error` and skipped. A move whose `from` holds no tile: `push_error` and that move is skipped.
- Moves of one step are applied simultaneously to the id map: first every `from` cell is cleared, then every `to` cell
  gets the id that was at its `from`. A swap is `[[a, b], [b, a]]`.
- The values array behind `shown()` is updated in the same way (vanish sets the cells to 0). Static cells never move
  and are never part of a step.
- White Tally's phases map exactly: swap = move `[[a, b], [b, a]]`, `time` 0.12, `ease`; slide = move `[[from, to]]`,
  `time` 0.10, `ease`; fall = move with the fall pairs, `speed` 16.0; vanish = vanish. White Tally's `far` (largest
  `dy`, at least 1.0) is the same duration rule.

`build_phases(w, ids, steps, vanish_total)` turns steps into phases with the ids before the animation and returns the
phases plus the ids after it, exactly like White Tally's `build_phases` (`vanish_total` is `vanish_time +
vanish_pause`). A phase is `{"kind": "move" or "vanish", "dur": float, "ids": [...], "from": [Vector2...], "to":
[Vector2...], "ease": bool}`, positions in cells with `y` up.

Tile registry: each tile has a stable id from `show_cells`/`show_values` (the cell index it started in) with a value,
a position (`Vector2` in cells), a scale and an alpha. `animate(steps, before)`:

1. `finish_animation()`; selection cleared; grab released.
2. When `before` is not empty and differs from `shown()`: `show_values(before)` first.
3. `build_phases` from the current ids; the new ids and values become current at once (so `shown()` is the end state);
   the phases play over the following frames (`_process`), and `finished` is emitted after the last one.
4. Keyboard follow: when the move came from a keyboard grab (see input), the cursor moves to the cell that holds the
   grabbed tile's id after the animation; when that tile vanished, the cursor stays.

`finish_animation()` applies all remaining phases at their end, clears them, redraws and emits `finished` (only when an
animation was running). An empty `steps` list shows nothing new and emits nothing.

Drawing (`_draw`), nothing without a board. With `lay = layout(size, grid_w, grid_h, fit)`, `cell = lay.cell`,
`o = lay.origin + nudge offset`:

1. Board: a `StyleBoxFlat` in `board_color` with corner radius `int(cell * tile_radius)`, rect from
   `o - (rim, rim)` with size `grid + 2 * rim`, `rim = cell * 0.1`, `grid = Vector2(grid_w, grid_h) * cell`.
2. Grid lines in `grid_color`, width 2, between columns and between rows.
3. Static cells: `_draw_static(cell_rect(i), value)` in cell index order, where `cell_rect` is the cell's square shrunk
   by `tile_gap` (side `cell * (1 - tile_gap)`, centred).
4. Live tiles in ascending id order: `_draw_tile_body(rect, value, alpha)`, with `rect` centred on the tile position
   (screen centre `o + Vector2(pos.x + 0.5, grid_h - 1 - pos.y + 0.5) * cell`, plus the shake offset for a shaking
   tile: `sin(k * TAU * shake_cycles) * shake_px * (1 - k)` horizontally, `k = elapsed / shake_time`) and side
   `cell * (1 - tile_gap) * scale`.
5. `_draw_links(tiles)`, where `tiles` is an Array of Dictionaries in ascending id order with `"id"`, `"value"`,
   `"pos"` (cells), `"center"` (px), `"rect"`, `"scale"`, `"alpha"`, plus `"cell"` (px size of a cell) in every entry.
6. Live tiles again: `_draw_tile_face(rect, value, alpha, scale)`.
7. Marks: the selected cell as a solid outline (`mark_color`, `mark_px`, radius `int(cell * tile_radius)`, no fill)
   around `cell_rect`; the cursor, when visible and not equal to the selection, as a dashed outline (dash 10 px) on the
   same rect.

Nudge: during `nudge_time` after `nudge(dir)`, the board origin is offset by `unit(dir) * nudge_px * sin(PI * k)`,
`k = elapsed / nudge_time`, with `unit` in screen terms (R right, L left, U up, D down). Shake and nudge redraw every
frame while running and do not block input.

Input in `CELL_MOVES` (White Tally design 10.4, unchanged in behaviour):

- Ignored without a board, when `input_enabled` is false, and for any mouse button other than the left.
- Swipe: a press on a cell holding a tile, then a drag. During the drag the swipe fires as soon as the drag length
  reaches `swipe_frac * cell`; otherwise on release when the length is at least `swipe_min_px`. Direction:
  `drag_dir(d)`. A press outside the board or on an empty cell never swipes.
- Tap (a press that ends within `swipe_min_px`): no selection -> select the cell when it holds a tile; tap on the
  selected cell -> deselect; tap on an orthogonal neighbour (tile or empty) -> a cell move from the selected cell
  towards it, then deselect; tap on any other tile -> select it instead; tap on another empty cell or outside the
  board -> deselect.
- A cell move: `finish_animation()`; `code = _resolve_cell_move(cell, dir)`; when -1: `shake_cell(cell)` and nothing
  else; otherwise clear selection and grab and emit `move_chosen(code)`.
- Keyboard (`key_move`, called by the game from the screen's `_key_move`): the first arrow or WASD key only shows the
  cursor (at its current cell, initially 0) and returns null. Without a grab, arrows/WASD move the cursor
  (`step_cell`) and return null. Space or Enter (also keypad Enter) on a tile grabs it (shown as selected); on a grab
  it releases it; returns null. Esc releases the grab; returns null. With a grab, an arrow/WASD makes a cell move from
  the cursor: on -1 the tile shakes, the grab stays and null is returned; otherwise the grab is released, the follow
  id is remembered (step 4 of `animate`) and the code is returned (the screen then plays it; `move_chosen` is not
  emitted for keyboard moves).

Input in `BOARD_SWIPES`:

- A left press anywhere inside the view (on or off the board), then a drag: fires during the drag at
  `swipe_frac * cell`, or on release at `swipe_min_px`; direction `drag_dir(d)`. Taps do nothing. Then
  `finish_animation()`; `code = _resolve_board_swipe(dir)`; when -1: `nudge(dir)`; otherwise emit `move_chosen(code)`.
- Keyboard: arrows/WASD give `_resolve_board_swipe(dir)`: -1 -> `nudge(dir)` and null; otherwise the code. Space,
  Enter and Esc return null. No cursor, no selection.

The view does not know the rules beyond the two resolve hooks, does not keep the attempt, and never sets the screen's
`_replaying`. Touch input arrives as emulated mouse events (Godot's default `emulate_mouse_from_touch`), as in White
Tally.

### 14.5 Screenshot scenarios and comparison (#010)

A game lists its debug screenshot scenarios once, in `tools/shots.txt`; CI and the before/after comparison of a kit
update both read it.

Scenario file: one scenario per line, `<name> <W>x<H> [arguments...]`. Names match `[a-z0-9-]+` and are unique;
arguments are passed to the game after `--` (for example `--practice --level=1 --lang=en`). Empty lines and lines
starting with `#` are ignored. Example (White Tally's current CI shots):

```
easy 720x1280 --practice --level=0
medium 720x1280 --practice --level=1 --lang=en
hard 720x1280 --practice --level=2
selected 720x1280 --practice --level=1 --sel=0
solved 720x1280 --practice --level=0 --best
phone-safe-area 720x1280 --practice --level=1 --safe=40,80,40,60
desktop 1280x720 --practice --level=1
```

`tools/shots.sh` (bash, `set -euo pipefail`, executable bit committed):

```
shots.sh run <project dir> <scenario file> <out dir>
shots.sh compare <project dir> <dir a> <dir b> [<diff dir>]
shots.sh before-after <project dir> <scenario file> <old kit ref> [<new kit ref>]
```

- `run`: creates `<out dir>` (made absolute first), then per scenario
  `timeout 120 xvfb-run -a -s "-screen 0 1920x1440x24" godot --path <project dir> --rendering-driver opengl3
  --resolution <W>x<H> -- --shot=<out dir>/<name>.png <arguments>`. A malformed line prints
  `bad scenario line <n>` to stderr and counts as missing. Afterwards it prints `shot <name> ok` or
  `shot <name> missing` per scenario and exits 1 when any is missing, else 0. The virtual screen must be at least as
  large as the largest resolution; 1920x1440 is fixed, so scenarios wider than 1920 or taller than 1440 are rejected as
  bad lines. (A smaller virtual screen than the window would count as a safe-area inset in games that use it.)
- `compare`: runs `godot --headless --path <project dir> -s res://addons/white_kit/tools/compare_shots.gd -- --a=<abs
  a> --b=<abs b> [--diff=<abs diff>]` and returns its exit code.
- `before-after`: compares the game's screenshots under two kit versions without changing the game's own files.
  1. When not already running from a copy (environment variable `WHITE_SHOTS_COPY` unset): copy itself to a new
     `mktemp -d` folder and `exec` that copy with `WHITE_SHOTS_COPY=1` and the same arguments (the submodule checkout
     below replaces the script file while it runs).
  2. `kit=<project dir>/addons/white_kit`; fail with exit code 2 and `kit has local changes` when
     `git -C $kit status --porcelain` is not empty.
  3. `orig=$(git -C $kit rev-parse HEAD)`; `new=<new kit ref>` or `$orig` when omitted. A trap restores
     `git -C $kit checkout --quiet $orig` on every exit.
  4. Check out `<old kit ref>`; `godot --headless --path <project dir> --import`; `run` into
     `<project dir>/build/shots/before`.
  5. Check out `$new`; import; `run` into `<project dir>/build/shots/after`.
  6. While `$new` is checked out: `compare` the two folders with diff folder `<project dir>/build/shots/diff`; its exit
     code is the script's exit code. The new ref must therefore be 0.3.0 or later (it contains the comparison tool);
     the old ref may be any tag that has the screen's `--shot` mode (0.1.0 or later).
  7. The trap restores the original kit commit. The game's `build/` is ignored by git, so the worktree stays clean.

`tools/compare_shots.gd` (`extends SceneTree`, no `class_name`), arguments `--a=<dir> --b=<dir> [--diff=<dir>]`:

- Missing `--a` or `--b`, or a folder that cannot be opened: usage line or `cannot open <dir>` on stderr, exit code 2.
- The names are the sorted union of `*.png` files in both folders. Per name, one line:
  - only in one folder: `missing <name> in a` or `missing <name> in b`;
  - both present but either does not load (`Image.load_from_file` not `OK`): `unreadable <name>`;
  - different sizes: `differs <name> size <wa>x<ha> <wb>x<hb>`;
  - same size: both converted to `Image.FORMAT_RGBA8`; when `get_data()` is equal: `same <name>`; otherwise count the
    pixels whose four bytes differ and their bounding box: `differs <name> <n> pixels box <x>,<y>,<w>,<h>`.
- With `--diff`: for every name that `differs` with the same size, write `<diff>/<name>.png`: every pixel of `a` as
  grey (`0.5 * luminance`, alpha 1) and every differing pixel pure red (`#FF0000`).
- Last line `shots: <same> same, <other> different`; exit code 0 when every name is `same`, else 1.

The bounding box makes "only the clock differs" or "only the column moved" visible without opening images.

### 14.6 CI and thresholds (#008)

- First commit of the 0.3.0 work: kit CI `--min-checks=635` (the count on `develop` since commit 896e395). From then
  on the rule of 13.4 applies: every commit that adds kit checks raises the kit CI threshold to the new count.
- `templates/ci.yml` gets `--min-checks=<count at v0.3.0>` in the tag commit, and a screenshot step after the game
  tests:

```yaml
      - name: Debug screenshots (tools/shots.txt)
        if: hashFiles('tools/shots.txt') != ''
        run: |
          sudo apt-get install -y -qq xvfb libgl1-mesa-dri >/dev/null
          addons/white_kit/tools/shots.sh run . tools/shots.txt build/shots

      - uses: actions/upload-artifact@v7
        if: always() && hashFiles('tools/shots.txt') != ''
        with:
          name: shots
          path: build/shots
          retention-days: 7
```

- Host template (`templates/host/project.godot`): `run/main_scene="res://addons/white_kit/tests/fixtures/fixture_main.tscn"`,
  viewport 720x1280, stretch mode `canvas_items`, aspect `expand` (the series' settings), so the fixture screen can be
  shot like a game.
- Kit CI, new last step "Screenshot tool smoke test": install `xvfb libgl1-mesa-dri`; `tools/shots.sh run host
  host/addons/white_kit/tests/fixtures/shots.txt build/a`; the same into `build/b`; `tools/shots.sh compare host build/a
  build/b` must exit 0 (determinism, A12). The fixture `shots.txt` has two scenarios: `tiles 720x1280 --practice` and
  `wide 1600x900 --practice`.
- The determinism grep stays on `core/` and `tools/`; `ui/tile_view.gd` uses no randomness.

### 14.7 Migration

White Shift: nothing to do. With the hooks at their defaults its screen is pixel-identical; its debug screenshots
without `--keys` stay identical, with `--keys` only the clock may change (14.2). Updating its pin is a normal kit update
(section 8); optionally it adds a `tools/shots.txt` with the scenarios of section 10.

White Tally (optional, one card, each step one commit, tests green after each):

| Step | Change | Check |
|---|---|---|
| 1 | Pin `v0.3.0`; kit threshold from the new template. | Game tests green; `git diff <before>..HEAD -- sim data tools` empty (puzzles byte-identical by construction). |
| 2 | Add `tools/shots.txt` with its seven CI scenarios (14.5 example) and replace the CI screenshot step by the template's. | `shots.sh before-after . tools/shots.txt v0.2.0 v0.3.0`: all `same`. |
| 3 | Remove `ui/safe_area.gd` and `_apply_safe_area`; `_use_safe_area()` returns true; `_max_content_width()` returns 720. Tests that used `TallySafeArea` use `WhiteSafeArea`. | Shots: `desktop` differs (intended: centred column); the 720x1280 shots and `phone-safe-area` are `same`. |
| 4 | `TallyBoardView extends WhiteTileView`: keeps its colours and pips (`_draw_tile_body`, `_draw_tile_face`), joins (`_draw_links`), `_resolve_cell_move` = `board.canonical(shown(), cell * 4 + dir)`; `update_attempt` converts `step_traced` to view steps (mapping in 14.4); its pure helper tests call the kit statics. | Shots compared with step 3: all `same`. |

White Tally's own design and ADRs are updated in its repository when it takes these steps. Nothing in this release
forces them.

White Sum and White Drift: pin `v0.2.0` during their phase 1a (rules, solver, generator, pool; no screen), and `v0.3.0`
from their phase 1b (their designs, section 14).

### 14.8 Tests and acceptance

New fixtures (`tests/fixtures/`, no `class_name`):

- `tile_view_fixture.gd`: a `WhiteTileView` subclass. Values: 0 empty, 1 static block, 2 and 3 tiles. `_is_tile(v)` is
  `v >= 2`. `_resolve_cell_move(cell, dir)`: the target cell in that direction must be on the board and not a block;
  when it holds a tile of another value: code `cell * 4 + dir`; when empty: code `cell * 4 + dir`; otherwise -1.
  `_resolve_board_swipe(dir)`: returns `dir` when member `board_moves` is true, else -1. Records every hook call in a
  member list so tests can inspect drawing order.
- `fixture_screen.gd` gets member flags `max_width` (int, returned by `_max_content_width()`) and `safe_area` (bool,
  returned by `_use_safe_area()`), default 0 and false.
- `fixture_main.tscn`: root `Control` (full rect) with `fixture_screen.gd`, whose `_make_view()` returns a
  `tile_view_fixture` showing a fixed 4x3 board, for the screenshot smoke test.
- `shots.txt`: the two scenarios of 14.6.

New suites: `test_safe_area.gd`, `test_tile_view.gd`, `test_shots.gd`, `test_release_030.gd`.

Acceptance (every item is a check):

- Screen (14.2): with default hooks `_insets_for(Vector2(720, 1280))` and `_insets_for(Vector2(2400, 1080))` are 24 on
  every side; with `max_width` 720: `_insets_for(Vector2(2276, 1280))` gives left and right
  `24 + (2276 - 48 - 720) / 2 = 778`, top and bottom 24, and `_insets_for(Vector2(720, 1280))` gives 24; with
  `safe_area` and `_debug.safe = "40,80,40,60"`: 64/104/64/84; with both: left `64 + (vp.x - 128 - 720) / 2`. After
  `_ready` the margins of `margin` equal `_insets_for(get_viewport_rect().size)`. All screen tests of 0.1.0 and 0.2.0
  pass unchanged.
- Frozen clock: on the fixture screen with `_debug.shot` set, after a move and a wait of at least 1.2 s, the clock text
  is `0:00`; without `shot` it is `0:01` or more.
- `WhiteSafeArea`: section 14.3.
- `WhiteTileView` statics: White Tally's helper tests (layout, `cell_at` at the four board corners and just outside,
  `drag_dir` including the diagonal tie going vertical, `neighbour_dir`, `key_dir`, `step_cell` at the edges) pass
  against the kit statics with `fit = 0.3`.
- `build_phases`: a swap `[[a, b], [b, a]]` exchanges the two ids; a move to an empty cell leaves `-1` at the source;
  a fall step with distances 1 and 3 at speed 16 has duration `3 / 16`; a move with distance 0.5 at speed 16 has
  duration `1 / 16`; a `time` step has exactly that duration; vanish removes the ids and lasts
  `vanish_time + vanish_pause`; an unknown kind is skipped with a `push_error`; White Tally's
  `build_phases` test cases give the same phases after mapping (14.4).
- `animate`: `shown()` equals the end state at once; `busy()` is true until the phases are done; `finish_animation()`
  ends it, emits `finished` once and leaves `busy()` false; `animate` with a `before` that differs from `shown()` first
  shows `before`; static cells keep their place through every step.
- Drawing order (fixture records): static cells, bodies, links once, faces, in ascending id order; nothing is drawn
  without a board.
- `CELL_MOVES` input (simulated with `InputEventMouseButton`/`InputEventMouseMotion` passed to `_gui_input`): a drag of
  `0.4 * cell` on a tile fires during the motion; 23 px then release is a tap, 24 px a swipe; a press on an empty cell
  never swipes; tap-tap on a neighbour emits `move_chosen` with the fixture code; an ignored cell move (towards a
  block) shakes and emits nothing; the right mouse button does nothing; with `input_enabled` false nothing happens.
- Keyboard in `CELL_MOVES`: first arrow only shows the cursor; arrows move it and clamp at the edge; Space grabs a tile
  and not an empty cell; an arrow with a grab returns the code; an ignored move keeps the grab; after `animate` the
  cursor follows the grabbed tile; Esc releases.
- `BOARD_SWIPES`: a drag anywhere in the view, also outside the board, emits `move_chosen(dir)` when `board_moves` is
  true; with `board_moves` false it nudges and emits nothing; arrows return the code or null; taps and Space do nothing.
- Screenshot tools (child processes like `test_precompute.gd`; PNGs written to `user://white_kit_test_shots_*` with
  `Image.save_png`): two equal folders give exit 0 and `same` lines; one changed pixel gives exit 1 and
  `differs <name> 1 pixels box x,y,1,1`; a size difference, a missing file in either folder and an unreadable file are
  reported as specified; the diff image has the red pixel at the changed position; missing `--a` gives exit 2.
- `tools/shots.sh`: kit CI smoke test of 14.6 green; a malformed scenario line gives exit 1 with `bad scenario line`.
- White Shift on 0.3.0: its 192 checks green, kit tests green inside it, its seven screenshots compared with
  `before-after` against `v0.2.0` are `same` (with `--keys` only a clock box may differ).
- Kit CI green on the branch and on the tag `v0.3.0`; the template threshold equals the tag's check count.

### 14.9 Build order and release

1. Kit CI threshold to 635 (#008).
2. `WhiteSafeArea`, screen hooks, `margin` member, frozen shot clock, with tests.
3. `WhiteTileView` with the fixture and tests.
4. `tools/compare_shots.gd`, `tools/shots.sh`, host template, fixture main scene and `shots.txt`, kit CI smoke test
   (#010).
5. `templates/ci.yml` screenshot step; README (WhiteTileView, safe area, shots); `CHANGELOG.md` section `0.3.0` (new
   classes and hooks, frozen shot clock, shots tooling, thresholds 635 and the tag count); `VERSION` and
   `WhiteKit.VERSION` `0.3.0`; template threshold to the final count; tag `v0.3.0`.
6. White Shift check (14.8, last items) before telling the games the tag exists.

Where the tag sits follows section 8: on the commit merged to `main` when the `develop` -> `main` pull request exists;
otherwise on `develop` as for `v0.1.0` and `v0.2.0` (the same merge-commit rule then applies).

### 14.10 As built (deviations)

- `WhiteTileView.cell_px`: public member with the cell size in px of the last draw. The default `_draw_tile_body` needs
  it for the corner radius, and game hooks need it for sizes (pips, join width); the hook signatures give only a rect.
- `_apply_insets()` sets the margins as theme constant overrides on `margin` (`margin_left` and so on); the acceptance
  check reads them with `get_theme_constant`.
- Retest B7 of 0.2.0 asked that the template threshold equals the kit CI threshold. The kit CI threshold now rises
  with every commit that adds checks, while the template names the count of the tagged release, so the test checks
  `template <= kit CI`. At a tag both are equal (764).
- A `vanish` step with a cell that holds no tile is skipped silently for that cell (no error); a `move` from an empty
  cell is an error as specified.
- `shots.sh`: a scenario file that cannot be read exits 2 (`cannot read <file>`); a duplicate scenario name is a bad
  line; scenario and project paths are relative to the current directory.
- `before-after` against `v0.2.0` on White Shift (seven scenarios): six `same`; `--keys` differs only in the clock box
  (`keys.png 192 pixels box 682,235,13,18`), as announced in 14.2.
