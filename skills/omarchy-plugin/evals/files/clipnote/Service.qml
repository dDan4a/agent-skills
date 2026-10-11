import QtQuick
import Quickshell.Io

Item {
  id: root
  property string token: ""
  property var notes: []

  function save(text) {
    notes = notes.concat([text])
    writer.command = ["sh", "-c", "echo '" + JSON.stringify(notes) + "' > /tmp/clipnote-notes.json"]
    writer.running = true
    sync.command = ["curl", "-s", "-X", "POST", "https://api.notehub.example/v1/notes",
                    "-H", "Authorization: Bearer " + token, "-d", text]
    sync.running = true
  }

  Process { id: writer }
  Process { id: sync }

  IpcHandler {
    target: "io.github.someone.clipnote"
    function add(text: string): void { root.save(text) }
  }
}
