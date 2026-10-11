# Publishing to the Omarchy plugin marketplace

Catalog: omarchyplugins.com. Repository: `omacom/omarchy-plugin-marketplace`;
read its `SUBMISSION.md`, `VERIFICATION.md` and `SECURITY.md` before
submitting, since the rules change.

## Repository layout

- Public GitHub repo, plugin at the **root**: `manifest.json`, the entry
  points, a root `README` (with install and removal instructions) and a root
  `LICENSE`/`LICENCE`/`COPYING`.
- **Exactly one `manifest.json`.** A second one anywhere fails as
  `unsupported-repository-layout`.
- **No symlinks.**
- Optional root `preview.png` (or webp/jpg/avif), up to 50 MB and 40 MP. The
  marketplace makes the card images itself.

## Submitting

1. Open an issue with the form `issues/new?template=submit-plugin.yml`. The
   body has six headings, in order: Repository URL (root URL, no trailing
   slash), Category, Tags, Suggest a missing tag, Maintainer notes,
   Submission checklist (all five boxes checked). Unused fields:
   `_No response_`.
2. Category, one of: Appearance, Desktop, Developer Tools, Hardware, Kids,
   Productivity, System, Widgets, Other.
3. Tags, 1 to 3 of: ai, bar, education, games, hyprland, kids, launcher,
   media, power-management, quickshell, security, system, vpn, workspaces.
4. Use Maintainer notes for whatever a reviewer should know: a required
   CLI, what runs when, what is written where.
5. Agents: show the owner the full title and body and get a yes before
   creating the issue. Publishing is public.
6. **To fix something, push a commit and edit the same issue.** Every edit
   revalidates at the current HEAD. Never open a duplicate. Keep HEAD
   still while the issue is open.

## What the bot checks

**Validation:** the manifest (as in `manifest.md`, with lowercase ids and
`author`/`description` required), the files, the layout, the README and the
license. Labels: `validated` or `needs-fixes`.

**Automated security baseline:** a static scan of that exact commit. It
reads the root README, `.sh .py .js .mjs .qml .lua .toml .yaml .desktop
.service` and similar files, extensionless files in `bin/` and `scripts/`,
and every entry point. It skips `docs/`, `test(s)/`, `.github/` and `*.md`
other than the root README.

| Capability | Triggered by (anywhere scanned, README included) |
|---|---|
| `package-manager` | `pacman -S`, `yay -S`, `omarchy pkg add`, `pip install`, `npm install`, `go install`, `cargo install`, ... |
| `privilege` | `sudo`, `pkexec` (except clearly negated text like "no sudo is required") |
| `service-management` | `systemctl`, `systemd-run`, `*.service` files |
| `installer` | a file name with `install`, `setup` or `uninstall` as a word |
| `remote-build` | cloning or downloading your own repo, then building or running it |
| `sudoers-modification` | sudoers files or commands |
| `bundled-executable-binary` | a committed executable ELF/PE/Mach-O |

Outcomes:
- `passed`: no capabilities. Verified automatically.
- `review-required`: capabilities, no findings. Gets `security-review-required`
  and waits for a maintainer to accept the exact capability set. Common and
  fine, just slower: days, not minutes.
- `needs-fixes`: findings. `curl | sh`, `cargo install --git` without a full
  `--rev`, unpinned remote code, NOPASSWD sudoers rules, PIDs read from `/tmp`
  and passed to sudo. Blocks listing.

To stay at `passed`: no install, sudo or systemctl commands in code or the
root README. Describe dependencies neutrally ("needs X from the official
repositories") or move the step-by-step to `docs/`.

## What human reviewers ask to fix

From real reviews, most frequent first:

1. **Private data in process arguments**: tokens, prompts, diffs, notes,
   message or notification text in argv (readable via `/proc/*/cmdline`).
   Use stdin or a 0600 file.
2. **Too-open files**: state, logs, exports created 0644 under umask 022; an
   atomic rewrite that turns a 0600 file into 0644; private files in `/tmp`.
   Use 0700 dirs, 0600 files, keep the existing mode.
3. **Side effects beyond the user's choice**: e.g. installing into a shared
   directory that other tools read when the user selected one tool.
4. **Shell injection**: data interpolated into `bash -c` strings.
5. **Weak local boundaries**: daemons on `0.0.0.0`/`[::]`, loopback without
   auth, setuid helpers.
6. **Unpinned remote code**: `curl | sh` in scripts or the README; builds of
   a moving branch. Pin a tag or a full SHA.
7. Structural: a second manifest, no LICENSE, edited issue headings,
   duplicates.

Reviewers also read third-party CLIs or daemons the plugin requires.

## Labels

| Label | Meaning |
|---|---|
| `submission` | A submission issue. |
| `validated` | Structure and manifest passed at the commit shown. |
| `needs-fixes` | Blocks publication until a new commit fixes it. |
| `security-review-required` | Waiting for a maintainer to accept capabilities. |
| `manual-setup` | `omarchy plugin add <repo> --enable` alone is not enough (a native binary or a build step). The site shows a note instead of the one-line install. Optional settings or API keys do not count. |
| `approved-and-verified` | Maintainer approval, applied last; re-scans the exact commit and publishes. |
| `listed` | Published. |

## After listing

- Approval is pinned to one commit. `omarchy plugin add`/`update` still
  install the branch HEAD.
- A newer upstream commit shows as "Update unverified" in the catalog. To
  verify it, use the `verify-plugin.yml` form with the plugin id, repo URL and
  the full 40-character SHA. It runs the same validation, baseline and
  approval; the old snapshot stays listed until then.
- Batch changes into releases: every verified version is another review.

## Pre-submission checklist

- [ ] `omarchy plugin validate` passes on a real (non-symlink) checkout.
- [ ] One `manifest.json` at the root; lowercase id, not `omarchy.*`;
      `author`, `description`, `license` set.
- [ ] README: what it does, install, enable, remove, dependencies,
      what it writes where. LICENSE present.
- [ ] Works on two monitors, from a hotkey, after `omarchy restart shell`,
      with the helper binary missing.
- [ ] No private data in argv; files 0600 in 0700 dirs; no `/tmp` secrets.
- [ ] Nothing installed or changed without an explicit click; versions pinned.
- [ ] No `sh -c` with interpolated data; outside text is `PlainText`.
- [ ] Optional `preview.png` of the real widget, no personal data in it.
