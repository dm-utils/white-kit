# Conventions

How code, tests, releases and branches are handled in this repository. The design is in `docs/design.md`; decisions
are in `docs/adr/`.

## Engine and layout

- Godot 4.7.2, GDScript only. The version is pinned for the whole series in `ci/setup-godot/action.yml`.
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
  are listed in the design; nothing else with `_` may be called from a game.
- Classes in `core/` extend `RefCounted` and mostly expose static functions; `WhiteAttempt`, `WhiteRng` and
  `WhitePuzzleStore` are instances.
- Kit code compiles without warnings under Godot's default warning settings (the host project uses the defaults).
  Intended integer divisions carry `@warning_ignore("integer_division")`.
- Documentation comments use `##` on the class and on public functions; ordinary comments use `#`. All comments and
  identifiers are in English.
- The kit contains no game-specific code, names or texts. Default texts are generic and exist in Dutch and English with
  the same keys. Optional keys that the screen reads only when a game defines them (`count_final`) are not in the
  defaults.
- Test and fixture scripts declare no `class_name`; they are loaded with `preload`. The single exception is
  `WhiteTestRunner` (`tests/test_runner.gd`), which games extend.
- No credentials, keys or personal data in the repository.

## Determinism

- `core/` and `tools/` never use `RandomNumberGenerator` or the global random functions (`randi`, `randf`,
  `randomize`, `seed`); CI greps for them. Reproducible randomness comes only from `WhiteRng`.
- In `WhiteSeed` and `WhiteRng`, every intermediate value stays within int64 without overflow: 32-bit words are kept
  non-negative and masked with `0xFFFFFFFF`; 32 x 32-bit products are split into 16-bit halves; no left shift may reach
  the sign bit.
- The output of `WhiteSeed` and `WhiteRng` for a given seed is frozen. Changing it is a MAJOR version, and the reference
  vectors in `tests/test_rng.gd` and `tools/reference/white_rng.py` change in the same commit.
- Rules code (in games) is deterministic and integer-based; the kit never compares states itself.
- Published puzzle data is never regenerated; new days are added with the precompute tool's `--merge`, which refuses to
  change an existing key.

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

- The runner prints `tests: N passed, M failed` and exits with code 1 on any failure; `--min-checks=N` makes it fail
  when fewer checks ran.
- `check(ok, what)`: `what` describes the expected behaviour in plain words, so a failure message explains itself.
- Every public function and every screen hook has at least one test; every acceptance criterion in the design has a
  test.
- Tests that write files use names under `user://` starting with `white_kit_test_` and delete them afterwards; they
  never touch `user://progress.json`, because the kit tests also run inside games.
- Reference vectors: CI compares `tools/rng_vectors.gd` with `tools/reference/white_rng.py` line by line.

## Branches and releases

- `develop` is the working branch; `main` is protected and updated through pull requests only; CI runs on pushes to
  both, on pull requests to `main` and on tags. This is the same model as the games.
- Semantic versions in `VERSION` and `WhiteKit.VERSION` (always equal; a test checks this). `CHANGELOG.md` has a
  section per version, newest first, with breaking changes marked.
- A release is a commit on `main` tagged `v<VERSION>`; CI on the tag checks that the tag matches `VERSION`.
- Games pin a tag; their CI rejects any other submodule commit.
- Branch names: `feature/<description>`, `fix/<description>`, `chore/<description>`.
- Commit messages in English, imperative, short subject line.
- CI must be green before merging to `main` and before tagging.

## Using the kit in a game

```bash
git submodule add https://github.com/dm-utils/white-kit.git addons/white_kit
git -C addons/white_kit checkout v0.1.0
git add .gitmodules addons/white_kit
```

- Clone a game with `git clone --recurse-submodules`, or run `git submodule update --init` after a plain clone.
- Export preset: add `addons/white_kit/tests/*,addons/white_kit/tools/*` to `exclude_filter`.
- CI: copy `templates/ci.yml` to `.github/workflows/ci.yml`.
- Update: `git -C addons/white_kit fetch --tags && git -C addons/white_kit checkout v<new>`, run the game tests, commit
  `chore: update White Kit to v<new>`.
