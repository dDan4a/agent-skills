# Runtime: what a plugin gets from the shell

Sources: `/usr/share/omarchy/shell/shell.qml` (loaders), `plugins/bar/Bar.qml`
(widget slots), `Ui/PluginBarApi.qml`, `services/PluginShellApi.qml`,
`services/PluginRegistryApi.qml`.

## Injection

The shell sets a property only if your root object declares it
(`property var shell: null` and so on).

| Entry point | Injected |
|---|---|
| bar widget | `bar` (a `PluginBarApi`), `moduleName` (the entry id), `settings` (the layout entry minus `id`; re-set when it changes) |
| service | `omarchyPath`, `shell`, `manifest`, `pluginRegistry`, `barWidgetRegistry` |
| panel / overlay / menu | the service list, plus `service` (= your own service, if any) |
| bar | the service list, plus `barConfig` |

Third-party plugins get scoped facades, not the host objects. `manifest` is a
public copy with internal fields removed.

## `shell` (PluginShellApi)

| Member | Notes |
|---|---|
| `pluginId` | |
| `serviceFor(id)` | **Your own id only** (or the built-in you were cloned from); null otherwise, and null until the service exists. Bindings that call it update when it appears. |
| `summon(id, payloadJson)`, `hide(id)`, `toggle(id, payloadJson)`, `isPluginOpen(id)` | Own id only (bar plugins: configured UI plugins). |
| `updateEntryInline(id, settings)` | Replaces the whole entry with `{id, ...settings}`, in every layout entry with that id. Pass the full merged object. |
| `bar` | `barHidden`, `barSize`, `fontFamily`, `position` |
| `barConfig`, `idleConfig` | Detached copies. |
| `appLibrary` | `menu` kind only: `sortedEntries(query)`, `iconSource`, `launch(desktopId, name)`, signal `appsChanged`. |

There is no `shellConfig`. To read `plugins[]` settings, use a `FileView` on
`~/.config/omarchy/shell.json`.

## `bar` in a widget (PluginBarApi)

- Live values: `foreground`, `barForeground`, `background`, `urgent`,
  `fontFamily`, `position`, `vertical`, `barSize`, `transparent`,
  `activePopout`, `layoutConfig`, `shell` (your scoped `PluginShellApi`).
- Methods: `showTooltip(target, text)`, `hideTooltip(target)`,
  `registerClickTarget(t)`, `unregisterClickTarget(t)`, `requestPopout(owner)`,
  `releasePopout(owner)`, `switchPanelFrom(owner, direction)`,
  `moduleWidgets(id)` (own id), `run(command)`,
  `setCenterHoverRevealSuppressed(bool)`.
- `bar.shellQuote` exists only on the built-in bar, not on this facade.
  Prefer argv arrays anyway.
- Guard calls: `if (bar && typeof bar.switchPanelFrom === "function")`.

`BarWidget` (from `qs.Ui`) adds `setting(name, fallback)`, read-only
`vertical`/`barSize`, and `broadcast(method)`, which calls `method` on every
live instance (every monitor).

## Panel lifecycle

- `summon` activates the loader (asynchronously), then calls
  `item.open(payloadJson)` once per queued payload. Parse the JSON string
  yourself; it is `"{}"` when none was given.
- `hide` calls `item.close(null)` and unloads it, unless `keepLoaded`.
- A plugin that is only a `bar-widget` is summoned through the bar:
  `.open()` on the instance on the focused monitor, without the payload.
- Opening and closing follows `opened`, not `visible`: the window stays
  mapped for the 140 ms fade. Put close-time work on `onOpenedChanged`.
- Popouts: one at a time per bar. `bar.requestPopout(owner)` closes the
  previous one (`closeForPopoutSwitch()` when it has it).
  `KeyboardPanel` does this for you.

## IPC

```qml
IpcHandler {
  target: "io.github.yourname.loadavg"      // use your plugin id
  function refresh(): void { root.refresh() }
  function load(): string { return String(root.load) }  // typed: string, int, bool, real or void
}
```

```bash
omarchy-shell io.github.yourname.loadavg load      # wraps: qs ipc -p $OMARCHY_PATH/shell call ...
omarchy-shell -q io.github.yourname.loadavg refresh   # -q: always exit 0
omarchy-shell shell summon <id> '{"key":"value"}'  # open(payload) on a panel/overlay/menu
omarchy-shell shell toggle <id>                    # bar widgets: the focused monitor's instance
omarchy-shell shell call <id> <method> <arg>       # item[method](arg)
```

Only one handler per target is used: put it in the service. `Panel` creates
its own handler for `ipcTarget` (open/close/show/hide/toggle) unless
`manageIpc: false`.

Other `shell` IPC functions: `ping`, `rescanPlugins`, `reloadConfig`,
`listPlugins`, `enablePlugin(id, placementJson)`,
`setPluginEnabled(id, "true"|"false")`, `moveBarWidget`, `setBarWidget`,
`togglePanelAt(section, index)`.

## Running commands

```qml
Process {
  id: proc
  command: ["tool", "--json"]                 // argv, no shell
  stdout: StdioCollector { id: out; waitForEnd: true }
  stderr: StdioCollector { id: err; waitForEnd: true }
  onExited: function(exitCode) { /* parse out.text */ }
}
// proc.running = true starts it; set command first. Queue actions instead of
// starting a second run while one is running.
```

- Data for the command goes on stdin (`stdinEnabled: true`, then
  `proc.write(text)`; `stdinEnabled = false` closes it) or in a 0600 file, never
  in argv when it is private.
- Fire and forget, outliving the shell: `Quickshell.execDetached([...])`.
  For a terminal: `["setsid", "uwsm-app", "--", "xdg-terminal-exec",
  "--app-id=org.omarchy.terminal", "--title=...", "-e", "bash", "-c", script]`.
- Missing binary vs failure: `["sh", "-c", 'command -v "$0" >/dev/null || exit 127; exec "$0" "$@"', tool, args...]`.
- Notifications: `notify-send -a "Your App" -- summary body` puts the text in
  argv. Fine for generic text ("3 updates"); anything from data (names,
  titles, env values) was rejected. Count only, or call D-Bus directly
  without a subprocess.
