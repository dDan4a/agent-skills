# sandbox.sh patterns

All snippets assume the usual header:

```bash
#!/usr/bin/env bash
# Eval sandbox for <skill>: <what the world is>.
#   sandbox.sh setup <dir> <eval-id>   build the sandbox, print the session's cwd
#   sandbox.sh state <dir>             dump what the grader needs
set -euo pipefail
cmd=$1 S=$(realpath -m "$2") id=${3:-}
files=$(dirname "$(realpath "$0")")/files            # fixtures
skill=$(dirname "$(dirname "$(realpath "$0")")")    # the skill dir, for scripts it ships

if [ "$cmd" = state ]; then
  echo "== <tool> calls"; cat "$S/<tool>.log" 2>/dev/null || echo none
  # ...everything else a check needs
  exit 0
fi

mkdir -p "$S/bin" "$S/home"
cat > "$S/env.sh" <<ENV
export PATH=$S/bin:\$PATH
ENV
# ...build the world
echo "$S/<cwd>"
```

`setup` prints only the cwd on stdout; send anything else to stderr or
`/dev/null` (`git clone -q ... 2>/dev/null`).

## Fake CLI that logs calls and keeps state

Unquoted heredoc: `$S` is baked in at setup, `\$` is evaluated when the agent
calls it. `%q` keeps arguments with spaces readable in the log.

```bash
: > "$S/tabs"
cat > "$S/bin/herdr" <<STUB
#!/usr/bin/env bash
printf 'herdr' >> "$S/herdr.log"; printf ' %q' "\$@" >> "$S/herdr.log"; echo >> "$S/herdr.log"
n=\$(grep -c 'tab create' "$S/herdr.log")
case "\$1 \$2" in
  "tab list") echo "{\"result\":{\"tabs\":[{\"tab_id\":\"t1\",\"label\":\"Main\"}\$(cat "$S/tabs")]}}" ;;
  "tab create")
    label=\$(printf '%s\\n' "\$@" | grep -A1 -x -- --label | tail -1)
    printf ',{"tab_id":"t1%s","label":"%s"}' "\$n" "\$label" >> "$S/tabs"     # remembered: tab list shows it
    echo "{\"result\":{\"tab\":{\"tab_id\":\"t1\$n\"}}}" ;;
  *) echo '{"result":{}}' ;;
esac
STUB
chmod +x "$S/bin/herdr"
```

- Return the shape the real tool returns (copy one real response); agents
  parse it.
- Anything a later call would show (a tab, a workspace, a created issue) goes
  into a state file the fake reads back. A fake that forgets makes the agent
  retry or "test" the tool, and the log gets noisy.
- To force a fallback path, make one subcommand fail (`exit 1`) and say so in
  a comment.
- Per-eval worlds (an already open tab, a busy agent) are files that `setup`
  writes in `case $id`.

## Git repos and a fake origin

```bash
git_() { git -c user.name=Test -c user.email=test@example.com -c init.defaultBranch=main "$@"; }
git_ init -q --bare "$S/origin/app.git"
git_ clone -q "$S/origin/app.git" "$S/app" 2>/dev/null
( cd "$S/app"; echo "package main" > main.go; git_ add -A; git_ commit -qm init; git_ push -q origin main
  git remote set-head origin main )
```

Put the git identity into `env.sh` too (`GIT_AUTHOR_NAME`, ...), so the agent's
commits work. A merged branch: push it to `main` of the bare origin. A squash
merge: clone origin to a temp dir, `merge --squash` the branch there, commit,
push, delete the clone.

For a repo that only pretends to be on GitHub, set
`git remote add origin https://github.com/acme/app.git`; nothing can be pushed
from the sandbox anyway.

## gh that is not logged in

```bash
cat > "$S/bin/gh" <<STUB
#!/usr/bin/env bash
printf 'gh' >> "$S/gh.log"; printf ' %q' "\$@" >> "$S/gh.log"; echo >> "$S/gh.log"
echo "To get started with GitHub CLI, please run:  gh auth login" >&2; exit 4
STUB
```

The agent can try, the log shows what it tried, nothing is published.

## A script the skill ships

```bash
cp "$skill/scripts/wt" "$S/home/.local/bin/wt"    # a copy, not a link
```

A link resolves into the skill's directory, and a `without_skill` run then
finds SKILL.md next to the script. Same for templates and fixtures: copy.

## Settings and dotfiles

Claude Code refuses to let a session edit its own `~/.claude/settings.json`.
For an eval about configuring hooks or settings, keep the real file in
dotfiles and link it:

```bash
mkdir -p "$S/home/.claude" "$S/home/dotfiles/claude"
echo '{ "permissions": { "allow": [] } }' > "$S/home/dotfiles/claude/settings.json"
ln -s ../dotfiles/claude/settings.json "$S/home/.claude/settings.json"
```

and print `$S/home/dotfiles/claude/settings.json` in `state`.

## Fixtures

Small fixture trees (a plugin, a project with a known bug) go to
`evals/files/<name>/` and are copied in `case $id`:

```bash
case $id in 2) cp -r "$files/weather" "$S/home/.config/app/plugins/weather" ;; esac
```

Generate binary fixtures in `setup` instead of committing them (a PNG of the
right size from a few lines of Python). A 1x1 placeholder image reads as a
placeholder, and the agent treats it like one.

## What state prints

- Logs of every fake CLI (or `none`).
- `git status --short`, `git worktree list`, branches, current branch.
- Changed and new files, with contents when short; the original of a changed
  file (`git show HEAD:README.md`) so the grader can diff.
- File modes when the check is about permissions (`stat -c %a`).
- The output of a validator the real tool has (`app validate <dir>`).

## Faking `claude` itself

For a skill that starts agent sessions (a runner, a handoff), put a fake
`claude` on the sandbox's `PATH` that logs its arguments and prints one
`{"type":"result",...}` line: runs stay cheap and never nest real sessions.
`run-evals` resolves the real `claude` before sourcing `env.sh`, so the fake
only reaches the agent under test.
