import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io

Scope {
    id: root

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

    function triggerRefresh() {
        refreshTimer.restart();
    }

    Component.onCompleted: {
        checkStatusProc.running = true;
    }

    // Process to run the Rust helper
    Process {
        id: checkStatusProc

        command: ["/home/parazeeknova/doty/.config/quickshell/network_popup/get_network_status"]
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

                screen: modelData
                color: "transparent"
                exclusionMode: PanelWindow.ExclusionMode.Ignore
                focusable: true
                implicitWidth: 240
                implicitHeight: mainLayout.implicitHeight + 20

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
                                color: "#d5c4a1"
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
                                    color: "#d5c4a1"
                                    font.family: "FiraCode Nerd Font"
                                    font.pixelSize: 9
                                    elide: Text.ElideRight
                                    renderType: Text.NativeRendering
                                }

                                Text {
                                    text: "Signal: " + root.activeSignal + "%"
                                    color: "#d5c4a1"
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
                            color: "#d5c4a1"
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
                                color: "#d5c4a1"
                                font.family: "FiraCode Nerd Font"
                                font.pixelSize: 9
                                font.bold: true
                                renderType: Text.NativeRendering

                                MouseArea {
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    onEntered: wifiToggleText.color = "#ebdbb2"
                                    onExited: wifiToggleText.color = "#d5c4a1"
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
                                color: "#d5c4a1"
                                font.family: "FiraCode Nerd Font"
                                font.pixelSize: 9
                                font.bold: true
                                renderType: Text.NativeRendering

                                MouseArea {
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    onEntered: airplaneToggleText.color = "#ebdbb2"
                                    onExited: airplaneToggleText.color = "#d5c4a1"
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
                            color: "#d5c4a1"
                            opacity: 0.15
                        }

                        Column {
                            width: parent.width
                            spacing: 4

                            Rectangle {
                                width: parent.width
                                height: 14
                                color: "transparent"

                                Text {
                                    text: "Details " + (root.detailsExpanded ? "󰅀" : "󰅂")
                                    color: "#d5c4a1"
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
                                    color: "#d5c4a1"
                                    font.family: "FiraCode Nerd Font"
                                    font.pixelSize: 8
                                    renderType: Text.NativeRendering
                                }

                                Text {
                                    text: "  Gateway: " + root.details.gateway
                                    color: "#d5c4a1"
                                    font.family: "FiraCode Nerd Font"
                                    font.pixelSize: 8
                                    renderType: Text.NativeRendering
                                }

                                Text {
                                    text: "  Subnet: " + root.details.subnet
                                    color: "#d5c4a1"
                                    font.family: "FiraCode Nerd Font"
                                    font.pixelSize: 8
                                    renderType: Text.NativeRendering
                                }

                                Text {
                                    text: "  DNS: " + root.details.dns
                                    color: "#d5c4a1"
                                    font.family: "FiraCode Nerd Font"
                                    font.pixelSize: 8
                                    renderType: Text.NativeRendering
                                }

                                Text {
                                    text: "  BSSID: " + root.details.bssid
                                    color: "#d5c4a1"
                                    font.family: "FiraCode Nerd Font"
                                    font.pixelSize: 8
                                    renderType: Text.NativeRendering
                                }

                                Text {
                                    text: "  Security: " + root.details.security
                                    color: "#d5c4a1"
                                    font.family: "FiraCode Nerd Font"
                                    font.pixelSize: 8
                                    renderType: Text.NativeRendering
                                }

                            }

                            Text {
                                text: "  No connection active"
                                color: "#d5c4a1"
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
                                color: "#d5c4a1"
                                font.family: "FiraCode Nerd Font"
                                font.pixelSize: 9
                                font.bold: true
                                renderType: Text.NativeRendering
                            }

                            // WARP Toggle
                            Rectangle {
                                width: parent.width
                                height: 16
                                color: "transparent"

                                Text {
                                    anchors.left: parent.left
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: "WARP: " + (root.warpConnected ? "Connected" : "Disconnected")
                                    color: "#d5c4a1"
                                    font.family: "FiraCode Nerd Font"
                                    font.pixelSize: 8
                                    renderType: Text.NativeRendering
                                }

                                Text {
                                    id: warpToggleBtn

                                    anchors.right: parent.right
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: root.warpConnected ? "disconnect" : "connect"
                                    color: "#d5c4a1"
                                    font.family: "FiraCode Nerd Font"
                                    font.pixelSize: 8
                                    renderType: Text.NativeRendering

                                    MouseArea {
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        onEntered: warpToggleBtn.color = "#ebdbb2"
                                        onExited: warpToggleBtn.color = "#d5c4a1"
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
                                        color: "transparent"

                                        Text {
                                            id: vpnNameText

                                            anchors.left: parent.left
                                            anchors.verticalCenter: parent.verticalCenter
                                            text: modelData.name + " (" + modelData.vpn_type + ")"
                                            color: "#d5c4a1"
                                            font.family: "FiraCode Nerd Font"
                                            font.pixelSize: 8
                                            renderType: Text.NativeRendering
                                        }

                                        Text {
                                            id: vpnActionBtn

                                            anchors.right: parent.right
                                            anchors.verticalCenter: parent.verticalCenter
                                            text: modelData.active ? "disconnect" : "connect"
                                            color: "#d5c4a1"
                                            font.family: "FiraCode Nerd Font"
                                            font.pixelSize: 8
                                            renderType: Text.NativeRendering

                                            MouseArea {
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                onEntered: vpnActionBtn.color = "#ebdbb2"
                                                onExited: vpnActionBtn.color = "#d5c4a1"
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
                                color: "#d5c4a1"
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
                                color: "#d5c4a1"
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
                                            color: "transparent"

                                            Row {
                                                anchors.left: parent.left
                                                anchors.verticalCenter: parent.verticalCenter
                                                spacing: 4

                                                Text {
                                                    text: (modelData.active ? "* " : "  ") + modelData.ssid
                                                    color: "#d5c4a1"
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
                                                    var activeColor = "#d5c4a1";
                                                    var inactiveColor = "#3c3836";
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
                                                    color: "#d5c4a1"
                                                    font.family: "FiraCode Nerd Font"
                                                    font.pixelSize: 8
                                                    renderType: Text.NativeRendering

                                                    MouseArea {
                                                        anchors.fill: parent
                                                        hoverEnabled: true
                                                        onEntered: connActionBtn.color = "#ebdbb2"
                                                        onExited: connActionBtn.color = "#d5c4a1"
                                                        onClicked: {
                                                            if (modelData.active)
                                                                Quickshell.execDetached(["nmcli", "device", "disconnect", "wlan0"]);
                                                            else
                                                                Quickshell.execDetached(["nmcli", "device", "wifi", "connect", modelData.ssid]);
                                                            root.expandedNetworkSsid = "";
                                                            root.triggerRefresh();
                                                        }
                                                    }

                                                }

                                                Text {
                                                    id: forgetActionBtn

                                                    text: "Forget"
                                                    color: "#d5c4a1"
                                                    font.family: "FiraCode Nerd Font"
                                                    font.pixelSize: 8
                                                    renderType: Text.NativeRendering

                                                    MouseArea {
                                                        anchors.fill: parent
                                                        hoverEnabled: true
                                                        onEntered: forgetActionBtn.color = "#ebdbb2"
                                                        onExited: forgetActionBtn.color = "#d5c4a1"
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
                                                    color: "#d5c4a1"
                                                    font.family: "FiraCode Nerd Font"
                                                    font.pixelSize: 8
                                                    renderType: Text.NativeRendering

                                                    MouseArea {
                                                        anchors.fill: parent
                                                        hoverEnabled: true
                                                        onEntered: autoActionBtn.color = "#ebdbb2"
                                                        onExited: autoActionBtn.color = "#d5c4a1"
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
                                                color: "#d5c4a1"
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
                                color: "#d5c4a1"
                                font.family: "FiraCode Nerd Font"
                                font.pixelSize: 9
                                renderType: Text.NativeRendering

                                MouseArea {
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    onEntered: settingsBtn.color = "#ebdbb2"
                                    onExited: settingsBtn.color = "#d5c4a1"
                                    onClicked: {
                                        Quickshell.execDetached(["nm-connection-editor"]);
                                        Qt.quit(); // Close popup when launching settings editor
                                    }
                                }

                            }

                            // Restart WiFi
                            Text {
                                id: restartBtn

                                text: "Restart Wi-Fi"
                                color: "#d5c4a1"
                                font.family: "FiraCode Nerd Font"
                                font.pixelSize: 9
                                renderType: Text.NativeRendering

                                MouseArea {
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    onEntered: restartBtn.color = "#ebdbb2"
                                    onExited: restartBtn.color = "#d5c4a1"
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
