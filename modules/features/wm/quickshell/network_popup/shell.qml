import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io

Scope {
    id: root

    property string homeDir: Quickshell.env("HOME")
    // Network state properties
    property bool wifiEnabled: false
    property bool airplaneMode: false
    property bool connected: false
    property string activeSsid: ""
    property int activeSignal: 0
    property bool warpConnected: false
    property var details: ({
            "ip_address": "",
            "gateway": "",
            "dns": "",
            "subnet": "",
            "security": "",
            "bssid": ""
        })
    property var networks: []
    property var vpns: []
    property bool detailsExpanded: false
    property string expandedNetworkSsid: "" // Tracks which scanned network is expanded for actions
    property int lastActiveSection: 0
    property int lastActiveSubIndex: 0
    property bool isKeyboardTriggered: Quickshell.env("QS_KEYBOARD") === "1"

    signal requestClose

    function getNetworkSectionItemsCount() {
        // Connect, Forget, Auto buttons

        var count = 0;
        for (var i = 0; i < root.networks.length; i++) {
            count++; // the header row
            if (root.expandedNetworkSsid === root.networks[i].ssid)
                count += 3;
        }
        return count;
    }

    function getNetworkItemAtSubIndex(subIndex) {
        var current = 0;
        for (var i = 0; i < root.networks.length; i++) {
            if (current === subIndex)
                return {
                    "type": "header",
                    "netIndex": i,
                    "netData": root.networks[i]
                };

            current++;
            if (root.expandedNetworkSsid === root.networks[i].ssid) {
                if (current === subIndex)
                    return {
                        "type": "connect",
                        "netIndex": i,
                        "netData": root.networks[i]
                    };

                current++;
                if (current === subIndex)
                    return {
                        "type": "forget",
                        "netIndex": i,
                        "netData": root.networks[i]
                    };

                current++;
                if (current === subIndex)
                    return {
                        "type": "auto",
                        "netIndex": i,
                        "netData": root.networks[i]
                    };

                current++;
            }
        }
        return null;
    }

    function saveFocusState(sec, sub) {
        var state = {
            "activeSection": sec,
            "activeSubIndex": sub
        };
        var stateStr = JSON.stringify(state);
        saveFocusProc.command = ["sh", "-c", "mkdir -p " + root.homeDir + "/.cache && echo '" + stateStr + "' > " + root.homeDir + "/.cache/quickshell_network_focus.json"];
        saveFocusProc.running = false;
        saveFocusProc.running = true;
    }

    function triggerRefresh() {
        refreshTimer.restart();
        focusStateFile.reload();
    }

    Component.onCompleted: {
        checkStatusProc.running = true;
    }

    Process {
        id: saveFocusProc

        running: false
    }

    FileView {
        id: focusStateFile

        path: "file://" + root.homeDir + "/.cache/quickshell_network_focus.json"
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
                console.log("Failed to parse network focus state: " + e);
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

        target: "network_popup"
    }

    // Process to run the Rust helper
    Process {
        id: checkStatusProc

        command: [root.homeDir + "/.config/quickshell/network_popup/get_network_status"]
        running: false

        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var data = JSON.parse(this.text);
                    root.wifiEnabled = data.wifi_enabled;
                    root.airplaneMode = data.airplane_mode;
                    root.connected = data.connected;
                    root.activeSsid = data.active_ssid || "";
                    root.activeSignal = data.active_signal || 0;
                    root.warpConnected = data.warp_connected || false;
                    root.details = data.details || ({
                            "ip_address": "",
                            "gateway": "",
                            "dns": "",
                            "subnet": "",
                            "security": "",
                            "bssid": ""
                        });
                    root.networks = data.networks || [];
                    root.vpns = data.vpns || [];
                } catch (e) {
                    console.log("Failed to parse network status: " + e);
                }
            }
        }
    }

    // Timer to wait and refresh status after actions
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

    // Periodic polling every 3 seconds
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

                function navigateSubIndex(dir) {
                    var maxItems = 0;
                    if (win.activeSection === 0)
                        maxItems = 2;
                    else if (win.activeSection === 1)
                        maxItems = 1;
                    else if (win.activeSection === 2)
                        maxItems = 1 + root.vpns.length;
                    else if (win.activeSection === 3)
                        maxItems = root.getNetworkSectionItemsCount();
                    else if (win.activeSection === 4)
                        maxItems = 2;
                    if (maxItems > 0)
                        win.activeSubIndex = (win.activeSubIndex + dir + maxItems) % maxItems;
                    else
                        win.activeSubIndex = 0;
                }

                function triggerActiveElement() {
                    if (win.activeSection === 0) {
                        if (win.activeSubIndex === 0) {
                            if (root.wifiEnabled)
                                Quickshell.execDetached(["nmcli", "radio", "wifi", "off"]);
                            else
                                Quickshell.execDetached(["nmcli", "radio", "wifi", "on"]);
                            root.triggerRefresh();
                        } else if (win.activeSubIndex === 1) {
                            if (root.airplaneMode)
                                Quickshell.execDetached(["rfkill", "unblock", "all"]);
                            else
                                Quickshell.execDetached(["rfkill", "block", "all"]);
                            root.triggerRefresh();
                        }
                    } else if (win.activeSection === 1) {
                        if (win.activeSubIndex === 0)
                            root.detailsExpanded = !root.detailsExpanded;
                    } else if (win.activeSection === 2) {
                        if (win.activeSubIndex === 0) {
                            if (root.warpConnected)
                                Quickshell.execDetached(["warp-cli", "disconnect"]);
                            else
                                Quickshell.execDetached(["warp-cli", "connect"]);
                            root.triggerRefresh();
                        } else {
                            var idx = win.activeSubIndex - 1;
                            if (idx >= 0 && idx < root.vpns.length) {
                                var vpn = root.vpns[idx];
                                if (vpn.active)
                                    Quickshell.execDetached(["nmcli", "connection", "down", vpn.name]);
                                else
                                    Quickshell.execDetached(["nmcli", "connection", "up", vpn.name]);
                                root.triggerRefresh();
                            }
                        }
                    } else if (win.activeSection === 3) {
                        var item = root.getNetworkItemAtSubIndex(win.activeSubIndex);
                        if (item) {
                            if (item.type === "header") {
                                if (root.expandedNetworkSsid === item.netData.ssid)
                                    root.expandedNetworkSsid = "";
                                else
                                    root.expandedNetworkSsid = item.netData.ssid;
                            } else if (item.type === "connect") {
                                if (item.netData.active) {
                                    Quickshell.execDetached(["nmcli", "device", "disconnect", "wlan0"]);
                                } else {
                                    var script = "SSID=\"$1\"; SECURITY=\"$2\"; if nmcli connection show id \"$SSID\" >/dev/null 2>&1; then nmcli device wifi connect \"$SSID\"; else if [ \"$SECURITY\" != \"--\" ] && [ -n \"$SECURITY\" ]; then pass=$(rofi -dmenu -password -p \"Password for $SSID\"); [ -n \"$pass\" ] && nmcli device wifi connect \"$SSID\" password \"$pass\"; else nmcli device wifi connect \"$SSID\"; fi; fi";
                                    Quickshell.execDetached(["sh", "-c", script, "sh", item.netData.ssid, item.netData.security]);
                                }
                                root.expandedNetworkSsid = "";
                                root.triggerRefresh();
                            } else if (item.type === "forget") {
                                Quickshell.execDetached(["nmcli", "connection", "delete", item.netData.ssid]);
                                root.expandedNetworkSsid = "";
                                root.triggerRefresh();
                            } else if (item.type === "auto") {
                                var val = item.netData.autoconnect ? "no" : "yes";
                                Quickshell.execDetached(["nmcli", "connection", "modify", item.netData.ssid, "connection.autoconnect", val]);
                                root.triggerRefresh();
                            }
                        }
                    } else if (win.activeSection === 4) {
                        if (win.activeSubIndex === 0) {
                            Quickshell.execDetached(["hyprctl", "dispatch", 'hl.dsp.exec_cmd("[float;size 55% 65%;center] ghostty --title=impala -e impala")']);
                            win.closePopup();
                        } else if (win.activeSubIndex === 1) {
                            Quickshell.execDetached(["nmcli", "radio", "wifi", "off"]);
                            Quickshell.execDetached(["sh", "-c", "sleep 0.5 && nmcli radio wifi on"]);
                            root.triggerRefresh();
                        }
                    }
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
                            if ((event.modifiers & Qt.ShiftModifier) || (event.modifiers & Qt.ControlModifier))
                                win.activeSection = (win.activeSection + 4) % 5;
                            else
                                win.activeSection = (win.activeSection + 1) % 5;
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
                        // --- SECTION 3: CONNECTION DETAILS COLLAPSIBLE ---

                        id: mainLayout

                        anchors.top: parent.top
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.margins: 10
                        spacing: 8

                        // --- SECTION 1: HEADER STATUS ---
                        Column {
                            width: parent.width
                            spacing: 2

                            Text {
                                text: root.connected ? "Wi-Fi Connected" : "Wi-Fi Disconnected"
                                color: theme.accent
                                font.family: "FiraCode Nerd Font"
                                font.pixelSize: 10
                                font.bold: true
                                renderType: Text.NativeRendering
                            }

                            Column {
                                width: parent.width
                                spacing: 1
                                visible: root.connected

                                Text {
                                    text: "SSID: " + root.activeSsid
                                    color: theme.accent
                                    font.family: "FiraCode Nerd Font"
                                    font.pixelSize: 9
                                    elide: Text.ElideRight
                                    renderType: Text.NativeRendering
                                }

                                Text {
                                    text: "Signal: " + root.activeSignal + "%"
                                    color: theme.accent
                                    opacity: 0.6
                                    font.family: "FiraCode Nerd Font"
                                    font.pixelSize: 8
                                    renderType: Text.NativeRendering
                                }
                            }
                        }

                        Rectangle {
                            width: parent.width
                            height: 1
                            color: theme.accent
                            opacity: 0.15
                        }

                        // --- SECTION 2: QUICK TOGGLES ---
                        Row {
                            spacing: 20
                            anchors.horizontalCenter: parent.horizontalCenter

                            // WiFi Toggle Button
                            Text {
                                id: wifiToggleText

                                text: "Wi-Fi: " + (root.wifiEnabled ? "On" : "Off")
                                color: theme.accent
                                font.family: "FiraCode Nerd Font"
                                font.pixelSize: 9
                                font.bold: true
                                renderType: Text.NativeRendering

                                Rectangle {
                                    anchors.fill: parent
                                    color: (win.activeSection === 0 && win.activeSubIndex === 0) ? win.focusHighlightColor : "transparent"
                                    radius: 0
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    onEntered: wifiToggleText.color = theme.accent
                                    onExited: wifiToggleText.color = theme.accent
                                    onClicked: {
                                        if (root.wifiEnabled)
                                            Quickshell.execDetached(["nmcli", "radio", "wifi", "off"]);
                                        else
                                            Quickshell.execDetached(["nmcli", "radio", "wifi", "on"]);
                                        root.triggerRefresh();
                                    }
                                }
                            }

                            // Airplane Mode Button
                            Text {
                                id: airplaneToggleText

                                text: "Airplane: " + (root.airplaneMode ? "On" : "Off")
                                color: theme.accent
                                font.family: "FiraCode Nerd Font"
                                font.pixelSize: 9
                                font.bold: true
                                renderType: Text.NativeRendering

                                Rectangle {
                                    anchors.fill: parent
                                    color: (win.activeSection === 0 && win.activeSubIndex === 1) ? win.focusHighlightColor : "transparent"
                                    radius: 0
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    onEntered: airplaneToggleText.color = theme.accent
                                    onExited: airplaneToggleText.color = theme.accent
                                    onClicked: {
                                        if (root.airplaneMode)
                                            Quickshell.execDetached(["rfkill", "unblock", "all"]);
                                        else
                                            Quickshell.execDetached(["rfkill", "block", "all"]);
                                        root.triggerRefresh();
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

                        Column {
                            width: parent.width
                            spacing: 4

                            Rectangle {
                                width: parent.width
                                height: 14
                                color: (win.activeSection === 1 && win.activeSubIndex === 0) ? win.focusHighlightColor : "transparent"
                                radius: 0

                                Text {
                                    text: "Details " + (root.detailsExpanded ? "󰅀" : "󰅂")
                                    color: theme.accent
                                    font.family: "FiraCode Nerd Font"
                                    font.pixelSize: 9
                                    font.bold: true
                                    renderType: Text.NativeRendering
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    onClicked: {
                                        root.detailsExpanded = !root.detailsExpanded;
                                    }
                                }
                            }

                            Column {
                                width: parent.width
                                spacing: 2
                                visible: root.detailsExpanded && root.connected

                                Text {
                                    text: "  IP: " + root.details.ip_address
                                    color: theme.accent
                                    font.family: "FiraCode Nerd Font"
                                    font.pixelSize: 8
                                    renderType: Text.NativeRendering
                                }

                                Text {
                                    text: "  Gateway: " + root.details.gateway
                                    color: theme.accent
                                    font.family: "FiraCode Nerd Font"
                                    font.pixelSize: 8
                                    renderType: Text.NativeRendering
                                }

                                Text {
                                    text: "  Subnet: " + root.details.subnet
                                    color: theme.accent
                                    font.family: "FiraCode Nerd Font"
                                    font.pixelSize: 8
                                    renderType: Text.NativeRendering
                                }

                                Text {
                                    text: "  DNS: " + root.details.dns
                                    color: theme.accent
                                    font.family: "FiraCode Nerd Font"
                                    font.pixelSize: 8
                                    renderType: Text.NativeRendering
                                }

                                Text {
                                    text: "  BSSID: " + root.details.bssid
                                    color: theme.accent
                                    font.family: "FiraCode Nerd Font"
                                    font.pixelSize: 8
                                    renderType: Text.NativeRendering
                                }

                                Text {
                                    text: "  Security: " + root.details.security
                                    color: theme.accent
                                    font.family: "FiraCode Nerd Font"
                                    font.pixelSize: 8
                                    renderType: Text.NativeRendering
                                }
                            }

                            Text {
                                text: "  No connection active"
                                color: theme.accent
                                opacity: 0.5
                                font.family: "FiraCode Nerd Font"
                                font.pixelSize: 8
                                renderType: Text.NativeRendering
                                visible: root.detailsExpanded && !root.connected
                            }
                        }

                        // --- SECTION 4: VPN SECTION ---
                        Column {
                            width: parent.width
                            spacing: 3

                            Text {
                                text: "VPN"
                                color: theme.accent
                                font.family: "FiraCode Nerd Font"
                                font.pixelSize: 9
                                font.bold: true
                                renderType: Text.NativeRendering
                            }

                            // WARP Toggle
                            Rectangle {
                                width: parent.width
                                height: 16
                                color: (win.activeSection === 2 && win.activeSubIndex === 0) ? win.focusHighlightColor : "transparent"
                                radius: 0

                                Text {
                                    anchors.left: parent.left
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: "WARP: " + (root.warpConnected ? "Connected" : "Disconnected")
                                    color: theme.accent
                                    font.family: "FiraCode Nerd Font"
                                    font.pixelSize: 8
                                    renderType: Text.NativeRendering
                                }

                                Text {
                                    id: warpToggleBtn

                                    anchors.right: parent.right
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: root.warpConnected ? "disconnect" : "connect"
                                    color: theme.accent
                                    font.family: "FiraCode Nerd Font"
                                    font.pixelSize: 8
                                    renderType: Text.NativeRendering

                                    MouseArea {
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        onEntered: warpToggleBtn.color = theme.accent
                                        onExited: warpToggleBtn.color = theme.accent
                                        onClicked: {
                                            if (root.warpConnected)
                                                Quickshell.execDetached(["warp-cli", "disconnect"]);
                                            else
                                                Quickshell.execDetached(["warp-cli", "connect"]);
                                            root.triggerRefresh();
                                        }
                                    }
                                }
                            }

                            Column {
                                width: parent.width
                                spacing: 2
                                visible: root.vpns.length > 0

                                Repeater {
                                    model: root.vpns

                                    delegate: Rectangle {
                                        width: parent.width
                                        height: 16
                                        color: (win.activeSection === 2 && win.activeSubIndex === (index + 1)) ? win.focusHighlightColor : "transparent"
                                        radius: 0

                                        Text {
                                            id: vpnNameText

                                            anchors.left: parent.left
                                            anchors.verticalCenter: parent.verticalCenter
                                            text: modelData.name + " (" + modelData.vpn_type + ")"
                                            color: theme.accent
                                            font.family: "FiraCode Nerd Font"
                                            font.pixelSize: 8
                                            renderType: Text.NativeRendering
                                        }

                                        Text {
                                            id: vpnActionBtn

                                            anchors.right: parent.right
                                            anchors.verticalCenter: parent.verticalCenter
                                            text: modelData.active ? "disconnect" : "connect"
                                            color: theme.accent
                                            font.family: "FiraCode Nerd Font"
                                            font.pixelSize: 8
                                            renderType: Text.NativeRendering

                                            MouseArea {
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                onEntered: vpnActionBtn.color = theme.accent
                                                onExited: vpnActionBtn.color = theme.accent
                                                onClicked: {
                                                    if (modelData.active)
                                                        Quickshell.execDetached(["nmcli", "connection", "down", modelData.name]);
                                                    else
                                                        Quickshell.execDetached(["nmcli", "connection", "up", modelData.name]);
                                                    root.triggerRefresh();
                                                }
                                            }
                                        }
                                    }
                                }
                            }

                            Text {
                                text: "  Disabled"
                                color: theme.accent
                                opacity: 0.5
                                font.family: "FiraCode Nerd Font"
                                font.pixelSize: 8
                                renderType: Text.NativeRendering
                                visible: root.vpns.length === 0
                            }
                        }

                        // --- SECTION 5: SCANNED NETWORK LIST ---
                        Column {
                            width: parent.width
                            spacing: 3

                            Text {
                                text: "WiFi Networks"
                                color: theme.accent
                                font.family: "FiraCode Nerd Font"
                                font.pixelSize: 9
                                font.bold: true
                                renderType: Text.NativeRendering
                            }

                            Column {
                                width: parent.width
                                spacing: 3

                                Repeater {
                                    model: root.networks

                                    delegate: Column {
                                        width: parent.width
                                        spacing: 2

                                        // Scanned SSID Row
                                        Rectangle {
                                            width: parent.width
                                            height: 16
                                            color: {
                                                var item = root.getNetworkItemAtSubIndex(win.activeSubIndex);
                                                if (win.activeSection === 3 && item && item.type === "header" && item.netIndex === index)
                                                    return win.focusHighlightColor;

                                                return "transparent";
                                            }
                                            radius: 0

                                            Row {
                                                anchors.left: parent.left
                                                anchors.verticalCenter: parent.verticalCenter
                                                spacing: 4

                                                Text {
                                                    text: (modelData.active ? "* " : "  ") + modelData.ssid
                                                    color: theme.accent
                                                    font.family: "FiraCode Nerd Font"
                                                    font.pixelSize: 8
                                                    font.bold: modelData.active
                                                    elide: Text.ElideRight
                                                    width: 140
                                                    renderType: Text.NativeRendering
                                                }
                                            }

                                            // Signal Strength Bars
                                            Text {
                                                anchors.right: parent.right
                                                anchors.verticalCenter: parent.verticalCenter
                                                textFormat: Text.RichText
                                                text: {
                                                    var activeLimit = Math.round(modelData.signal / 20);
                                                    var activeColor = theme.accent;
                                                    var inactiveColor = theme.bg_light;
                                                    var str = "";
                                                    for (var i = 0; i < 5; i++) {
                                                        var color = (i < activeLimit) ? activeColor : inactiveColor;
                                                        str += "<font color='" + color + "'>█</font>";
                                                    }
                                                    return str;
                                                }
                                                font.family: "FiraCode Nerd Font"
                                                font.pixelSize: 8
                                                renderType: Text.NativeRendering
                                            }

                                            MouseArea {
                                                anchors.fill: parent
                                                onClicked: {
                                                    if (root.expandedNetworkSsid === modelData.ssid)
                                                        root.expandedNetworkSsid = "";
                                                    else
                                                        root.expandedNetworkSsid = modelData.ssid;
                                                }
                                            }
                                        }

                                        // Expanded connection/forget/auto-connect options
                                        Column {
                                            width: parent.width
                                            spacing: 2
                                            visible: root.expandedNetworkSsid === modelData.ssid

                                            Row {
                                                spacing: 10
                                                anchors.horizontalCenter: parent.horizontalCenter

                                                Text {
                                                    id: connActionBtn

                                                    text: modelData.active ? "Disconnect" : "Connect"
                                                    color: theme.accent
                                                    font.family: "FiraCode Nerd Font"
                                                    font.pixelSize: 8
                                                    renderType: Text.NativeRendering

                                                    Rectangle {
                                                        anchors.fill: parent
                                                        color: {
                                                            var item = root.getNetworkItemAtSubIndex(win.activeSubIndex);
                                                            if (win.activeSection === 3 && item && item.type === "connect" && item.netIndex === index)
                                                                return win.focusHighlightColor;

                                                            return "transparent";
                                                        }
                                                        radius: 0
                                                    }

                                                    MouseArea {
                                                        anchors.fill: parent
                                                        hoverEnabled: true
                                                        onEntered: connActionBtn.color = theme.accent
                                                        onExited: connActionBtn.color = theme.accent
                                                        onClicked: {
                                                            if (modelData.active) {
                                                                Quickshell.execDetached(["nmcli", "device", "disconnect", "wlan0"]);
                                                            } else {
                                                                var script = "SSID=\"$1\"; SECURITY=\"$2\"; " + "if nmcli connection show id \"$SSID\" >/dev/null 2>&1; then " + "  nmcli device wifi connect \"$SSID\"; " + "else " + "  if [ \"$SECURITY\" != \"--\" ] && [ -n \"$SECURITY\" ]; then " + "    pass=$(rofi -dmenu -password -p \"Password for $SSID\"); " + "    [ -n \"$pass\" ] && nmcli device wifi connect \"$SSID\" password \"$pass\"; " + "  else " + "    nmcli device wifi connect \"$SSID\"; " + "  fi; " + "fi";
                                                                Quickshell.execDetached(["sh", "-c", script, "sh", modelData.ssid, modelData.security]);
                                                            }
                                                            root.expandedNetworkSsid = "";
                                                            root.triggerRefresh();
                                                        }
                                                    }
                                                }

                                                Text {
                                                    id: forgetActionBtn

                                                    text: "Forget"
                                                    color: theme.accent
                                                    font.family: "FiraCode Nerd Font"
                                                    font.pixelSize: 8
                                                    renderType: Text.NativeRendering

                                                    Rectangle {
                                                        anchors.fill: parent
                                                        color: {
                                                            var item = root.getNetworkItemAtSubIndex(win.activeSubIndex);
                                                            if (win.activeSection === 3 && item && item.type === "forget" && item.netIndex === index)
                                                                return win.focusHighlightColor;

                                                            return "transparent";
                                                        }
                                                        radius: 0
                                                    }

                                                    MouseArea {
                                                        anchors.fill: parent
                                                        hoverEnabled: true
                                                        onEntered: forgetActionBtn.color = theme.accent
                                                        onExited: forgetActionBtn.color = theme.accent
                                                        onClicked: {
                                                            Quickshell.execDetached(["nmcli", "connection", "delete", modelData.ssid]);
                                                            root.expandedNetworkSsid = "";
                                                            root.triggerRefresh();
                                                        }
                                                    }
                                                }

                                                Text {
                                                    id: autoActionBtn

                                                    text: "Auto: " + (modelData.autoconnect ? "On" : "Off")
                                                    color: theme.accent
                                                    font.family: "FiraCode Nerd Font"
                                                    font.pixelSize: 8
                                                    renderType: Text.NativeRendering

                                                    Rectangle {
                                                        anchors.fill: parent
                                                        color: {
                                                            var item = root.getNetworkItemAtSubIndex(win.activeSubIndex);
                                                            if (win.activeSection === 3 && item && item.type === "auto" && item.netIndex === index)
                                                                return win.focusHighlightColor;

                                                            return "transparent";
                                                        }
                                                        radius: 0
                                                    }

                                                    MouseArea {
                                                        anchors.fill: parent
                                                        hoverEnabled: true
                                                        onEntered: autoActionBtn.color = theme.accent
                                                        onExited: autoActionBtn.color = theme.accent
                                                        onClicked: {
                                                            var val = modelData.autoconnect ? "no" : "yes";
                                                            Quickshell.execDetached(["nmcli", "connection", "modify", modelData.ssid, "connection.autoconnect", val]);
                                                            root.triggerRefresh();
                                                        }
                                                    }
                                                }
                                            }

                                            // Additional details for scanned network
                                            Text {
                                                anchors.horizontalCenter: parent.horizontalCenter
                                                text: "Security: " + modelData.security + " | Rate: " + modelData.rate
                                                color: theme.accent
                                                opacity: 0.6
                                                font.family: "FiraCode Nerd Font"
                                                font.pixelSize: 7
                                                renderType: Text.NativeRendering
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        // --- SECTION 6: FOOTER ACTIONS ---
                        Row {
                            spacing: 20
                            anchors.horizontalCenter: parent.horizontalCenter

                            // Network Settings
                            Text {
                                id: settingsBtn

                                text: "Settings"
                                color: theme.accent
                                font.family: "FiraCode Nerd Font"
                                font.pixelSize: 9
                                renderType: Text.NativeRendering

                                Rectangle {
                                    anchors.fill: parent
                                    color: (win.activeSection === 4 && win.activeSubIndex === 0) ? win.focusHighlightColor : "transparent"
                                    radius: 0
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    onEntered: settingsBtn.color = theme.accent
                                    onExited: settingsBtn.color = theme.accent
                                    onClicked: {
                                        Quickshell.execDetached(["hyprctl", "dispatch", 'hl.dsp.exec_cmd("[float;size 55% 65%;center] ghostty --title=impala -e impala")']);
                                        win.closePopup(); // Close popup when launching settings editor
                                    }
                                }
                            }

                            // Restart WiFi
                            Text {
                                id: restartBtn

                                text: "Restart Wi-Fi"
                                color: theme.accent
                                font.family: "FiraCode Nerd Font"
                                font.pixelSize: 9
                                renderType: Text.NativeRendering

                                Rectangle {
                                    anchors.fill: parent
                                    color: (win.activeSection === 4 && win.activeSubIndex === 1) ? win.focusHighlightColor : "transparent"
                                    radius: 0
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    onEntered: restartBtn.color = theme.accent
                                    onExited: restartBtn.color = theme.accent
                                    onClicked: {
                                        Quickshell.execDetached(["nmcli", "radio", "wifi", "off"]);
                                        // Detached delay helper or execute sequential shell command
                                        Quickshell.execDetached(["sh", "-c", "sleep 0.5 && nmcli radio wifi on"]);
                                        root.triggerRefresh();
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
