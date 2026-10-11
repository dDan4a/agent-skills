import QtQuick
import Quickshell
import qs.Commons
import qs.Ui

// One instance per monitor. Keep it thin: read the shared service, show it,
// open the panel. Anything that runs, polls or notifies belongs in Service.qml.
BarWidget {
  id: root
  moduleName: "io.github.yourname.loadavg"

  // The bar's popout routing needs these on the widget root.
  readonly property bool opened: panelLoader.item ? panelLoader.item.opened === true : false
  readonly property bool popoutSwitchClosing: panelLoader.item ? panelLoader.item.popoutSwitchClosing === true : false
  function open() { if (panelLoader.item) panelLoader.item.open() }
  function close() { if (panelLoader.item) panelLoader.item.close() }
  function togglePanel() { if (panelLoader.item) panelLoader.item.toggle() }
  function closeForPopoutSwitch() { if (panelLoader.item) panelLoader.item.closeForPopoutSwitch() }

  // The plugin's own service; null until the shell has created it. The binding
  // re-evaluates when the shell's service map changes.
  readonly property var source: bar && bar.shell ? bar.shell.serviceFor(moduleName) : null

  // Settings arrive raw from shell.json, never merged with the manifest's
  // defaults: always give a fallback. A service cannot read them, so pass them on.
  function configureSource() {
    if (source) source.intervalSec = Number(setting("intervalSec", 5))
  }
  onSourceChanged: { configureSource(); injectPanel() }
  onSettingsChanged: { configureSource(); injectPanel() }
  onBarChanged: injectPanel()

  function injectPanel() {
    var p = panelLoader.item
    if (!p) return
    p.bar = root.bar
    p.settings = root.settings
    p.anchorItem = button
    p.hostWidget = root
    p.source = root.source
  }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  Loader {
    id: panelLoader
    source: Qt.resolvedUrl("Panel.qml")
    visible: false
    onLoaded: { root.injectPanel(); Qt.callLater(root.injectPanel) }
  }

  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    active: root.opened
    text: "󰊚 " + (root.source ? root.source.load.toFixed(2) : "…") // nf-md-gauge
    foreground: root.source && root.source.error !== "" ? Color.urgent : (root.bar ? root.bar.barForeground : Color.foreground)
    tooltipText: root.source && root.source.error !== "" ? "Load: " + root.source.error : ""
    onPressed: root.togglePanel()
  }
}
