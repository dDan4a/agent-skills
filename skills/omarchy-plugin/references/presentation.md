# Presenting a plugin for publication

How a plugin should look on GitHub and in the catalog (plugins.omarchy.org)
before it is submitted. The model is `dDan4a/syschange`: a designed preview,
a centered README header with badges, topics, tags and CI.

Do all of it **before** opening the submission issue. After listing, any
change is a commit, "Update unverified" in the catalog and another
`verify-plugin.yml` round (see `marketplace.md`).

**Keep this file current.** When a review or a publication teaches something
new about presentation, add or fix the rule here and log it below, one line:
date, source, what changed.

## 1. Check the panel layout first

Open the panel at its real size, on the smallest monitor you have, and look
at every state (empty, error, many items, long names). Text must not run
past the frame: long rows get `wrapMode: Text.WordWrap` or `elide:
Text.ElideRight` and a width. Key-hint footers are the usual offender
(grafana-alerts' hint line was wider than its panel). Fix it before the
screenshot, or the screenshot shows the bug.

## 2. The screenshot

Use demo or fake data: the plugin's demo mode if it has one, otherwise a
throwaway state dir, fake server or fixture config. No real hosts, names,
tokens, notifications or paths in the frame.

Opening the panel over IPC is not synthetic input, so do it yourself:

```bash
mon=$(hyprctl -j monitors | jq -r '.[] | select(.focused).name')
omarchy-shell shell toggle <id>; sleep 1      # opens on the focused monitor
grim -o "$mon" shot.png
omarchy-shell shell toggle <id>
```

Cut out only the panel, by its frame: the panel border is the theme accent
(`accent` in `~/.local/state/omarchy/current/theme/colors.toml`; confirm with
`magick shot.png -crop 1x1+X+Y txt:-` on a frame pixel). Then nothing of the
desktop or other windows gets in.

```bash
frame='#7aa2f7'   # the accent
# bounding box of frame-colored pixels; pre-crop to the panel's side if the bar
# also uses the accent
box=$(magick shot.png -fuzz 6% -fill white -opaque "$frame" -fill black +opaque white -format '%@' info:)
magick shot.png -crop "$box" +repage panel.png
```

Read `panel.png` and check the edges are the frame. If the box is off, scan
one row and one column through the panel (`magick shot.png -crop 1920x1+0+<y>
txt:- | grep -i <frame>`) for the exact edges.

## 3. The preview: 1920x1080

Dark background in the panel's own color (sample it inside the panel; syschange
on tokyo-night: `#16161e`), the panel on the left, text on the right:
the plugin name large, "for Omarchy" in the accent, 2-4 short lines of what it
gives. Monospace font, as in the shell (JetBrains Mono, `magick -list font |
grep JetBrains`).

```bash
bg='#16161e'; accent='#7aa2f7'; fg='#c0caf5'
magick -size 1920x1080 "xc:$bg" \
  \( panel.png -resize 'x980>' \) -gravity west -geometry +90+0 -composite \
  -gravity northwest -fill "$fg" -font JetBrainsMono-NF-Bold -pointsize 72 -annotate +860+260 'Plugin Name' \
  -font JetBrainsMono-NF-Regular -fill "$accent" -pointsize 34 -annotate +862+380 'for Omarchy' \
  -fill "$fg" -interline-spacing 24 -annotate +862+500 $'First benefit.\nSecond benefit.\nThird benefit.' \
  preview.png
```

For more layout control, HTML + headless chromium works too (as the profile
cards in `dDan4a/assets`, `src/render.sh`). Catalog cards crop the edges
(`object-fit: cover`), so keep the panel and the name clear of them.

Read `preview.png`, check it for personal data, show it to the user, and
commit it at the repo root.

## 4. README header

```html
<div align="center">

<h1>Plugin Name</h1>

One line: what it does.

[![test](https://github.com/<user>/<repo>/actions/workflows/test.yml/badge.svg)](https://github.com/<user>/<repo>/actions/workflows/test.yml)
[![tag](https://img.shields.io/github/v/tag/<user>/<repo>?sort=semver&label=version)](https://github.com/<user>/<repo>/tags)
[![Omarchy plugin](https://img.shields.io/badge/Omarchy_plugin-verified-7aa2f7)](https://plugins.omarchy.org/plugin.html?id=<id>)
[![license](https://img.shields.io/github/license/<user>/<repo>)](LICENSE)

<img src="preview.png" alt="<what the image shows>" width="900">

</div>
```

The "verified" badge links to the catalog page; until the plugin is listed,
leave it out or label it `submitted`. Below the header: what it does, install,
enable, remove, dependencies, what it writes where (`marketplace.md`).

## 5. The GitHub repository

- **Description**: the README's one line.
- **Topics**: `omarchy`, `omarchy-plugin`, `quickshell`, `hyprland`,
  `arch-linux`, plus the subject (`grafana`, `alerting`, `dotfiles`, ...):
  `gh repo edit --add-topic omarchy,omarchy-plugin,...`.
- **Tags**: `vX.Y.Z` on every release, equal to `version` in `manifest.json`.
- **CI**: a `.github/workflows/test.yml` running the tests and checking that
  `manifest.json` parses (`jq -e '.id and .entryPoints' manifest.json`). The
  marketplace scanner skips `.github/`, so CI adds no capabilities.

## Log

- 2026-10-17, dan4a.grafana-alerts (#11872) listed without a preview, panel
  hint line wider than the panel; syschange as the model: this file.
