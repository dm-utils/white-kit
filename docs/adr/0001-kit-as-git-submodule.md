# 0001 Games include the kit as a git submodule at a tagged release

Status: accepted (2026-11-17)

## Context

White Kit is shared by several game repositories (White Shift now, White Tally next). Every repository is public on
GitHub under `dm-utils`. Each game's CI imports the project, runs the tests and exports the web build that GitHub
Pages serves; Android builds follow later. CI must therefore get the kit without credentials, and a game must build
the same way on every machine and in CI. A game must also be able to stay on an older kit version while another game
moves on, and it must be visible in each game's history which kit version it uses.

Godot finds global classes (`class_name`) anywhere under `res://`, so the kit needs no editor plugin; it only needs to
be present as a folder. Godot skips folders that contain their own `project.godot`, so the kit repository root cannot
be a Godot project if that root is placed inside a game.

## Decision

- The kit repository root is the addon root; it has no `project.godot` and no `plugin.cfg`.
- A game adds the kit as a git submodule at `addons/white_kit`, with the HTTPS URL
  `https://github.com/dm-utils/white-kit.git`, checked out at a release tag.
- Releases are semantic versions: `VERSION` file, `WhiteKit.VERSION` constant and git tag `v<version>` on a commit on
  the kit's `main` branch. Rules for MAJOR/MINOR/PATCH are in the design (section 8); the output of the seed hash and
  the random generator is frozen and only changes with a MAJOR version.
- A game's CI checks out submodules and verifies that the submodule commit is exactly the tag `v<VERSION>`; it then
  runs the kit tests and the game tests against that pinned version.
- Shared CI steps (Godot download, checksum, cache, install) live in a composite action inside the kit
  (`ci/setup-godot`), used by path from the submodule, so the CI code is pinned together with the kit code.
- The kit's own tests run in a host project that is created on the fly (`templates/host/project.godot`), locally by
  `tools/kit_host.sh` and in the kit's CI.

## Alternatives considered

- Copy the kit into each game (vendoring) with a version check in CI: no submodule handling for contributors and
  clones, but every update is a large copy diff, local edits in a game drift silently, and the version check has to
  compare file contents. Rejected: drift is the main risk this kit is meant to remove.
- Git subtree: the code is physically in the game repository (plain clone works), updates by `git subtree pull`.
  Rejected for now: the history of both repositories mixes, pushing fixes back is awkward, and the pinned version is
  not visible as one value. It stays the fallback if submodules cause trouble in practice.
- Godot Asset Library: suited to third-party distribution, but publication goes through a review step, versions are
  not pinned per game in a way CI can check, and it adds a public listing that is not needed. Rejected.
- Kit repository as a full Godot project with the code under `addons/white_kit/`, games copying only that folder:
  makes local kit development simpler, but games can then not include the repository directly (it would be skipped
  as a nested project, or land at `addons/white_kit/addons/white_kit`). Rejected.
- Reusable GitHub workflow in the kit (`uses: dm-utils/white-kit/.github/workflows/...@v0.1.0`): works for public
  repositories, but introduces a second pin next to the submodule that can drift from it. Rejected in favour of a
  composite action used by path from the submodule.

## Consequences

- Clones need `--recurse-submodules` (or `git submodule update --init`); each game's README says so.
- `actions/checkout` with `submodules: true` fetches the public kit without secrets; GitHub Pages deploys the exported
  build, so it needs nothing extra.
- Updating the kit in a game is an explicit commit that changes one gitlink; the game's CI runs the kit tests on that
  version.
- Kit code is exported with each game; the kit's `tests/` and `tools/` are excluded in every game's export preset.
- Kit development and game development happen in different working copies; trying an unreleased kit in a game means
  checking out a branch in the submodule locally, and CI will reject it until a tag exists.
- Tooling that copies repository contents elsewhere must handle the submodule (a gitlink, not files).
