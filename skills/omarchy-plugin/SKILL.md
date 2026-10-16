---
name: omarchy-plugin
description: Write, debug and publish plugins for the Omarchy shell (Quattro, Quickshell/QML) - bar widgets, panels, services, overlays, menus and full bars. Use when creating or changing anything under ~/.config/omarchy/plugins/, writing a manifest.json for Omarchy, working in any repo that has an Omarchy plugin manifest.json (often symlinked from ~/.config/omarchy/plugins/ to a project checkout), changing the companion CLI or daemon a published plugin runs or installs, making a widget work across several monitors, or submitting or re-verifying a plugin in the Omarchy plugin marketplace (omacom/omarchy-plugin-marketplace).
license: MIT
---

# Omarchy plugins

Omarchy's bar, panels, notifications and overlays run in one long-lived
Quickshell process (`omarchy-shell`). A plugin is a folder with a
`manifest.json` and QML entry points in `~/.config/omarchy/plugins/<id>/`.

The shell changes quickly between releases. When this skill and the installed
shell disagree, the shell wins: read the source under
`/usr/share/omarchy/shell/` (`$OMARCHY_PATH/shell`):

- `services/PluginRegistry.qml`: the manifest schema and enable rules
- `Ui/*.qml` and `Ui/qmldir`: the UI kit; `Commons/*.qml`: colors, sizes, helpers
- `Ui/PluginBarApi.qml`, `services/PluginShellApi.qml`: what a third-party plugin may call
- `plugins/panels/*/`: first-party widgets and panels to copy patterns from

## Workflow

1. **Pick the kinds.** Most plugins are `["service", "bar-widget"]`: a service
   that does the work once, and a bar widget that shows it on every monitor.
   Add a panel by loading `Panel.qml` from the widget (see the template).
   `panel`, `overlay` and `menu` kinds are separate surfaces summoned by id;
   `bar` replaces the whole bar.
2. **Start from `template/`.** It is a complete, working `service` +
   `bar-widget` + panel plugin. Copy it, then replace
   `io.github.yourname.loadavg` everywhere: manifest `id`, `moduleName`s, the
   `IpcHandler` target. IDs: lowercase `[a-z0-9._-]`, never `omarchy.*`,
   permanent once published. `io.github.<user>.<name>` is the safe form.
3. **Develop in place.** Use a real directory (a git checkout), not a symlink:
   `~/.config/omarchy/plugins/<id>/`. `omarchy plugin validate` rejects
   symlinks, and the file watcher that hot-reloads plugins does not follow them.
4. **Validate, load, enable:**
   ```bash
   omarchy plugin validate ~/.config/omarchy/plugins/<id>   # silent, exit 0 when valid
   omarchy-shell shell rescanPlugins          # the new id must be known first
   omarchy plugin enable <id> right           # or: left, center, --after omarchy.clock
   ```
5. **Watch the log** while you work. Saving a file reloads plugin code.
   ```bash
   qs log -p /usr/share/omarchy/shell -f | grep -iE "<id>|PluginRegistry|failed"
   ```
   `qmllint` works on a copy anywhere, but flags the shell's `qs.*` imports
   and `onExited` types as unknown: ignore those.
   A rejected manifest is only a `PluginRegistry:` warning there; the plugin
   silently does not appear. A `keepLoaded` service keeps its old code until
   `omarchy restart shell`.
6. **Test on every monitor, and with the panel opened from a hotkey**
   (`omarchy-shell shell toggle <id>` opens it on the focused monitor).
7. **Clean up after experiments:** `omarchy plugin disable <id>`, remove the
   folder, `omarchy-shell shell rescanPlugins`.
8. **Present it before publishing**, not after listing: check the panel
   layout, a 1920x1080 `preview.png` from a real screenshot on demo data, a
   README header with badges and the preview, repo topics, tags and CI. Follow
   `references/presentation.md`. Open the panel yourself over IPC
   (`omarchy-shell shell toggle <id>`), never with synthetic key presses.
   Show the user the image and check it for personal data before committing.

## Several monitors: the rules

The bar exists once per screen, so every bar widget, and every panel it loads,
exists once per screen too. Monitors come and go: instances are created and
destroyed at any time. A service is created once for the whole shell.

- **State and work go in the service.** Polling timers, `Process` calls, file
  watches, notifications, network requests: in a widget they run N times, and
  side effects (a notification, a write, an install) happen N times.
- **Widgets only bind and forward.** Reach the service with
  `bar && bar.shell ? bar.shell.serviceFor(moduleName) : null`; it can be null
  at first, so bind defensively.
- **Settings flow widget -> service.** Only widgets receive `settings`; a
  service cannot read its own. Push them in from the widget (`configureSource()`
  in the template). Every monitor pushes the same values, so that is idempotent.
- **IPC lives in the service.** An `IpcHandler` in a widget is registered per
  monitor; Quickshell keeps the first and logs "Handler was registered but will
  not be used". For a widget-only plugin, fan out with `broadcast("method")`.
  For panels, set `manageIpc: false` and let `omarchy-shell shell toggle <id>`
  pick the focused monitor's instance.
- **Route async answers to the panel that asked.** When a panel starts
  something slow through the service (an AI call, a scan), every monitor's
  panel sees the result signal. Remember the request key in the asking panel
  and ignore results that are not yours, and never overwrite what the user is
  typing in another panel.
- **Popout identity.** In a widget that loads a panel, the bar knows the slot by
  the widget. Give the panel `hostWidget`, use `owner: hostWidget || root` and
  `bar.switchPanelFrom(owner, direction)` for Tab, and expose `opened`,
  `open()`, `close()`, `popoutSwitchClosing` and `closeForPopoutSwitch()` on
  the widget root.
- **`panel`/`overlay`/`menu` kinds have one instance, not one per screen.**
  Need a surface on each screen? Use `Variants { model: Quickshell.screens }`.
- **`allowMultiple` is metadata only.** Several layout entries with the same id
  are several instances. `shell.updateEntryInline(id, settings)` rewrites
  every entry with that id, and replaces the whole entry: pass full settings.

## Things that bite

- **Settings are not merged with defaults.** `defaults` and `schema` in the
  manifest only describe the settings form: values are not validated. Always
  read with `setting(key, fallback)` and clamp numbers yourself.
- **Run commands as argv arrays**, `["tool", "--flag", value]`. Never build a
  `sh -c` string from data. If you need a shell, pass data as positional
  arguments: `["sh", "-c", 'tool "$1"', "sh", value]`.
- **Private data never goes in argv.** Command lines are readable by every
  local user (`/proc/<pid>/cmdline`), and that includes every helper a script
  starts. This is the review finding raised most often. Private means more
  than tokens:
  - API responses or any field of them passed to a helper:
    `jq --arg/--argjson x "$resp"`, `grep "$x"`, `notify-send "$title" "$body"`;
  - URLs (hosts, IDs, filters), request bodies (`curl -d '{...}'`), headers;
  - prompts, diffs, notes, message text, notification bodies.

  Pattern that passed review:
  - curl reads everything from a `-K -` config on stdin
    (`header = "Authorization: Bearer ..."`, `url = "..."`); the body comes
    in through the process environment and a heredoc on fd 3
    (`--data-binary @/dev/fd/3 3<<END`). Quickshell `Process.environment`
    is added to the shell's environment (unless `clearEnvironment`), and a
    process's environment is readable only by the same uid.
  - Refuse a value written into a curl config if it has `"`, `\` or a
    newline: server data could otherwise add options (`output = ...`).
  - Responses travel only through pipes: `printf "%s" "$r" | jq ...` (printf
    is a builtin). Combine several JSON documents with
    `{ printf "%s" "$a"; printf "%s" "$b"; } | jq -s ...`, not `--argjson`.
  - Drop private fields you do not need as early as possible:
    `jq "[.results[] | {id, name}]"`.
  - With curl, user text goes as `--data-binary`, never `-d`/`data`: they read
    a value starting with `@` as a file name to upload.
- **Notifications have no plugin API, and `notify-send` puts its text in
  argv.** Reviewers reject alert names, job names or env values there. Notify
  with a count only ("3 new alerts", the panel shows the rest), or make the
  D-Bus call directly without a subprocess.
- **Links from server data** (`generatorURL` and the like) open only if they
  match `^https?://`, never `file://` or app schemes.
- **Files: state dirs 0700, files 0600.** Atomic temp-and-rename writes must
  keep the destination's mode, not widen it to 0644. Keep private files out of
  shared `/tmp`; use `$XDG_RUNTIME_DIR` or `~/.local/state/<id>/`.
- **Nothing installs, enables or edits config without an explicit click.**
  Packages, services, files of other programs: show what will happen, ask,
  then do it. Pin versions (`go install mod@vX.Y.Z`, full SHAs), never
  `curl | sh`.
- **Text from outside the shell** (file names, SSIDs, API data) gets
  `textFormat: Text.PlainText` and `elide`. Default AutoText renders it as
  rich text.
- **No `TextField`/`TextInput`/`TextEdit`/`TextArea`, the kit's included.**
  Qt 6.12 text inputs read foreign clipboard text by themselves on every
  clipboard change (to know whether they could paste), with no size limit or
  deadline, whether hidden or focused; a clipboard owner that streams forever
  stalls the whole shell. Creating the field through a `Loader` only while
  typing does not help: it still reads while the user types, and reviewers
  rejected that workaround. Copy `template/LineEdit.qml` next to your QML and
  use it instead: a one-line editor on key events that pastes only on Ctrl+V,
  through `wl-paste` in its own process with a timeout and a size cap.
  ```qml
  LineEdit {
    id: input
    width: parent.width
    placeholderText: "New note"
    foreground: root.foreground
    onAccepted: { root.source.save(text); text = "" }
    onCanceled: root.close()
  }
  ```
- **Keyboard:** `KeyboardPanel` needs a `focusTarget`. `PanelKeyCatcher`
  sees keys before children, so set `blocked: input.activeFocus` while an
  inline `LineEdit` is focused, or h/j/k/l, x and Enter never reach it.
- **Colors and sizes are bindings.** Use `bar.foreground`, `Color.*` and
  `Style.space(px)`; never copy a value once, or theme and font-size
  changes will not apply.
- **Destructive actions take two clicks** (arm, then confirm within a few
  seconds) or a `ConfirmDialog`.
- **A missing helper binary** (`command -v` fails) should show which package
  is missing in the panel ("needs github-cli"), not an endless error and not
  an install command: `sudo`, `pacman -S` and the like in any scanned file,
  QML strings included, flag the plugin in the marketplace scan. Run it
  through `sh -c 'command -v "$0" || exit 127; exec "$0" ...'` to tell
  "missing" (exit 127) from "failed".
- **Saved state is loaded on start.** A service that writes a file (notes,
  history, a cache) reads it back when it is created, before its first
  write; otherwise the first save after `omarchy restart shell` overwrites
  everything saved before.

## Companion CLI

When the plugin runs or installs its own CLI or daemon (`go install
mod@vX.Y.Z`), reviewers read that code too, with the same rules, plus:

- **Files of other programs only through confined operations.** Open the
  directory once with Go `os.OpenRoot` and write, rename and remove through
  the `*os.Root`, so a symlink or `..` in a stored path cannot reach outside
  it. Never create symlinks that point out of it.
- **Reading user files:** open with `O_NOFOLLOW|O_NONBLOCK`, check the type
  on the open fd (`f.Stat()`, regular file only), then read through
  `io.LimitReader(f, max+1)`. A path swapped for a FIFO otherwise hangs the
  process; a size check before reading misses a file that is still growing.
- **A file restored after deletion is created 0600.** git and similar stores
  do not keep the mode; a restored `~/.claude/settings.json` that was 0600
  would come back 0644. An existing file keeps its mode.
- **Copying user files** (history, backups, snapshots): a secret filter is
  a heuristic, so also refuse paths that hold keys or passwords: `.ssh`,
  `.gnupg`, `.netrc`, `.pgpass`, `.git-credentials`, `.kube`, `.aws`,
  `.docker`, `*_history`, and the like. A check that errors refuses the file
  (fail closed).
- **Pin a CLI version that has every command the QML calls.** Bumping the
  QML to call a new subcommand without bumping the pinned tag ships a button
  that fails. See the release checklist in `references/marketplace.md`.

## References

- `references/manifest.md`: every manifest field, kinds, settings schema
  types, `omarchy plugin` commands, `shell.json`
- `references/runtime.md`: what the shell injects, the `bar` and `shell`
  facades, panel lifecycle, IPC
- `references/ui-kit.md`: the `qs.Ui` components and `qs.Commons`
  singletons, keyboard conventions, the two widget + panel patterns
- `references/marketplace.md`: submitting to the marketplace, the automated
  security baseline, labels, updates after listing, a pre-submission checklist
- `references/presentation.md`: how the plugin looks when published: layout
  check, the 1920x1080 preview, README header and badges, repo topics, tags,
  CI; updated with each new lesson
- `template/`: the working example plugin; `LineEdit.qml` is the text input to copy when a panel needs one
