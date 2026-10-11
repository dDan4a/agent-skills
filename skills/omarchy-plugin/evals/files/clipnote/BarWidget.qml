import QtQuick
import Quickshell
import qs.Commons
import qs.Ui

BarWidget {
  id: root
  moduleName: "io.github.someone.clipnote"
  readonly property var source: bar && bar.shell ? bar.shell.serviceFor(moduleName) : null
  onSourceChanged: if (source) source.token = setting("token", "")
  onSettingsChanged: if (source) source.token = setting("token", "")

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  Loader { id: panelLoader; source: Qt.resolvedUrl("Panel.qml"); visible: false
    onLoaded: { item.bar = root.bar; item.anchorItem = button; item.hostWidget = root; item.source = root.source } }

  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: "󰎚 " + (root.source ? root.source.notes.length : 0)
    onPressed: if (panelLoader.item) panelLoader.item.toggle()
  }
}
