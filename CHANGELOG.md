# Changelog

## 0.2.0

- `WhiteDayScreen`: hook `_practice_only() -> bool` (default false). When true the screen opens practice, hides the
  mode button and ignores `_toggle_mode()` (ADR 0004, amendment 2).
- `WhiteTestRunner`: GDScript script errors and parse errors during `_run()` count as failed checks, printed as
  `FAIL: script error: <file>:<line> <message>` (ADR 0005). `push_error` is not counted. `--min-checks` with a value
  that is not a non-negative integer now fails the run.
- `WhiteRng.range_int`: a range whose span overflows int64 is a bad range (`push_error`, returns `from`, draws
  nothing) instead of hanging or dividing by zero. Output for valid ranges is unchanged.
- `WhiteDaily.number` and `add_days`: an invalid date gives `push_error` and a defined result (`number` 0,
  `add_days` the date unchanged) instead of an engine error and a bogus value. Valid dates are unchanged.
- Documented 0.1.0 behaviour: signal `refreshed`, `WhiteDaily.is_date`, precompute merge details.
- Kit CI and `templates/ci.yml`: `--min-checks` raised to 522.

## 0.1.0

First release: `WhiteDaily`, `WhiteSeed`, `WhiteRng`, `WhitePuzzleStore`, `WhiteRules`, `WhiteAttempt` (two count
modes), `WhiteProgress`, `WhiteText`, `WhiteFormat`, `WhiteTheme`, `WhiteUi`, `WhiteDayScreen`, `WhiteTestRunner`,
`WhitePrecompute`, the composite action `ci/setup-godot` and the game workflow template.

`WhiteSeed` and `WhiteRng` output is frozen from this version on; see `docs/design.md` section 8.
