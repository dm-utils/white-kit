# 0005 Test runner counts script errors as failures

Status: accepted (2026-11-17), built in 0.2.0

## Context

`WhiteTestRunner` (design section 5.13) counts only explicit `check(ok, what)` calls. When a GDScript runtime error
occurs inside a test function (for example a call on `null`, a wrong type, an invalid index), Godot aborts that
function and its caller continues. The checks after the error never run, nothing is counted as failed, and the run can
end with `0 failed` and exit code 0. This was seen while building 0.1.0. The only guard is `--min-checks=N`, which
catches the problem only when enough checks are lost (kit CI 250 of 258, White Shift 177 of 177).

The same runner is used by every game, so a fix in the kit protects all of them.

Godot 4.5 and later (the series pins 4.7.2) offers `Logger`: an object registered with `OS.add_logger` receives every
engine and script error with its type. GDScript runtime errors arrive as `ERROR_TYPE_SCRIPT`; `push_error` arrives as
`ERROR_TYPE_ERROR` (assumption A10 in the design).

## Decision

During `_run()` the runner registers a `Logger` (inner class, no `class_name`) that collects every error of type
`ERROR_TYPE_SCRIPT`. After `_run()` it removes the logger and counts each collected error as a failed check, printed as
`FAIL: script error: <file>:<line> <message>`. `push_error`, warnings and shader errors are not counted. The summary
line and exit code contract stay the same; `--min-checks` stays as a second guard. Specification and acceptance:
design sections 5.13 and 13.2.

## Alternatives considered

- Keep `--min-checks` only: no code change, but it misses a lost check whenever the threshold is below the real count,
  and every game must keep its threshold exactly equal to its check count to be safe. Rejected as the only guard.
- A completion marker per suite (`completed = true` as the last statement, checked by the runner): simple and
  engine-independent, but an error inside a helper function aborts only the helper; the suite's `run` still reaches its
  marker. Catches only errors directly in `run`. Rejected.
- Each suite declares its expected number of checks: catches every loss, but the numbers must be maintained by hand at
  every test change and are often wrong. Rejected.
- Fail CI on `SCRIPT ERROR` in the test output (a `grep` in the workflow): engine-independent, but only in CI, not in
  local runs or the game's own scripts, and it depends on the text format of engine output. Kept as the fallback if
  assumption A10 turned out to be wrong; not needed (see below).
- Count every engine error (`ERROR_TYPE_ERROR` too) and let tests mark expected errors: strictest, but the kit tests
  deliberately trigger many `push_error` calls (unimplemented hooks, invalid RNG ranges, invalid dates, unknown text
  keys), each of which would need wrapping. Rejected for now; can be added later as an opt-in.

## Consequences

- A runtime error in any test now fails the run, locally and in CI, in the kit and in every game, with the file and
  line in the output.
- Tests that pass today only because a script error silently skipped their remaining checks will fail after the
  update. That is intended; such a failure is a test or code finding in the game, not a reason to weaken the runner.
- The runner depends on `Logger`, so the series cannot go below Godot 4.5. The kit pins 4.7.2 already.
- The behaviour of `push_error` in tests is unchanged.
- This is part of 0.2.0 together with the practice-only hook (ADR 0004, amendment 2).

## Outcome (0.2.0, 2026-11-17)

- Assumption A10 holds: the fixture `runner_script_error` (call on `null`) is counted, `runner_push_error` is not.
  The fallback was not needed.
- A parse error in a script compiled during the run also arrives as `ERROR_TYPE_SCRIPT` and fails the run
  (`runner_parse_error`); a script error after an `await` and several errors in one run are each counted
  (`runner_await_error`).
- Added in the same change: `--min-checks` with a value that is not a non-negative integer fails the run before any
  test runs, instead of silently disabling the guard. The thresholds were raised to the real check count (522 at tag
  `v0.2.0`, design 13.4).
- No hidden script errors surfaced in the kit tests or in White Shift's 192 checks.
