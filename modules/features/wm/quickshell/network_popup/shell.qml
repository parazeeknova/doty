import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland

Scope {
    id: root

    property string homeDir: Quickshell.env("HOME")
    // Network state properties
    property bool wifiEnabled: false
    property bool airplaneMode: false
    property bool connected: false
    property string activeSsid: ""
    property int activeSignal: 0
    property string wifiDevice: "wlo1"
    property bool warpConnected: false
    property bool tailscaleConnected: false
    property string tailscaleIp: ""
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
    property bool moreExpanded: false
    property string expandedNetworkSsid: "" // Tracks which scanned network is expanded for actions
    property bool isScanning: false
    property int lastActiveSection: 0
    property int lastActiveSubIndex: 0
    property bool isKeyboardTriggered: Quickshell.env("QS_KEYBOARD") === "1"

    signal requestClose

    function getNetworkSectionItemsCount() {
        var count = 0;
        for (var i = 0; i < root.networks.length; i++) {
            count++; // the header row
            if (root.expandedNetworkSsid === root.networks[i].ssid) {
                if (root.networks[i].saved)
                    count += 3;
                else
                    // Connect, Forget, Auto
                    count += 1; // Connect
            }
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
                if (root.networks[i].saved) {
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

    function triggerScan() {
        if (updateStatusProc.running)
            return;
        root.isScanning = true;
        updateStatusProc.running = false;
        updateStatusProc.running = true;
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

    FileView {
        id: statusCacheFile

        path: "file://" + root.homeDir + "/.cache/quickshell/network_status.json"
        watchChanges: true
        onLoaded: {
            try {
                var raw = statusCacheFile.text().trim();
                if (raw === "")
                    return;

                var data = JSON.parse(raw);
                root.wifiEnabled = data.wifi_enabled ?? false;
                root.airplaneMode = data.airplane_mode ?? false;
                root.connected = data.connected ?? false;
                root.activeSsid = data.active_ssid || "";
                root.activeSignal = data.active_signal || 0;
                root.wifiDevice = data.wifi_device || "wlo1";
                root.warpConnected = data.warp_connected || false;
                root.tailscaleConnected = data.tailscale_connected || false;
                root.tailscaleIp = data.tailscale_ip || "";
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
                console.log("Failed to parse network status cache: " + e);
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
                    root.wifiDevice = data.wifi_device || "wlo1";
                    root.warpConnected = data.warp_connected || false;
                    root.tailscaleConnected = data.tailscale_connected || false;
                    root.tailscaleIp = data.tailscale_ip || "";
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

    // Process to run the Rust helper with --rescan to force a hardware scan
    Process {
        id: updateStatusProc

        command: [root.homeDir + "/.config/quickshell/network_popup/get_network_status", "--rescan"]
        running: false

        onRunningChanged: {
            if (running) {
                root.isScanning = true;
            } else {
                root.isScanning = false;
            }
        }

        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var data = JSON.parse(this.text);
                    root.wifiEnabled = data.wifi_enabled;
                    root.airplaneMode = data.airplane_mode;
                    root.connected = data.connected;
                    root.activeSsid = data.active_ssid || "";
                    root.activeSignal = data.active_signal || 0;
                    root.wifiDevice = data.wifi_device || "wlo1";
                    root.warpConnected = data.warp_connected || false;
                    root.tailscaleConnected = data.tailscale_connected || false;
                    root.tailscaleIp = data.tailscale_ip || "";
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
                    console.log("Failed to parse network scan status: " + e);
                }
                root.isScanning = false;
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
            if (!checkStatusProc.running && !updateStatusProc.running)
                checkStatusProc.running = true;
        }
    }

    // Timer to trigger full hardware rescans in the background (every 15 seconds)
    Timer {
        id: backgroundScanTimer

        interval: 15000
        repeat: true
        running: true
        triggeredOnStart: false
        onTriggered: {
            if (!updateStatusProc.running)
                root.triggerScan();
        }
    }

    Variants {
        model: Quickshell.screens

        delegate: Component {
            PanelWindow {
                id: win
                WlrLayershell.namespace: theme.floatingMode ? "quickshell-top" : "quickshell"

                required property var modelData
                property bool isClosing: false
                property real animLeftMargin: -260
                property real animTop: -320
                property real animOpacity: 0
                property int activeSection: root.lastActiveSection
                property int activeSubIndex: root.lastActiveSubIndex
                property bool isLoaded: false
                property bool showFocusHighlight: root.isKeyboardTriggered
                property string focusHighlightColor: showFocusHighlight ? "#30d5c4a1" : "transparent"

                property bool isRestartingWifi: false
                property bool isDnsFlushed: false
                property bool isResettingNet: false

                Timer {
                    id: feedbackTimer

                    interval: 1500
                    repeat: false
                    onTriggered: {
                        win.isRestartingWifi = false;
                        win.isDnsFlushed = false;
                        win.isResettingNet = false;
                    }
                }

                function navigateSubIndex(dir) {
                    var maxItems = 0;
                    if (win.activeSection === 0)
                        maxItems = 2;
                    else if (win.activeSection === 1)
                        maxItems = 1;
                    else if (win.activeSection === 2)
                        maxItems = 2 + root.vpns.length;
                    else if (win.activeSection === 3)
                        maxItems = root.getNetworkSectionItemsCount();
                    else if (win.activeSection === 4)
                        maxItems = root.moreExpanded ? 5 : 1;
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
                        } else if (win.activeSubIndex === 1) {
                            if (root.tailscaleConnected)
                                Quickshell.execDetached(["sudo", "tailscale", "down"]);
                            else
                                Quickshell.execDetached(["sudo", "tailscale", "up"]);
                            root.triggerRefresh();
                        } else {
                            var idx = win.activeSubIndex - 2;
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
                                var isNetActive = item.netData.active || (root.connected && root.activeSsid === item.netData.ssid);
                                if (isNetActive) {
                                    Quickshell.execDetached(["nmcli", "device", "disconnect", root.wifiDevice || "wlo1"]);
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
                                if (item.netData.saved) {
                                    var nextVal = !item.netData.autoconnect;
                                    item.netData.autoconnect = nextVal;
                                    Quickshell.execDetached(["nmcli", "connection", "modify", item.netData.ssid, "connection.autoconnect", nextVal ? "yes" : "no"]);
                                    root.triggerRefresh();
                                }
                            }
                        }
                    } else if (win.activeSection === 4) {
                        if (win.activeSubIndex === 0) {
                            root.moreExpanded = !root.moreExpanded;
                        } else if (win.activeSubIndex === 1) {
                            Quickshell.execDetached(["hyprctl", "dispatch", 'hl.dsp.exec_cmd("[float;size 55% 65%;center] kitty --title impala impala")']);
                            win.closePopup();
                        } else if (win.activeSubIndex === 2) {
                            win.isRestartingWifi = true;
                            feedbackTimer.restart();
                            Quickshell.execDetached(["nmcli", "radio", "wifi", "off"]);
                            Quickshell.execDetached(["sh", "-c", "sleep 0.5 && nmcli radio wifi on"]);
                            root.triggerRefresh();
                        } else if (win.activeSubIndex === 3) {
                            win.isDnsFlushed = true;
                            feedbackTimer.restart();
                            Quickshell.execDetached(["sh", "-c", "sudo resolvectl flush-caches 2>/dev/null || true; notify-send -u low -i network-wireless -a 'Network' 'DNS Flushed' 'System DNS caches cleared.'"]);
                            root.triggerRefresh();
                        } else if (win.activeSubIndex === 4) {
                            win.isResettingNet = true;
                            feedbackTimer.restart();
                            Quickshell.execDetached(["sh", "-c", "sudo ip route flush cache 2>/dev/null || true; nmcli networking off && sleep 0.5 && nmcli networking on; notify-send -u low -i network-wireless -a 'Network' 'Network Offloaded' 'IP route cache & network stack reset.'"]);
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
                    left: !theme.floatingMode
                    bottom: !theme.floatingMode
                    top: theme.floatingMode
                    right: theme.floatingMode
                }

                margins {
                    bottom: 18
                    top: theme.floatingMode ? win.animTop : 0
                    left: theme.floatingMode ? 0 : win.animLeftMargin
                    right: theme.floatingMode ? 8 : 0
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
                        property: "animTop"
                        from: -320
                        to: 24
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
                        property: "animTop"
                        from: 24
                        to: -320
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

                                text: "󰤨 Wi-Fi: " + (root.wifiEnabled ? "On" : "Off")
                                color: theme.accent
                                opacity: (wifiToggleMouse.containsMouse || (win.activeSection === 0 && win.activeSubIndex === 0) || root.wifiEnabled) ? 1.0 : 0.6
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
                                    id: wifiToggleMouse

                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
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

                                text: "󰀝 Airplane: " + (root.airplaneMode ? "On" : "Off")
                                color: theme.accent
                                opacity: (airplaneToggleMouse.containsMouse || (win.activeSection === 0 && win.activeSubIndex === 1) || root.airplaneMode) ? 1.0 : 0.6
                                font.family: "FiraCode Nerd Font"
                                font.pixelSize: 9
                                font.bold: true
                                renderType: Text.NativeRendering

                                Rectangle {
                                    anchors.fill: parent
                                    anchors.margins: -2
                                    color: (win.activeSection === 0 && win.activeSubIndex === 1) ? win.focusHighlightColor : "transparent"
                                    radius: 0
                                }

                                MouseArea {
                                    id: airplaneToggleMouse

                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
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

                        // --- SECTION 3: CONNECTION DETAILS ---
                        Column {
                            width: parent.width
                            spacing: 2
                            visible: root.connected

                            Rectangle {
                                width: parent.width
                                height: 16
                                color: (win.activeSection === 1 && win.activeSubIndex === 0) ? win.focusHighlightColor : "transparent"
                                radius: 0

                                Row {
                                    anchors.left: parent.left
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: 4

                                    Text {
                                        text: root.detailsExpanded ? "󰅁" : "󰅂"
                                        color: theme.accent
                                        font.family: "FiraCode Nerd Font"
                                        font.pixelSize: 8
                                        anchors.verticalCenter: parent.verticalCenter
                                        renderType: Text.NativeRendering
                                    }

                                    Text {
                                        text: "Details"
                                        color: theme.accent
                                        font.family: "FiraCode Nerd Font"
                                        font.pixelSize: 8
                                        anchors.verticalCenter: parent.verticalCenter
                                        renderType: Text.NativeRendering
                                    }
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        root.detailsExpanded = !root.detailsExpanded;
                                    }
                                }
                            }

                            Column {
                                width: parent.width
                                spacing: 2
                                visible: root.detailsExpanded

                                Text {
                                    text: "  IP: " + (root.details.ip_address || "None")
                                    color: theme.accent
                                    font.family: "FiraCode Nerd Font"
                                    font.pixelSize: 8
                                    renderType: Text.NativeRendering
                                }

                                Text {
                                    text: "  Gateway: " + (root.details.gateway || "None")
                                    color: theme.accent
                                    font.family: "FiraCode Nerd Font"
                                    font.pixelSize: 8
                                    renderType: Text.NativeRendering
                                }

                                Text {
                                    text: "  DNS: " + (root.details.dns || "None")
                                    color: theme.accent
                                    font.family: "FiraCode Nerd Font"
                                    font.pixelSize: 8
                                    renderType: Text.NativeRendering
                                }

                                Text {
                                    text: "  Subnet: " + (root.details.subnet || "None")
                                    color: theme.accent
                                    font.family: "FiraCode Nerd Font"
                                    font.pixelSize: 8
                                    renderType: Text.NativeRendering
                                }

                                Text {
                                    text: "  Security: " + (root.details.security || "None")
                                    color: theme.accent
                                    font.family: "FiraCode Nerd Font"
                                    font.pixelSize: 8
                                    renderType: Text.NativeRendering
                                }

                                Text {
                                    text: "  BSSID: " + (root.details.bssid || "None")
                                    color: theme.accent
                                    font.family: "FiraCode Nerd Font"
                                    font.pixelSize: 8
                                    renderType: Text.NativeRendering
                                }
                            }
                        }

                        // --- SECTION 4: VPNS & PROXIES ---
                        Column {
                            width: parent.width
                            spacing: 4

                            Text {
                                text: "VPNs & Proxies"
                                color: theme.accent
                                opacity: 0.5
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
                                    opacity: (warpMouse.containsMouse || (win.activeSection === 2 && win.activeSubIndex === 0) || root.warpConnected) ? 1.0 : 0.6
                                    font.family: "FiraCode Nerd Font"
                                    font.pixelSize: 8
                                    renderType: Text.NativeRendering

                                    MouseArea {
                                        id: warpMouse

                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
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

                            // Tailscale Toggle
                            Rectangle {
                                width: parent.width
                                height: root.tailscaleConnected ? 28 : 16
                                color: (win.activeSection === 2 && win.activeSubIndex === 1) ? win.focusHighlightColor : "transparent"
                                radius: 0

                                Column {
                                    anchors.left: parent.left
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: 1

                                    Text {
                                        text: "Tailscale: " + (root.tailscaleConnected ? "Connected" : "Disconnected")
                                        color: theme.accent
                                        font.family: "FiraCode Nerd Font"
                                        font.pixelSize: 8
                                        renderType: Text.NativeRendering
                                    }

                                    Text {
                                        text: "  IP: " + root.tailscaleIp
                                        visible: root.tailscaleConnected
                                        color: theme.accent
                                        opacity: 0.7
                                        font.family: "FiraCode Nerd Font"
                                        font.pixelSize: 8
                                        renderType: Text.NativeRendering
                                    }
                                }

                                Text {
                                    id: tailscaleToggleBtn

                                    anchors.right: parent.right
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: root.tailscaleConnected ? "disconnect" : "connect"
                                    color: theme.accent
                                    opacity: (tsMouse.containsMouse || (win.activeSection === 2 && win.activeSubIndex === 1) || root.tailscaleConnected) ? 1.0 : 0.6
                                    font.family: "FiraCode Nerd Font"
                                    font.pixelSize: 8
                                    renderType: Text.NativeRendering

                                    MouseArea {
                                        id: tsMouse

                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            if (root.tailscaleConnected)
                                                Quickshell.execDetached(["sudo", "tailscale", "down"]);
                                            else
                                                Quickshell.execDetached(["sudo", "tailscale", "up"]);
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
                                        color: (win.activeSection === 2 && win.activeSubIndex === (index + 2)) ? win.focusHighlightColor : "transparent"
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
                                            opacity: (vpnMouse.containsMouse || (win.activeSection === 2 && win.activeSubIndex === (index + 2)) || modelData.active) ? 1.0 : 0.6
                                            font.family: "FiraCode Nerd Font"
                                            font.pixelSize: 8
                                            renderType: Text.NativeRendering

                                            MouseArea {
                                                id: vpnMouse

                                                anchors.fill: parent
                                                hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor
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
                            spacing: 4

                            // Header with WiFi Networks label and Rescan text button
                            Item {
                                width: parent.width
                                height: 16

                                Text {
                                    anchors.left: parent.left
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: "WiFi Networks"
                                    color: theme.accent
                                    font.family: "FiraCode Nerd Font"
                                    font.pixelSize: 9
                                    font.bold: true
                                    renderType: Text.NativeRendering
                                }

                                Text {
                                    id: scanBtn

                                    anchors.right: parent.right
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: root.isScanning ? "󰑐 searching..." : "󰑐 refresh"
                                    color: theme.accent
                                    opacity: (scanMouse.containsMouse || root.isScanning) ? 1.0 : 0.6
                                    font.family: "FiraCode Nerd Font"
                                    font.pixelSize: 8
                                    renderType: Text.NativeRendering

                                    MouseArea {
                                        id: scanMouse

                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            root.triggerScan();
                                        }
                                    }
                                }
                            }

                            Column {
                                width: parent.width
                                spacing: 3

                                Repeater {
                                    model: root.networks

                                    delegate: Column {
                                        id: netRowCol

                                        width: parent.width
                                        spacing: 2

                                        property bool isNetActive: modelData.active || (root.connected && root.activeSsid === modelData.ssid)

                                        Rectangle {
                                            width: parent.width
                                            height: 16
                                            color: {
                                                var item = root.getNetworkItemAtSubIndex(win.activeSubIndex);
                                                if (win.activeSection === 3 && item && item.type === "header" && item.netIndex === index)
                                                    return win.focusHighlightColor;

                                                return rowMouse.containsMouse ? Qt.rgba(theme.accent.r, theme.accent.g, theme.accent.b, 0.1) : "transparent";
                                            }
                                            radius: 0

                                            Row {
                                                anchors.left: parent.left
                                                anchors.verticalCenter: parent.verticalCenter
                                                spacing: 4

                                                Text {
                                                    text: (netRowCol.isNetActive ? "* " : "  ") + modelData.ssid
                                                    color: theme.accent
                                                    font.family: "FiraCode Nerd Font"
                                                    font.pixelSize: 8
                                                    font.bold: netRowCol.isNetActive
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
                                                id: rowMouse

                                                anchors.fill: parent
                                                hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor
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
                                                spacing: 12
                                                anchors.horizontalCenter: parent.horizontalCenter

                                                // Connect / Disconnect button
                                                Text {
                                                    id: connActionBtn

                                                    property bool itemConnectFocused: {
                                                        var item = root.getNetworkItemAtSubIndex(win.activeSubIndex);
                                                        return item && item.type === "connect" && item.netIndex === index;
                                                    }

                                                    text: netRowCol.isNetActive ? "Disconnect" : "Connect"
                                                    color: theme.accent
                                                    opacity: (connMouse.containsMouse || connActionBtn.itemConnectFocused || netRowCol.isNetActive) ? 1.0 : 0.6
                                                    font.family: "FiraCode Nerd Font"
                                                    font.pixelSize: 8
                                                    font.bold: netRowCol.isNetActive
                                                    renderType: Text.NativeRendering

                                                    Rectangle {
                                                        anchors.fill: parent
                                                        anchors.margins: -2
                                                        color: connActionBtn.itemConnectFocused ? win.focusHighlightColor : "transparent"
                                                        radius: 0
                                                    }

                                                    MouseArea {
                                                        id: connMouse

                                                        anchors.fill: parent
                                                        hoverEnabled: true
                                                        cursorShape: Qt.PointingHandCursor
                                                        onClicked: {
                                                            if (netRowCol.isNetActive) {
                                                                Quickshell.execDetached(["nmcli", "device", "disconnect", root.wifiDevice || "wlo1"]);
                                                            } else {
                                                                var script = "SSID=\"$1\"; SECURITY=\"$2\"; " + "if nmcli connection show id \"$SSID\" >/dev/null 2>&1; then " + "  nmcli device wifi connect \"$SSID\"; " + "else " + "  if [ \"$SECURITY\" != \"--\" ] && [ -n \"$SECURITY\" ]; then " + "    pass=$(rofi -dmenu -password -p \"Password for $SSID\"); " + "    [ -n \"$pass\" ] && nmcli device wifi connect \"$SSID\" password \"$pass\"; " + "  else " + "    nmcli device wifi connect \"$SSID\"; " + "  fi; " + "fi";
                                                                Quickshell.execDetached(["sh", "-c", script, "sh", modelData.ssid, modelData.security]);
                                                            }
                                                            root.expandedNetworkSsid = "";
                                                            root.triggerRefresh();
                                                        }
                                                    }
                                                }

                                                // Forget button (only for saved networks)
                                                Text {
                                                    id: forgetActionBtn

                                                    property bool itemForgetFocused: {
                                                        var item = root.getNetworkItemAtSubIndex(win.activeSubIndex);
                                                        return item && item.type === "forget" && item.netIndex === index;
                                                    }

                                                    visible: modelData.saved
                                                    text: "Forget"
                                                    color: forgetMouse.containsMouse ? theme.error : theme.accent
                                                    opacity: (forgetMouse.containsMouse || forgetActionBtn.itemForgetFocused) ? 1.0 : 0.6
                                                    font.family: "FiraCode Nerd Font"
                                                    font.pixelSize: 8
                                                    renderType: Text.NativeRendering

                                                    Rectangle {
                                                        anchors.fill: parent
                                                        anchors.margins: -2
                                                        color: forgetActionBtn.itemForgetFocused ? win.focusHighlightColor : "transparent"
                                                        radius: 0
                                                    }

                                                    MouseArea {
                                                        id: forgetMouse

                                                        anchors.fill: parent
                                                        hoverEnabled: true
                                                        cursorShape: Qt.PointingHandCursor
                                                        onClicked: {
                                                            Quickshell.execDetached(["nmcli", "connection", "delete", modelData.ssid]);
                                                            root.expandedNetworkSsid = "";
                                                            root.triggerRefresh();
                                                        }
                                                    }
                                                }

                                                // Auto button (only for saved networks)
                                                Text {
                                                    id: autoActionBtn

                                                    property bool itemAutoFocused: {
                                                        var item = root.getNetworkItemAtSubIndex(win.activeSubIndex);
                                                        return item && item.type === "auto" && item.netIndex === index;
                                                    }

                                                    visible: modelData.saved
                                                    text: "Auto: " + (modelData.autoconnect ? "On" : "Off")
                                                    color: theme.accent
                                                    opacity: (autoMouse.containsMouse || autoActionBtn.itemAutoFocused || modelData.autoconnect) ? 1.0 : 0.6
                                                    font.family: "FiraCode Nerd Font"
                                                    font.pixelSize: 8
                                                    font.bold: modelData.autoconnect
                                                    renderType: Text.NativeRendering

                                                    Rectangle {
                                                        anchors.fill: parent
                                                        anchors.margins: -2
                                                        color: autoActionBtn.itemAutoFocused ? win.focusHighlightColor : "transparent"
                                                        radius: 0
                                                    }

                                                    MouseArea {
                                                        id: autoMouse

                                                        anchors.fill: parent
                                                        hoverEnabled: true
                                                        cursorShape: Qt.PointingHandCursor
                                                        onClicked: {
                                                            var nextVal = !modelData.autoconnect;
                                                            modelData.autoconnect = nextVal;
                                                            Quickshell.execDetached(["nmcli", "connection", "modify", modelData.ssid, "connection.autoconnect", nextVal ? "yes" : "no"]);
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
                                                font.pixelSize: 8
                                                renderType: Text.NativeRendering
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        // --- SECTION 6: FOOTER ACTIONS (MORE) ---
                        Column {
                            width: parent.width
                            spacing: 4

                            Rectangle {
                                width: parent.width
                                height: 16
                                color: (win.activeSection === 4 && win.activeSubIndex === 0) ? win.focusHighlightColor : "transparent"
                                radius: 0

                                Row {
                                    anchors.left: parent.left
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: 4

                                    Text {
                                        text: root.moreExpanded ? "󰅁" : "󰅂"
                                        color: theme.accent
                                        opacity: (moreMouse.containsMouse || (win.activeSection === 4 && win.activeSubIndex === 0)) ? 1.0 : 0.6
                                        font.family: "FiraCode Nerd Font"
                                        font.pixelSize: 9
                                        anchors.verticalCenter: parent.verticalCenter
                                        renderType: Text.NativeRendering
                                    }

                                    Text {
                                        text: "More"
                                        color: theme.accent
                                        opacity: (moreMouse.containsMouse || (win.activeSection === 4 && win.activeSubIndex === 0)) ? 1.0 : 0.6
                                        font.family: "FiraCode Nerd Font"
                                        font.pixelSize: 9
                                        font.bold: true
                                        anchors.verticalCenter: parent.verticalCenter
                                        renderType: Text.NativeRendering
                                    }
                                }

                                MouseArea {
                                    id: moreMouse

                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        root.moreExpanded = !root.moreExpanded;
                                    }
                                }
                            }

                            Column {
                                width: parent.width
                                spacing: 4
                                visible: root.moreExpanded

                                Row {
                                    spacing: 20
                                    anchors.horizontalCenter: parent.horizontalCenter

                                    // Button 0: Settings
                                    Text {
                                        id: settingsBtn

                                        text: "󰒓 Settings"
                                        color: theme.accent
                                        opacity: (settingsMouse.containsMouse || (win.activeSection === 4 && win.activeSubIndex === 1)) ? 1.0 : 0.6
                                        font.family: "FiraCode Nerd Font"
                                        font.pixelSize: 9
                                        renderType: Text.NativeRendering

                                        Rectangle {
                                            anchors.fill: parent
                                            anchors.margins: -2
                                            color: (win.activeSection === 4 && win.activeSubIndex === 1) ? win.focusHighlightColor : "transparent"
                                            radius: 0
                                        }

                                        MouseArea {
                                            id: settingsMouse

                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                Quickshell.execDetached(["hyprctl", "dispatch", 'hl.dsp.exec_cmd("[float;size 55% 65%;center] kitty --title impala impala")']);
                                                win.closePopup();
                                            }
                                        }
                                    }

                                    // Button 1: Restart Wi-Fi
                                    Text {
                                        id: restartBtn

                                        text: win.isRestartingWifi ? "󰑐 Restarting..." : "󰑐 Restart Wi-Fi"
                                        color: theme.accent
                                        opacity: (restartMouse.containsMouse || (win.activeSection === 4 && win.activeSubIndex === 2) || win.isRestartingWifi) ? 1.0 : 0.6
                                        font.family: "FiraCode Nerd Font"
                                        font.pixelSize: 9
                                        renderType: Text.NativeRendering

                                        Rectangle {
                                            anchors.fill: parent
                                            anchors.margins: -2
                                            color: (win.activeSection === 4 && win.activeSubIndex === 2) ? win.focusHighlightColor : "transparent"
                                            radius: 0
                                        }

                                        MouseArea {
                                            id: restartMouse

                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                win.isRestartingWifi = true;
                                                feedbackTimer.restart();
                                                Quickshell.execDetached(["nmcli", "radio", "wifi", "off"]);
                                                Quickshell.execDetached(["sh", "-c", "sleep 0.5 && nmcli radio wifi on"]);
                                                root.triggerRefresh();
                                            }
                                        }
                                    }
                                }

                                Row {
                                    spacing: 20
                                    anchors.horizontalCenter: parent.horizontalCenter

                                    // Button 2: Flush DNS
                                    Text {
                                        id: flushDnsBtn

                                        text: win.isDnsFlushed ? "󰃢 Flushed!" : "󰃢 Flush DNS"
                                        color: theme.accent
                                        opacity: (flushMouse.containsMouse || (win.activeSection === 4 && win.activeSubIndex === 3) || win.isDnsFlushed) ? 1.0 : 0.6
                                        font.family: "FiraCode Nerd Font"
                                        font.pixelSize: 9
                                        renderType: Text.NativeRendering

                                        Rectangle {
                                            anchors.fill: parent
                                            anchors.margins: -2
                                            color: (win.activeSection === 4 && win.activeSubIndex === 3) ? win.focusHighlightColor : "transparent"
                                            radius: 0
                                        }

                                        MouseArea {
                                            id: flushMouse

                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                win.isDnsFlushed = true;
                                                feedbackTimer.restart();
                                                Quickshell.execDetached(["sh", "-c", "sudo resolvectl flush-caches 2>/dev/null || true; notify-send -u low -i network-wireless -a 'Network' 'DNS Flushed' 'System DNS caches cleared.'"]);
                                                root.triggerRefresh();
                                            }
                                        }
                                    }

                                    // Button 3: Offload / Reset Network
                                    Text {
                                        id: offloadBtn

                                        text: win.isResettingNet ? "󰌘 Resetting..." : "󰌘 Offload Network"
                                        color: theme.accent
                                        opacity: (offloadMouse.containsMouse || (win.activeSection === 4 && win.activeSubIndex === 4) || win.isResettingNet) ? 1.0 : 0.6
                                        font.family: "FiraCode Nerd Font"
                                        font.pixelSize: 9
                                        renderType: Text.NativeRendering

                                        Rectangle {
                                            anchors.fill: parent
                                            anchors.margins: -2
                                            color: (win.activeSection === 4 && win.activeSubIndex === 4) ? win.focusHighlightColor : "transparent"
                                            radius: 0
                                        }

                                        MouseArea {
                                            id: offloadMouse

                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                win.isResettingNet = true;
                                                feedbackTimer.restart();
                                                Quickshell.execDetached(["sh", "-c", "sudo ip route flush cache 2>/dev/null || true; nmcli networking off && sleep 0.5 && nmcli networking on; notify-send -u low -i network-wireless -a 'Network' 'Network Offloaded' 'IP route cache & network stack reset.'"]);
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
    }
}
