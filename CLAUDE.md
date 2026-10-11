# agent-skills: rules for agents working in this repo

- Each skill is a plugin in `.claude-plugin/marketplace.json`. Any change under `skills/<name>/` bumps that
  plugin's `version` in the same commit: installed copies only update when the version changes.
- After pushing such a change to `main`, end your reply with the command to update the local install, for every
  plugin that changed (the user runs it; it needs `/reload-plugins` or a restart afterwards):
  ```bash
  claude plugin marketplace update dan4a-skills && claude plugin update <name>@dan4a-skills
  ```
