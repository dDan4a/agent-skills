---
name: omarchy-plugin
description: Write, debug and publish plugins for the Omarchy shell (Quattro, Quickshell/QML) - bar widgets, panels, services, overlays, menus and full bars. Use when creating or changing anything under ~/.config/omarchy/plugins/, writing a manifest.json for Omarchy, making a widget work across several monitors, or submitting a plugin to the Omarchy plugin marketplace (omacom/omarchy-plugin-marketplace).
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
  local user (`/proc/<pid>/cmdline`). Prompts, diffs, notes, tokens, message
  text, notification bodies with personal content: send them on stdin or in a
  0600 file. This is the review finding raised most often.
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
- **Text fields exist only while typing.** A live `TextField` (Qt 6.12) reads
  the clipboard on every clipboard change to know whether it could paste,
  even while hidden; a clipboard owner that streams forever can stall the
  whole shell. Create it with a `Loader { active: editing }` and reach it as
  `loader.item`. Reviewers flag always-instantiated fields.
- **Keyboard:** `KeyboardPanel` needs a `focusTarget`. `PanelKeyCatcher`
  sees keys before children, so set `blocked: loader.item !== null &&
  loader.item.activeFocus` while an inline `TextField` is focused, or h/j/k/l,
  x and Enter never reach it.
- **Colors and sizes are bindings.** Use `bar.foreground`, `Color.*` and
  `Style.space(px)`; never copy a value once, or theme and font-size
  changes will not apply.
- **Destructive actions take two clicks** (arm, then confirm within a few
  seconds) or a `ConfirmDialog`.
- **A missing helper binary** (`command -v` fails) should show an install hint
  in the panel, not an endless error. Run it through `sh -c 'command -v "$0"
  || exit 127; exec "$0" ...'` to tell "missing" (exit 127) from "failed".

## References

- `references/manifest.md`: every manifest field, kinds, settings schema
  types, `omarchy plugin` commands, `shell.json`
- `references/runtime.md`: what the shell injects, the `bar` and `shell`
  facades, panel lifecycle, IPC
- `references/ui-kit.md`: the `qs.Ui` components and `qs.Commons`
  singletons, keyboard conventions, the two widget + panel patterns
- `references/marketplace.md`: submitting to the marketplace, the automated
  security baseline, labels, updates after listing, a pre-submission checklist
- `template/`: the working example plugin
