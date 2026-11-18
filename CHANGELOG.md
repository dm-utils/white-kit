# Changelog

## 0.3.0

All additions are backward compatible; a game that overrides nothing new behaves as with 0.2.0 (ADR 0007).

- `WhiteTileView` (`ui/tile_view.gd`): board view base class. Layout, tile registry with stable ids, phase animation
  from generic `move` and `vanish` steps (`animate`, `finish_animation`, `busy`, `shown`), shake and nudge, input in two
  modes (`CELL_MOVES`: swipe, tap-tap, keyboard grab; `BOARD_SWIPES`: swipe anywhere or arrows). Games override
  `_is_tile`, `_resolve_cell_move`, `_resolve_board_swipe`, `_draw_static`, `_draw_tile_body`, `_draw_links` and
  `_draw_tile_face`; look and timing are members with White Tally's values as defaults.
- `WhiteSafeArea` (`ui/safe_area.gd`): insets of the display safe area, window-relative, with `--safe=l,t,r,b` override.
- `WhiteDayScreen`: member `margin`, hooks `_max_content_width()` (default 0, no limit) and `_use_safe_area()` (default
  false), `_insets_for()` and `_apply_insets()`; margins follow viewport size changes.
- `WhiteDayScreen`: the clock text is frozen at the stored time in `--shot` mode, so screenshots are deterministic
  (a `--keys` shot shows `0:00` where 0.2.0 could show `0:01`).
- `tools/shots.sh` (`run`, `compare`, `before-after`) and `tools/compare_shots.gd`: debug screenshots from a scenario
  file per game (`tools/shots.txt`), pixel comparison with a diff image, and screenshots before and after a kit update.
- `templates/ci.yml`: screenshot step and artifact when the game has `tools/shots.txt`. The host template has a main
  scene and the series display settings.
- Kit CI: screenshot tool smoke test, `--min-checks` raised to 635 and then to the 0.3.0 count; the template threshold
  equals the count at this tag.

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
