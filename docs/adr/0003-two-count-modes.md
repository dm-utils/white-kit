# 0003 Two count modes in one attempt record

Status: accepted (2026-11-17)

## Context

White Shift scores a daily puzzle by every effective move in the attempt, including moves later undone or discarded by
a restart (White Shift ADR 0002). White Tally uses the same rule for the daily puzzle, but its practice mode counts
only the moves of the final solution: practice is for exploring, so undo must give moves back there.

Both games need undo, restart, a record that reloads progress exactly, and a record a server can later replay to verify
a score. White Tally's moves are not swipe directions: it has swaps of two neighbouring stones and slides of a stone
into an empty neighbouring cell, so a move needs more than one character.

## Decision

- One attempt class (`WhiteAttempt`) with a count mode chosen at creation: `EVERY_MOVE` or `FINAL_ONLY`.
- The attempt always tracks both numbers: `moves_made` (every effective move) and `line_length()` (moves from the start
  position to the current state, i.e. the size of the undo history). `count()` returns the one the mode selects.
- The record is identical in both modes: move tokens for effective moves, `z` for undo, `r` for restart. The mode is
  not stored in the record; it follows from the context (daily or practice) and is part of what a server needs to
  verify a score.
- Undo and restart behave the same in both modes (undo returns to the previous state, restart returns to the start and
  clears the undo history); only the count differs.
- Moves are fixed-width tokens defined by the game (`WhiteRules.move_len()`, `encode_move`, `decode_move`) using only
  upper-case letters and digits; lower-case letters are reserved for kit-level actions. White Shift keeps its
  one-letter tokens, so its existing records and saves stay valid.
- Only effective moves are recorded; a game's rules decide which moves are effective by returning `null` from
  `apply` for a rejected move.

## Alternatives considered

- Separate attempt classes per mode: duplicates undo, restart and replay logic, and two record formats would have to
  stay in step. Rejected.
- Rewrite the record on undo in final-only mode (drop the undone move): the record would no longer show what the player
  did, a reload could not restore the undo history, and the two modes would need different replay code. Rejected.
- Store the mode inside the record (a prefix letter): makes records self-describing, but changes White Shift's existing
  saves and duplicates information the context already fixes. Rejected for now; a later kit-level action letter could
  add it without breaking old records.
- Separator-based records (for example `C3R,D4L`): flexible move lengths, but larger and a new format for White Shift.
  Rejected while fixed-width tokens suffice.

## Consequences

- White Tally's practice mode is a one-line choice in its screen (`_count_mode`), with the same save and replay code
  as the daily puzzle.
- A server verifying a result needs the puzzle, the record and the mode; it re-derives the count by replay.
- The shared screen shows `count()`; the hint before the first move uses `moves_made`, so a final-only attempt that is
  back at zero after undo does not show the start hint again.
- Adding a new kit-level action (for example "give up") uses a free lower-case letter and is a MINOR kit version; old
  records stay valid because unknown lower-case letters are ignored on replay today.
