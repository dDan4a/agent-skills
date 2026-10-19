---
name: parallel-worktrees
description: Run several coding-agent sessions at once without them stepping on each other - one task = one branch = one git worktree = one session, created with the bundled `wt` script and removed automatically once the branch is merged (merge or squash). Use when starting a task in a repo that other sessions may also be working in, handing a task off to a new agent session, setting up task worktrees for a group of repos, cleaning up merged worktrees, or when the user mentions `wt`, worktrees, parallel sessions or handoff.
license: MIT
---

# Parallel agent sessions on git worktrees

Several agent sessions working in one checkout overwrite each other's changes,
switch branches under each other and mix unrelated work into one commit. The
fix is boring: every task gets its own branch in its own git worktree, and
exactly one session works there.

## Layout

```
$WT_ROOT/                       # default ~/projects
  <group>/                      # one per client or kind of work
    .wt.conf                    # optional group settings (bash), see references/setup.md
    <repo>/                     # main checkout, stays on the default branch
    .worktrees/<repo>/<branch>/ # one task worktree per branch, e.g. .worktrees/api/fix/login
```

`wt` is `scripts/wt` in this skill. If it is not on `PATH`, see
`references/setup.md` (install, the SessionEnd hook, group settings).

## Rules

- **One task = one branch = one worktree = one session.** Two sessions never
  work in the same checkout.
- **The main checkout stays on its default branch.** Read from it, merge or
  release there when the user asks; do task work in a worktree.
- **Start a task with `wt new`**, not `git worktree add` or the agent's own
  worktree feature: `wt` puts the worktree where cleanup finds it and links
  the untracked files the group needs.
  ```bash
  wt new <group>/<repo> <branch>   # prints the worktree path; then work there
  wt new <repo> <branch>           # same, when run inside <group>/
  ```
  It branches from the remote's default branch (or `BASE` from `.wt.conf`)
  after a fetch. Run every later command in the printed path.
- **Branch names:** the tracker's id when there is one (`PROJ-431.short-desc`),
  else `feat/…`, `fix/…`.
- **Shared resources collide.** Two worktrees of one service fight over
  ports, docker compose project names and local databases. Run them with a
  distinct `COMPOSE_PROJECT_NAME` and port, or one at a time.
- **Global changes** (dotfiles, packages, services) affect every session:
  make them from one session at a time.
- **Push and merge are the user's call** unless they said otherwise. Before
  ending, say what is left: branch, worktree path, open PR/MR.
- **Never `rm -rf` a worktree.** Cleanup is automatic (below); to drop
  unmerged work, ask the user.

## Handing a task off (Herdr)

Inside Herdr, a terminal multiplexer for coding agents (`HERDR_ENV=1`), when a
session sitting in a main checkout gets a task, start the task in its own
session and keep this one free:

```bash
wt new <group>/<repo> <branch> --agent claude --brief - <<'BRIEF'
<task, what is known with file:line, constraints, open questions, the next step>
BRIEF
```

This creates the worktree in a Herdr workspace, starts the agent there
(`claude` or `codex`; add `--focus` to switch to it) and sends the brief as
its first message. `--role <name>` (Claude only) starts it as
`claude --agent <name>`, with the role file `.claude/agents/<name>.md`, and
forbids it `git push` and `gh pr create/merge/ready` (`--disallowedTools`). The
brief is the new session's only context: write it so a stranger could
continue. After the handoff, do not touch that task's code
from this session.

When you merge a handed-off branch from the main checkout, run
`wt clean <worktree path>` (or `wt sync <group>`) right after the push: it
removes the worktree and its Herdr workspace, and with it the child session,
which would otherwise sit idle. Do not `/exit` children by hand. A workspace
whose agent is still `working` or `blocked` is kept and reported. If `wt`
reports that removing failed, tell the user; do not remove the worktree,
branch or workspace by hand.

Without Herdr, `--agent` is refused: create the worktree and tell the user to
open a new session in the printed path, with the brief in your reply.

## Cleanup

A task worktree is removed, together with its local branch, when the branch
has reached the base branch (a normal merge, or a squash merge checked with
`git cherry`) and the worktree has no uncommitted changes. A branch with no
commits yet is kept. Untracked files count as uncommitted: keep build output
(`__pycache__`, `node_modules`, …) in `.gitignore` or the worktree stays. The
remote branch is not touched; delete it when merging (the forge's option).

- `wt hook`: the Claude Code `SessionEnd` hook. Cleans the session's own
  worktree; with `TASK_RE` set, also the same task's worktrees in the
  group's other repos. Does nothing outside `.worktrees` and does not update
  the main checkout: `wt sync` does.
- `wt sync [group] [--dry-run]`: per repo, fetch, fast-forward the local
  default branch, prune stale worktrees, remove merged ones and report on the
  rest (`✔` removed, `⚠` merged but dirty, `•` kept and why).
- `wt clean [path]`, `wt clean --all [group]`: the same check for one or all.
- `wt list`: every open task worktree and its uncommitted file count.

Inside Herdr, `wt new` also opens a workspace for the repo's main checkout.
Once the repo's last task worktree is removed, `wt` closes that workspace too,
unless it holds an agent or a running command, or is the caller's own.

Agents without a session-end hook: run `wt sync` when the user asks to tidy
up, or at the start of a session.

## Testing `wt` itself

Use a throwaway `WT_ROOT` (a bare `origin` plus a clone) and run `wt` with
`env -u HERDR_ENV`. Inside Herdr, `wt new` opens a Herdr workspace for every
test repo, and an interrupted test leaves them open. To test the Herdr path
itself, use a separate Herdr session (`herdr --session`) and stop it afterwards.
