#!/usr/bin/env bash
# A project outside $WT_ROOT with its settings in the repos' own .wt.conf (sandbox 6), run without WT_ROOT:
# `wt new` by path and by sibling name, base branch and linked files from the config, list, and the SessionEnd
# hook removing the task's merged worktrees in both repos. Run: bash evals/repo-test.sh
set -euo pipefail
here=$(dirname "$(realpath "$0")")
S=$(mktemp -d); trap 'rm -rf "$S"' EXIT
app=$("$here/sandbox.sh" setup "$S" 6)
. "$S/env.sh"; unset WT_ROOT HERDR_ENV
fail() { echo "FAIL: $*"; exit 1; }
W=$(dirname "$app")/.worktrees
git_() { git -c user.name=Test -c user.email=test@example.com "$@"; }

cd "$app"
[ "$(wt new . SHOP-7.cart 2>/dev/null)" = "$W/app/SHOP-7.cart" ] || fail "wt new . did not print $W/app/SHOP-7.cart"
[ -f "$W/app/SHOP-7.cart/develop.txt" ] || fail "app task did not branch from develop (committed .wt.conf)"
[ "$(readlink "$W/app/SHOP-7.cart/.env")" = "$app/.env" ] || fail ".env not linked by link_local_files"
cd "$W/app/SHOP-7.cart"
[ "$(wt new lib SHOP-7.cart 2>/dev/null)" = "$W/lib/SHOP-7.cart" ] || fail "wt new <sibling> from a worktree"
[ -f "$W/lib/SHOP-7.cart/stable.txt" ] || fail "lib task did not branch from stable (local .wt.conf)"
[ "$(wt list | awk '{print $1}' | tr '\n' ' ')" = "shop/.worktrees/app/SHOP-7.cart shop/.worktrees/lib/SHOP-7.cart " ] ||
  fail "wt list: $(wt list)"

for r in app:develop lib:stable; do
  d=$W/${r%%:*}/SHOP-7.cart
  echo cart > "$d/cart.txt"; git_ -C "$d" add -A; git_ -C "$d" commit -qm cart; git_ -C "$d" push -q origin "HEAD:${r#*:}"
done
echo '{"cwd":"'"$W/app/SHOP-7.cart"'"}' | (cd / && wt hook) 2>/dev/null
[ ! -e "$W/app/SHOP-7.cart" ] || fail "hook kept the merged app worktree"
[ ! -e "$W/lib/SHOP-7.cart" ] || fail "hook kept the same task's merged lib worktree"
git -C "$app" show-ref -q --verify refs/heads/SHOP-7.cart && fail "hook kept the local branch"
[ -z "$(git -C "$app" status --porcelain)" ] || fail "main checkout of app is dirty"
cd "$S" && wt list >/dev/null 2>&1 && fail "wt list outside a project without WT_ROOT should fail"
echo ok
