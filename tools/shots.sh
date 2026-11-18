#!/usr/bin/env bash
# Debug screenshots of a game from a scenario file, comparison, and before/after of a kit update.
#   shots.sh run <project dir> <scenario file> <out dir>
#   shots.sh compare <project dir> <dir a> <dir b> [<diff dir>]
#   shots.sh before-after <project dir> <scenario file> <old kit ref> [<new kit ref>]
# Scenario line: <name> <W>x<H> [arguments...]; empty lines and # lines are ignored.
set -euo pipefail

GODOT="${GODOT:-godot}"

die() { echo "$*" >&2; exit "${2:-2}"; }

abs() { (cd "$1" && pwd); }

run() {
	local project scen out
	project="$(abs "$1")"
	scen="$2"
	[ -r "$scen" ] || die "cannot read $scen" 2
	mkdir -p "$3"
	out="$(abs "$3")"
	local n=0 bad=0 failed=0 line name res args names=()
	while IFS= read -r line || [ -n "$line" ]; do
		n=$((n + 1))
		[[ -z "${line//[[:space:]]/}" || "$line" =~ ^[[:space:]]*# ]] && continue
		read -r name res args <<<"$line"
		if [[ ! "$name" =~ ^[a-z0-9-]+$ || ! "$res" =~ ^([0-9]+)x([0-9]+)$ ]]; then
			echo "bad scenario line $n" >&2
			bad=1
			continue
		fi
		local w="${BASH_REMATCH[1]}" h="${BASH_REMATCH[2]}"
		if [ "$w" -gt 1920 ] || [ "$h" -gt 1440 ] || [[ " ${names[*]:-} " == *" $name "* ]]; then
			echo "bad scenario line $n" >&2
			bad=1
			continue
		fi
		names+=("$name")
		rm -f "$out/$name.png"
		# shellcheck disable=SC2086
		timeout 120 xvfb-run -a -s "-screen 0 1920x1440x24" "$GODOT" --path "$project" --rendering-driver opengl3 \
			--resolution "${w}x${h}" -- --shot="$out/$name.png" $args >/dev/null 2>&1 || true
	done <"$scen"
	for name in "${names[@]:-}"; do
		[ -n "$name" ] || continue
		if [ -s "$out/$name.png" ]; then
			echo "shot $name ok"
		else
			echo "shot $name missing"
			failed=1
		fi
	done
	[ "$bad" -eq 0 ] && [ "$failed" -eq 0 ]
}

compare() {
	local project a b diff=()
	project="$(abs "$1")"
	a="$(abs "$2")"
	b="$(abs "$3")"
	if [ -n "${4:-}" ]; then
		mkdir -p "$4"
		diff=("--diff=$(abs "$4")")
	fi
	timeout 300 "$GODOT" --headless --path "$project" -s res://addons/white_kit/tools/compare_shots.gd -- \
		"--a=$a" "--b=$b" "${diff[@]}"
}

before_after() {
	local project scen old new kit orig
	project="$(abs "$1")"
	scen="$(cd "$(dirname "$2")" && pwd)/$(basename "$2")"
	old="$3"
	# the checkout below replaces this file while it runs: continue from a copy
	if [ -z "${WHITE_SHOTS_COPY:-}" ]; then
		local tmp
		tmp="$(mktemp -d)"
		cp "${BASH_SOURCE[0]}" "$tmp/shots.sh"
		WHITE_SHOTS_COPY=1 exec bash "$tmp/shots.sh" before-after "$project" "$scen" "$old" "${4:-}"
	fi
	kit="$project/addons/white_kit"
	if [ -n "$(git -C "$kit" status --porcelain)" ]; then
		echo "kit has local changes" >&2
		exit 2
	fi
	orig="$(git -C "$kit" rev-parse HEAD)"
	new="${4:-$orig}"
	# expanded now: locals are gone when the trap fires
	trap "git -C '$kit' checkout --quiet '$orig'" EXIT
	rm -rf "$project/build/shots"
	mkdir -p "$project/build/shots"
	git -C "$kit" checkout --quiet "$old"
	timeout 600 "$GODOT" --headless --path "$project" --import >/dev/null 2>&1
	run "$project" "$scen" "$project/build/shots/before" || true
	git -C "$kit" checkout --quiet "$new"
	timeout 600 "$GODOT" --headless --path "$project" --import >/dev/null 2>&1
	run "$project" "$scen" "$project/build/shots/after" || true
	compare "$project" "$project/build/shots/before" "$project/build/shots/after" "$project/build/shots/diff"
}

case "${1:-}" in
	run) [ $# -eq 4 ] || die "usage: shots.sh run <project dir> <scenario file> <out dir>"; run "$2" "$3" "$4" ;;
	compare) [ $# -ge 4 ] && [ $# -le 5 ] || die "usage: shots.sh compare <project dir> <dir a> <dir b> [<diff dir>]"; compare "$2" "$3" "$4" "${5:-}" ;;
	before-after) [ $# -ge 4 ] && [ $# -le 5 ] || die "usage: shots.sh before-after <project dir> <scenario file> <old kit ref> [<new kit ref>]"; before_after "$2" "$3" "$4" "${5:-}" ;;
	*) die "usage: shots.sh run|compare|before-after ..." ;;
esac
