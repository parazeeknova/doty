import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import QtQuick

Scope {
  id: root

  property var activeNotifs: []
  property var historyNotifs: []
  property bool historyExpanded: false
  property bool btEnabled: false
  property bool wifiEnabled: false
  property bool audioMuted: false

  // Track expanded notification IDs
  property var expandedNotifIds: ({})

  // Process to fetch notification lists
  Process {
    id: checkNotifsProc
    command: ["/home/parazeeknova/doty/.config/quickshell/notif_popup/get_notif_status"]
    running: false
    stdout: StdioCollector {
      onStreamFinished: {
        try {
          var data = JSON.parse(this.text)
          root.activeNotifs = data.active || []
          root.historyNotifs = data.history || []
          root.btEnabled = data.bt_enabled || false
          root.wifiEnabled = data.wifi_enabled || false
          root.audioMuted = data.audio_muted || false
        } catch (e) {
          console.log("Failed to parse notifications: " + e)
        }
      }
    }
  }

  function triggerRefresh() {
    checkNotifsProc.running = false
    checkNotifsProc.running = true
  }

  Component.onCompleted: {
    triggerRefresh()
  }

  Variants {
    model: Quickshell.screens

    delegate: Component {
      PanelWindow {
        id: win
        required property var modelData
        screen: modelData
        color: "transparent"

        anchors {
          left: true
        }

        // Center vertically on the left screen edge
        margins {
          left: 32
        }

        exclusionMode: PanelWindow.ExclusionMode.Ignore
        focusable: true

        HyprlandFocusGrab {
          active: true
          windows: [win]
          onCleared: {
            Qt.quit()
          }
        }

        implicitWidth: 240
        implicitHeight: mainLayout.implicitHeight + 20

        Rectangle {
          anchors.fill: parent
          color: "#1d2021"
          border.width: 1
          border.color: "#d5c4a1"
          radius: 0
          antialiasing: false

          focus: true
          Keys.onPressed: (event) => {
            if (event.key === Qt.Key_Escape) {
              Qt.quit()
            }
          }

          Component.onCompleted: {
            forceActiveFocus()
          }

          Column {
            id: mainLayout
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.margins: 10
            spacing: 10

            // --- SECTION 1: HEADER & ACTIONS ---
            Item {
              width: parent.width
              height: 16

              Text {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                text: "Notifications"
                color: "#d5c4a1"
                font.family: "FiraCode Nerd Font"
                font.pixelSize: 10
                font.bold: true
                renderType: Text.NativeRendering
              }

              Text {
                id: clearAllBtn
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                text: "Clear All"
                color: "#d5c4a1"
                font.family: "FiraCode Nerd Font"
                font.pixelSize: 8
                font.bold: true
                renderType: Text.NativeRendering

                MouseArea {
                  anchors.fill: parent
                  hoverEnabled: true
                  onEntered: clearAllBtn.color = "#ebdbb2"
                  onExited: clearAllBtn.color = "#d5c4a1"
                  onClicked: {
                    Quickshell.execDetached(["makoctl", "dismiss", "-a"])
                    root.activeNotifs = []
                    root.triggerRefresh()
                  }
                }
              }
            }

            Rectangle {
              width: parent.width
              height: 1
              color: "#d5c4a1"
              opacity: 0.15
            }

            // --- SECTION 2: ACTIVE NOTIFICATIONS ---
            Column {
              width: parent.width
              spacing: 6

              Text {
                text: "Active"
                color: "#d5c4a1"
                font.family: "FiraCode Nerd Font"
                font.pixelSize: 8
                font.bold: true
                opacity: 0.6
                renderType: Text.NativeRendering
              }

              Text {
                text: "No active notifications"
                color: "#d5c4a1"
                font.family: "FiraCode Nerd Font"
                font.pixelSize: 8
                opacity: 0.4
                renderType: Text.NativeRendering
                visible: root.activeNotifs.length === 0
              }

              Repeater {
                model: root.activeNotifs
                delegate: Rectangle {
                  width: parent.width
                  // Size dynamically to Column child layout
                  height: activeBoxCol.implicitHeight + 10
                  color: "#282828"
                  border.width: 1
                  border.color: modelData.urgency === "critical" ? "#ea6962" : "#3c3836"

                  Column {
                    id: activeBoxCol
                    anchors.top: parent.top
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.margins: 5
                    spacing: 4

                    Row {
                      width: parent.width
                      spacing: 8

                      // App Icon
                      Rectangle {
                        width: 20
                        height: 20
                        color: "transparent"
                        anchors.verticalCenter: parent.verticalCenter
                        visible: modelData.app_icon !== ""

                        Image {
                          anchors.fill: parent
                          source: modelData.app_icon.startsWith("/") ? ("file://" + modelData.app_icon) : ("image://icon/" + modelData.app_icon)
                          fillMode: Image.PreserveAspectFit
                          asynchronous: true
                        }
                      }

                      Column {
                        width: parent.width - (modelData.app_icon !== "" ? 28 : 0)
                        spacing: 2
                        anchors.verticalCenter: parent.verticalCenter

                        Item {
                          width: parent.width
                          height: 12

                          Text {
                            text: modelData.summary
                            color: "#d5c4a1"
                            font.family: "FiraCode Nerd Font"
                            font.pixelSize: 8
                            font.bold: true
                            elide: Text.ElideRight
                            anchors.left: parent.left
                            anchors.right: dismissBtn.left
                            anchors.rightMargin: 5
                            anchors.verticalCenter: parent.verticalCenter
                            renderType: Text.NativeRendering
                          }

                          Text {
                            id: dismissBtn
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            text: "dismiss"
                            color: "#d5c4a1"
                            font.family: "FiraCode Nerd Font"
                            font.pixelSize: 8
                            font.bold: true
                            renderType: Text.NativeRendering

                            MouseArea {
                              anchors.fill: parent
                              hoverEnabled: true
                              onEntered: dismissBtn.color = "#ebdbb2"
                              onExited: dismissBtn.color = "#d5c4a1"
                              onClicked: {
                                Quickshell.execDetached(["makoctl", "dismiss", "-n", String(modelData.id)])
                                root.triggerRefresh()
                              }
                            }
                          }
                        }
                      }
                    }

                    // Description Box
                    Column {
                      width: parent.width
                      spacing: 2

                      // Text body element
                      Text {
                        id: descText
                        text: modelData.body
                        color: "#d5c4a1"
                        font.family: "FiraCode Nerd Font"
                        font.pixelSize: 8
                        wrapMode: Text.Wrap
                        width: parent.width
                        // 1 line limit when collapsed, unlimited when expanded
                        elide: root.expandedNotifIds[modelData.id] ? Text.ElideNone : Text.ElideRight
                        maximumLineCount: root.expandedNotifIds[modelData.id] ? 99 : 1
                        renderType: Text.NativeRendering
                      }

                      // Expand control row (shown as secondary line when collapsed, or bottom control when expanded)
                      Item {
                        width: parent.width
                        height: 10
                        visible: modelData.body.length > 50 || modelData.body.includes("\n")

                        Text {
                          id: showMoreBtn
                          anchors.right: parent.right
                          anchors.verticalCenter: parent.verticalCenter
                          text: root.expandedNotifIds[modelData.id] ? "show less" : "show more"
                          color: "#d5c4a1"
                          font.family: "FiraCode Nerd Font"
                          font.pixelSize: 7
                          font.bold: true
                          renderType: Text.NativeRendering

                          MouseArea {
                            anchors.fill: parent
                            onClicked: {
                              var copy = Object.assign({}, root.expandedNotifIds);
                              copy[modelData.id] = !copy[modelData.id];
                              root.expandedNotifIds = copy;
                            }
                          }
                        }
                      }
                    }
                  }
                }
              }
            }

            Rectangle {
              width: parent.width
              height: 1
              color: "#d5c4a1"
              opacity: 0.15
            }

            // --- SECTION 3: HISTORY ---
            Column {
              width: parent.width
              spacing: 6

              Item {
                width: parent.width
                height: 14

                Row {
                  id: historyTitleRow
                  anchors.left: parent.left
                  anchors.verticalCenter: parent.verticalCenter
                  spacing: 4

                  Text {
                    text: root.historyExpanded ? "" : ""
                    color: "#d5c4a1"
                    font.family: "FiraCode Nerd Font"
                    font.pixelSize: 8
                    font.bold: true
                    opacity: 0.6
                    renderType: Text.NativeRendering
                  }

                  Text {
                    text: "History"
                    color: "#d5c4a1"
                    font.family: "FiraCode Nerd Font"
                    font.pixelSize: 8
                    font.bold: true
                    opacity: 0.6
                    renderType: Text.NativeRendering
                  }
                }

                MouseArea {
                  anchors.fill: historyTitleRow
                  onClicked: {
                    root.historyExpanded = !root.historyExpanded
                  }
                }

                Text {
                  id: restoreBtn
                  anchors.right: parent.right
                  anchors.verticalCenter: parent.verticalCenter
                  text: "Restore Last"
                  color: "#d5c4a1"
                  font.family: "FiraCode Nerd Font"
                  font.pixelSize: 8
                  renderType: Text.NativeRendering
                  visible: root.historyNotifs.length > 0

                  MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    onEntered: restoreBtn.color = "#ebdbb2"
                    onExited: restoreBtn.color = "#d5c4a1"
                    onClicked: {
                      Quickshell.execDetached(["makoctl", "restore"])
                      root.triggerRefresh()
                    }
                  }
                }
              }

              Column {
                width: parent.width
                spacing: 6
                visible: root.historyExpanded

                Text {
                  text: "No history"
                  color: "#d5c4a1"
                  font.family: "FiraCode Nerd Font"
                  font.pixelSize: 8
                  opacity: 0.4
                  renderType: Text.NativeRendering
                  visible: root.historyNotifs.length === 0
                }

                Repeater {
                  model: root.historyNotifs
                  delegate: Rectangle {
                    width: parent.width
                    height: histBoxCol.implicitHeight + 10
                    color: "#1d2021"
                    border.width: 1
                    border.color: "#3c3836"

                    Column {
                      id: histBoxCol
                      anchors.top: parent.top
                      anchors.left: parent.left
                      anchors.right: parent.right
                      anchors.margins: 5
                      spacing: 4

                      Row {
                        width: parent.width
                        spacing: 8

                        // App Icon
                        Rectangle {
                          width: 20
                          height: 20
                          color: "transparent"
                          anchors.verticalCenter: parent.verticalCenter
                          visible: modelData.app_icon !== ""

                          Image {
                            anchors.fill: parent
                            source: modelData.app_icon.startsWith("/") ? ("file://" + modelData.app_icon) : ("image://icon/" + modelData.app_icon)
                            fillMode: Image.PreserveAspectFit
                            asynchronous: true
                          }
                        }

                        Column {
                          width: parent.width - (modelData.app_icon !== "" ? 28 : 0)
                          spacing: 2
                          anchors.verticalCenter: parent.verticalCenter

                          Text {
                            text: modelData.summary
                            color: "#d5c4a1"
                            font.family: "FiraCode Nerd Font"
                            font.pixelSize: 8
                            font.bold: true
                            elide: Text.ElideRight
                            width: parent.width
                            renderType: Text.NativeRendering
                          }
                        }
                      }

                      // Description Box
                      Column {
                        width: parent.width
                        spacing: 2

                        Text {
                          id: histDescText
                          text: modelData.body
                          color: "#d5c4a1"
                          font.family: "FiraCode Nerd Font"
                          font.pixelSize: 8
                          wrapMode: Text.Wrap
                          width: parent.width
                          elide: root.expandedNotifIds[modelData.id + "_hist"] ? Text.ElideNone : Text.ElideRight
                          maximumLineCount: root.expandedNotifIds[modelData.id + "_hist"] ? 99 : 1
                          renderType: Text.NativeRendering
                        }

                        Item {
                          width: parent.width
                          height: 10
                          visible: modelData.body.length > 60 || modelData.body.includes("\n")

                          Text {
                            id: histShowMoreBtn
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            text: root.expandedNotifIds[modelData.id + "_hist"] ? "show less" : "show more"
                            color: "#d5c4a1"
                            font.family: "FiraCode Nerd Font"
                            font.pixelSize: 7
                            font.bold: true
                            renderType: Text.NativeRendering

                            MouseArea {
                              anchors.fill: parent
                              onClicked: {
                                var copy = Object.assign({}, root.expandedNotifIds);
                                copy[modelData.id + "_hist"] = !copy[modelData.id + "_hist"];
                                root.expandedNotifIds = copy;
                              }
                            }
                          }
                        }
                      }
                    }
                  }
                }
              }
            }

            Rectangle {
              width: parent.width
              height: 1
              color: "#d5c4a1"
              opacity: 0.15
            }

            Row {
              width: parent.width

              // Volume Button
              Item {
                width: parent.width / 5
                height: 14

                Text {
                  id: btnVol
                  anchors.centerIn: parent
                  text: root.audioMuted ? "󰝟" : "󰕾"
                  color: "#d5c4a1"
                  font.family: "FiraCode Nerd Font"
                  font.pixelSize: 12
                  renderType: Text.NativeRendering
                }

                MouseArea {
                  anchors.fill: parent
                  hoverEnabled: true
                  onEntered: btnVol.color = "#ebdbb2"
                  onExited: btnVol.color = "#d5c4a1"
                  onClicked: {
                    Quickshell.execDetached(["quickshell", "--config", "volume_popup"])
                    Qt.quit()
                  }
                }
              }

              // Network Button
              Item {
                width: parent.width / 5
                height: 14

                Text {
                  id: btnNet
                  anchors.centerIn: parent
                  text: root.wifiEnabled ? "󰖩" : "󰖪"
                  color: "#d5c4a1"
                  font.family: "FiraCode Nerd Font"
                  font.pixelSize: 12
                  renderType: Text.NativeRendering
                }

                MouseArea {
                  anchors.fill: parent
                  hoverEnabled: true
                  onEntered: btnNet.color = "#ebdbb2"
                  onExited: btnNet.color = "#d5c4a1"
                  onClicked: {
                    Quickshell.execDetached(["quickshell", "--config", "network_popup"])
                    Qt.quit()
                  }
                }
              }

              // Bluetooth Button
              Item {
                width: parent.width / 5
                height: 14

                Text {
                  id: btnBt
                  anchors.centerIn: parent
                  text: root.btEnabled ? "󰂯" : "󰂲"
                  color: "#d5c4a1"
                  font.family: "FiraCode Nerd Font"
                  font.pixelSize: 12
                  renderType: Text.NativeRendering
                }

                MouseArea {
                  anchors.fill: parent
                  hoverEnabled: true
                  onEntered: btnBt.color = "#ebdbb2"
                  onExited: btnBt.color = "#d5c4a1"
                  onClicked: {
                    Quickshell.execDetached(["quickshell", "--config", "bluetooth_popup"])
                    Qt.quit()
                  }
                }
              }

              // Brightness Button
              Item {
                width: parent.width / 5
                height: 14

                Text {
                  id: btnBright
                  anchors.centerIn: parent
                  text: "󰃠"
                  color: "#d5c4a1"
                  font.family: "FiraCode Nerd Font"
                  font.pixelSize: 12
                  renderType: Text.NativeRendering
                }

                MouseArea {
                  anchors.fill: parent
                  hoverEnabled: true
                  onEntered: btnBright.color = "#ebdbb2"
                  onExited: btnBright.color = "#d5c4a1"
                  onClicked: {
                    Quickshell.execDetached(["quickshell", "--config", "brightness_popup"])
                    Qt.quit()
                  }
                }
              }

              // Battery Button
              Item {
                width: parent.width / 5
                height: 14

                Text {
                  id: btnBat
                  anchors.centerIn: parent
                  text: "󰁹"
                  color: "#d5c4a1"
                  font.family: "FiraCode Nerd Font"
                  font.pixelSize: 12
                  renderType: Text.NativeRendering
                }

                MouseArea {
                  anchors.fill: parent
                  hoverEnabled: true
                  onEntered: btnBat.color = "#ebdbb2"
                  onExited: btnBat.color = "#d5c4a1"
                  onClicked: {
                    Quickshell.execDetached(["quickshell", "--config", "battery_popup"])
                    Qt.quit()
                  }
                }
              }
            }
          }
        }
      }
    }
  }
}
