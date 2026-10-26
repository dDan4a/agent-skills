# Setting up `wt`

Needs bash (3.2 is enough, so stock macOS works), git 2.31+ and `jq`.
Optional: `notify-send` for desktop notifications, Herdr for `--agent`.

## Install

Put the script on `PATH`:

```bash
ln -s ~/.claude/skills/parallel-worktrees/scripts/wt ~/.local/bin/wt   # wherever the skill was installed
```

Repos can live anywhere: a repo's task worktrees go to `.worktrees/` next to
it (`~/code/shop/app` → `~/code/shop/.worktrees/app/<branch>`), so repos
cloned into one folder share it. `wt` without arguments prints its help.

Optional, for a `~/projects/<group>/<repo>` layout: `export WT_ROOT=$HOME/projects`
lets `wt new <group>/<repo>` and `wt sync <group>` run from anywhere, and
`wt sync`/`wt list` outside a project cover every group.

## Claude Code hook

`~/.claude/settings.json` (merge into an existing `hooks` object; the path is
where you put the link), so a finished session removes its merged worktree:

```json
"hooks": {
  "SessionEnd": [
    { "hooks": [ { "type": "command", "command": "$HOME/.local/bin/wt hook", "timeout": 60 } ] }
  ]
}
```

The hook reads the `cwd` field of the hook's JSON on stdin, finds the repo
from it and exits 0 whatever happens; it needs no `WT_ROOT`.

Then run the exact command you configured, the way Claude Code will, to catch a
wrong path. Outside a task worktree it changes nothing:

```bash
echo '{"cwd":"'"$PWD"'"}' | $HOME/.local/bin/wt hook; echo "exit $?"
```

Other agents (Codex, Gemini CLI, …) have no session-end event at the time of
writing. Run `wt sync` by hand, or from a session-start hook if the agent has
one; a merged worktree is then removed when the next session starts.

## Repo settings: `<repo>/.wt.conf`

Optional, sourced by bash. Commit it so the whole team gets the same settings;
`wt` reads it from the main checkout, so an uncommitted local one works too:

```bash
BASE=main                 # base branch; default: the remote's HEAD branch
REMOTE=origin             # remote to branch from and check merges against
INTEGRATION=dev           # a branch merged before BASE; only shown in the sync report
TASK_RE='PROJ-[0-9]+'     # task id at the start of branch names (<id>.<desc>):
                          # `wt hook` then also cleans <id>.* worktrees of the project's other repos

# Untracked files each new worktree needs (env files, local configs), as paths under
# src (the main checkout) and dst (the new worktree). Only link files git ignores: an
# untracked file counts as an uncommitted change and blocks cleanup.
link_local_files() {
  local repo=$1 src=$2 dst=$3
  ln -sfn "$src/.env" "$dst/.env"
}
```

The project's other repos are `$src/../<name>`.

## Agent instructions

Put the rules from `SKILL.md` (or a pointer to this skill) into the root
instructions file the agents read, for example `CLAUDE.md` or `AGENTS.md`,
so sessions follow them even when the skill is not loaded.

## Check

```bash
wt                 # help
wt list            # open task worktrees of the current project
wt sync --dry-run  # what cleanup would do
```
