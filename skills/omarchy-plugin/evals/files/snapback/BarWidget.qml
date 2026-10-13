import QtQuick
import Quickshell
import qs.Commons

Item {
  id: root
  property var bar: null
  readonly property var source: bar && bar.shell ? bar.shell.serviceFor("io.github.someone.snapback") : null
  implicitWidth: label.implicitWidth
  implicitHeight: label.implicitHeight

  Text {
    id: label
    text: "󰁯"
    color: root.bar ? root.bar.foreground : Color.foreground
    MouseArea { anchors.fill: parent; onClicked: if (root.source) root.source.snapshot(Quickshell.env("HOME") + "/.bashrc") }
  }
}
