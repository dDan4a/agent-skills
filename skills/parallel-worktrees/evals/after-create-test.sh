#!/usr/bin/env bash
# WT_AFTER_CREATE in the eval sandbox: runs after link_local_files and before the agent, with the path as $1; its stdout and
# stdin never touch wt's; a failure only warns; `wt fan` runs it per worktree; an existing worktree does not. Run: bash evals/after-create-test.sh
set -euo pipefail
here=$(dirname "$(realpath "$0")")
S=$(mktemp -d); trap 'rm -rf "$S"' EXIT
app=$("$here/sandbox.sh" setup "$S" 6)
. "$S/env.sh"; unset WT_ROOT; export HERDR_ENV=1
fail() { echo "FAIL: $*"; exit 1; }
W=$(dirname "$app")/.worktrees/app
export HOOK_LOG=$S/hook.log

export WT_AFTER_CREATE='echo noise; cat; test -L "$1/.env" && echo "hook $1" >> "$HOOK_LOG" && echo "herdr hook" >> '"$S/herdr.log"
out=$(echo "the brief" | wt new "$app" feat/a --agent claude --brief - 2>/dev/null)
[ "$out" = "$W/feat/a" ] || fail "stdout is not the path alone: $out"
[ "$(cat "$HOOK_LOG")" = "hook $W/feat/a" ] || fail "hook did not get the path after link_local_files: $(cat "$HOOK_LOG")"
[ "$(grep -n -m1 'herdr hook' "$S/herdr.log" | cut -d: -f1)" -lt "$(grep -n -m1 'agent start' "$S/herdr.log" | cut -d: -f1)" ] ||
  fail "hook ran after the agent started: $(cat "$S/herdr.log")"
grep -q 'the brief' "$S/herdr.log" || fail "hook swallowed the brief: $(cat "$S/herdr.log")"

: > "$HOOK_LOG"
wt new "$app" feat/a >/dev/null 2>&1
[ ! -s "$HOOK_LOG" ] || fail "hook ran for an existing worktree"

export WT_AFTER_CREATE='echo "$1" >> "$HOOK_LOG"'
wt fan "$app" feat/f -n 2 >/dev/null 2>&1
[ "$(cat "$HOOK_LOG")" = "$(printf '%s\n' "$W/feat/f-1" "$W/feat/f-2")" ] || fail "fan: $(cat "$HOOK_LOG")"

export WT_AFTER_CREATE='exit 3'
out=$(wt new "$app" feat/bad --agent claude </dev/null 2>"$S/err") || fail "a failing hook stopped wt"
[ "$out" = "$W/feat/bad" ] || fail "failing hook, stdout: $out"
grep -q 'WT_AFTER_CREATE failed with code 3' "$S/err" || fail "no warning: $(cat "$S/err")"
grep -q 'agent start feat-bad' "$S/herdr.log" || fail "a failing hook stopped the agent"
echo ok
