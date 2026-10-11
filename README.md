# agent-skills

Skills for AI coding agents (Claude Code, Codex, Gemini CLI, Cursor and others
that read [Agent Skills](https://agentskills.io)).

| Skill | What it teaches |
|---|---|
| [`omarchy-plugin`](skills/omarchy-plugin/SKILL.md) | Writing, debugging and publishing [Omarchy](https://omarchy.org) shell plugins: the manifest, services and bar widgets that work across several monitors, panels and the UI kit, IPC, settings, and what the plugin marketplace review asks for. Comes with a working template plugin. |
| [`parallel-worktrees`](skills/parallel-worktrees/SKILL.md) | Running several agent sessions at once without collisions: one task = one branch = one git worktree = one session. Comes with `wt`, a script that creates task worktrees, hands a task off to a new session (in Herdr) and removes worktrees once their branch is merged, including squash merges, from a Claude Code `SessionEnd` hook. |

## Install

Any agent, with the [`skills`](https://github.com/vercel-labs/skills) CLI:

```bash
npx skills add dDan4a/agent-skills                         # pick from the list
npx skills add dDan4a/agent-skills --skill omarchy-plugin  # just this one
```

Claude Code, as a plugin marketplace:

```
/plugin marketplace add dDan4a/agent-skills
/plugin install omarchy-plugin@dan4a-skills
```

By hand: copy `skills/<name>/` into your agent's skills directory, for
example `~/.claude/skills/`, `~/.codex/skills/` or `~/.gemini/skills/`.

## Use

Ask for what you want; the agent loads the skill when it fits:

> Make an Omarchy bar widget that shows my GitHub notifications, with a panel listing them.

Skills read the installed sources first (`/usr/share/omarchy/shell/`) and
treat them as the truth, so they keep working as Omarchy changes.

## Evals

Every skill has evals in `skills/<name>/evals/`: `evals.json` (prompts and
the checks a run must pass, in the
[skill-creator](https://github.com/anthropics/skills/tree/main/skills/skill-creator)
format) and `sandbox.sh`, which builds a throwaway home, repos or plugins for
each prompt. `scripts/run-evals` runs every prompt with and without the skill
in Claude Code, isolated from your own settings and files:

```bash
MODEL=claude-opus-5-5 scripts/run-evals parallel-worktrees /tmp/evals/iteration-1
```

Then grade the runs against the expectations, for example with skill-creator's
grader and benchmark viewer.

## License

MIT
