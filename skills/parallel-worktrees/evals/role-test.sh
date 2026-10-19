#!/usr/bin/env bash
# `wt new --role` in the eval sandbox: the stub herdr must see `-- --agent <role> --permission-mode auto`, and nothing
# extra without --role. Run: bash evals/role-test.sh
set -euo pipefail
here=$(dirname "$(realpath "$0")")
S=$(mktemp -d); trap 'rm -rf "$S"' EXIT
"$here/sandbox.sh" setup "$S" 0 >/dev/null
. "$S/env.sh"; export HERDR_ENV=1
fail() { echo "FAIL: $*"; exit 1; }
start() { grep '^herdr agent start' "$S/herdr.log" | tail -1; }

wt new acme/api feat/plain --agent claude </dev/null >/dev/null 2>&1
[ "$(start)" = "herdr agent start feat-plain --kind claude --pane p-1" ] || fail "without --role: $(start)"
wt new acme/api feat/role --agent claude --role implementer </dev/null >/dev/null 2>&1
[ "$(start)" = "herdr agent start feat-role --kind claude --pane p-1 -- --agent implementer --permission-mode auto" ] ||
  fail "with --role: $(start)"
for bad in "--role Bad_Name --agent claude" "--role implementer" "--role implementer --agent codex"; do
  # shellcheck disable=SC2086
  wt new acme/api feat/bad $bad </dev/null >/dev/null 2>&1 && fail "accepted: $bad"
  [ -e "$WT_ROOT/acme/.worktrees/api/feat/bad" ] && fail "created a worktree for: $bad"
done
echo ok
