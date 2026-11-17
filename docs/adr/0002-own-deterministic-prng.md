# 0002 Own deterministic integer PRNG instead of RandomNumberGenerator

Status: accepted (2026-11-17)

## Context

Daily puzzles are generated from a seed text (`<game>|<date>|<level>`) hashed with FNV-1a 64-bit. White Shift feeds that
seed into Godot's `RandomNumberGenerator`. The engine documents neither that this generator's sequence stays the same
across Godot versions nor how a seed is mixed into its state, so the same seed may give a different puzzle after an
engine upgrade, and no other implementation (for example a server check later, through st33f-engine) can reproduce it.
White Shift's design already notes that a seed alone is not a portable puzzle description.

The current FNV-1a implementation multiplies 64-bit signed integers and relies on wrap-around on overflow, which the
engine does not promise.

White Shift has published puzzles (`data/daily.json`, `data/practice.json`). Its rule is that published days are never
regenerated, because any generator change would change them. The game only reads these files; it never generates at
run time.

## Decision

- The kit provides `WhiteRng`: xoshiro128** (32-bit words, period 2^128 - 1), seeded from a 64-bit seed through a fixed
  mixing step (murmur3 `fmix32` over a Weyl sequence), with `range_int` by rejection sampling, `next_float` as
  `u32 / 2^32` and Fisher-Yates `shuffle`. The exact algorithm is in the design (section 5.4).
- `WhiteSeed.fnv1a64` computes the same values as White Shift's `seed_for`, but on two 32-bit halves, so no operation
  overflows int64.
- All arithmetic keeps values non-negative and below 2^63; no float is used in the state. `next_float` is exact because
  every 32-bit integer divided by 2^32 is representable in a double.
- A Python reference implementation in the kit is the portable contract; CI compares its output with Godot's.
  Published reference values (xoshiro128** from state 1, 2, 3, 4; FNV-1a test vectors) are part of the tests.
- Game code in `sim/` and tools use only `WhiteRng` for anything that must be reproducible.
- Published puzzles are data, not seeds: the shipped JSON files are the source of truth for the game. White Shift
  switches its generator to `WhiteRng` (migration step 10); this changes what a seed produces, but nothing that is
  published is regenerated, so every published day and practice set stays exactly as it is. Days built after the
  switch use `WhiteRng`. Merging new days uses the precompute tool's merge, which refuses to change a published key.

## Alternatives considered

- Keep `RandomNumberGenerator`: no work, but determinism across engine versions and a second implementation are not
  guaranteed. Rejected.
- PCG32: well known and good, but its step multiplies two 64-bit numbers modulo 2^64, which in GDScript needs either
  overflow (not promised) or a slow multi-word multiplication on every draw. Rejected in favour of a generator whose
  step needs only shifts, xor and small multiplications.
- xorshift32: simplest, but small state (period 2^32 - 1) and known statistical weaknesses in the low bits. Rejected.
- Regenerate White Shift's published days with the new generator: would change puzzles players already played
  (and their saved records would replay wrongly). Rejected.
- Keep White Shift on `RandomNumberGenerator` and use `WhiteRng` only in new games: avoids the switch, but leaves White
  Shift's future days non-portable and keeps two random sources in the series. Rejected.

## Consequences

- The same seed gives the same sequence on web, Android, desktop, CI and in the Python reference, independent of the
  Godot version.
- The output of `WhiteRng` and `WhiteSeed` for a given seed is frozen; changing it is a MAJOR kit version and changes
  every future puzzle of every game that regenerates.
- White Shift: after the switch, `tools/build_puzzles.gd` produces different puzzles for the same seed text than before.
  This only matters for days not yet published; the generator's par bands are measured again after the switch
  (`tools/measure.gd`).
- Generation speed in GDScript is somewhat lower than the native generator (a few integer operations per draw); the
  generator's time is dominated by the solver, so this is negligible.
