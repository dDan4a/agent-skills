# Setting up `wt`

Needs bash, git 2.31+, `jq`, GNU coreutils and findutils (Linux; on macOS
install `coreutils` and `findutils` and put their gnubin first on `PATH`).
Optional: `notify-send` for desktop notifications, Herdr for `--agent`.

## Install

Put the script on `PATH` and pick the projects root (default `~/projects`):

```bash
ln -s ~/.claude/skills/parallel-worktrees/scripts/wt ~/.local/bin/wt   # wherever the skill was installed
echo 'export WT_ROOT=$HOME/code' >> ~/.bashrc                           # only if not ~/projects
```

Repos go to `$WT_ROOT/<group>/<repo>`; a group with a single repo is fine.
`wt` without arguments prints its help.

## Claude Code hook

`~/.claude/settings.json`, so a finished session removes its merged worktree:

```json
"hooks": {
  "SessionEnd": [
    { "hooks": [ { "type": "command", "command": "$HOME/.local/bin/wt hook", "timeout": 60 } ] }
  ]
}
```

Hooks may not see `WT_ROOT` from your shell rc: if it is not `~/projects`,
write `WT_ROOT=$HOME/code $HOME/.local/bin/wt hook`. The hook reads the
session's `cwd` from stdin and exits 0 whatever happens.

Other agents (Codex, Gemini CLI, …) have no session-end event at the time of
writing. Run `wt sync` by hand, or from a session-start hook if the agent has
one; a merged worktree is then removed when the next session starts.

## Group settings: `<group>/.wt.conf`

Optional, sourced by bash for every repo of the group:

```bash
BASE=main                 # base branch; default: the remote's HEAD branch
REMOTE=origin             # remote to branch from and check merges against
INTEGRATION=dev           # a branch merged before BASE; only shown in the sync report
TASK_RE='PROJ-[0-9]+'     # task id at the start of branch names (<id>.<desc>):
                          # `wt hook` then also cleans <id>.* worktrees in the group's other repos

# Untracked files each new worktree needs (env files, local configs). Only link files git
# ignores: an untracked file counts as an uncommitted change and blocks cleanup.
link_local_files() {
  local repo=$1 src=$2 dst=$3
  case $repo in
    api) ln -sfn "$src/.env" "$dst/.env" ;;
  esac
}
```

`WT_GROUP=<group>` makes `wt new <repo> …` resolve the group from anywhere,
handy in a per-group wrapper script.

## Agent instructions

Put the rules from `SKILL.md` (or a pointer to this skill) into the root
instructions file the agents read, for example `$WT_ROOT/CLAUDE.md` or
`AGENTS.md`, so sessions follow them even when the skill is not loaded.

## Check

```bash
wt                 # help
wt list            # open task worktrees
wt sync --dry-run  # what cleanup would do
```
