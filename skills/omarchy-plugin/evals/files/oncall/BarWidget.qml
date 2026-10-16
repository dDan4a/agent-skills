import QtQuick

Item {
  id: root
  required property var bar
  readonly property var svc: bar.shell.serviceFor("io.github.someone.oncall")
  implicitWidth: label.implicitWidth
  implicitHeight: label.implicitHeight
  Text { id: label; text: root.svc ? root.svc.onCall : ""; textFormat: Text.PlainText; elide: Text.ElideRight }
}
