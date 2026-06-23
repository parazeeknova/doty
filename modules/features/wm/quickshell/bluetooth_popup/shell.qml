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
    property int lastActiveSection: 0
    property int lastActiveSubIndex: 0
    property bool isKeyboardTriggered: Quickshell.env("QS_KEYBOARD") === "1"

    signal requestClose

    function triggerRefresh() {
        refreshTimer.restart();
    }

    function saveFocusState(sec, sub) {
        var state = {
            "activeSection": sec,
            "activeSubIndex": sub
        };
        var stateStr = JSON.stringify(state);
        saveFocusProc.command = ["sh", "-c", "mkdir -p " + root.homeDir + "/.cache && echo '" + stateStr + "' > " + root.homeDir + "/.cache/quickshell_bluetooth_focus.json"];
        saveFocusProc.running = false;
        saveFocusProc.running = true;
    }

    Component.onCompleted: {
        checkStatusProc.running = true;
        focusStateFile.reload();
    }

    Process {
        id: saveFocusProc

        running: false
    }

    FileView {
        id: focusStateFile

        path: "file://" + root.homeDir + "/.cache/quickshell_bluetooth_focus.json"
        watchChanges: false
        onLoaded: {
            try {
                var raw = focusStateFile.text().trim();
                if (raw === "")
                    return;

                var parsed = JSON.parse(raw);
                if (parsed.activeSection !== undefined)
                    root.lastActiveSection = parsed.activeSection;

                if (parsed.activeSubIndex !== undefined)
                    root.lastActiveSubIndex = parsed.activeSubIndex;
            } catch (e) {
                console.log("Failed to parse bluetooth focus state: " + e);
            }
        }
    }

    Theme {
        id: theme
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
                property int activeSection: root.lastActiveSection
                property int activeSubIndex: root.lastActiveSubIndex
                property bool isLoaded: false
                property bool showFocusHighlight: root.isKeyboardTriggered
                property string focusHighlightColor: showFocusHighlight ? "#30d5c4a1" : "transparent"

                function getConnectedDevices() {
                    if (root.loading || !root.btEnabled)
                        return [];

                    return root.devices.filter(function (d) {
                        return d.connected;
                    });
                }

                function getPairedDevices() {
                    if (root.loading || !root.btEnabled)
                        return [];

                    return root.devices.filter(function (d) {
                        return d.paired && !d.connected;
                    });
                }

                function getAvailableDevices() {
                    if (root.loading || !root.btEnabled)
                        return [];

                    return root.devices.filter(function (d) {
                        return !d.paired;
                    });
                }

                function getMaxItemsForSection(section) {
                    if (section === 0)
                        return root.btEnabled ? 2 : 1;
                    else if (section === 1)
                        return getConnectedDevices().length;
                    else if (section === 2)
                        return getPairedDevices().length;
                    else if (section === 3)
                        return getAvailableDevices().length;
                    return 0;
                }

                function triggerActiveElement() {
                    if (win.activeSection === 0) {
                        if (win.activeSubIndex === 0) {
                            if (root.btEnabled)
                                Quickshell.execDetached(["bluetoothctl", "power", "off"]);
                            else
                                Quickshell.execDetached(["bluetoothctl", "power", "on"]);
                            root.triggerRefresh();
                        } else if (win.activeSubIndex === 1 && root.btEnabled) {
                            if (!checkStatusProc.running) {
                                root.scanning = true;
                                root.pendingScan = true;
                                scanTimer.restart();
                                checkStatusProc.running = true;
                            }
                        }
                    } else if (win.activeSection === 1) {
                        var connDevs = getConnectedDevices();
                        if (win.activeSubIndex < connDevs.length) {
                            var dev = connDevs[win.activeSubIndex];
                            Quickshell.execDetached(["bluetoothctl", "disconnect", dev.address]);
                            root.triggerRefresh();
                        }
                    } else if (win.activeSection === 2) {
                        var pairDevs = getPairedDevices();
                        if (win.activeSubIndex < pairDevs.length) {
                            var dev = pairDevs[win.activeSubIndex];
                            Quickshell.execDetached(["bluetoothctl", "connect", dev.address]);
                            root.triggerRefresh();
                        }
                    } else if (win.activeSection === 3) {
                        var availDevs = getAvailableDevices();
                        if (win.activeSubIndex < availDevs.length) {
                            var dev = availDevs[win.activeSubIndex];
                            Quickshell.execDetached(["bluetoothctl", "pair", dev.address]);
                            root.triggerRefresh();
                        }
                    }
                }

                function navigateSubIndex(dir) {
                    var maxItems = getMaxItemsForSection(win.activeSection);
                    if (maxItems > 0)
                        win.activeSubIndex = (win.activeSubIndex + dir + maxItems) % maxItems;
                    else
                        win.activeSubIndex = 0;
                }

                function closePopup() {
                    if (isClosing)
                        return;

                    isClosing = true;
                    exitAnim.start();
                }

                onActiveSectionChanged: {
                    if (isLoaded)
                        root.saveFocusState(activeSection, activeSubIndex);
                }
                onActiveSubIndexChanged: {
                    if (isLoaded)
                        root.saveFocusState(activeSection, activeSubIndex);
                }
                screen: modelData
                color: "transparent"
                exclusionMode: PanelWindow.ExclusionMode.Ignore
                focusable: true
                implicitWidth: 240
                implicitHeight: mainLayout.implicitHeight + 20
                Component.onCompleted: {
                    isLoaded = true;
                    introAnim.start();
                }

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
                    border.color: theme.accent
                    radius: 0
                    antialiasing: false
                    focus: true
                    Keys.onPressed: event => {
                        if (event.key === Qt.Key_Escape) {
                            win.closePopup();
                            event.accepted = true;
                        } else if (event.key === Qt.Key_Tab) {
                            win.showFocusHighlight = true;
                            var attempts = 0;
                            var nextSec = win.activeSection;
                            while (attempts < 4) {
                                if ((event.modifiers & Qt.ShiftModifier) || (event.modifiers & Qt.ControlModifier))
                                    nextSec = (nextSec + 3) % 4;
                                else
                                    nextSec = (nextSec + 1) % 4;
                                if (win.getMaxItemsForSection(nextSec) > 0) {
                                    win.activeSection = nextSec;
                                    break;
                                }
                                attempts++;
                            }
                            win.activeSubIndex = 0;
                            event.accepted = true;
                        } else if (event.key === Qt.Key_Down || event.key === Qt.Key_Right) {
                            win.showFocusHighlight = true;
                            win.navigateSubIndex(1);
                            event.accepted = true;
                        } else if (event.key === Qt.Key_Up || event.key === Qt.Key_Left) {
                            win.showFocusHighlight = true;
                            win.navigateSubIndex(-1);
                            event.accepted = true;
                        } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Space) {
                            win.showFocusHighlight = true;
                            win.triggerActiveElement();
                            event.accepted = true;
                        }
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
                        Item {
                            width: parent.width
                            height: Math.max(titleColumn.implicitHeight, toggleRow.implicitHeight)

                            Column {
                                id: titleColumn

                                anchors.left: parent.left
                                anchors.right: toggleRow.left
                                anchors.rightMargin: 8
                                spacing: 2

                                Text {
                                    text: "Bluetooth"
                                    color: theme.accent
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

                                        var connected = root.devices.filter(function (d) {
                                            return d.connected;
                                        });
                                        if (connected.length === 0)
                                            return "No devices connected";

                                        return connected.map(function (d) {
                                            return d.name;
                                        }).join(", ");
                                    }
                                    color: theme.accent
                                    opacity: 0.6
                                    font.family: "FiraCode Nerd Font"
                                    font.pixelSize: 8
                                    elide: Text.ElideRight
                                    width: parent.width
                                    renderType: Text.NativeRendering
                                    visible: true
                                }
                            }

                            Row {
                                id: toggleRow

                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 8

                                Text {
                                    id: btToggleText

                                    anchors.verticalCenter: parent.verticalCenter
                                    text: root.btEnabled === null ? "--" : (root.btEnabled ? "On" : "Off")
                                    color: theme.accent
                                    font.family: "FiraCode Nerd Font"
                                    font.pixelSize: 9
                                    font.bold: true
                                    renderType: Text.NativeRendering

                                    Rectangle {
                                        anchors.fill: parent
                                        anchors.margins: -2
                                        color: (win.activeSection === 0 && win.activeSubIndex === 0) ? win.focusHighlightColor : "transparent"
                                        radius: 0
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        onEntered: btToggleText.color = theme.accent
                                        onExited: btToggleText.color = theme.accent
                                        onClicked: {
                                            if (root.btEnabled)
                                                Quickshell.execDetached(["bluetoothctl", "power", "off"]);
                                            else
                                                Quickshell.execDetached(["bluetoothctl", "power", "on"]);
                                            root.triggerRefresh();
                                        }
                                    }
                                }

                                Text {
                                    id: scanBtn

                                    anchors.verticalCenter: parent.verticalCenter
                                    text: root.scanning ? "refreshing" : "refresh"
                                    color: theme.accent
                                    font.family: "FiraCode Nerd Font"
                                    font.pixelSize: 8
                                    renderType: Text.NativeRendering
                                    visible: root.btEnabled

                                    Rectangle {
                                        anchors.fill: parent
                                        anchors.margins: -2
                                        color: (win.activeSection === 0 && win.activeSubIndex === 1) ? win.focusHighlightColor : "transparent"
                                        radius: 0
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        onEntered: scanBtn.color = theme.accent
                                        onExited: scanBtn.color = theme.accent
                                        onClicked: {
                                            if (checkStatusProc.running)
                                                return;

                                            root.scanning = true;
                                            root.pendingScan = true;
                                            scanTimer.restart();
                                            checkStatusProc.running = true;
                                        }
                                    }
                                }
                            }
                        }

                        Rectangle {
                            width: parent.width
                            height: 1
                            color: theme.accent
                            opacity: 0.15
                        }

                        Text {
                            text: "  Loading devices..."
                            color: theme.accent
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
                            visible: !root.loading && root.btEnabled && root.devices.filter(function (d) {
                                return d.connected;
                            }).length > 0

                            Text {
                                text: "Connected"
                                color: theme.accent
                                font.family: "FiraCode Nerd Font"
                                font.pixelSize: 9
                                font.bold: true
                                renderType: Text.NativeRendering
                            }

                            Column {
                                width: parent.width
                                spacing: 2

                                Repeater {
                                    model: root.devices.filter(function (d) {
                                        return d.connected;
                                    })

                                    delegate: Column {
                                        width: parent.width
                                        spacing: 2

                                        Rectangle {
                                            width: parent.width
                                            height: 16
                                            color: (win.activeSection === 1 && win.activeSubIndex === index) ? win.focusHighlightColor : "transparent"
                                            radius: 0

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
                                                    color: theme.accent
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
                                                color: theme.accent
                                                font.family: "FiraCode Nerd Font"
                                                font.pixelSize: 8
                                                renderType: Text.NativeRendering
                                            }

                                            Text {
                                                id: disconnectBtn

                                                anchors.right: parent.right
                                                anchors.verticalCenter: parent.verticalCenter
                                                text: "disconnect"
                                                color: theme.accent
                                                font.family: "FiraCode Nerd Font"
                                                font.pixelSize: 8
                                                renderType: Text.NativeRendering

                                                MouseArea {
                                                    anchors.fill: parent
                                                    hoverEnabled: true
                                                    onEntered: disconnectBtn.color = theme.accent
                                                    onExited: disconnectBtn.color = theme.accent
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
                                color: theme.accent
                                opacity: 0.5
                                font.family: "FiraCode Nerd Font"
                                font.pixelSize: 8
                                renderType: Text.NativeRendering
                                visible: root.devices.filter(function (d) {
                                    return d.connected;
                                }).length === 0
                            }
                        }

                        Rectangle {
                            width: parent.width
                            height: 1
                            color: theme.accent
                            opacity: 0.15
                            visible: !root.loading && root.btEnabled && root.devices.filter(function (d) {
                                return d.connected;
                            }).length > 0
                        }

                        // --- SECTION 4: PAIRED DEVICES ---
                        Column {
                            width: parent.width
                            spacing: 3
                            visible: !root.loading && root.btEnabled && root.devices.filter(function (d) {
                                return d.paired && !d.connected;
                            }).length > 0

                            Text {
                                text: "Paired"
                                color: theme.accent
                                font.family: "FiraCode Nerd Font"
                                font.pixelSize: 9
                                font.bold: true
                                renderType: Text.NativeRendering
                            }

                            Column {
                                width: parent.width
                                spacing: 2

                                Repeater {
                                    model: root.devices.filter(function (d) {
                                        return d.paired && !d.connected;
                                    })

                                    delegate: Column {
                                        width: parent.width
                                        spacing: 2

                                        Rectangle {
                                            width: parent.width
                                            height: 16
                                            color: (win.activeSection === 2 && win.activeSubIndex === index) ? win.focusHighlightColor : "transparent"
                                            radius: 0

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
                                                    color: theme.accent
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
                                                color: theme.accent
                                                font.family: "FiraCode Nerd Font"
                                                font.pixelSize: 8
                                                renderType: Text.NativeRendering
                                            }

                                            Text {
                                                id: connectBtn

                                                anchors.right: parent.right
                                                anchors.verticalCenter: parent.verticalCenter
                                                text: "connect"
                                                color: theme.accent
                                                font.family: "FiraCode Nerd Font"
                                                font.pixelSize: 8
                                                renderType: Text.NativeRendering

                                                MouseArea {
                                                    anchors.fill: parent
                                                    hoverEnabled: true
                                                    onEntered: connectBtn.color = theme.accent
                                                    onExited: connectBtn.color = theme.accent
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
                                color: theme.accent
                                opacity: 0.5
                                font.family: "FiraCode Nerd Font"
                                font.pixelSize: 8
                                renderType: Text.NativeRendering
                                visible: root.devices.filter(function (d) {
                                    return d.paired && !d.connected;
                                }).length === 0
                            }
                        }

                        Rectangle {
                            width: parent.width
                            height: 1
                            color: theme.accent
                            opacity: 0.15
                            visible: !root.loading && root.btEnabled && root.devices.filter(function (d) {
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
                                color: theme.accent
                                font.family: "FiraCode Nerd Font"
                                font.pixelSize: 9
                                font.bold: true
                                renderType: Text.NativeRendering
                            }

                            Column {
                                width: parent.width
                                spacing: 2

                                Repeater {
                                    model: root.devices.filter(function (d) {
                                        return !d.paired;
                                    })

                                    delegate: Column {
                                        width: parent.width
                                        spacing: 2

                                        Rectangle {
                                            width: parent.width
                                            height: 16
                                            color: (win.activeSection === 3 && win.activeSubIndex === index) ? win.focusHighlightColor : "transparent"
                                            radius: 0

                                            Text {
                                                anchors.left: parent.left
                                                anchors.verticalCenter: parent.verticalCenter
                                                text: modelData.name
                                                color: theme.accent
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
                                                color: theme.accent
                                                font.family: "FiraCode Nerd Font"
                                                font.pixelSize: 8
                                                renderType: Text.NativeRendering

                                                MouseArea {
                                                    anchors.fill: parent
                                                    hoverEnabled: true
                                                    onEntered: pairBtn.color = theme.accent
                                                    onExited: pairBtn.color = theme.accent
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
                                color: theme.accent
                                opacity: 0.5
                                font.family: "FiraCode Nerd Font"
                                font.pixelSize: 8
                                renderType: Text.NativeRendering
                                visible: root.devices.filter(function (d) {
                                    return !d.paired;
                                }).length === 0
                            }
                        }

                        // --- FOOTER: Bluetooth off message ---
                        Text {
                            text: "  Bluetooth is disabled"
                            color: theme.accent
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
