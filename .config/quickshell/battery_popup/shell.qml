import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io

Scope {
    id: root

    // Battery status properties
    property string homeDir: Quickshell.env("HOME")
    property int capacity: 0
    property string status: "Unknown"
    property double health: 100
    property double powerDraw: 0
    property string timeRemaining: "N/A"
    property string activeProfile: "Unknown"
    property var history: []

    function runCmd(cmdList) {
        actionProc.command = cmdList;
        actionProc.running = true;
    }

    function setProfile(profile) {
        runCmd(["sh", "-c", "asusctl profile set " + profile + " && " + root.homeDir + "/.config/quickshell/osd/bin/osdctl show 'profile: " + profile.toLowerCase() + "' good 1500"]);
    }

    Component.onCompleted: {
        checkStatusProc.running = true;
    }

    Theme {
        id: theme
    }

    // Process to run the Rust helper
    Process {
        id: checkStatusProc

        command: [root.homeDir + "/.config/quickshell/battery_popup/get_battery_status"]
        running: false

        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var data = JSON.parse(this.text);
                    root.capacity = data.capacity;
                    root.status = data.status;
                    root.health = data.health;
                    root.powerDraw = data.power_draw_w;
                    root.timeRemaining = data.time_remaining_str;
                    root.activeProfile = data.active_profile;
                    root.history = data.history || [];
                } catch (e) {
                    console.log("Failed to parse status: " + e);
                }
            }
        }

    }

    // Timer to poll battery status every 5 seconds
    Timer {
        id: refreshTimer

        interval: 5000
        repeat: true
        running: true
        triggeredOnStart: true
        onTriggered: {
            checkStatusProc.running = true;
        }
    }

    // Process for executing commands
    Process {
        id: actionProc

        running: false
        onRunningChanged: {
            if (!running)
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
                // Enable keyboard focus for key events (Esc key)
                focusable: true
                implicitWidth: 240
                implicitHeight: 150
                Component.onCompleted: introAnim.start()

                anchors {
                    bottom: true
                    left: true
                }

                margins {
                    bottom: 10
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

                // Use HyprlandFocusGrab to automatically close the widget when clicking outside
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
                    border.color: "#d5c4a1"
                    radius: 0
                    antialiasing: false
                    // Request keyboard focus and listen for Escape key
                    focus: true
                    Keys.onPressed: (event) => {
                        if (event.key === Qt.Key_Escape)
                            win.closePopup();

                    }
                    Component.onCompleted: {
                        forceActiveFocus();
                    }

                    // Main Layout Container
                    Item {
                        anchors.fill: parent
                        anchors.margins: 10

                        // Header: Battery Icon + Status
                        Text {
                            id: titleLabel

                            anchors.top: parent.top
                            anchors.left: parent.left
                            text: (root.status === "Charging" ? "󰢝 " : "󰁹 ") + "Battery: " + root.capacity + "%"
                            color: "#d5c4a1"
                            font.family: "FiraCode Nerd Font"
                            font.pixelSize: 10
                            font.bold: true
                            renderType: Text.NativeRendering
                        }

                        Text {
                            id: drawLabel

                            anchors.top: parent.top
                            anchors.right: parent.right
                            text: root.powerDraw + "W"
                            color: "#d5c4a1"
                            font.family: "FiraCode Nerd Font"
                            font.pixelSize: 9
                            renderType: Text.NativeRendering
                        }

                        // Stats grid area
                        Item {
                            id: statsArea

                            anchors.top: titleLabel.bottom
                            anchors.topMargin: 6
                            anchors.left: parent.left
                            anchors.right: parent.right
                            height: 32

                            Text {
                                id: healthLabel

                                anchors.left: parent.left
                                anchors.top: parent.top
                                text: "Health: " + root.health + "%"
                                color: "#d5c4a1"
                                opacity: 0.8
                                font.family: "FiraCode Nerd Font"
                                font.pixelSize: 9
                                renderType: Text.NativeRendering
                            }

                            Text {
                                id: timeLabel

                                anchors.right: parent.right
                                anchors.top: parent.top
                                text: root.timeRemaining
                                color: "#d5c4a1"
                                opacity: 0.8
                                font.family: "FiraCode Nerd Font"
                                font.pixelSize: 9
                                renderType: Text.NativeRendering
                            }

                            // Sparkline/History Bar Graph (Full Width)
                            Row {
                                id: graphRow

                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.bottom: parent.bottom
                                height: 12
                                spacing: 2

                                Repeater {
                                    model: root.history

                                    delegate: Rectangle {
                                        width: (graphRow.width - (graphRow.spacing * 9)) / 10
                                        height: {
                                            var max = Math.max.apply(null, root.history);
                                            if (max > 0)
                                                return Math.max(2, (modelData / max) * graphRow.height);

                                            return 2;
                                        }
                                        anchors.bottom: parent.bottom
                                        color: "#d5c4a1"
                                        radius: 0
                                    }

                                }

                            }

                        }

                        // Separator 1
                        Rectangle {
                            id: sep1

                            anchors.top: statsArea.bottom
                            anchors.topMargin: 4
                            anchors.left: parent.left
                            anchors.right: parent.right
                            height: 1
                            color: "#d5c4a1"
                            opacity: 0.25
                        }

                        // Section 2: Power Modes
                        Text {
                            id: modeTitle

                            anchors.top: sep1.bottom
                            anchors.topMargin: 6
                            anchors.left: parent.left
                            text: "Power Mode"
                            color: "#d5c4a1"
                            font.family: "FiraCode Nerd Font"
                            font.pixelSize: 9
                            font.bold: true
                            renderType: Text.NativeRendering
                        }

                        Row {
                            id: modeRow

                            anchors.top: modeTitle.bottom
                            anchors.topMargin: 5
                            anchors.left: parent.left
                            anchors.right: parent.right
                            spacing: 5

                            // Quiet Button
                            Rectangle {
                                width: 60
                                height: 20
                                color: "transparent"
                                border.color: "transparent"
                                radius: 0

                                Text {
                                    id: quietText

                                    anchors.left: parent.left
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: (root.activeProfile === "Quiet" ? "* " : "  ") + "Quiet"
                                    color: root.activeProfile === "Quiet" ? "#ebdbb2" : "#d5c4a1"
                                    opacity: root.activeProfile === "Quiet" ? 1 : 0.7
                                    font.family: "FiraCode Nerd Font"
                                    font.pixelSize: 9
                                    renderType: Text.NativeRendering
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    onEntered: {
                                        if (root.activeProfile !== "Quiet") {
                                            quietText.color = "#ebdbb2";
                                            quietText.opacity = 1;
                                        }
                                    }
                                    onExited: {
                                        if (root.activeProfile !== "Quiet") {
                                            quietText.color = "#d5c4a1";
                                            quietText.opacity = 0.7;
                                        }
                                    }
                                    onClicked: root.setProfile("Quiet")
                                }

                            }

                            // Balanced Button
                            Rectangle {
                                width: 70
                                height: 20
                                color: "transparent"
                                border.color: "transparent"
                                radius: 0

                                Text {
                                    id: balancedText

                                    anchors.left: parent.left
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: (root.activeProfile === "Balanced" ? "* " : "  ") + "Balanced"
                                    color: root.activeProfile === "Balanced" ? "#ebdbb2" : "#d5c4a1"
                                    opacity: root.activeProfile === "Balanced" ? 1 : 0.7
                                    font.family: "FiraCode Nerd Font"
                                    font.pixelSize: 9
                                    renderType: Text.NativeRendering
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    onEntered: {
                                        if (root.activeProfile !== "Balanced") {
                                            balancedText.color = "#ebdbb2";
                                            balancedText.opacity = 1;
                                        }
                                    }
                                    onExited: {
                                        if (root.activeProfile !== "Balanced") {
                                            balancedText.color = "#d5c4a1";
                                            balancedText.opacity = 0.7;
                                        }
                                    }
                                    onClicked: root.setProfile("Balanced")
                                }

                            }

                            // Performance Button
                            Rectangle {
                                width: 90
                                height: 20
                                color: "transparent"
                                border.color: "transparent"
                                radius: 0

                                Text {
                                    id: perfText

                                    anchors.left: parent.left
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: (root.activeProfile === "Performance" ? "* " : "  ") + "Performance"
                                    color: root.activeProfile === "Performance" ? "#ebdbb2" : "#d5c4a1"
                                    opacity: root.activeProfile === "Performance" ? 1 : 0.7
                                    font.family: "FiraCode Nerd Font"
                                    font.pixelSize: 9
                                    renderType: Text.NativeRendering
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    onEntered: {
                                        if (root.activeProfile !== "Performance") {
                                            perfText.color = "#ebdbb2";
                                            perfText.opacity = 1;
                                        }
                                    }
                                    onExited: {
                                        if (root.activeProfile !== "Performance") {
                                            perfText.color = "#d5c4a1";
                                            perfText.opacity = 0.7;
                                        }
                                    }
                                    onClicked: root.setProfile("Performance")
                                }

                            }

                        }

                        // Separator 2
                        Rectangle {
                            id: sep2

                            anchors.top: modeRow.bottom
                            anchors.topMargin: 6
                            anchors.left: parent.left
                            anchors.right: parent.right
                            height: 1
                            color: "#d5c4a1"
                            opacity: 0.25
                        }

                        // Section 3: Power Options
                        Row {
                            id: powerRow

                            anchors.top: sep2.bottom
                            anchors.topMargin: 6
                            anchors.left: parent.left
                            anchors.right: parent.right
                            spacing: 5

                            // Logout Button
                            Rectangle {
                                width: 112
                                height: 20
                                color: "transparent"
                                border.color: "transparent"
                                radius: 0

                                Text {
                                    id: logoutText

                                    anchors.centerIn: parent
                                    text: "󰍃 Exit"
                                    color: "#d5c4a1"
                                    font.family: "FiraCode Nerd Font"
                                    font.pixelSize: 9
                                    renderType: Text.NativeRendering
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    onEntered: {
                                        logoutText.color = "#ebdbb2";
                                    }
                                    onExited: {
                                        logoutText.color = "#d5c4a1";
                                    }
                                    onClicked: {
                                        win.closePopup();
                                        root.runCmd(["sh", "-c", "hyprctl dispatch 'hl.dsp.exit()' || pkill -x Hyprland"]);
                                    }
                                }

                            }

                            // Poweroff Button
                            Rectangle {
                                width: 113
                                height: 20
                                color: "transparent"
                                border.color: "transparent"
                                radius: 0

                                Text {
                                    id: poweroffText

                                    anchors.centerIn: parent
                                    text: "󰐥 Off"
                                    color: "#d5c4a1"
                                    font.family: "FiraCode Nerd Font"
                                    font.pixelSize: 9
                                    renderType: Text.NativeRendering
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    onEntered: {
                                        poweroffText.color = "#ebdbb2";
                                    }
                                    onExited: {
                                        poweroffText.color = "#d5c4a1";
                                    }
                                    onClicked: {
                                        win.closePopup();
                                        root.runCmd(["systemctl", "poweroff"]);
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
