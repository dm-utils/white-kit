# 0006 Defined results for invalid input

Status: accepted (2026-11-17), built in 0.2.0

## Context

The test round on 0.1.0 found two public functions without a defined result for invalid input:

- `WhiteRng.range_int(from, to)` computed `n = to - from + 1`. When the true span exceeds int64 the subtraction wraps,
  `n` becomes negative or 0, and the rejection loop could hang or take a modulo by zero (finding B2). `from > to` and
  more than 2^32 values were already rejected with `push_error` and `from`.
- `WhiteDaily.number(date, first_day)` and `WhiteDaily.add_days(date, days)` passed any text to `Time`. For an
  impossible or malformed date `Time` printed an engine error and the functions returned a meaningless value
  (finding B3). `is_date` already existed as the validity check.

Both functions return a plain `int` or `String` and are called from game code and tools. Changing their return types
would break callers. Every integer is a possible valid `number` result (negative for days long before the first day,
0 for the day before), so no in-band value can mean "invalid" without ambiguity.

## Decision

- `range_int`: `span = to - from`; a range is bad when `from > to`, `span < 0` (the subtraction overflowed) or
  `span >= 2^32`. A bad range is a `push_error` and returns `from` without drawing. Valid ranges are unchanged.
- `WhiteDaily` gets one private validity function `_valid(text)` (format, then year/month/day ranges, without calling
  `Time`). `is_date` returns `_valid(text)`. `number` returns 0 with a `push_error` when either argument is not valid;
  `add_days` returns the date unchanged with a `push_error` when it is not valid. Neither calls `Time` for invalid
  input, so there is no engine output.
- The returned values are a safe fallback, not a validity signal. Callers with untrusted text check `is_date` first.
  Specification: design sections 5.2, 5.4 and 13.3.

## Alternatives considered

- `number` returns -1 (or another sentinel) for invalid input: -1 is a valid puzzle number (two days before the first
  day), so the sentinel is as ambiguous as 0 and less natural as a display fallback (`#0` versus `#-1`). Rejected.
- Return a `Variant` that is `null` on invalid input, or a result dictionary `{ok, value}`: unambiguous, but a breaking
  change of the return type of a public function and extra code at every call site, where callers normally have a valid
  date already. Rejected; `is_date` gives the same certainty without an API break.
- `add_days` returns `""` for an invalid date: a caller that uses the result as a dictionary key or file name silently
  gets an empty key. Returning the input unchanged keeps the faulty value visible and keeps `add_days(x, 0) == x` true
  for every `x`. Rejected.
- Leave the 0.1.0 behaviour and only document "pass valid dates": the engine error appears in game and test output and
  the returned value is undefined. Rejected.
- `range_int` clamps an overflowing range to the int64 limits, or draws 64-bit values for wide ranges: gives a result
  where the caller asked for an impossible one, and 64-bit draws would add a second generator path that must be frozen
  and mirrored in the Python reference. No game needs ranges wider than 2^32 values. Rejected.
- `range_int` asserts (`assert`) instead of `push_error`: asserts are stripped in release exports, so a release build
  would hang again. Rejected.

## Consequences

- No hang, no modulo by zero and no engine output for any input to these functions; each rejected call gives exactly
  one `push_error`.
- 0 from `number` and an unchanged string from `add_days` can be valid results; the documentation says so and points
  to `is_date`. The runner does not count `push_error` (ADR 0005), so tests can exercise invalid input directly.
- Output for valid input is unchanged, including the frozen `WhiteRng` sequences; this is MINOR-compatible
  (part of 0.2.0).
- New public functions with a plain return type follow the same pattern (conventions, GDScript style).
