import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io

Scope {
    id: root

    property string homeDir: Quickshell.env("HOME")
    property var btEnabled: null
    property var devices: []
    property string expandedDeviceAddr: ""
    property bool scanning: false
    property bool pendingScan: false
    property bool loading: true

    signal requestClose()

    function triggerRefresh() {
        refreshTimer.restart();
    }

    Component.onCompleted: {
        checkStatusProc.running = true;
    }

    Theme {
        id: theme
    }

    QuickshellWindow {
        id: window
        width: 320
        height: 500
        target: "bluetooth_popup"
    }

    IpcHandler {
        function close() {
            root.requestClose();
        }

        target: "bluetooth_popup"
    }

    Process {
        id: checkStatusProc

        command: {
            var cmd = [root.homeDir + "/.config/quickshell/bluetooth_popup/get_bluetooth_status"];
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
                implicitHeight: Math.max(100, mainLayout.implicitHeight)
                Component.onCompleted: introAnim.start()

                Connections {
                    function onRequestClose() {
                        win.closePopup();
                    }

                    target: root
                }

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
                    color: theme.popupBgColor
                    border.width: 1
                    border.color: theme.c.accent
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

                        // --- SECTION 1: HEADER ---
                        Row {
                            width: parent.width
                            spacing: 4

                            Column {
                                width: parent.width - btToggleText.width - scanBtn.width - 16
                                spacing: 2

                                Text {
                                    text: "Bluetooth"
                                    color: theme.c.accent
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
                                    color: theme.c.accent
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
                                color: theme.c.accent
                                font.family: "FiraCode Nerd Font"
                                font.pixelSize: 9
                                font.bold: true
                                renderType: Text.NativeRendering

                                MouseArea {
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    onEntered: btToggleText.color = theme.c.accent
                                    onExited: btToggleText.color = theme.c.accent
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
                                color: theme.c.accent
                                font.family: "FiraCode Nerd Font"
                                font.pixelSize: 11
                                renderType: Text.NativeRendering
                                visible: root.btEnabled

                                MouseArea {
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    onEntered: scanBtn.color = theme.c.accent
                                    onExited: scanBtn.color = theme.c.accent
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
                            color: theme.c.accent
                            opacity: 0.15
                        }

                        Text {
                            text: "  Loading devices..."
                            color: theme.c.accent
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
                                color: theme.c.accent
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
                                                    color: theme.c.accent
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
                                                color: theme.c.accent
                                                font.family: "FiraCode Nerd Font"
                                                font.pixelSize: 8
                                                renderType: Text.NativeRendering
                                            }

                                            Text {
                                                id: disconnectBtn

                                                anchors.right: parent.right
                                                anchors.verticalCenter: parent.verticalCenter
                                                text: "disconnect"
                                                color: theme.c.accent
                                                font.family: "FiraCode Nerd Font"
                                                font.pixelSize: 8
                                                renderType: Text.NativeRendering

                                                MouseArea {
                                                    anchors.fill: parent
                                                    hoverEnabled: true
                                                    onEntered: disconnectBtn.color = theme.c.accent
                                                    onExited: disconnectBtn.color = theme.c.accent
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
                                color: theme.c.accent
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
                            color: theme.c.accent
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
                                color: theme.c.accent
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
                                                    color: theme.c.accent
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
                                                color: theme.c.accent
                                                font.family: "FiraCode Nerd Font"
                                                font.pixelSize: 8
                                                renderType: Text.NativeRendering
                                            }

                                            Text {
                                                id: connectBtn

                                                anchors.right: parent.right
                                                anchors.verticalCenter: parent.verticalCenter
                                                text: "connect"
                                                color: theme.c.accent
                                                font.family: "FiraCode Nerd Font"
                                                font.pixelSize: 8
                                                renderType: Text.NativeRendering

                                                MouseArea {
                                                    anchors.fill: parent
                                                    hoverEnabled: true
                                                    onEntered: connectBtn.color = theme.c.accent
                                                    onExited: connectBtn.color = theme.c.accent
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
                                color: theme.c.accent
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
                            color: theme.c.accent
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
                                color: theme.c.accent
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
                                                color: theme.c.accent
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
                                                color: theme.c.accent
                                                font.family: "FiraCode Nerd Font"
                                                font.pixelSize: 8
                                                renderType: Text.NativeRendering

                                                MouseArea {
                                                    anchors.fill: parent
                                                    hoverEnabled: true
                                                    onEntered: pairBtn.color = theme.c.accent
                                                    onExited: pairBtn.color = theme.c.accent
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
                                color: theme.c.accent
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
                            color: theme.c.accent
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
