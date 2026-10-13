import QtQuick
import Quickshell.Io

Item {
  id: root
  readonly property string cliModule: "github.com/someone/snapback/cli@v0.2.0"
  property string status: ""

  // Called from the widget after the user clicks "Install snapback".
  function installCli() { run(["go", "install", cliModule]) }
  function snapshot(path) { run(["snapback", "save", path]) }

  function run(argv) { proc.command = argv; proc.running = true }

  Process {
    id: proc
    stdout: StdioCollector { onStreamFinished: root.status = this.text.trim() }
  }
}
