import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

BarWidget {
  id: root
  moduleName: "io.github.someone.weather"

  property string temp: "…"
  property real lastTemp: NaN

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  Process {
    id: fetch
    command: ["sh", "-c", "curl -s 'https://wttr.in/" + root.settings.city + "?format=%t'"]
    stdout: StdioCollector {
      onStreamFinished: {
        root.temp = text.trim()
        var t = parseFloat(root.temp)
        if (!isNaN(root.lastTemp) && Math.abs(t - root.lastTemp) >= 5)
          notify.running = true
        root.lastTemp = t
      }
    }
  }

  Process {
    id: notify
    command: ["notify-send", "Weather", "Temperature is now " + root.temp]
  }

  Timer {
    interval: root.settings.intervalMin * 60000
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: fetch.running = true
  }

  // omarchy-shell io.github.someone.weather refresh
  IpcHandler {
    target: "io.github.someone.weather"
    function refresh(): void { fetch.running = true }
  }

  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: "󰖐 " + root.temp
    onPressed: fetch.running = true
  }
}
