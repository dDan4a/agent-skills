# manifest.json, commands and shell.json

Source of truth: `/usr/share/omarchy/shell/services/PluginRegistry.qml`
(`validateManifest`) and `/usr/share/omarchy/bin/omarchy-plugin-validate`.

## Example

```json
{
  "schemaVersion": 1,
  "id": "io.github.yourname.loadavg",
  "name": "Load Average",
  "version": "0.1.0",
  "author": "yourname",
  "license": "MIT",
  "description": "System load in the bar.",
  "kinds": ["service", "bar-widget"],
  "entryPoints": { "service": "Service.qml", "barWidget": "BarWidget.qml" },
  "barWidget": {
    "displayName": "Load Average",
    "description": "System load, with 1/5/15 minute averages in a panel",
    "category": "System",
    "aliases": ["load", "cpu"],
    "allowMultiple": false,
    "defaultSection": "right",
    "defaults": { "intervalSec": 5 },
    "schema": [
      { "key": "intervalSec", "type": "integer", "label": "Refresh every (seconds)",
        "min": 1, "max": 60, "step": 1, "defaultValue": 5 }
    ]
  },
  "keepLoaded": false
}
```

## Fields

| Field | Rules |
|---|---|
| `schemaVersion` | The number `1`. A string `"1"` is rejected. |
| `id` | Required. `^[a-z0-9][a-z0-9._-]*$` (the marketplace requires lowercase), no `..`, not `omarchy.*` (reserved), not a first-party id. The install directory must have the same name. Permanent once published. |
| `name`, `version` | Required, non-empty. |
| `author`, `license`, `description`, `homepage` | Optional for the shell. The marketplace requires `author` and `description` (≤ 500 characters). |
| `kinds` | Required, non-empty array. Any mix of the kinds below. |
| `entryPoints` | Required object. One key per kind; relative paths, no `..`, no leading `/`. The files must exist. Subdirectories are fine (`"qml/Service.qml"`). |
| `barWidget` | Bar widget metadata: see below. |
| `keepLoaded` | Panels, overlays and menus stay loaded between summons. A service survives plugin hot-reload and only picks up code changes on `omarchy restart shell`. |

There are no `permissions`, `dependencies` or `minShellVersion` fields.
`activation` is ignored. `omarchy.clonedFrom` is set by `omarchy plugin clone`.
`omarchy.capabilities` is honoured only for first-party plugins.

### Kinds

| Kind | entryPoints key | Instances |
|---|---|---|
| `service` | `service` | One, created when the plugin is enabled. Headless. |
| `bar-widget` | `barWidget` | One per monitor (one per layout entry per monitor). |
| `panel` | `panel` | One, loaded when summoned (or always with `keepLoaded`). |
| `overlay` | `overlay` | Same as `panel`; full-screen surface. |
| `menu` | `menu` | Same as `panel`; also receives `appLibrary`. |
| `bar` | `bar` | Replaces the whole bar when selected as `bar.id`; falls back to the built-in bar if it fails. |

A plugin with several of `panel`/`overlay`/`menu` gets one loader: `panel`
wins, then `overlay`, then `menu`.

### barWidget block

| Key | Meaning |
|---|---|
| `displayName` | Name in the widget picker; falls back to `name`. |
| `description` | Falls back to the manifest `description`. |
| `category` | Free string, default `"Plugin"`. Common: System, Hardware, Media, Network, Status, Time, Monitoring, AI. |
| `aliases` | Search words for the picker. |
| `allowMultiple` | Metadata only; nothing enforces it. |
| `defaultSection` | `left`, `center` or `right` (validated). Where `omarchy plugin enable` puts it; default `center`. |
| `defaults` | Metadata only. **Not merged into `settings`.** |
| `schema` | The settings form. Metadata only; values are not validated. |

### Settings schema entries

All entries: `key`, `type`, `label`, optional `description` and `defaultValue`.

| `type` | Extra fields |
|---|---|
| `string` | none |
| `path` | none (a file or directory path) |
| `integer` | `min`, `max`, `step` |
| `number` | optional `min`, `max`, `step` |
| `boolean` | `defaultValue: true/false` |
| `enum` | `options`: a plain string array, e.g. `["Off", "On"]` (numbers as strings too) |

Settings reach a widget as its raw `shell.json` entry minus `id`. Read them
with `setting(key, fallback)` every time.

## Commands

| Command | Does |
|---|---|
| `omarchy plugin validate <dir>` | The checks above, plus: the files exist, each kind has its entry point, **no symlinks** anywhere. Exit 0 when valid. |
| `omarchy plugin add <git-url> [--enable] [--yes]` | Clones, validates, moves to `plugins/<id>`, rescans. Never runs plugin code. Needs `--yes` without a TTY. |
| `omarchy plugin update [<id>] [--yes]` | Fetch, show the diff, fast-forward, re-validate (rolls back on failure). Git checkouts only. |
| `omarchy plugin remove <id>` | Deletes the folder. |
| `omarchy plugin enable <id> [left\|center\|right] [--index N] [--before ID\|--after ID]` | Adds it to the bar (widgets) or to `plugins[]` (others). |
| `omarchy plugin disable <id>` | Removes the entry. |
| `omarchy plugin list [--json]` | `id, name, kinds, enabled, active, firstParty, clonedFrom`. |
| `omarchy plugin clone <omarchy.id>` | Copies a built-in into `~/.config/omarchy/plugins/$USER.<name>` and swaps it into the bar. |
| `omarchy-shell shell rescanPlugins` | Rescan now (needed before enabling a brand-new id). |
| `omarchy restart shell` | Full restart; refuses while the session is locked. |
| `omarchy bar move <id> --section right` | Move a widget. |

Logs: `qs log -p /usr/share/omarchy/shell [-f]`. Look for
`PluginRegistry:` (manifest rejected), `Plugin widget <id> failed:`,
`service plugin load failed for <id>`, `panel plugin <id> failed to load`.

## ~/.config/omarchy/shell.json

```json
{
  "version": 1,
  "bar": {
    "id": "omarchy.bar",
    "position": "top",
    "layout": {
      "left":   [{ "id": "omarchy.workspaces" }],
      "center": [{ "id": "omarchy.clock" }],
      "right":  [{ "id": "omarchy.tray" }, { "id": "io.github.yourname.loadavg", "intervalSec": 2 }]
    }
  },
  "plugins": [{ "id": "some.service-or-overlay", "anySetting": 1 }],
  "disabledPlugins": []
}
```

- Hot-reloaded on save. Once the file exists it replaces the defaults
  entirely (no merge).
- A third-party plugin is enabled when its id appears in `bar.id`,
  `bar.layout.*` or `plugins[]`. `disabledPlugins` turns off first-party ones.
- Widget settings live inline in the layout entry. Non-widget plugins keep
  theirs in `plugins[]`, which the plugin API cannot read: watch the file
  with a `FileView` if you need them.
