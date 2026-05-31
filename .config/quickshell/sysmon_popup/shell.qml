import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import QtQuick

Scope {
  id: root

  property string cpuName: ""
  property int cpuUsage: 0
  property int cpuTemp: 0
  property double cpuFreq: 0.0
  property double cpuPower: 0.0
  property string gpuName: ""
  property int gpuUsage: 0
  property int gpuTemp: 0
  property double gpuPower: 0.0
  property int gpuMemUsed: 0
  property int gpuMemTotal: 0
  property string ramName: ""
  property string ramSpeed: ""
  property double ramTotal: 0.0
  property double ramUsed: 0.0

  property int ramUsage: ramTotal > 0 ? Math.round((ramUsed / ramTotal) * 100) : 0

  function centerText(str, width) {
    var pad = width - str.length;
    if (pad <= 0) return str.substring(0, width);
    var left = Math.floor(pad / 2);
    var right = pad - left;
    return " ".repeat(left) + str + " ".repeat(right);
  }

  // Label value formatting helper. Ensure floating values are properly passed as strings.
  function formatLabelVal(label, valStr, unit, width) {
    var contentWidth = width - 2;
    var pad = contentWidth - label.length - valStr.length - unit.length;
    if (pad < 0) pad = 0;
    return " " + label + " ".repeat(pad) + valStr + unit + " ";
  }

  // Process to fetch sysmon status
  Process {
    id: checkStatusProc
    command: ["/home/parazeeknova/doty/.config/quickshell/sysmon_popup/get_sysmon_status"]
    running: false
    stdout: StdioCollector {
      onStreamFinished: {
        try {
          var data = JSON.parse(this.text)
          root.cpuName = data.cpu_name || "CPU"
          root.cpuUsage = data.cpu_usage || 0
          root.cpuTemp = data.cpu_temp || 0
          root.cpuFreq = data.cpu_freq || 0.0
          root.cpuPower = data.cpu_power || 0.0
          root.gpuName = data.gpu_name || "GPU"
          root.gpuUsage = data.gpu_usage || 0
          root.gpuTemp = data.gpu_temp || 0
          root.gpuPower = data.gpu_power || 0.0
          root.gpuMemUsed = data.gpu_mem_used || 0
          root.gpuMemTotal = data.gpu_mem_total || 0
          root.ramName = data.ram_name || "DDR"
          root.ramSpeed = data.ram_speed || "N/A"
          root.ramTotal = data.ram_total || 0.0
          root.ramUsed = data.ram_used || 0.0
        } catch (e) {
          console.log("Failed to parse sysmon status: " + e)
        }
      }
    }
  }

  // Poll status every 2 seconds
  Timer {
    id: pollTimer
    interval: 2000
    repeat: true
    running: true
    triggeredOnStart: true
    onTriggered: {
      if (!checkStatusProc.running) {
        checkStatusProc.running = true
      }
    }
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
          bottom: true
          left: true
        }

        margins {
          bottom: 18
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
            spacing: 8

            // Heading without icon, styled like other popups (9px, bold)
            Item {
              width: parent.width
              height: 14

              Text {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                text: "System Monitor"
                color: "#d5c4a1"
                font.family: "FiraCode Nerd Font"
                font.pixelSize: 9
                font.bold: true
                renderType: Text.NativeRendering
              }
            }

            Column {
              spacing: 0
              width: parent.width

              Row {
                width: parent.width
                spacing: 0

                // CPU Column (Left)
                Column {
                  width: parent.width / 2
                  spacing: 0
                  anchors.verticalCenter: parent.verticalCenter

                  Text {
                    text: " CPU: " + root.cpuName
                    color: "#d5c4a1"
                    font.family: "FiraCode Nerd Font"
                    font.pixelSize: 9
                    font.bold: true
                    renderType: Text.NativeRendering
                    leftPadding: 4
                  }

                  // CPU Box
                  Text {
                    text: "┏━━━━━━━━━━━━━━━━━┓\n" +
                          "┃" + root.formatLabelVal("usage:", String(root.cpuUsage), "%", 17) + "┃\n" +
                          "┃" + root.formatLabelVal("temp:", String(root.cpuTemp), "°C", 17) + "┃\n" +
                          "┃" + root.formatLabelVal("freq:", root.cpuFreq.toFixed(2), "GHz", 17) + "┃\n" +
                          "┃" + root.formatLabelVal("power:", root.cpuPower.toFixed(1), "W", 17) + "┃\n" +
                          "┗━━━━━━━━━━━━━━━━━┛"
                    color: "#d5c4a1"
                    font.family: "FiraCode Nerd Font"
                    font.pixelSize: 9
                    font.bold: false
                    lineHeight: 1.15
                    horizontalAlignment: Text.AlignHCenter
                    anchors.horizontalCenter: parent.horizontalCenter
                    renderType: Text.NativeRendering
                  }
                }

                // GPU Column (Right)
                Column {
                  width: parent.width / 2
                  spacing: 0
                  anchors.verticalCenter: parent.verticalCenter

                  Text {
                    text: "󰢮 GPU: " + root.gpuName
                    color: "#d5c4a1"
                    font.family: "FiraCode Nerd Font"
                    font.pixelSize: 9
                    font.bold: true
                    renderType: Text.NativeRendering
                    leftPadding: 4
                  }

                  // GPU Box
                  Text {
                    text: "┏━━━━━━━━━━━━━━━━━┓\n" +
                          "┃" + root.formatLabelVal("usage:", String(root.gpuUsage), "%", 17) + "┃\n" +
                          "┃" + root.formatLabelVal("temp:", String(root.gpuTemp), "°C", 17) + "┃\n" +
                          "┃" + root.formatLabelVal("used:", String(root.gpuMemUsed), "M", 17) + "┃\n" +
                          "┃" + root.formatLabelVal("power:", root.gpuPower.toFixed(1), "W", 17) + "┃\n" +
                          "┗━━━━━━━━━━━━━━━━━┛"
                    color: "#d5c4a1"
                    font.family: "FiraCode Nerd Font"
                    font.pixelSize: 9
                    font.bold: false
                    lineHeight: 1.15
                    horizontalAlignment: Text.AlignHCenter
                    anchors.horizontalCenter: parent.horizontalCenter
                    renderType: Text.NativeRendering
                  }
                }
              }

              // 󰍛MEM label
              Text {
                text: "󰍛 MEM: Micron Crucial CT2K16G48C40S5"
                color: "#d5c4a1"
                font.family: "FiraCode Nerd Font"
                font.pixelSize: 9
                font.bold: true
                renderType: Text.NativeRendering
              }

              // RAM Box
              Text {
                text: "┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓\n" +
                      "┃" + root.formatLabelVal("type:", root.ramName, "", 18) + " " + root.formatLabelVal("speed:", root.ramSpeed, "", 18) + "┃\n" +
                      "┃" + root.formatLabelVal("ram:", (root.ramUsed.toFixed(2) + "/" + root.ramTotal.toFixed(2)), "G", 18) + " " + root.formatLabelVal("usg:", String(root.ramUsage), "%", 18) + "┃\n" +
                      "┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛"
                color: "#d5c4a1"
                font.family: "FiraCode Nerd Font"
                font.pixelSize: 9
                font.bold: false
                lineHeight: 1.15
                horizontalAlignment: Text.AlignHCenter
                anchors.horizontalCenter: parent.horizontalCenter
                renderType: Text.NativeRendering
              }
            }
          }
        }
      }
    }
  }
}
