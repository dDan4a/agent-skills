import QtQuick
import Quickshell
import qs.Commons
import qs.Ui

Panel {
  id: root
  moduleName: "io.github.someone.clipnote"
  manageIpc: false
  property var anchorItem: null
  property var hostWidget: null
  property var source: null
  function toggle() { root.opened ? root.controller.hide() : root.controller.show() }

  KeyboardPanel {
    id: panel
    anchorItem: root.anchorItem
    owner: root.hostWidget || root
    bar: root.bar
    open: root.opened
    focusTarget: input
    contentWidth: Style.space(320)
    contentHeight: column.implicitHeight

    Column {
      id: column
      width: parent.width
      Repeater {
        model: root.source ? root.source.notes : []
        delegate: Text { text: modelData; color: Color.foreground; width: column.width; elide: Text.ElideRight }
      }
      TextField {
        id: input
        width: column.width
        placeholderText: "New note"
        onAccepted: { if (root.source) root.source.save(text); text = "" }
      }
    }
  }
}
