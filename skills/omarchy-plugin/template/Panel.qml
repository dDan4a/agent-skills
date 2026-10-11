import QtQuick
import Quickshell
import qs.Commons
import qs.Ui

// The popup of one monitor's widget. Each monitor has its own copy; the data
// comes from the shared service.
Panel {
  id: root
  moduleName: "io.github.yourname.loadavg"
  manageIpc: false // IPC lives in the service; a handler here would exist per monitor

  property var anchorItem: null
  property var hostWidget: null
  property var source: null
  // The bar knows a slot by the widget mounted in it, not by this nested panel.
  readonly property var barIdentity: hostWidget || root
  readonly property color foreground: bar ? bar.foreground : Color.foreground
  readonly property color dim: Qt.darker(foreground, 1.4)
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family

  function open() { if (source) source.refresh(); root.controller.show() }
  function close() { root.controller.hide() }
  function toggle() { root.opened ? root.close() : root.open() }
  function switchPanel(direction) {
    if (root.bar && typeof root.bar.switchPanelFrom === "function")
      return root.bar.switchPanelFrom(root.barIdentity, direction)
    return false
  }

  KeyboardPanel {
    id: panel
    anchorItem: root.anchorItem
    owner: root.barIdentity
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher // without it, keys go nowhere
    contentWidth: panel.fittedContentWidth(Style.space(300))
    contentHeight: panel.fittedContentHeight(column.implicitHeight)

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }
      onTextKey: function(text) { if (text === "r" && root.source) root.source.refresh() }

      // Small screens cap the card's height: scroll instead of cutting it off.
      Flickable {
        anchors.fill: parent
        contentWidth: width
        contentHeight: column.implicitHeight
        interactive: contentHeight > height
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        Column {
          id: column
          width: parent.width
          spacing: Style.space(10)

          PanelHero {
            width: parent.width
            title: "Load average"
            meta: root.source ? root.source.running + " processes running" : ""
            foreground: root.foreground
            fontFamily: root.fontFamily
            iconComponent: Text {
              text: "󰊚"
              color: root.foreground
              font.family: root.fontFamily
              font.pixelSize: Style.font.display
            }
          }

          Text {
            visible: text !== ""
            width: parent.width
            text: root.source ? root.source.error : ""
            color: Color.urgent
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
            wrapMode: Text.Wrap
            textFormat: Text.PlainText // text from outside the shell is never rich text
          }

          PanelSeparator { width: parent.width }

          Repeater {
            model: [["1 minute", 0], ["5 minutes", 1], ["15 minutes", 2]]
            delegate: Item {
              required property var modelData
              width: column.width
              height: label.implicitHeight
              Text {
                id: label
                text: modelData[0]
                color: root.foreground
                font.family: root.fontFamily
                font.pixelSize: Style.font.body
              }
              Text {
                anchors.right: parent.right
                text: root.source && root.source.averages.length > 2 ? root.source.averages[modelData[1]].toFixed(2) : "…"
                color: root.foreground
                font.family: root.fontFamily
                font.pixelSize: Style.font.body
                font.bold: true
              }
            }
          }

          Text {
            width: parent.width
            text: "r refresh · Tab next panel · Esc close"
            color: root.dim
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
            horizontalAlignment: Text.AlignHCenter
          }
        }
      }
    }
  }
}
