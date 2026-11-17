# 0004 Shared day screen as a base class with hooks

Status: accepted (2026-11-17); amended (2026-11-17, see below)

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

## Amendment 1 (2026-11-17, in 0.1.0): signal `refreshed()`

Context: White Shift's Best route button is an extra button created by the game (`_extra_buttons`). Its text must
follow the language toggle, but only the screen knows when texts are refreshed, and no hook covered this. Found while
building 0.1.0.

Decision: `WhiteDayScreen` emits `signal refreshed()` as the last action of every `_refresh()`, in both branches (with
and without puzzles). A game connects to it to update what the screen does not manage, such as the text of its extra
buttons. Handlers must not change members the screen sets in `_refresh()`.

Alternatives:
- Let the game override `_refresh()` and call `super()`: works, but `_refresh` is internal and the order of the game's
  code against the screen's (and against later kit changes) is then the game's problem; the hook table exists to avoid
  exactly that. Rejected.
- A hook `_extra_texts() -> void` called at the end of `_refresh()`: equivalent, but every game must subclass to use
  it, while a signal also serves other listeners (a later statistics panel). Rejected in favour of the signal.
- Return button texts as text keys from `_extra_buttons()` and let the screen set them: covers buttons only and needs
  a new return type. Rejected.

Consequences: no behaviour change for games that ignore the signal; White Shift uses it for Best route.

## Amendment 2 (2026-11-17, planned for 0.2.0): practice-only screen, hook `_practice_only()`

Context: White Tally's phase 1 has no daily puzzles, only practice sets (White Tally design, section 7.1 R3). With the
0.1.0 screen it would open on a "no puzzle" day and show a mode button that leads nowhere. Its interim solution
overrides `_open_day()` and `_refresh()`, both internal.

Decision: a hook `_practice_only() -> bool` (default false). When true, the screen opens practice instead of the day,
hides the mode button and ignores `_toggle_mode()`; everything else is practice behaviour. Specification and acceptance:
design section 13.1.

Alternatives:
- Name it `_start_in_practice()` (White Tally's suggestion): describes only the start, while the hook also hides the
  mode button and blocks switching to the day. Rejected for the clearer name; the behaviour is what White Tally asked.
- Two hooks, one for the start mode and one for the mode button's visibility: more freedom, but a combination of
  "start in practice, mode button visible" is already the normal screen after one click, and "start on the day, no mode
  button" has no requester. Rejected (YAGNI).
- Keep White Tally's interim overrides of `_open_day()` and `_refresh()`: no kit change, but the game then depends on
  internal functions whose content may change in any kit version. Rejected.

Consequences: a MINOR version (0.2.0). White Shift is unaffected (default false). White Tally removes its interim
overrides when it updates to 0.2.0. When White Tally gets daily puzzles in phase 2 it returns false from the hook.
