---
name: skill-evals
description: Write and run evals for an Agent Skill - prompts with concrete checks, a throwaway sandbox per run (fake CLIs, fake git remotes, a home of its own), runs with and without the skill in Claude Code, grading against the checks and comparing the two. Use when the user wants to test, benchmark or prove a skill they wrote, add evals or an evals.json to a skill, write a sandbox.sh, run a skill's evals, grade eval runs, or asks whether their skill actually changes what the agent does. Not for evaluating a model or an LLM app (that is a different kind of eval).
license: MIT
---

# Evals for an Agent Skill

An eval answers one question: does the agent behave differently, and better,
with the skill than without it? So every eval is run twice, `with_skill` and
`without_skill`, in identical sandboxes, and graded against the same checks.
A check that passes without the skill proves nothing about the skill.

## When evals are worth it

Worth it when the skill changes what the agent does: rules it would otherwise
break, an order of steps, a bundled script it should call instead of improvising,
something it must not do. Write one eval per rule that matters, 3-5 per skill;
aim each at a place where an agent without the skill goes wrong.

Not worth it for a skill that only holds reference facts the model already
knows; a quick read-through does more there.

## Layout

Evals live inside the skill, so they ship with it (a few KB):

```
<skill>/
  SKILL.md
  evals/
    evals.json    prompts and checks
    sandbox.sh    builds the world for one run, dumps its end state
    files/        fixtures sandbox.sh copies in (optional)
```

`evals.json` uses skill-creator's format, so its grader and viewer work on it:

```json
{
  "skill_name": "my-skill",
  "evals": [
    {
      "id": 1,
      "name": "short-kebab-name",
      "prompt": "What a user would type, with the details a real user gives and nothing that names the skill's rules",
      "expected_output": "One or two sentences: what a good run does",
      "files": ["evals/sandbox.sh"],
      "expectations": ["One concrete, checkable statement per item"]
    }
  ]
}
```

The prompt is a real request. Don't hint at the answer ("use wt", "make sure
the label has an emoji"): then the run without the skill passes too and the
eval measures the prompt, not the skill.

## Expectations: checkable, not vibes

A grader reads three things: `transcript.md` (every tool call and result),
`outputs/state.txt` (what `sandbox.sh state` printed after the run) and
`outputs/final.md` (the last reply). Each expectation must be decidable from
them by someone who has not read the skill.

| Vague | Checkable |
|---|---|
| Opens tabs with good names | The herdr log shows exactly three `tab create` calls; the AUR one's label starts with 🔍 |
| Cleans up properly | The fix/merged worktree and branch are gone; fix/dirty still exists with notes.txt intact |
| Handles errors well | The CLI restores the file with mode 0600 and refuses a path containing `..` (state shows both) |
| Writes a good README | The README keeps every install command from the original (diff in state) |

Include:
- **Negative checks.** "Did not run `rm -rf`", "notes/ideas.md is unchanged",
  "no file in acme/web was changed". Agents without a skill fail most often by
  doing too much.
- **The method, when the skill prescribes one.** "Used `wt clean`, not hand-run
  `git worktree remove`" (visible in the transcript).
- **The reply, when it matters.** "The final reply names the branch and worktree path".

Re-read each expectation against the skill text. If the skill allows two ways,
the check accepts both; a check stricter than the skill fails good runs.

## sandbox.sh

One script, two commands. The runner calls it for every run:

```
sandbox.sh setup <dir> <eval-id>   build the world in <dir>, write <dir>/env.sh, print the session's cwd
sandbox.sh state <dir>             print everything the grader needs about the end state
```

- Everything lives under `<dir>`: the run's `HOME` is `<dir>/home`, the agent
  can write only inside `<dir>`. Never touch real config, repos or services.
- `env.sh` is sourced before the session starts: `PATH` with fake CLIs first,
  env vars the scenario needs (`HERDR_ENV=1`, a `WT_ROOT`, git identity).
- `case $id in` for per-eval worlds; shared setup above it.
- `state` dumps logs of fake CLIs, `git status`/`worktree list`/branches,
  changed files (with contents if short), the original of what was changed.
  If a check needs it, `state` prints it. The grader can't see the sandbox.

Patterns, with code, in [references/sandbox-patterns.md](references/sandbox-patterns.md):

- **Fake CLI that logs every call** for anything external (a multiplexer, `gh`,
  a cloud CLI). It returns plausible output and **remembers what it created**:
  if `tab list` does not show the tab just made, the agent "tries out" another.
- **Fake remote**: a bare repo as `origin`, merges and squash-merges done by a
  temp clone, so "merged" is real git state.
- **Not logged in** `gh` for anything that would publish: the agent can try,
  the log shows it, nothing leaves the machine.
- **Copy, don't link** a script the skill ships: a run without the skill must
  not find the skill next to it.
- **Settings through dotfiles**: a session can't edit its own
  `~/.claude/settings.json`; put the real file in `~/dotfiles` and symlink it.
- **cwd outside the repo** whose `.git` the task changes (removing worktrees):
  Claude Code's sandbox mounts over the cwd repo's `.git`.

Test `setup` and `state` by hand before the first run:
`d=$(mktemp -d); evals/sandbox.sh setup $d 1 && . $d/env.sh && evals/sandbox.sh state $d`.

## Running

Runs use Claude Code (`claude -p`); the format itself is portable, any agent
runner can use the same evals.json and sandbox.sh.

```bash
MODEL=claude-opus-5-5 scripts/run-evals <skill dir> /tmp/evals/<skill>/iteration-1 [eval id...]
```

`scripts/run-evals` is in this skill's directory. Env: `MODEL` (default: the
CLI's), `JOBS` (parallel runs, default 4), `CONFIGS` (default
`with_skill without_skill`; `CONFIGS=with_skill` to iterate on a fix cheaply).

Each run gets its own `HOME`, only project settings (no user CLAUDE.md, plugins
or hooks), Bash inside Claude Code's sandbox, and no `CLAUDE*`/`HERDR_*` vars
of the calling session. `with_skill` copies the skill (without `evals/`) into
the sandbox's `.claude/skills/`, the way an installed skill is offered. Output,
per run: `eval-<id>-<name>/<config>/run-1/{transcript.jsonl,transcript.md,timing.json,outputs/{final.md,state.txt},sandbox/}`
and `eval-<id>-<name>/eval_metadata.json`.

- Write output under `/tmp/evals/`, not inside an agent scratchpad: nested
  sandboxes there fail with bwrap errors.
- A run costs real tokens; say how many runs (evals x configs) before starting.
- User skills and plugins are not loaded (only built-ins), so a copy of the
  skill you have installed does not leak into `without_skill` runs.

## Grading

For each run, check every expectation against `transcript.md`, `state.txt` and
`final.md`, and write `grading.json` next to `outputs/`:

```json
{"expectations": [{"text": "<the expectation>", "passed": true, "evidence": "state: herdr log has 3 tab create calls"}],
 "summary": {"passed": 6, "failed": 1, "total": 7, "pass_rate": 0.86}}
```

- Grade from the state and the transcript, not from what the agent says it did:
  "I removed the worktree" in `final.md` counts only if `state.txt` agrees.
- Evidence quotes or points at the line. "Looks fine" is not evidence.
- One subagent per run (or skill-creator's grader agent) keeps grading fast and
  unbiased; give it the expectations and the three files, not the skill.

Compare the configs:

```bash
cd /tmp/evals/<skill>/iteration-1
for c in with_skill without_skill; do
  jq -s --arg c $c '{config: $c, passed: (map(.summary.passed) | add), total: (map(.summary.total) | add)}' */$c/run-1/grading.json
done
```

skill-creator's `aggregate_benchmark` and viewer also read this layout.

## Iterating

- **Fails with the skill**: read the transcript. Either the skill is unclear or
  silent on it (fix the skill, bump its version) or the check is wrong (fix the
  check; say so, don't quietly loosen it).
- **Passes without the skill**: the eval doesn't measure the skill. Make the
  prompt more realistic, aim at a rule the agent really breaks, or drop it.
- **Flaky**: one run per eval is a smoke test; rerun the eval a few times
  before trusting a single pass or fail that decides something.
- New run after a change: `iteration-N+1`, so the old one stays to compare.
- After a change to the skill, rerun at least the evals that cover it.
