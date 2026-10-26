#!/usr/bin/env bash
# `wt fan` in the eval sandbox: N worktrees <branch>-1..N from the base branch, agents in turn from the list, the same
# brief to each, the compare commands in the output; bad input creates nothing. Run: bash evals/fan-test.sh
set -euo pipefail
here=$(dirname "$(realpath "$0")")
S=$(mktemp -d); trap 'rm -rf "$S"' EXIT
"$here/sandbox.sh" setup "$S" 0 >/dev/null
. "$S/env.sh"; export HERDR_ENV=1
fail() { echo "FAIL: $*"; exit 1; }
W=$WT_ROOT/acme/.worktrees/api

out=$(echo "rename login to signIn" | wt fan acme/api feat/x -n 3 --agent claude,codex --brief - 2>"$S/err")
[ "$out" = "$(printf '%s\n' "$W/feat/x-1" "$W/feat/x-2" "$W/feat/x-3")" ] || fail "paths: $out"
starts=$(grep '^herdr agent start' "$S/herdr.log" | awk '{print $4, $6}' | tr '\n' ' ')
[ "$starts" = "feat-x-1 claude feat-x-2 codex feat-x-3 claude " ] || fail "agents not in turn: $starts"
[ "$(grep -c 'rename login to signIn' "$S/herdr.log")" = 3 ] || fail "brief not sent to every agent: $(cat "$S/herdr.log")"
for i in 1 2 3; do
  grep -qF "git -C $WT_ROOT/acme/api diff origin/main...feat/x-$i" "$S/err" || fail "no diff command for x-$i: $(cat "$S/err")"
done

for bad in "-n 1" "-n x" "-n 2 --agent claude,gpt" "-n 2 --agent claude --nope"; do
  # shellcheck disable=SC2086
  wt fan acme/api feat/bad $bad </dev/null >/dev/null 2>&1 && fail "accepted: $bad"
done
wt fan acme/api feat/a-branch-name-too-long-for-herdr -n 2 --agent claude </dev/null >/dev/null 2>&1 && fail "accepted a long name"
env -u HERDR_ENV wt fan acme/api feat/bad -n 2 --agent claude </dev/null >/dev/null 2>&1 && fail "accepted --agent without Herdr"
[ -z "$(ls "$W/feat" | grep -v '^x-')" ] || fail "bad input created worktrees: $(ls "$W/feat")"

out=$(env -u HERDR_ENV wt fan acme/api feat/plain -n 2 2>/dev/null)
[ "$out" = "$(printf '%s\n' "$W/feat/plain-1" "$W/feat/plain-2")" ] || fail "without --agent: $out"
echo ok
