#!/usr/bin/env bash
# Renders cards.html into ../<card>-<theme>.png (2x, transparent background). Rerun after changing a card or eval results.
set -euo pipefail
cd "$(dirname "$0")"
for card in omarchy-plugin parallel-worktrees herdr-tabs github-readme skill-evals; do
  for theme in dark light; do
    chromium --headless --disable-gpu --hide-scrollbars --force-device-scale-factor=2 --default-background-color=00000000 \
      --virtual-time-budget=5000 --window-size=772,204 --screenshot="../$card-$theme.png" \
      "file://$PWD/cards.html?c=$card&t=$theme" 2>/dev/null
  done
done
