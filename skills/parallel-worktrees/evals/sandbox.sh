#!/usr/bin/env bash
# Eval sandbox for parallel-worktrees. Never touches the real $HOME or projects.
#   sandbox.sh setup <dir> <eval-id>   build the sandbox, print the session's cwd
#   sandbox.sh state <dir>             dump what the grader needs
set -euo pipefail
cmd=$1 S=$(realpath -m "$2") id=${3:-}
skill=$(dirname "$(dirname "$(realpath "$0")")")
P=$S/projects

git_() { git -c user.name=Test -c user.email=test@example.com -c init.defaultBranch=main "$@"; }

if [ "$cmd" = state ]; then
  echo "== worktrees"; for r in "$P"/acme/*/; do echo "-- ${r%/}"; git -C "$r" worktree list; git -C "$r" branch --format='%(refname:short)'; done
  echo "== main checkout branches"; for r in "$P"/acme/*/; do echo "$(basename "$r"): $(git -C "$r" branch --show-current) $(git -C "$r" status --porcelain | wc -l) dirty"; done
  echo "== files under acme/.worktrees"; { find "$P/acme/.worktrees" -maxdepth 4 -not -path '*/.git*' 2>/dev/null || true; } | sed "s|$S/||" | sort
  echo "== herdr calls"; cat "$S/herdr.log" 2>/dev/null || echo none
  echo "== ~/dotfiles/claude/settings.json"; cat "$S/home/dotfiles/claude/settings.json" 2>/dev/null || echo none
  echo "== wt on PATH"; ls -l "$S/home/.local/bin/" 2>/dev/null || true
  exit 0
fi

mkdir -p "$S/home/.local/bin" "$S/bin" "$S/origin" "$P/acme"
cat > "$S/env.sh" <<ENV
export WT_ROOT=$P PATH=$S/home/.local/bin:$S/bin:\$PATH
export GIT_AUTHOR_NAME=Test GIT_AUTHOR_EMAIL=test@example.com GIT_COMMITTER_NAME=Test GIT_COMMITTER_EMAIL=test@example.com
ENV

for repo in api web; do
  git_ init -q --bare "$S/origin/$repo.git"
  git_ clone -q "$S/origin/$repo.git" "$P/acme/$repo" 2>/dev/null
  ( cd "$P/acme/$repo"
    mkdir -p src; echo "package main // $repo" > src/main.go
    [ $repo = api ] && cat > src/login.go <<'GO'
package main

import "net/http"

// login checks a password against the stored hash prefix (toy code for the eval).
func login(w http.ResponseWriter, r *http.Request) {
	user, password := r.FormValue("user"), r.FormValue("password")
	if password[0] != users[user][0] { // panics (500) on an empty password
		http.Error(w, "wrong password", http.StatusUnauthorized)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

var users = map[string]string{"alice": "s3cret"}
GO
    git_ add -A; git_ commit -qm init; git_ push -q origin main
    git remote set-head origin main )
done

# A stand-in for Herdr: logs every call, does what `wt` relies on.
cat > "$S/bin/herdr" <<STUB
#!/usr/bin/env bash
printf 'herdr %s\n' "\$*" >> "$S/herdr.log"
case "\$1 \$2" in
  "worktree create")
    while [ \$# -gt 0 ]; do case \$1 in --cwd) c=\$2; shift 2 ;; --branch) b=\$2; shift 2 ;; --base) base=\$2; shift 2 ;; --path) p=\$2; shift 2 ;; *) shift ;; esac; done
    git -C "\$c" worktree add -q --no-track -b "\$b" "\$p" "\$base" >&2 && echo '{"result":{"root_pane":{"pane_id":"p-1"}}}' ;;
  "worktree list") echo '{"result":{"worktrees":[]}}' ;;
  *) echo '{"result":{}}' ;;
esac
STUB
chmod +x "$S/bin/herdr"

# A copy, not a link: a run without the skill must not find it next to the script.
cp "$skill/scripts/wt" "$S/home/.local/bin/wt"
case $id in
  4)
    # In dotfiles: Claude Code will not let a session edit its own ~/.claude/settings.json.
    mkdir -p "$S/home/.claude" "$S/home/dotfiles/claude"
    echo '{ "model": "opus", "permissions": { "allow": ["Bash(git status:*)"] } }' > "$S/home/dotfiles/claude/settings.json"
    ln -s ../dotfiles/claude/settings.json "$S/home/.claude/settings.json" ;;
  2) echo "export HERDR_ENV=1" >> "$S/env.sh" ;;
  3)
    cd "$P/acme/api"
    W=$P/acme/.worktrees/api
    new() { git_ worktree add -q --no-track -b "$1" "$W/$1" origin/main; }
    commit() { echo "$2" >> "$W/$1/src/${1//\//-}.txt"; git_ -C "$W/$1" add -A; git_ -C "$W/$1" commit -qm "$1: $2"; }
    new fix/merged;   commit fix/merged a; git_ -C "$W/fix/merged" push -q origin fix/merged:main
    new feat/squashed; commit feat/squashed a; commit feat/squashed b
    tmp=$S/squash; git_ clone -q "$S/origin/api.git" "$tmp" 2>/dev/null
    git_ -C "$tmp" fetch -q "$W/feat/squashed" feat/squashed && git_ -C "$tmp" merge -q --squash FETCH_HEAD >/dev/null && git_ -C "$tmp" commit -qm "feat: squashed (#2)" && git_ -C "$tmp" push -q origin main
    rm -rf "$tmp"
    new feat/wip;     commit feat/wip a
    new fix/dirty;    commit fix/dirty a; git_ -C "$W/fix/dirty" pull -q --rebase origin main; git_ -C "$W/fix/dirty" push -q origin HEAD:main
    echo "unsaved" > "$W/fix/dirty/notes.txt"
    new feat/empty
    ;;
esac
cd "$P"
case $id in 1|2) echo "$P/acme/api" ;; *) echo "$P" ;; esac
