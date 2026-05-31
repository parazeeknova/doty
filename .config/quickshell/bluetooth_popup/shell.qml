import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io

Scope {
    id: root

    property var btEnabled: null
    property var devices: []
    property string expandedDeviceAddr: ""
    property bool scanning: false
    property bool pendingScan: false
    property bool loading: true

    function triggerRefresh() {
        refreshTimer.restart();
    }

    Component.onCompleted: {
        checkStatusProc.running = true;
    }

    Process {
        id: checkStatusProc

        command: {
            var cmd = ["/home/parazeeknova/doty/.config/quickshell/bluetooth_popup/get_bluetooth_status"];
            if (root.pendingScan)
                cmd.push("--scan");

            return cmd;
        }
        running: false

        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var data = JSON.parse(this.text);
                    root.btEnabled = data.enabled;
                    root.devices = data.devices || [];
                    root.pendingScan = false;
                    root.loading = false;
                } catch (e) {
                    console.log("Failed to parse bluetooth status: " + e);
                    root.pendingScan = false;
                    root.loading = false;
                }
            }
        }

    }

    Timer {
        id: refreshTimer

        interval: 800
        repeat: false
        running: false
        onTriggered: {
            checkStatusProc.running = false;
            checkStatusProc.running = true;
        }
    }

    Timer {
        id: scanTimer

        interval: 2000
        repeat: false
        running: false
        onTriggered: {
            root.scanning = false;
        }
    }

    Timer {
        id: pollTimer

        interval: 3000
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

                screen: modelData
                color: "transparent"
                exclusionMode: PanelWindow.ExclusionMode.Ignore
                focusable: true
                implicitWidth: 240
                implicitHeight: Math.max(100, mainLayout.implicitHeight)

                anchors {
                    bottom: true
                    left: true
                }

                margins {
                    bottom: 18
                    left: 32
                }

                HyprlandFocusGrab {
                    active: true
                    windows: [win]
                    onCleared: {
                        Qt.quit();
                    }
                }

                Rectangle {
                    anchors.fill: parent
                    color: "#1d2021"
                    border.width: 1
                    border.color: "#d5c4a1"
                    radius: 0
                    antialiasing: false
                    focus: true
                    Keys.onPressed: (event) => {
                        if (event.key === Qt.Key_Escape)
                            Qt.quit();

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

                        // --- SECTION 1: HEADER ---
                        Row {
                            width: parent.width
                            spacing: 4

                            Column {
                                width: parent.width - btToggleText.width - scanBtn.width - 16
                                spacing: 2

                                Text {
                                    text: "Bluetooth"
                                    color: "#d5c4a1"
                                    font.family: "FiraCode Nerd Font"
                                    font.pixelSize: 10
                                    font.bold: true
                                    renderType: Text.NativeRendering
                                }

                                Text {
                                    text: {
                                        if (root.loading)
                                            return "Loading...";

                                        if (root.btEnabled === false)
                                            return "Disabled";

                                        var connected = root.devices.filter(function(d) {
                                            return d.connected;
                                        });
                                        if (connected.length === 0)
                                            return "No devices connected";

                                        return connected.map(function(d) {
                                            return d.name;
                                        }).join(", ");
                                    }
                                    color: "#d5c4a1"
                                    opacity: 0.6
                                    font.family: "FiraCode Nerd Font"
                                    font.pixelSize: 8
                                    elide: Text.ElideRight
                                    width: parent.width
                                    renderType: Text.NativeRendering
                                    visible: true
                                }

                            }

                            Text {
                                id: btToggleText

                                anchors.verticalCenter: parent.verticalCenter
                                text: root.btEnabled === null ? "--" : (root.btEnabled ? "On" : "Off")
                                color: "#d5c4a1"
                                font.family: "FiraCode Nerd Font"
                                font.pixelSize: 9
                                font.bold: true
                                renderType: Text.NativeRendering

                                MouseArea {
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    onEntered: btToggleText.color = "#ebdbb2"
                                    onExited: btToggleText.color = "#d5c4a1"
                                    onClicked: {
                                        if (root.btEnabled)
                                            Quickshell.execDetached(["bluetoothctl", "power", "off"]);
                                        else
                                            Quickshell.execDetached(["bluetoothctl", "power", "on"]);
                                        root.triggerRefresh();
                                    }
                                }

                            }

                            Item {
                                width: 8
                                height: 1
                            }

                            Text {
                                id: scanBtn

                                anchors.verticalCenter: parent.verticalCenter
                                text: "󰑐"
                                color: "#d5c4a1"
                                font.family: "FiraCode Nerd Font"
                                font.pixelSize: 11
                                renderType: Text.NativeRendering
                                visible: root.btEnabled

                                MouseArea {
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    onEntered: scanBtn.color = "#ebdbb2"
                                    onExited: scanBtn.color = "#d5c4a1"
                                    onClicked: {
                                        if (checkStatusProc.running)
                                            return ;

                                        root.scanning = true;
                                        root.pendingScan = true;
                                        scanTimer.restart();
                                        checkStatusProc.running = true;
                                    }
                                }

                                RotationAnimation on rotation {
                                    id: scanSpin

                                    from: 0
                                    to: 360
                                    duration: 1000
                                    loops: Animation.Infinite
                                    running: root.scanning
                                }

                            }

                        }

                        Rectangle {
                            width: parent.width
                            height: 1
                            color: "#d5c4a1"
                            opacity: 0.15
                        }

                        Text {
                            text: "  Loading devices..."
                            color: "#d5c4a1"
                            opacity: 0.5
                            font.family: "FiraCode Nerd Font"
                            font.pixelSize: 8
                            renderType: Text.NativeRendering
                            visible: root.loading
                        }

                        // --- SECTION 2: CONNECTED DEVICES ---
                        Column {
                            width: parent.width
                            spacing: 3
                            visible: !root.loading && root.btEnabled && root.devices.filter(function(d) {
                                return d.connected;
                            }).length > 0

                            Text {
                                text: "Connected"
                                color: "#d5c4a1"
                                font.family: "FiraCode Nerd Font"
                                font.pixelSize: 9
                                font.bold: true
                                renderType: Text.NativeRendering
                            }

                            Column {
                                width: parent.width
                                spacing: 2

                                Repeater {
                                    model: root.devices.filter(function(d) {
                                        return d.connected;
                                    })

                                    delegate: Column {
                                        width: parent.width
                                        spacing: 2

                                        Rectangle {
                                            width: parent.width
                                            height: 16
                                            color: "transparent"

                                            Row {
                                                anchors.left: parent.left
                                                anchors.verticalCenter: parent.verticalCenter
                                                spacing: 4

                                                Text {
                                                    text: {
                                                        var icon = "󰋋";
                                                        if (modelData.device_type === "keyboard")
                                                            icon = "󰌌";
                                                        else if (modelData.device_type === "mouse")
                                                            icon = "󰍽";
                                                        else if (modelData.device_type === "controller")
                                                            icon = "󰊴";
                                                        return icon + " " + modelData.name;
                                                    }
                                                    color: "#d5c4a1"
                                                    font.family: "FiraCode Nerd Font"
                                                    font.pixelSize: 8
                                                    font.bold: true
                                                    elide: Text.ElideRight
                                                    width: 150
                                                    renderType: Text.NativeRendering
                                                }

                                            }

                                            // Battery indicator
                                            Text {
                                                anchors.right: disconnectBtn.left
                                                anchors.rightMargin: 6
                                                anchors.verticalCenter: parent.verticalCenter
                                                text: modelData.battery !== null ? Math.round(modelData.battery) + "%" : ""
                                                color: "#d5c4a1"
                                                font.family: "FiraCode Nerd Font"
                                                font.pixelSize: 8
                                                renderType: Text.NativeRendering
                                            }

                                            Text {
                                                id: disconnectBtn

                                                anchors.right: parent.right
                                                anchors.verticalCenter: parent.verticalCenter
                                                text: "disconnect"
                                                color: "#d5c4a1"
                                                font.family: "FiraCode Nerd Font"
                                                font.pixelSize: 8
                                                renderType: Text.NativeRendering

                                                MouseArea {
                                                    anchors.fill: parent
                                                    hoverEnabled: true
                                                    onEntered: disconnectBtn.color = "#ebdbb2"
                                                    onExited: disconnectBtn.color = "#d5c4a1"
                                                    onClicked: {
                                                        Quickshell.execDetached(["bluetoothctl", "disconnect", modelData.address]);
                                                        root.triggerRefresh();
                                                    }
                                                }

                                            }

                                        }

                                    }

                                }

                            }

                            Text {
                                text: "  No devices connected"
                                color: "#d5c4a1"
                                opacity: 0.5
                                font.family: "FiraCode Nerd Font"
                                font.pixelSize: 8
                                renderType: Text.NativeRendering
                                visible: root.devices.filter(function(d) {
                                    return d.connected;
                                }).length === 0
                            }

                        }

                        Rectangle {
                            width: parent.width
                            height: 1
                            color: "#d5c4a1"
                            opacity: 0.15
                            visible: !root.loading && root.btEnabled && root.devices.filter(function(d) {
                                return d.connected;
                            }).length > 0
                        }

                        // --- SECTION 4: PAIRED DEVICES ---
                        Column {
                            width: parent.width
                            spacing: 3
                            visible: !root.loading && root.btEnabled && root.devices.filter(function(d) {
                                return d.paired && !d.connected;
                            }).length > 0

                            Text {
                                text: "Paired"
                                color: "#d5c4a1"
                                font.family: "FiraCode Nerd Font"
                                font.pixelSize: 9
                                font.bold: true
                                renderType: Text.NativeRendering
                            }

                            Column {
                                width: parent.width
                                spacing: 2

                                Repeater {
                                    model: root.devices.filter(function(d) {
                                        return d.paired && !d.connected;
                                    })

                                    delegate: Column {
                                        width: parent.width
                                        spacing: 2

                                        Rectangle {
                                            width: parent.width
                                            height: 16
                                            color: "transparent"

                                            Row {
                                                anchors.left: parent.left
                                                anchors.verticalCenter: parent.verticalCenter
                                                spacing: 4

                                                Text {
                                                    text: {
                                                        var icon = "󰋋";
                                                        if (modelData.device_type === "keyboard")
                                                            icon = "󰌌";
                                                        else if (modelData.device_type === "mouse")
                                                            icon = "󰍽";
                                                        else if (modelData.device_type === "controller")
                                                            icon = "󰊴";
                                                        return icon + " " + modelData.name;
                                                    }
                                                    color: "#d5c4a1"
                                                    font.family: "FiraCode Nerd Font"
                                                    font.pixelSize: 8
                                                    elide: Text.ElideRight
                                                    width: 150
                                                    renderType: Text.NativeRendering
                                                }

                                            }

                                            // Battery indicator
                                            Text {
                                                anchors.right: connectBtn.left
                                                anchors.rightMargin: 6
                                                anchors.verticalCenter: parent.verticalCenter
                                                text: modelData.battery !== null ? Math.round(modelData.battery) + "%" : ""
                                                color: "#d5c4a1"
                                                font.family: "FiraCode Nerd Font"
                                                font.pixelSize: 8
                                                renderType: Text.NativeRendering
                                            }

                                            Text {
                                                id: connectBtn

                                                anchors.right: parent.right
                                                anchors.verticalCenter: parent.verticalCenter
                                                text: "connect"
                                                color: "#d5c4a1"
                                                font.family: "FiraCode Nerd Font"
                                                font.pixelSize: 8
                                                renderType: Text.NativeRendering

                                                MouseArea {
                                                    anchors.fill: parent
                                                    hoverEnabled: true
                                                    onEntered: connectBtn.color = "#ebdbb2"
                                                    onExited: connectBtn.color = "#d5c4a1"
                                                    onClicked: {
                                                        Quickshell.execDetached(["bluetoothctl", "connect", modelData.address]);
                                                        root.triggerRefresh();
                                                    }
                                                }

                                            }

                                        }

                                    }

                                }

                            }

                            Text {
                                text: "  No paired devices"
                                color: "#d5c4a1"
                                opacity: 0.5
                                font.family: "FiraCode Nerd Font"
                                font.pixelSize: 8
                                renderType: Text.NativeRendering
                                visible: root.devices.filter(function(d) {
                                    return d.paired && !d.connected;
                                }).length === 0
                            }

                        }

                        Rectangle {
                            width: parent.width
                            height: 1
                            color: "#d5c4a1"
                            opacity: 0.15
                            visible: !root.loading && root.btEnabled && root.devices.filter(function(d) {
                                return d.paired && !d.connected;
                            }).length > 0
                        }

                        // --- SECTION 5: AVAILABLE DEVICES ---
                        Column {
                            width: parent.width
                            spacing: 3
                            visible: !root.loading && root.btEnabled

                            Text {
                                text: "Available"
                                color: "#d5c4a1"
                                font.family: "FiraCode Nerd Font"
                                font.pixelSize: 9
                                font.bold: true
                                renderType: Text.NativeRendering
                            }

                            Column {
                                width: parent.width
                                spacing: 2

                                Repeater {
                                    model: root.devices.filter(function(d) {
                                        return !d.paired;
                                    })

                                    delegate: Column {
                                        width: parent.width
                                        spacing: 2

                                        Rectangle {
                                            width: parent.width
                                            height: 16
                                            color: "transparent"

                                            Text {
                                                anchors.left: parent.left
                                                anchors.verticalCenter: parent.verticalCenter
                                                text: modelData.name
                                                color: "#d5c4a1"
                                                font.family: "FiraCode Nerd Font"
                                                font.pixelSize: 8
                                                elide: Text.ElideRight
                                                width: 150
                                                renderType: Text.NativeRendering
                                            }

                                            Text {
                                                id: pairBtn

                                                anchors.right: parent.right
                                                anchors.verticalCenter: parent.verticalCenter
                                                text: "pair"
                                                color: "#d5c4a1"
                                                font.family: "FiraCode Nerd Font"
                                                font.pixelSize: 8
                                                renderType: Text.NativeRendering

                                                MouseArea {
                                                    anchors.fill: parent
                                                    hoverEnabled: true
                                                    onEntered: pairBtn.color = "#ebdbb2"
                                                    onExited: pairBtn.color = "#d5c4a1"
                                                    onClicked: {
                                                        Quickshell.execDetached(["bluetoothctl", "pair", modelData.address]);
                                                        root.triggerRefresh();
                                                    }
                                                }

                                            }

                                        }

                                    }

                                }

                            }

                            Text {
                                text: "  No available devices"
                                color: "#d5c4a1"
                                opacity: 0.5
                                font.family: "FiraCode Nerd Font"
                                font.pixelSize: 8
                                renderType: Text.NativeRendering
                                visible: root.devices.filter(function(d) {
                                    return !d.paired;
                                }).length === 0
                            }

                        }

                        // --- FOOTER: Bluetooth off message ---
                        Text {
                            text: "  Bluetooth is disabled"
                            color: "#d5c4a1"
                            opacity: 0.5
                            font.family: "FiraCode Nerd Font"
                            font.pixelSize: 8
                            renderType: Text.NativeRendering
                            visible: root.btEnabled === false
                        }

                    }

                }

            }

        }

    }

}
