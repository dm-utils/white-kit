# 0007 Share the tile view and the tooling, not the rules

Status: accepted (2026-11-18), to be built in 0.3.0

## Context

White Tally (phase 1 built) has a grid layer of its own: board state as `PackedByteArray` with `y` up, cell names
(`A1`), move tokens, group detection, gravity, waves and chains, a traced step for animation, a solver (iterative
deepening with a transposition table, beam prefilter, greedy bot), a reverse-building generator, a board view with
tile animation and swipe/tap/keyboard input, a safe-area helper, debug screenshots in CI and a measuring tool.

Two new games start now: White Sum (Tally's moves and gravity, but rows and columns that add up to 10 vanish) and
White Drift (the whole board tilts; groups vanish by White Tally's size rule; fixed blocks). With White Shift that makes
four games. The question is which parts move into White Kit and which are copied and adapted per game.

Constraints:

- White Tally must keep byte-identical puzzles (its pool is published on its play version).
- The kit API must stay stable; every kit change reaches every game through a tagged release.
- Hot paths (move resolution, solver, generator) run hundreds of thousands of times per puzzle in GDScript; Tally's
  solver reaches about 1 800 expansions per second and that already limits par exactness.
- The kit is a submodule; a kit change that a game needs blocks that game until the tag exists.

How the candidates compare across the three grid games:

| Part | Tally | Sum | Drift |
|---|---|---|---|
| State, coordinates, cell names | `y` up, `A1` | same | same, plus blocks |
| Moves | swap/slide, token `RB1` | same | four tilts, token `R` |
| What vanishes | equal-value group, size = value | maximal row or column run with sum 10 | as Tally, blocks excluded |
| Resolution | gravity down, waves | same | re-pack in the tilt direction, waves |
| Solver | IDDFS + table, beam, greedy | same family | breadth-first search (four moves) |
| Generator | reverse building | reverse building, other insertion | random start + exact search |
| Board view | tiles, phases, cell input | tiles, phases, cell input | tiles, phases, board swipes |
| Safe area, max width, screenshots, CI | game code / CI file | needed | needed |

## Decision

Kit 0.3.0 takes the parts that are the same in all three games and are not on a hot path:

1. `WhiteTileView` (`ui/tile_view.gd`): a board view base class with layout, coordinate conversion, a tile registry
   with stable ids, a phase animator driven by a small generic step format (`move`, `vanish`), shake and nudge feedback,
   and input in two modes: cell moves (White Tally's swipe, tap-tap and keyboard grab) and board swipes (swipe anywhere
   or arrow keys, for White Drift). Games implement drawing hooks and two resolve hooks that turn a raw gesture into a
   move code.
2. `WhiteSafeArea` (`ui/safe_area.gd`) and two new screen hooks: `_use_safe_area()` and `_max_content_width()` (the
   desktop finding of the White Tally test). Both default to the current behaviour.
3. A frozen clock in debug screenshot mode, so screenshots are deterministic.
4. Screenshot tooling (`tools/shots.sh`, `tools/compare_shots.gd`) with a per-game scenario file, used by CI and by the
   before/after comparison of a kit update (board card #010).
5. The CI template gets the screenshot step; kit CI raises its check threshold (board card #008).

Rules, solvers, generators, notation and measuring tools stay in each game. White Sum copies White Tally's `sim/` and
adapts it (same moves and gravity, different vanish rule and insertion); White Drift writes its own rules and a
breadth-first solver and borrows only patterns. A shared search or grid module may be extracted later, once three
built solvers show what is really common.

White Tally does not have to change. It may move to 0.3.0 later in optional steps (design 14.7); its `sim/` and `data/`
are not touched by any of them, so its puzzles stay byte-identical by construction.

## Alternatives considered

- **A shared grid engine in the kit** (state, groups, gravity, chain, traced step, solver and generator skeleton behind
  callbacks): the most sharing, but the three games differ exactly in these parts (vanish rule, move set, resolution
  direction, solver type). A generic engine needs callables or virtual calls in the innermost loops, which costs speed
  where Tally is already too slow for exact hard par. White Tally would have to migrate its hot path and prove
  byte-identical output for 120 puzzles (hours of rebuild), and every tuning of a solver would become a kit release.
  Rejected.
- **Copy everything per game, no kit change**: fastest start, but the board view (about 600 lines), safe area, max
  width, screenshot steps and CI would exist three times, and the two low findings of the White Tally test would have
  to be fixed three times. The look of the series would drift apart. Rejected.
- **Only safe area and max width in the kit; copy the view**: removes the smallest duplication and leaves the largest.
  The view's input and animation are identical in Tally and Sum and differ for Drift only in the input mode. Rejected.
- **A tiny `WhiteGrid` notation helper in `core/`** (cell names, cell-plus-direction tokens): about 20 lines per game,
  and token formats differ (Drift uses one letter). Putting it in the kit would make the games' phase 1a (rules,
  solver, generator) wait for the kit tag. Rejected; notation stays in the rules class of each game.
- **Shared solver/search module now** (`WhiteSearch` with IDDFS, beam, BFS): attractive, but only one built solver of
  the grid family exists, and the trials of Sum and Drift will change their solvers. Deferred, not rejected.

## Consequences

- Build order: kit 0.3.0 can be built in parallel with the phase 1a work of White Sum and White Drift (rules, solver,
  generator, pool), which only need kit 0.2.0. Their phase 1b (screen, view, Pages) needs the `v0.3.0` tag.
- `WhiteTileView` becomes a public API that three games depend on. Its look constants are members with White Tally's
  values as defaults, so a game tunes the look without a kit release.
- Defaults keep White Shift unchanged (no hook overridden). The only visible difference for an existing game is the
  frozen clock in debug screenshots that use `--keys`.
- White Tally keeps byte-identical puzzles whatever it decides; its optional migration is checked with the new
  screenshot comparison.
- The rules code of White Tally and White Sum is a deliberate copy. A bug found in Tally's copied parts (for example
  `canonical`, reverse moves) must be checked in Sum too; both designs name this.
