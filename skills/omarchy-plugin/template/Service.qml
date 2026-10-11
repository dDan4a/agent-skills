import QtQuick
import Quickshell.Io

// The plugin's single instance: the shell creates a service once, while the
// bar creates a widget (and its panel) on every monitor. Polling, processes,
// state, notifications and IPC live here; widgets only bind to it.
Item {
  id: root

  // Pushed in by the widget (a service cannot read its own settings). With
  // no widget in the bar, this default is what runs.
  property int intervalSec: 5

  property var averages: []   // [1 min, 5 min, 15 min]
  property string running: "" // "running/total" processes
  property string error: ""
  readonly property real load: averages.length > 0 ? averages[0] : 0

  function refresh() {
    if (!proc.running) proc.running = true
  }

  // argv array, never a shell string: no quoting bugs, no injection, and
  // nothing private ends up in a command line other users can read.
  Process {
    id: proc
    command: ["cat", "/proc/loadavg"]
    stdout: StdioCollector { id: out; waitForEnd: true }
    stderr: StdioCollector { id: err; waitForEnd: true }
    onExited: function(exitCode) {
      if (exitCode !== 0) { root.error = String(err.text || "cat failed").trim(); return }
      var f = String(out.text).trim().split(/\s+/)
      root.averages = [Number(f[0]), Number(f[1]), Number(f[2])]
      root.running = f[3] || ""
      root.error = ""
    }
  }

  Timer {
    // The manifest's min/max only shape the settings form: clamp here.
    interval: Math.max(1, root.intervalSec) * 1000
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: root.refresh()
  }

  // One handler for the whole plugin. In a widget it would exist once per
  // monitor, and all but the first would be ignored with a warning.
  // omarchy-shell io.github.yourname.loadavg refresh
  IpcHandler {
    target: "io.github.yourname.loadavg"
    function refresh(): void { root.refresh() }
    function load(): string { return String(root.load) }
  }
}
