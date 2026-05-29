import Quickshell
import Quickshell.Io
import QtQuick

Scope {
  id: root

  readonly property string statePath: Qt.resolvedUrl("./state.json")
  property string message: ""
  property string kind: "info"
  property bool visibleNow: false

  function defaultState() {
    return {
      visible: false,
      text: "",
      kind: "info",
      timeout_ms: 1200
    }
  }

  function readState() {
    try {
      var raw = stateFile.text()
      if (!raw || raw.trim() === "") {
        return defaultState()
      }

      var parsed = JSON.parse(raw)
      return {
        visible: parsed.visible !== false,
        text: String(parsed.text ?? ""),
        kind: String(parsed.kind ?? "info"),
        timeout_ms: parsed.timeout_ms ?? 1200
      }
    } catch (error) {
      return defaultState()
    }
  }

  function refreshState() {
    var state = readState()
    message = state.text
    kind = state.kind
    visibleNow = state.visible && state.text.length > 0

    if (visibleNow) {
      hideTimer.interval = state.timeout_ms || 1200
      hideTimer.restart()
    } else {
      hideTimer.stop()
    }
  }

  Timer {
    id: hideTimer
    interval: 1200
    repeat: false
    onTriggered: {
      root.visibleNow = false
    }
  }

  FileView {
    id: stateFile
    path: root.statePath
    blockLoading: true
    watchChanges: true
    onFileChanged: reload()
    onLoaded: root.refreshState()
  }

  Component.onCompleted: root.refreshState()

  Variants {
    model: Quickshell.screens

    delegate: Component {
      PanelWindow {
        required property var modelData
        screen: modelData
        color: "transparent"

        anchors {
          top: true
          left: true
        }

        margins {
          top: 5
          left: 30
        }

        exclusionMode: PanelWindow.ExclusionMode.Ignore
        visible: root.visibleNow

        implicitWidth: label.implicitWidth + 12
        implicitHeight: label.implicitHeight + 8

        Rectangle {
          anchors.fill: parent
          color: "#1d2021"
          border.width: 1
          border.color: root.kind === "good" ? "#a9b665" : root.kind === "bad" ? "#ea6962" : root.kind === "warn" ? "#e78a4e" : "#7c6f64"
          radius: 0
          antialiasing: false

          Text {
            id: label
            anchors.centerIn: parent
            text: root.message
            color: "#d4be98"
            font.family: "FiraCode Nerd Font"
            font.pixelSize: 8
            renderType: Text.NativeRendering
          }
        }
      }
    }
  }
}
