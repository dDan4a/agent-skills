#!/usr/bin/env bash
# Eval sandbox for herdr-tabs: a fake `herdr` that logs every call. Never touches a real Herdr session.
#   sandbox.sh setup <dir> <eval-id>   build the sandbox, print the session's cwd
#   sandbox.sh state <dir>             dump what the grader needs
set -euo pipefail
cmd=$1 S=$(realpath -m "$2") id=${3:-}

if [ "$cmd" = state ]; then
  echo "== herdr calls"; cat "$S/herdr.log" 2>/dev/null || echo none
  echo "== files in the project"; find "$S/notes" -type f | sed "s|$S/||" | sort
  echo "== notes/ideas.md"; cat "$S/notes/ideas.md"
  exit 0
fi

mkdir -p "$S/bin" "$S/notes"
printf "# Ideas\n\n- Plugins should recieve events over IPC, not poll.\n" > "$S/notes/ideas.md"
cat > "$S/env.sh" <<ENV
export PATH=$S/bin:\$PATH
ENV
[ "$id" = 3 ] || echo "export HERDR_ENV=1 HERDR_WORKSPACE_ID=w1 HERDR_TAB_ID=w1:t1 HERDR_PANE_ID=w1:p1" >> "$S/env.sh"

# Tabs after Main (eval 2 has one for dark mode already), one JSON object per tab with a leading comma; `tab create` appends to it.
: > "$S/tabs"; [ "$id" = 2 ] && echo -n ',{"tab_id":"w1:t4","label":"💡 dark-mode","agent_status":"idle","pane_count":1}' > "$S/tabs"
cat > "$S/bin/herdr" <<STUB
#!/usr/bin/env bash
printf 'herdr' >> "$S/herdr.log"; printf ' %q' "\$@" >> "$S/herdr.log"; echo >> "$S/herdr.log"
n=\$(grep -c 'tab create' "$S/herdr.log")
case "\$1 \$2" in
  "tab list") echo "{\"result\":{\"tabs\":[{\"tab_id\":\"w1:t1\",\"label\":\"Main\",\"agent_status\":\"working\",\"pane_count\":1}\$(cat "$S/tabs")]}}" ;;
  "tab create")
    label=\$(printf '%s\\n' "\$@" | grep -A1 -x -- --label | tail -1)
    printf ',{"tab_id":"w1:t1%s","label":"%s","agent_status":"unknown","pane_count":1}' "\$n" "\$label" >> "$S/tabs"
    echo "{\"result\":{\"tab\":{\"tab_id\":\"w1:t1\$n\"},\"root_pane\":{\"pane_id\":\"w1:p1\$n\"}}}" ;;
  "pane list") echo '{"result":{"panes":[{"pane_id":"w1:p1","tab_id":"w1:t1","agent":"claude"},{"pane_id":"w1:p4","tab_id":"w1:t4","agent":"claude","agent_name":"dark-mode"}]}}' ;;
  "agent list") echo '{"result":{"agents":[{"pane_id":"w1:p1","kind":"claude","status":"working"},{"pane_id":"w1:p4","name":"dark-mode","kind":"claude","status":"idle"}]}}' ;;
  *) echo '{"result":{}}' ;;
esac
STUB
chmod +x "$S/bin/herdr"
echo "$S/notes"
