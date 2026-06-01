import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io

Scope {
    id: root

    property string cpuName: ""
    property int cpuUsage: 0
    property int cpuTemp: 0
    property double cpuFreq: 0
    property double cpuPower: 0
    property string gpuName: ""
    property int gpuUsage: 0
    property int gpuTemp: 0
    property double gpuPower: 0
    property int gpuMemUsed: 0
    property int gpuMemTotal: 0
    property string ramName: ""
    property string ramSpeed: ""
    property double ramTotal: 0
    property double ramUsed: 0
    property int ramUsage: ramTotal > 0 ? Math.round((ramUsed / ramTotal) * 100) : 0
    // Disk properties - NVMe 0 (Samsung)
    property string disk0Name: ""
    property double disk0ReadRate: 0
    property double disk0WriteRate: 0
    property double disk0TotalGb: 0
    property double disk0UsedGb: 0
    property double disk0FreeGb: 0
    property int disk0UsagePct: 0
    // Disk properties - NVMe 1 (Crucial)
    property string disk1Name: ""
    property double disk1ReadRate: 0
    property double disk1WriteRate: 0
    property double disk1TotalGb: 0
    property double disk1UsedGb: 0
    property double disk1FreeGb: 0
    property int disk1UsagePct: 0

    function centerText(str, width) {
        var pad = width - str.length;
        if (pad <= 0)
            return str.substring(0, width);

        var left = Math.floor(pad / 2);
        var right = pad - left;
        return " ".repeat(left) + str + " ".repeat(right);
    }

    // Label value formatting helper. Ensure floating values are properly passed as strings.
    function formatLabelVal(label, valStr, unit, width) {
        var contentWidth = width - 2;
        var pad = contentWidth - label.length - valStr.length - unit.length;
        if (pad < 0)
            pad = 0;

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
                    var data = JSON.parse(this.text);
                    root.cpuName = data.cpu_name || "CPU";
                    root.cpuUsage = data.cpu_usage || 0;
                    root.cpuTemp = data.cpu_temp || 0;
                    root.cpuFreq = data.cpu_freq || 0;
                    root.cpuPower = data.cpu_power || 0;
                    root.gpuName = data.gpu_name || "GPU";
                    root.gpuUsage = data.gpu_usage || 0;
                    root.gpuTemp = data.gpu_temp || 0;
                    root.gpuPower = data.gpu_power || 0;
                    root.gpuMemUsed = data.gpu_mem_used || 0;
                    root.gpuMemTotal = data.gpu_mem_total || 0;
                    root.ramName = data.ram_name || "DDR";
                    root.ramSpeed = data.ram_speed || "N/A";
                    root.ramTotal = data.ram_total || 0;
                    root.ramUsed = data.ram_used || 0;
                    // Disk 0
                    if (data.disk0) {
                        root.disk0Name = data.disk0.name || "NVMe 0";
                        root.disk0ReadRate = data.disk0.read_rate || 0;
                        root.disk0WriteRate = data.disk0.write_rate || 0;
                        root.disk0TotalGb = data.disk0.total_gb || 0;
                        root.disk0UsedGb = data.disk0.used_gb || 0;
                        root.disk0FreeGb = data.disk0.free_gb || 0;
                        root.disk0UsagePct = data.disk0.usage_pct || 0;
                    }
                    // Disk 1
                    if (data.disk1) {
                        root.disk1Name = data.disk1.name || "NVMe 1";
                        root.disk1ReadRate = data.disk1.read_rate || 0;
                        root.disk1WriteRate = data.disk1.write_rate || 0;
                        root.disk1TotalGb = data.disk1.total_gb || 0;
                        root.disk1UsedGb = data.disk1.used_gb || 0;
                        root.disk1FreeGb = data.disk1.free_gb || 0;
                        root.disk1UsagePct = data.disk1.usage_pct || 0;
                    }
                } catch (e) {
                    console.log("Failed to parse sysmon status: " + e);
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
            if (!checkStatusProc.running)
                checkStatusProc.running = true;

        }
    }

    Variants {
        model: Quickshell.screens

        delegate: Component {
            PanelWindow {
                id: win

                required property var modelData
                property bool isClosing: false
                property real animLeftMargin: -260
                property real animOpacity: 0

                function closePopup() {
                    if (isClosing)
                        return ;

                    isClosing = true;
                    exitAnim.start();
                }

                screen: modelData
                color: "transparent"
                exclusionMode: PanelWindow.ExclusionMode.Ignore
                focusable: true
                implicitWidth: 240
                implicitHeight: mainLayout.implicitHeight + 20
                Component.onCompleted: introAnim.start()

                anchors {
                    bottom: true
                    left: true
                }

                margins {
                    bottom: 18
                    left: win.animLeftMargin
                }

                // Slide-in + fade-in
                ParallelAnimation {
                    id: introAnim

                    NumberAnimation {
                        target: win
                        property: "animLeftMargin"
                        from: -260
                        to: 32
                        duration: 120
                        easing.type: Easing.OutCubic
                    }

                    NumberAnimation {
                        target: win
                        property: "animOpacity"
                        from: 0
                        to: 1
                        duration: 120
                        easing.type: Easing.OutCubic
                    }

                }

                // Slide-out + fade-out
                ParallelAnimation {
                    id: exitAnim

                    onStopped: Qt.quit()

                    NumberAnimation {
                        target: win
                        property: "animLeftMargin"
                        from: 32
                        to: -260
                        duration: 100
                        easing.type: Easing.InCubic
                    }

                    NumberAnimation {
                        target: win
                        property: "animOpacity"
                        from: 1
                        to: 0
                        duration: 100
                        easing.type: Easing.InCubic
                    }

                }

                HyprlandFocusGrab {
                    active: !win.isClosing
                    windows: [win]
                    onCleared: {
                        win.closePopup();
                    }
                }

                Rectangle {
                    anchors.fill: parent
                    opacity: win.animOpacity
                    color: "#801d2021"
                    border.width: 1
                    border.color: "#d5c4a1"
                    radius: 0
                    antialiasing: false
                    focus: true
                    Keys.onPressed: (event) => {
                        if (event.key === Qt.Key_Escape)
                            win.closePopup();

                    }
                    Component.onCompleted: {
                        forceActiveFocus();
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

                            // btop launch button
                            Text {
                                id: btnBtop

                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                text: "launch btop"
                                color: "#d5c4a1"
                                font.family: "FiraCode Nerd Font"
                                font.pixelSize: 9
                                renderType: Text.NativeRendering

                                MouseArea {
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    onEntered: btnBtop.color = "#ebdbb2"
                                    onExited: btnBtop.color = "#d5c4a1"
                                    onClicked: {
                                        Quickshell.execDetached(["hyprctl", "dispatch", 'hl.dsp.exec_cmd("[float;size 55% 65%;center] ghostty --title=btop -e btop --force-utf")']);
                                        win.closePopup();
                                    }
                                }

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
                                        text: "┏━━━━━━━━━━━━━━━━━┓\n" + "┃" + root.formatLabelVal("usage:", String(root.cpuUsage), "%", 17) + "┃\n" + "┃" + root.formatLabelVal("temp:", String(root.cpuTemp), "°C", 17) + "┃\n" + "┃" + root.formatLabelVal("freq:", root.cpuFreq.toFixed(2), "GHz", 17) + "┃\n" + "┃" + root.formatLabelVal("power:", root.cpuPower.toFixed(1), "W", 17) + "┃\n" + "┗━━━━━━━━━━━━━━━━━┛"
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
                                        text: "┏━━━━━━━━━━━━━━━━━┓\n" + "┃" + root.formatLabelVal("usage:", String(root.gpuUsage), "%", 17) + "┃\n" + "┃" + root.formatLabelVal("temp:", String(root.gpuTemp), "°C", 17) + "┃\n" + "┃" + root.formatLabelVal("used:", String(root.gpuMemUsed), "M", 17) + "┃\n" + "┃" + root.formatLabelVal("power:", root.gpuPower.toFixed(1), "W", 17) + "┃\n" + "┗━━━━━━━━━━━━━━━━━┛"
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
                                text: "┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓\n" + "┃" + root.formatLabelVal("type:", root.ramName, "", 18) + " " + root.formatLabelVal("speed:", root.ramSpeed, "", 18) + "┃\n" + "┃" + root.formatLabelVal("ram:", (root.ramUsed.toFixed(2) + "/" + root.ramTotal.toFixed(2)), "G", 18) + " " + root.formatLabelVal("usg:", String(root.ramUsage), "%", 18) + "┃\n" + "┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛"
                                color: "#d5c4a1"
                                font.family: "FiraCode Nerd Font"
                                font.pixelSize: 9
                                font.bold: false
                                lineHeight: 1.15
                                horizontalAlignment: Text.AlignHCenter
                                anchors.horizontalCenter: parent.horizontalCenter
                                renderType: Text.NativeRendering
                            }

                            // 󰋊 DISKS heading
                            Text {
                                text: "󰋊 DISKS"
                                color: "#d5c4a1"
                                font.family: "FiraCode Nerd Font"
                                font.pixelSize: 9
                                font.bold: true
                                renderType: Text.NativeRendering
                                topPadding: 4
                            }

                            Row {
                                width: parent.width
                                spacing: 0

                                // NVMe 0 Column (Left)
                                Column {
                                    width: parent.width / 2
                                    spacing: 0

                                    Text {
                                        text: root.disk0Name
                                        color: "#d5c4a1"
                                        font.family: "FiraCode Nerd Font"
                                        font.pixelSize: 9
                                        font.bold: true
                                        renderType: Text.NativeRendering
                                        leftPadding: 4
                                        elide: Text.ElideRight
                                        width: parent.width
                                    }

                                    Text {
                                        text: "┏━━━━━━━━━━━━━━━━━┓\n" + "┃" + root.formatLabelVal("R:", root.disk0ReadRate.toFixed(1), "M/s", 17) + "┃\n" + "┃" + root.formatLabelVal("W:", root.disk0WriteRate.toFixed(1), "M/s", 17) + "┃\n" + "┃" + root.formatLabelVal("total:", root.disk0TotalGb.toFixed(0), "G", 17) + "┃\n" + "┃" + root.formatLabelVal("used:", root.disk0UsedGb.toFixed(0), "G", 17) + "┃\n" + "┃" + root.formatLabelVal("free:", root.disk0FreeGb.toFixed(0), "G", 17) + "┃\n" + "┃" + root.formatLabelVal("usg:", String(root.disk0UsagePct), "%", 17) + "┃\n" + "┗━━━━━━━━━━━━━━━━━┛"
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

                                // NVMe 1 Column (Right)
                                Column {
                                    width: parent.width / 2
                                    spacing: 0

                                    Text {
                                        text: root.disk1Name
                                        color: "#d5c4a1"
                                        font.family: "FiraCode Nerd Font"
                                        font.pixelSize: 9
                                        font.bold: true
                                        renderType: Text.NativeRendering
                                        leftPadding: 4
                                        elide: Text.ElideRight
                                        width: parent.width
                                    }

                                    Text {
                                        text: "┏━━━━━━━━━━━━━━━━━┓\n" + "┃" + root.formatLabelVal("R:", root.disk1ReadRate.toFixed(1), "M/s", 17) + "┃\n" + "┃" + root.formatLabelVal("W:", root.disk1WriteRate.toFixed(1), "M/s", 17) + "┃\n" + "┃" + root.formatLabelVal("total:", root.disk1TotalGb.toFixed(0), "G", 17) + "┃\n" + "┃" + root.formatLabelVal("used:", root.disk1UsedGb.toFixed(0), "G", 17) + "┃\n" + "┃" + root.formatLabelVal("free:", root.disk1FreeGb.toFixed(0), "G", 17) + "┃\n" + "┃" + root.formatLabelVal("usg:", String(root.disk1UsagePct), "%", 17) + "┃\n" + "┗━━━━━━━━━━━━━━━━━┛"
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

    }

}
