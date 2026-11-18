# Conventions

How code, tests, releases and branches are handled in this repository. The design is in `docs/design.md`; decisions
are in `docs/adr/`.

## Engine and layout

- Godot 4.7.2, GDScript only. The version is pinned for the whole series in `ci/setup-godot/action.yml`. The test
  runner needs Godot 4.5 or later from kit 0.2.0 on (ADR 0005).
- The repository root is the addon root, installed in games at `res://addons/white_kit/` (fixed path). There is no
  `project.godot` and no `plugin.cfg` in the repository.

| Folder | Content |
|---|---|
| `core/` | Day, seed, random generator, puzzle store, rules interface, attempt, progress file, texts, formatting. No scenes, no nodes, no input, no rendering. Only `WhiteProgress` touches `user://`, and only the path it is given. |
| `ui/` | Theme, widget factory and the shared day screen. Depends on `core/`, never the other way round. |
| `tools/` | Headless scripts (`extends SceneTree`): the precompute skeleton, the reference vector printer, the local host script and the Python reference. |
| `tests/` | Kit test runner, suites and fixtures. Excluded from every game's export. |
| `ci/` | Composite GitHub Actions used by games and by the kit's own CI. Has a `.gdignore`. |
| `templates/` | Game workflow template and the host project for the kit's tests. Has a `.gdignore`. |
| `docs/` | Design, conventions, glossary, ADRs. Has a `.gdignore`. |
| `build/` | Local output (host project). Ignored by git. |

- Godot's `.uid` files (`<script>.gd.uid`) are committed next to their script. Run `tools/kit_host.sh` (which imports)
  before committing a new or renamed script, so its `.uid` exists and is committed in the same commit. Without them a
  game's first import writes them into the submodule, which then shows as modified.

## Licence

- There is no licence file: all rights are reserved, as stated in the README. Do not add a `LICENSE` file or licence
  headers, and do not copy third-party code into the kit (published algorithms such as xoshiro128** and FNV-1a are
  implemented from their specification).

## GDScript style

- Godot style guide: tabs for indentation, `snake_case` for functions and variables, `PascalCase` for classes and
  enums, `UPPER_CASE` for constants and enum values. Lines within 120 characters.
- Static typing everywhere: typed parameters and return types, `:=` for inferred locals, typed arrays where practical.
- Every global class has a `class_name` with the prefix `White` (`WhiteDaily`, `WhiteRng`, ...). File names are the
  class name without the prefix in `snake_case` (`core/daily.gd`).
- Members and functions internal to a class start with `_`. Virtual hooks that games override also start with `_` and
  are listed in the design; nothing else with `_` may be called from a game. Kit tests may call internal functions
  (for example `WhitePrecompute._run`).
- A game reacts to screen events through the screen's signals (`level_shown`, `attempt_solved`, `progress_saved`,
  `refreshed`) or hooks, never by overriding internal functions such as `_refresh` or `_open_day`.
- Classes in `core/` extend `RefCounted` and mostly expose static functions; `WhiteAttempt`, `WhiteRng` and
  `WhitePuzzleStore` are instances.
- Kit code compiles without warnings under Godot's default warning settings (the host project uses the defaults).
  Intended integer divisions carry `@warning_ignore("integer_division")`.
- Kit code produces no engine error output on expected input, including invalid user input that it rejects (for
  example `WhiteDaily` checks the date parts itself before calling `Time`). `push_error` is only for programming
  errors: an unimplemented hook, an impossible `range_int` range, an invalid date passed to `WhiteDaily.number` or
  `add_days`.
- A public function that rejects invalid input returns a defined value together with its `push_error` (ADR 0006): the
  first argument (`range_int`), 0 (`number`) or the input unchanged (`add_days`). When that value is also a valid
  result, the documentation says so and names the check a caller uses first (`WhiteDaily.is_date`).
- Documentation comments use `##` on the class and on public functions; ordinary comments use `#`. All comments and
  identifiers are in English.
- The kit contains no game-specific code, names or texts. Default texts are generic and exist in Dutch and English with
  the same keys. Optional keys that the screen reads only when a game defines them (`count_final`) are not in the
  defaults.
- Test and fixture scripts declare no `class_name`; they are loaded with `preload` or by path. The single exception is
  `WhiteTestRunner` (`tests/test_runner.gd`), which games extend.
- No credentials, keys or personal data in the repository.

## Determinism

- `core/` and `tools/` never use `RandomNumberGenerator` or the global random functions (`randi`, `randf`,
  `randomize`, `seed`); CI greps for them. Reproducible randomness comes only from `WhiteRng`.
- In `WhiteSeed` and `WhiteRng`, every intermediate value stays within int64 without overflow: 32-bit words are kept
  non-negative and masked with `0xFFFFFFFF`; 32 x 32-bit products are split into 16-bit halves; no left shift may reach
  the sign bit. Arguments from the caller that could overflow (a `range_int` span) are checked first.
- The output of `WhiteSeed` and `WhiteRng` for a given seed is frozen. Changing it is a MAJOR version, and the reference
  vectors in `tests/test_rng.gd` and `tools/reference/white_rng.py` change in the same commit.
- Rules code (in games) is deterministic and integer-based; the kit never compares states itself.
- Published puzzle data is never regenerated; new days are added with the precompute tool's `--merge`, which refuses to
  change an existing key.
- Puzzle data uses JSON integers for whole numbers and strings for integers of 2^53 or more; the merge turns whole
  floats back into integers (design 5.14).

## Records and saved data

- Record grammar: `z` undo, `r` restart, other lower-case letters reserved for the kit, move tokens of fixed width from
  `[A-Z0-9]` defined by the game. New kit actions get a new lower-case letter; the meaning of a letter never changes.
- The progress file format is stable; a change that old files cannot be read with is a MAJOR version and needs a
  migration in `WhiteProgress.sanitize`.

## Tests

- Run the kit tests locally with the host project (the script imports first):

```bash
tools/kit_host.sh            # creates build/host, imports, runs res://addons/white_kit/tests/run_kit_tests.tscn
```

- The runner prints `tests: N passed, M failed` and exits with code 1 on any failure. `--min-checks=N` makes it fail
  when fewer checks ran; a value that is not a non-negative integer fails the run before any test runs.
- Thresholds: kit CI (`.github/workflows/ci.yml`) and the game template (`templates/ci.yml`) use `--min-checks=522`,
  the check count of tag `v0.2.0`. A commit that adds kit checks raises the kit CI threshold to the new count in the
  same commit; the template follows at the next tag, because a game runs the kit tests of the tag it pins. The
  threshold is only lowered when checks are removed on purpose, with a changelog note. Check counts per moment:
  design 13.4.
- A GDScript runtime error or parse error during a run counts as a failed check (`FAIL: script error: ...`, ADR 0005);
  `push_error` does not. A test may therefore call kit functions that `push_error` on purpose, and a script error in a
  test is a finding, never something to work around in the runner.
- `check(ok, what)`: `what` describes the expected behaviour in plain words, so a failure message explains itself.
- Every public function and every screen hook and signal has at least one test; every acceptance criterion in the
  design has a test.
- Behaviour that depends on a process exit code or on command-line output (the precompute tool, the runner itself,
  engine output of rejected input) is tested in a child Godot process (`OS.execute(OS.get_executable_path(), ...)`),
  not by calling `quit`.
- Tests that write files use names under `user://` starting with `white_kit_test_` and delete them afterwards; they
  never touch `user://progress.json`, because the kit tests also run inside games.
- Reference vectors: CI compares `tools/rng_vectors.gd` with `tools/reference/white_rng.py` line by line.

## Branches and releases

- `develop` is the working branch; `main` is protected and updated through pull requests only; CI runs on pushes to
  both, on pull requests to `main` and on tags. This is the same model as the games.
- Semantic versions in `VERSION` and `WhiteKit.VERSION` (always equal; a test checks this). `CHANGELOG.md` has a
  section per version, newest first, with breaking changes marked. A new hook or signal is a MINOR version.
- A release is tagged `v<VERSION>` on the commit merged to `main`; CI on the tag checks that the tag matches
  `VERSION`. `v0.1.0` and `v0.2.0` sit on `develop` commits; the pull request that brings them to `main` is therefore a
  merge commit (no squash, no rebase). Tags are never moved.
- Games pin a tag; their CI rejects any other submodule commit.
- Branch names: `feature/<description>`, `fix/<description>`, `chore/<description>`.
- Commit messages in English, imperative, short subject line.
- CI must be green before merging to `main` and before tagging.

## Using the kit in a game

```bash
git submodule add https://github.com/dm-utils/white-kit.git addons/white_kit
git -C addons/white_kit checkout v0.2.0
git add .gitmodules addons/white_kit
```

- Clone a game with `git clone --recurse-submodules`, or run `git submodule update --init` after a plain clone.
- Export preset: add `addons/white_kit/tests/*,addons/white_kit/tools/*` to `exclude_filter`.
- CI: copy `templates/ci.yml` to `.github/workflows/ci.yml` and set `MIN_CHECKS` to the game's own check count.
- Update: `git -C addons/white_kit fetch --tags && git -C addons/white_kit checkout v<new>`, take the kit threshold
  from the new `templates/ci.yml`, run the game tests, commit `chore: update White Kit to v<new>`.
- Untrusted dates (arguments, files) are checked with `WhiteDaily.is_date` before `number` or `add_days`.
