# White Kit

Shared base for the White daily puzzle games (Godot 4.7.2, GDScript): the Dutch puzzle day, a portable seed hash and
random generator, precomputed puzzle loading, attempt records with undo and two count modes, a robust progress file,
Dutch/English texts, the shared day screen, a tile board view with animation and input, a safe-area helper, a test
runner base, a precompute tool skeleton, screenshot tooling and CI building blocks.

Status: version 0.3.0. See `docs/design.md` and `docs/adr/`.

## Use in a game

The repository root is the addon root. Add it as a submodule at a release tag:

```bash
git submodule add https://github.com/dm-utils/white-kit.git addons/white_kit
git -C addons/white_kit checkout v0.3.0
git add .gitmodules addons/white_kit
```

Clone a game with `git clone --recurse-submodules` (or run `git submodule update --init` afterwards). Copy
`templates/ci.yml` to the game's `.github/workflows/ci.yml` and exclude `addons/white_kit/tests/*` and
`addons/white_kit/tools/*` from the export preset. Details in `docs/conventions.md`.

## Board view

`WhiteTileView` draws a `w x h` board of square cells and animates tiles. A game subclasses it, overrides the draw hooks
(`_draw_tile_body`, `_draw_tile_face`, `_draw_links`, `_draw_static`) and one resolve hook that turns a gesture into
its own move code (`_resolve_cell_move` for tap and swipe on a tile, `_resolve_board_swipe` for a swipe anywhere), and
feeds it generic steps: `animate([{"kind": "move", "moves": [[from, to]], "time": 0.1}, {"kind": "vanish",
"cells": [3]}])`. The view never knows the rules. `WhiteDayScreen` has hooks `_use_safe_area()` and
`_max_content_width()` for notches and a centred column on desktop.

## Screenshots

A game lists its debug screenshot scenarios in `tools/shots.txt` (`<name> <W>x<H> [arguments]`, one per line):

```bash
addons/white_kit/tools/shots.sh run . tools/shots.txt build/shots
addons/white_kit/tools/shots.sh before-after . tools/shots.txt v0.2.0 v0.3.0   # compare two kit versions
```

`before-after` checks out the two kit refs in turn, writes `build/shots/{before,after,diff}` and exits 1 when a
screenshot differs. The game's `templates/ci.yml` runs `run` when `tools/shots.txt` exists.

## Development

```bash
tools/kit_host.sh     # builds a host project in build/host, imports it and runs the kit tests
```

## Licence

All rights reserved. The source is public to read; no licence is granted to use, copy, modify or distribute it.
