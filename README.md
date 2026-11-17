# White Kit

Shared base for the White daily puzzle games (Godot 4.7.2, GDScript): the Dutch puzzle day, a portable seed hash and
random generator, precomputed puzzle loading, attempt records with undo and two count modes, a robust progress file,
Dutch/English texts, the shared day screen, a test runner base, a precompute tool skeleton and CI building blocks.

Status: designed, not built yet. See `docs/design.md` and `docs/adr/`.

## Use in a game

The repository root is the addon root. Add it as a submodule at a release tag:

```bash
git submodule add https://github.com/dm-utils/white-kit.git addons/white_kit
git -C addons/white_kit checkout v0.1.0
git add .gitmodules addons/white_kit
```

Clone a game with `git clone --recurse-submodules` (or run `git submodule update --init` afterwards). Copy
`templates/ci.yml` to the game's `.github/workflows/ci.yml` and exclude `addons/white_kit/tests/*` and
`addons/white_kit/tools/*` from the export preset. Details in `docs/conventions.md`.

## Development

```bash
tools/kit_host.sh     # builds a host project in build/host, imports it and runs the kit tests
```

## Licence

All rights reserved. The source is public to read; no licence is granted to use, copy, modify or distribute it.
