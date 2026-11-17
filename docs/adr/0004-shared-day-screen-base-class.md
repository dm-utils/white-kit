# 0004 Shared day screen as a base class with hooks

Status: accepted (2026-11-17)

## Context

White Shift's `ui/main.gd` holds the whole screen: title with mode and language buttons, subtitle with the puzzle
number, three level tabs, counter, par and clock, the board, a message line and the buttons (Undo, Restart, Best route,
Share, Next). It also holds the screen flow: opening a day by replaying saved records, choosing the first unsolved
level, the per-level clock, saving after every action, practice sets, the language toggle and a debug screenshot mode.
Only a small part is specific to White Shift: the board view, key mapping, the best-route animation and the texts.

White Tally has the same structure (three daily levels, practice, counter, par, clock, undo, restart, share). It also
needs its own message during play (for example when no move is left) and may want a different counter label in
practice. White Shift's UI tests use the screen's member variables and functions directly (`attempts`, `level`,
`times`, `_save`, `_open_day`, `_on_undo`, ...), and its migration must not change behaviour.

## Decision

- The kit provides `WhiteDayScreen extends Control`, containing the screen layout and flow of White Shift's `main.gd`,
  with the same member names.
- Game-specific parts are virtual hooks (`_load_day`, `_new_attempt`, `_make_view`, `_view_show`, `_view_update`,
  `_key_move`, `_extra_buttons`, `_count_mode`, `_texts`, `_hint_text`, `_play_message`, and a few more; full list in
  the design, section 5.12). Every hook has a default that reproduces White Shift's behaviour where one exists.
- The message line follows a fixed order: solved message, then the game's `_play_message` when it is not empty, then
  the start hint before the first move, else empty.
- The counter label uses the optional text key `count_final` in final-only mode when the game defines it (ADR 0003).
- A game's main scene script extends `WhiteDayScreen` and implements the hooks; it does not override `_ready`.
- The look comes from `WhiteTheme` and `WhiteUi` (constants and widget factory), shared by the series.
- The screen is part of kit 0.1.0, built and tested with a fixture game in the kit and verified by White Shift's own UI
  tests after its migration.

## Alternatives considered

- Only widgets (theme, buttons, tabs, a status row) and no flow: smaller API, but every game would copy the flow
  (replay on open, clock per level, saving, practice handling), which is where the bugs were found in White Shift.
  Rejected.
- A non-visual session object holding the flow, with each game building its own screen: cleaner separation, but White
  Shift's tests address the screen's members directly, so the screen would need many forwarding properties, and the
  layout would still be copied. Rejected for now; it can be extracted later behind the same base class if a game needs a
  different layout.
- No UI in the kit until White Tally's screen is designed: avoids designing against one game, but White Tally would
  start by copying `main.gd`, and the copy would then have to be merged back. Rejected: both games already share the
  screen structure.
- Let games write to the message label directly instead of a `_play_message` hook: the screen's `_refresh` would
  overwrite it on the next action, and the order of messages would differ per game. Rejected.

## Consequences

- White Shift's `main.gd` shrinks to its hooks and the best-route animation; its tests keep working because member
  names are kept.
- A game with a different screen structure (other than three levels per day with a practice mode) does not fit the base
  class without new hooks; such a change is a kit MINOR version, or the game builds its own screen from `WhiteUi`.
- Layout changes to the base class affect every game at its next kit update; games see them in their screenshot checks.
- The base class is the place where later features shared by the series land (statistics, settings, an engine sign-in
  button), each as a kit version.
