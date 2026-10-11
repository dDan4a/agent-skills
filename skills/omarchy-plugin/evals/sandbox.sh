#!/usr/bin/env bash
# Eval sandbox for omarchy-plugin: plugins live in <dir>/home/.config/omarchy/plugins, never in the real one.
#   sandbox.sh setup <dir> <eval-id>   build the sandbox, print the session's cwd
#   sandbox.sh state <dir>             dump what the grader needs
set -euo pipefail
cmd=$1 S=$(realpath -m "$2") id=${3:-}
files=$(dirname "$(realpath "$0")")/files
PL=$S/home/.config/omarchy/plugins

if [ "$cmd" = state ]; then
  for d in "$PL"/*/; do
    [ -d "$d" ] || continue
    echo "=== plugin ${d#"$S"/}"
    echo "--- omarchy plugin validate: $(omarchy plugin validate "$d" 2>&1 && echo OK)"
    find "$d" -type f -o -type l | sort | while read -r f; do echo "--- ${f#"$d"} ($(stat -c %a "$f"))"; cat "$f"; done
  done
  exit 0
fi

mkdir -p "$PL"
: > "$S/env.sh"
case $id in
  2) cp -r "$files/weather" "$PL/io.github.someone.weather" ;;
  3) cp -r "$files/clipnote" "$PL/io.github.someone.clipnote" ;;
esac
echo "$PL"
