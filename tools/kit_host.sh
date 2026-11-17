#!/usr/bin/env bash
# Creates the host project (default build/host), links the kit into it, imports and runs the kit tests.
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
host="${1:-$root/build/host}"

# keep godot out of the link target: build/ is inside the repository root the link points to
mkdir -p "$root/build"
touch "$root/build/.gdignore"
mkdir -p "$host/addons"
cp "$root/templates/host/project.godot" "$host/project.godot"
ln -sfn "$root" "$host/addons/white_kit"

timeout 600 godot --headless --path "$host" --import
timeout 300 godot --headless --path "$host" res://addons/white_kit/tests/run_kit_tests.tscn "${@:2}"
