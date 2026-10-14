---
name: herdr-tabs
description: Split parallel ideas into separate Herdr tabs, one agent session per idea, with consistent tab names (emoji type + topic) and a short report back to the session that spawned them. Use inside Herdr (HERDR_ENV=1) when the user brings several independent ideas, questions or tasks at once, asks to "разнеси по вкладкам", "open a tab for this", "start a session for each", or a new topic comes up that should not derail the current session. Not for separate workspaces or git worktrees (code tasks in a repo go through parallel-worktrees).
license: MIT
---

# Parallel ideas in Herdr tabs

One idea = one tab = one agent session, all in the **current workspace**. The
tab name says what kind of work it is and what it is about, so the user can
find it in the sidebar at a glance. Each tab reports back to the session that
opened it when it is done.

Check first: `test "${HERDR_ENV:-}" = 1`. Outside Herdr, do not run `herdr`
(not even `--help`) and do not ask how to proceed: say it is not inside Herdr,
then write one brief per idea right away, each under its label in its own code
block, ready to paste into a new session (brief format below, with the reply
line replaced by "end with a 2–3 line summary prefixed with `[<label>]`").

## When to split

- The user asks for it, or lists two or more ideas that can move independently.
  List the tabs you are about to open (label + one line each) and open them.
- One idea that depends on another's outcome stays in the same tab, or waits.
- A topic that already has a tab (see `herdr tab list`) goes to that tab's agent
  (`herdr agent prompt <its pane>`), not to a new tab.

Tabs share the workspace's checkout. A tab whose idea turns into code changes
in a repo starts its own worktree (parallel-worktrees, `wt new`); two tabs never
edit the same files.

## Naming

Label: `<emoji> <topic>`.

| Emoji | Kind of work |
|---|---|
| 💡 | idea, discussion, design: the outcome is a decision or a plan |
| 🔧 | task: the outcome is a change (files, config, a PR) |
| 🔍 | research: the outcome is an answer or a summary |

Topic: 1–2 words in kebab-case, about the subject, not the action
(`aur`, `readme-refresh`, `dark-mode`, not `research-the-aur-thing`), at most
20 characters. Unique among the workspace's tabs: on a clash, narrow it
(`syschange-aur`). Agent name: the topic itself (Herdr names allow
`[a-z][a-z0-9_-]{0,31}`). When a tab's work changes kind or topic, rename it:
`herdr tab rename "$HERDR_TAB_ID" "🔧 dark-mode"`.

## Opening a tab

Per idea, in the current workspace and directory, without taking the user's
focus. Use the same agent kind as this session unless the user asks otherwise:

```bash
pane=$(herdr tab create --workspace "$HERDR_WORKSPACE_ID" --cwd "$PWD" --label "💡 dark-mode" --no-focus \
  | jq -r '.result.root_pane.pane_id')
herdr agent start dark-mode --kind claude --pane "$pane"
herdr agent prompt dark-mode "$(cat <<BRIEF
<brief>

When you are done, or blocked on the user, send a 2–3 line summary to the session that opened this tab:
herdr agent prompt $HERDR_PANE_ID "[💡 dark-mode] <result, what is left>"
Do not close this tab.
BRIEF
)"
```

The brief is the new session's only context. Write it so a stranger could
continue: the idea in the user's words, what is already known (files with
`file:line`, links, decisions), constraints, what counts as done, the first step.
Keep the reply-to line: `$HERDR_PANE_ID` is this session's pane, expanded when
the prompt is sent. The pane id from `tab create` is the confirmation that the
tab exists: never open extra tabs to test or debug Herdr.

After opening, tell the user the tab labels in one line and do not work on
those ideas from this session.

## In a tab that was opened this way

- Do the idea, nothing else. A new unrelated topic: suggest a new tab.
- Report once at the end (or when blocked) with the line from the brief, as
  `[<label>] <result>`. Do not close the tab: the user closes it, or asks to.
