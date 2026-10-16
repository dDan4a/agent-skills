import QtQuick
import Quickshell
import Quickshell.Io

Item {
  id: root
  property string api: "https://oncall.example.net"
  property string tokenFile: Quickshell.env("HOME") + "/.config/oncall/token"
  property var schedules: []
  property string onCall: ""

  // The token never shows up in argv: it reaches curl as a -K config on stdin.
  readonly property string script:
    'set -e; t=$(cat "$1"); c() { printf \'header = "Authorization: %s"\\n\' "$t" | curl -sS --fail -K - "$@"; }; ' +
    's=$(c "$2/api/v1/schedules/"); u=$(c "$2/api/v1/users/?roles=on_call"); ' +
    'printf "%s" "$u" | jq --argjson s "$(printf "%s" "$s" | jq -c .results)" "{schedules: \\$s, users: .results}"'

  function refresh() { fetch.running = true }

  function changed(name) {
    Quickshell.execDetached(["notify-send", "--app-name=On-call", "--", "On call now", name])
  }

  function openSchedule(s) { Qt.openUrlExternally(s.ical_url_primary) }

  Process {
    id: fetch
    command: ["sh", "-c", root.script, "sh", root.tokenFile, root.api]
    stdout: StdioCollector { id: out; waitForEnd: true }
    onExited: function(code) {
      if (code !== 0) return
      var d = JSON.parse(out.text)
      root.schedules = d.schedules
      var name = d.users.length > 0 ? d.users[0].username : ""
      if (name !== root.onCall && name !== "") root.changed(name)
      root.onCall = name
    }
  }

  Timer { interval: 300000; running: true; repeat: true; triggeredOnStart: true; onTriggered: root.refresh() }
}
