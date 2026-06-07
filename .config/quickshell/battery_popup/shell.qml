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
    // Battery Automations settings
    property bool automationEnabled: true
    property int lowBatteryThreshold: 25
    property string lowProfile: "Quiet"
    property string batProfile: "Balanced"
    property string acProfile: "Performance"
    property int batScreenBrightness: 70
    property int batKbdBrightness: 33
    property int acScreenBrightness: 100
    property int acKbdBrightness: 90
    property int lowScreenBrightness: 30
    property int lowKbdBrightness: 0 // Collapsible states for the cards
    property bool acExpanded: false
    property bool batExpanded: false
    property bool lowExpanded: false
    // Active state indicators (what happens in the battery daemon)
    property bool isACActive: status === "Charging" || status === "Full"
    property bool isLowActive: !isACActive && capacity < lowBatteryThreshold
    property bool isBatActive: !isACActive && !isLowActive

    function saveSettings() {
        var data = {
            "automation_enabled": root.automationEnabled,
            "low_battery_threshold": root.lowBatteryThreshold,
            "low_profile": root.lowProfile,
            "bat_profile": root.batProfile,
            "ac_profile": root.acProfile,
            "bat_screen_brightness": root.batScreenBrightness,
            "bat_kbd_brightness": root.batKbdBrightness,
            "ac_screen_brightness": root.acScreenBrightness,
            "ac_kbd_brightness": root.acKbdBrightness,
            "low_screen_brightness": root.lowScreenBrightness,
            "low_kbd_brightness": root.lowKbdBrightness
        };
        var jsonStr = JSON.stringify(data);
        Quickshell.execDetached(["python3", "-c", "import json, sys; json.dump(json.loads(sys.argv[1]), open('" + root.homeDir + "/.config/quickshell/battery_popup/settings.json', 'w'), indent=4)", jsonStr]);
    }

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

    FileView {
        id: settingsWatcher

        path: "file://" + root.homeDir + "/.config/quickshell/battery_popup/settings.json"
        watchChanges: true
        onLoaded: {
            try {
                var txt = settingsWatcher.text().trim();
                if (txt === "")
                    return ;

                var data = JSON.parse(txt);
                root.automationEnabled = data.automation_enabled ?? true;
                root.lowBatteryThreshold = data.low_battery_threshold ?? 25;
                root.lowProfile = data.low_profile ?? "Quiet";
                root.batProfile = data.bat_profile ?? "Balanced";
                root.acProfile = data.ac_profile ?? "Performance";
                root.batScreenBrightness = data.bat_screen_brightness ?? 70;
                root.batKbdBrightness = data.bat_kbd_brightness ?? 33;
                root.acScreenBrightness = data.ac_screen_brightness ?? 100;
                root.acKbdBrightness = data.ac_kbd_brightness ?? 90;
                root.lowScreenBrightness = data.low_screen_brightness ?? 30;
                root.lowKbdBrightness = data.low_kbd_brightness ?? 0;
            } catch (e) {
                console.log("Failed to parse settings: " + e);
            }
        }
        onFileChanged: reload()
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
                implicitHeight: (powerRow.y + powerRow.height) + 20
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
                    border.color: theme.accent
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
                            color: theme.accent
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
                            color: theme.accent
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
                                color: theme.accent
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
                                color: theme.accent
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
                                        color: theme.accent
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
                            color: theme.accent
                            opacity: 0.25
                        }

                        // Section 4: Battery Automations
                        Text {
                            id: autoTitle

                            anchors.top: sep1.bottom
                            anchors.topMargin: 6
                            anchors.left: parent.left
                            text: "Battery Automations"
                            color: theme.accent
                            font.family: "FiraCode Nerd Font"
                            font.pixelSize: 9
                            font.bold: true
                            renderType: Text.NativeRendering
                        }

                        MouseArea {
                            id: autoToggleArea

                            anchors.top: autoTitle.bottom
                            anchors.topMargin: 5
                            anchors.left: parent.left
                            anchors.right: parent.right
                            height: 16
                            onClicked: {
                                root.automationEnabled = !root.automationEnabled;
                                root.saveSettings();
                            }

                            Row {
                                anchors.fill: parent
                                spacing: 8

                                Text {
                                    text: "Auto Power Control"
                                    color: theme.accent
                                    font.family: "FiraCode Nerd Font"
                                    font.pixelSize: 8
                                    renderType: Text.NativeRendering
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: parent.width - 36
                                }

                                Rectangle {
                                    width: 28
                                    height: 12
                                    color: root.automationEnabled ? theme.accent : theme.bg_light
                                    border.color: theme.accent
                                    border.width: 1
                                    anchors.verticalCenter: parent.verticalCenter

                                    Rectangle {
                                        width: 8
                                        height: 8
                                        color: root.automationEnabled ? theme.bg : theme.accent
                                        anchors.verticalCenter: parent.verticalCenter
                                        x: root.automationEnabled ? 18 : 2

                                        Behavior on x {
                                            NumberAnimation {
                                                duration: 150
                                                easing.type: Easing.OutQuad
                                            }

                                        }

                                    }

                                    Behavior on color {
                                        ColorAnimation {
                                            duration: 150
                                        }

                                    }

                                }

                            }

                        }

                        Column {
                            id: adjustersCol

                            anchors.top: autoToggleArea.bottom
                            anchors.topMargin: 6
                            anchors.left: parent.left
                            anchors.right: parent.right
                            spacing: 6
                            visible: root.automationEnabled

                            // 1. AC Mode Card
                            Rectangle {
                                width: parent.width
                                height: acCardCol.implicitHeight + 12
                                color: root.isACActive ? Qt.rgba(theme.accent.r, theme.accent.g, theme.accent.b, 0.12) : theme.bg_dark
                                border.width: 0
                                radius: 2

                                Column {
                                    id: acCardCol

                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    anchors.top: parent.top
                                    anchors.leftMargin: 6
                                    anchors.rightMargin: 6
                                    anchors.topMargin: 6
                                    spacing: 8

                                    MouseArea {
                                        width: parent.width
                                        height: 12
                                        onClicked: root.acExpanded = !root.acExpanded

                                        Text {
                                            anchors.left: parent.left
                                            anchors.verticalCenter: parent.verticalCenter
                                            text: "󰢝 AC Mode " + (root.acExpanded ? "▴" : "▾")
                                            color: theme.accent
                                            font.family: "FiraCode Nerd Font"
                                            font.pixelSize: 8
                                            font.bold: true
                                            renderType: Text.NativeRendering
                                        }

                                        Text {
                                            anchors.right: parent.right
                                            anchors.verticalCenter: parent.verticalCenter
                                            text: "Active"
                                            color: theme.accent
                                            font.family: "FiraCode Nerd Font"
                                            font.pixelSize: 7
                                            font.bold: true
                                            visible: root.isACActive
                                            renderType: Text.NativeRendering
                                        }

                                    }

                                    // Row 1: Profile Selector (stretch-aligned to full width)
                                    Item {
                                        width: parent.width
                                        height: 12

                                        Row {
                                            anchors.left: parent.left
                                            anchors.right: parent.right
                                            anchors.verticalCenter: parent.verticalCenter
                                            spacing: 4

                                            Repeater {
                                                model: ["Quiet", "Balanced", "Performance"]

                                                delegate: Item {
                                                    width: (parent.width - 8) / 3
                                                    height: 11

                                                    Text {
                                                        anchors.centerIn: parent
                                                        text: (root.acProfile === modelData ? "* " : "") + modelData
                                                        color: theme.accent
                                                        font.family: "FiraCode Nerd Font"
                                                        font.pixelSize: 7
                                                        font.bold: root.acProfile === modelData
                                                        renderType: Text.NativeRendering
                                                    }

                                                    MouseArea {
                                                        anchors.fill: parent
                                                        onClicked: {
                                                            root.acProfile = modelData;
                                                            root.saveSettings();
                                                        }
                                                    }

                                                }

                                            }

                                        }

                                    }

                                    // Row 2: Brightness controls (full width distribution via anchors)
                                    Item {
                                        width: parent.width
                                        height: 12
                                        visible: root.acExpanded

                                        // Screen Brightness (Left half, fully anchored)
                                        Item {
                                            anchors.left: parent.left
                                            anchors.right: parent.horizontalCenter
                                            anchors.rightMargin: 6
                                            height: parent.height

                                            Text {
                                                id: acScrIcon

                                                anchors.left: parent.left
                                                anchors.verticalCenter: parent.verticalCenter
                                                text: "󰃠 Screen"
                                                color: theme.accent
                                                font.pixelSize: 8
                                            }

                                            Item {
                                                id: acScrDec

                                                anchors.left: acScrIcon.right
                                                anchors.leftMargin: 4
                                                anchors.verticalCenter: parent.verticalCenter
                                                width: 12
                                                height: 11

                                                Text {
                                                    anchors.centerIn: parent
                                                    text: "-"
                                                    color: theme.accent
                                                    font.pixelSize: 8
                                                    font.bold: true
                                                    opacity: decAcBr.containsMouse ? 1 : 0.7
                                                }

                                                MouseArea {
                                                    id: decAcBr

                                                    anchors.fill: parent
                                                    hoverEnabled: true
                                                    onClicked: {
                                                        root.acScreenBrightness = Math.max(10, root.acScreenBrightness - 5);
                                                        root.saveSettings();
                                                    }
                                                }

                                            }

                                            Item {
                                                id: acScrInc

                                                anchors.right: parent.right
                                                anchors.verticalCenter: parent.verticalCenter
                                                width: 12
                                                height: 11

                                                Text {
                                                    anchors.centerIn: parent
                                                    text: "+"
                                                    color: theme.accent
                                                    font.pixelSize: 8
                                                    font.bold: true
                                                    opacity: incAcBr.containsMouse ? 1 : 0.7
                                                }

                                                MouseArea {
                                                    id: incAcBr

                                                    anchors.fill: parent
                                                    hoverEnabled: true
                                                    onClicked: {
                                                        root.acScreenBrightness = Math.min(100, root.acScreenBrightness + 5);
                                                        root.saveSettings();
                                                    }
                                                }

                                            }

                                            Text {
                                                anchors.left: acScrDec.right
                                                anchors.right: acScrInc.left
                                                anchors.verticalCenter: parent.verticalCenter
                                                text: root.acScreenBrightness + "%"
                                                color: theme.accent
                                                font.pixelSize: 7
                                                horizontalAlignment: Text.AlignHCenter
                                            }

                                        }

                                        // Keyboard (Right half, fully anchored)
                                        Item {
                                            anchors.left: parent.horizontalCenter
                                            anchors.leftMargin: 6
                                            anchors.right: parent.right
                                            height: parent.height

                                            Text {
                                                id: acKbIcon

                                                anchors.left: parent.left
                                                anchors.verticalCenter: parent.verticalCenter
                                                text: "󰥻 Keyboard"
                                                color: theme.accent
                                                font.pixelSize: 8
                                            }

                                            Item {
                                                id: acKbDec

                                                anchors.left: acKbIcon.right
                                                anchors.leftMargin: 4
                                                anchors.verticalCenter: parent.verticalCenter
                                                width: 12
                                                height: 11

                                                Text {
                                                    anchors.centerIn: parent
                                                    text: "-"
                                                    color: theme.accent
                                                    font.pixelSize: 8
                                                    font.bold: true
                                                    opacity: decAcKb.containsMouse ? 1 : 0.7
                                                }

                                                MouseArea {
                                                    id: decAcKb

                                                    anchors.fill: parent
                                                    hoverEnabled: true
                                                    onClicked: {
                                                        root.acKbdBrightness = Math.max(0, root.acKbdBrightness - 10);
                                                        root.saveSettings();
                                                    }
                                                }

                                            }

                                            Item {
                                                id: acKbInc

                                                anchors.right: parent.right
                                                anchors.verticalCenter: parent.verticalCenter
                                                width: 12
                                                height: 11

                                                Text {
                                                    anchors.centerIn: parent
                                                    text: "+"
                                                    color: theme.accent
                                                    font.pixelSize: 8
                                                    font.bold: true
                                                    opacity: incAcKb.containsMouse ? 1 : 0.7
                                                }

                                                MouseArea {
                                                    id: incAcKb

                                                    anchors.fill: parent
                                                    hoverEnabled: true
                                                    onClicked: {
                                                        root.acKbdBrightness = Math.min(100, root.acKbdBrightness + 10);
                                                        root.saveSettings();
                                                    }
                                                }

                                            }

                                            Text {
                                                anchors.left: acKbDec.right
                                                anchors.right: acKbInc.left
                                                anchors.verticalCenter: parent.verticalCenter
                                                text: root.acKbdBrightness + "%"
                                                color: theme.accent
                                                font.pixelSize: 7
                                                horizontalAlignment: Text.AlignHCenter
                                            }

                                        }

                                    }

                                }

                            }

                            // 2. Battery Mode Card
                            Rectangle {
                                width: parent.width
                                height: batCardCol.implicitHeight + 12
                                color: root.isBatActive ? Qt.rgba(theme.accent.r, theme.accent.g, theme.accent.b, 0.12) : theme.bg_dark
                                border.width: 0
                                radius: 2

                                Column {
                                    id: batCardCol

                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    anchors.top: parent.top
                                    anchors.leftMargin: 6
                                    anchors.rightMargin: 6
                                    anchors.topMargin: 6
                                    spacing: 8

                                    MouseArea {
                                        width: parent.width
                                        height: 12
                                        onClicked: root.batExpanded = !root.batExpanded

                                        Text {
                                            anchors.left: parent.left
                                            anchors.verticalCenter: parent.verticalCenter
                                            text: "󰁹 Battery Mode " + (root.batExpanded ? "▴" : "▾")
                                            color: theme.accent
                                            font.family: "FiraCode Nerd Font"
                                            font.pixelSize: 8
                                            font.bold: true
                                            renderType: Text.NativeRendering
                                        }

                                        Text {
                                            anchors.right: parent.right
                                            anchors.verticalCenter: parent.verticalCenter
                                            text: "Active"
                                            color: theme.accent
                                            font.family: "FiraCode Nerd Font"
                                            font.pixelSize: 7
                                            font.bold: true
                                            visible: root.isBatActive
                                            renderType: Text.NativeRendering
                                        }

                                    }

                                    // Row 1: Profile Selector (stretch-aligned to full width)
                                    Item {
                                        width: parent.width
                                        height: 12

                                        Row {
                                            anchors.left: parent.left
                                            anchors.right: parent.right
                                            anchors.verticalCenter: parent.verticalCenter
                                            spacing: 4

                                            Repeater {
                                                model: ["Quiet", "Balanced", "Performance"]

                                                delegate: Item {
                                                    width: (parent.width - 8) / 3
                                                    height: 11

                                                    Text {
                                                        anchors.centerIn: parent
                                                        text: (root.batProfile === modelData ? "* " : "") + modelData
                                                        color: theme.accent
                                                        font.family: "FiraCode Nerd Font"
                                                        font.pixelSize: 7
                                                        font.bold: root.batProfile === modelData
                                                        renderType: Text.NativeRendering
                                                    }

                                                    MouseArea {
                                                        anchors.fill: parent
                                                        onClicked: {
                                                            root.batProfile = modelData;
                                                            root.saveSettings();
                                                        }
                                                    }

                                                }

                                            }

                                        }

                                    }

                                    // Row 2: Brightness controls (full width distribution via anchors)
                                    Item {
                                        width: parent.width
                                        height: 12
                                        visible: root.batExpanded

                                        // Screen Brightness (Left half, fully anchored)
                                        Item {
                                            anchors.left: parent.left
                                            anchors.right: parent.horizontalCenter
                                            anchors.rightMargin: 6
                                            height: parent.height

                                            Text {
                                                id: batScrIcon

                                                anchors.left: parent.left
                                                anchors.verticalCenter: parent.verticalCenter
                                                text: "󰃠 Screen"
                                                color: theme.accent
                                                font.pixelSize: 8
                                            }

                                            Item {
                                                id: batScrDec

                                                anchors.left: batScrIcon.right
                                                anchors.leftMargin: 4
                                                anchors.verticalCenter: parent.verticalCenter
                                                width: 12
                                                height: 11

                                                Text {
                                                    anchors.centerIn: parent
                                                    text: "-"
                                                    color: theme.accent
                                                    font.pixelSize: 8
                                                    font.bold: true
                                                    opacity: decBatBr.containsMouse ? 1 : 0.7
                                                }

                                                MouseArea {
                                                    id: decBatBr

                                                    anchors.fill: parent
                                                    hoverEnabled: true
                                                    onClicked: {
                                                        root.batScreenBrightness = Math.max(10, root.batScreenBrightness - 5);
                                                        root.saveSettings();
                                                    }
                                                }

                                            }

                                            Item {
                                                id: batScrInc

                                                anchors.right: parent.right
                                                anchors.verticalCenter: parent.verticalCenter
                                                width: 12
                                                height: 11

                                                Text {
                                                    anchors.centerIn: parent
                                                    text: "+"
                                                    color: theme.accent
                                                    font.pixelSize: 8
                                                    font.bold: true
                                                    opacity: incBatBr.containsMouse ? 1 : 0.7
                                                }

                                                MouseArea {
                                                    id: incBatBr

                                                    anchors.fill: parent
                                                    hoverEnabled: true
                                                    onClicked: {
                                                        root.batScreenBrightness = Math.min(100, root.batScreenBrightness + 5);
                                                        root.saveSettings();
                                                    }
                                                }

                                            }

                                            Text {
                                                anchors.left: batScrDec.right
                                                anchors.right: batScrInc.left
                                                anchors.verticalCenter: parent.verticalCenter
                                                text: root.batScreenBrightness + "%"
                                                color: theme.accent
                                                font.pixelSize: 7
                                                horizontalAlignment: Text.AlignHCenter
                                            }

                                        }

                                        // Keyboard (Right half, fully anchored)
                                        Item {
                                            anchors.left: parent.horizontalCenter
                                            anchors.leftMargin: 6
                                            anchors.right: parent.right
                                            height: parent.height

                                            Text {
                                                id: batKbIcon

                                                anchors.left: parent.left
                                                anchors.verticalCenter: parent.verticalCenter
                                                text: "󰥻 Keyboard"
                                                color: theme.accent
                                                font.pixelSize: 8
                                            }

                                            Item {
                                                id: batKbDec

                                                anchors.left: batKbIcon.right
                                                anchors.leftMargin: 4
                                                anchors.verticalCenter: parent.verticalCenter
                                                width: 12
                                                height: 11

                                                Text {
                                                    anchors.centerIn: parent
                                                    text: "-"
                                                    color: theme.accent
                                                    font.pixelSize: 8
                                                    font.bold: true
                                                    opacity: decBatKb.containsMouse ? 1 : 0.7
                                                }

                                                MouseArea {
                                                    id: decBatKb

                                                    anchors.fill: parent
                                                    hoverEnabled: true
                                                    onClicked: {
                                                        root.batKbdBrightness = Math.max(0, root.batKbdBrightness - 33);
                                                        root.saveSettings();
                                                    }
                                                }

                                            }

                                            Item {
                                                id: batKbInc

                                                anchors.right: parent.right
                                                anchors.verticalCenter: parent.verticalCenter
                                                width: 12
                                                height: 11

                                                Text {
                                                    anchors.centerIn: parent
                                                    text: "+"
                                                    color: theme.accent
                                                    font.pixelSize: 8
                                                    font.bold: true
                                                    opacity: incBatKb.containsMouse ? 1 : 0.7
                                                }

                                                MouseArea {
                                                    id: incBatKb

                                                    anchors.fill: parent
                                                    hoverEnabled: true
                                                    onClicked: {
                                                        root.batKbdBrightness = Math.min(100, root.batKbdBrightness + 33);
                                                        root.saveSettings();
                                                    }
                                                }

                                            }

                                            Text {
                                                anchors.left: batKbDec.right
                                                anchors.right: batKbInc.left
                                                anchors.verticalCenter: parent.verticalCenter
                                                text: root.batKbdBrightness + "%"
                                                color: theme.accent
                                                font.pixelSize: 7
                                                horizontalAlignment: Text.AlignHCenter
                                            }

                                        }

                                    }

                                }

                            }

                            // 3. Low Battery Mode Card
                            Rectangle {
                                width: parent.width
                                height: lowCardCol.implicitHeight + 12
                                color: root.isLowActive ? Qt.rgba(theme.accent.r, theme.accent.g, theme.accent.b, 0.12) : theme.bg_dark
                                border.width: 0
                                radius: 2

                                Column {
                                    id: lowCardCol

                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    anchors.top: parent.top
                                    anchors.leftMargin: 6
                                    anchors.rightMargin: 6
                                    anchors.topMargin: 6
                                    spacing: 8

                                    MouseArea {
                                        width: parent.width
                                        height: 12
                                        onClicked: root.lowExpanded = !root.lowExpanded

                                        Text {
                                            anchors.left: parent.left
                                            anchors.verticalCenter: parent.verticalCenter
                                            text: "󰂃 Low Battery" + (root.isLowActive ? " (Active)" : "") + " " + (root.lowExpanded ? "▴" : "▾")
                                            color: theme.accent
                                            font.family: "FiraCode Nerd Font"
                                            font.pixelSize: 8
                                            font.bold: true
                                            renderType: Text.NativeRendering
                                        }

                                        Row {
                                            id: thresholdRow

                                            anchors.right: parent.right
                                            anchors.verticalCenter: parent.verticalCenter
                                            spacing: 3

                                            Text {
                                                text: "Threshold:"
                                                color: theme.accent
                                                font.pixelSize: 7
                                                font.bold: true
                                                anchors.verticalCenter: parent.verticalCenter
                                            }

                                            Item {
                                                width: 12
                                                height: 11

                                                Text {
                                                    anchors.centerIn: parent
                                                    text: "-"
                                                    color: theme.accent
                                                    font.pixelSize: 8
                                                    font.bold: true
                                                    opacity: decThres.containsMouse ? 1 : 0.7
                                                }

                                                MouseArea {
                                                    id: decThres

                                                    anchors.fill: parent
                                                    hoverEnabled: true
                                                    onClicked: {
                                                        root.lowBatteryThreshold = Math.max(5, root.lowBatteryThreshold - 5);
                                                        root.saveSettings();
                                                    }
                                                }

                                            }

                                            Text {
                                                text: root.lowBatteryThreshold + "%"
                                                color: theme.accent
                                                font.pixelSize: 7
                                                width: 24
                                                horizontalAlignment: Text.AlignHCenter
                                                anchors.verticalCenter: parent.verticalCenter
                                            }

                                            Item {
                                                width: 12
                                                height: 11

                                                Text {
                                                    anchors.centerIn: parent
                                                    text: "+"
                                                    color: theme.accent
                                                    font.pixelSize: 8
                                                    font.bold: true
                                                    opacity: incThres.containsMouse ? 1 : 0.7
                                                }

                                                MouseArea {
                                                    id: incThres

                                                    anchors.fill: parent
                                                    hoverEnabled: true
                                                    onClicked: {
                                                        root.lowBatteryThreshold = Math.min(95, root.lowBatteryThreshold + 5);
                                                        root.saveSettings();
                                                    }
                                                }

                                            }

                                        }

                                    }

                                    // Row 1: Profile Selector (stretch-aligned to full width)
                                    Item {
                                        width: parent.width
                                        height: 12

                                        Row {
                                            anchors.left: parent.left
                                            anchors.right: parent.right
                                            anchors.verticalCenter: parent.verticalCenter
                                            spacing: 4

                                            Repeater {
                                                model: ["Quiet", "Balanced", "Performance"]

                                                delegate: Item {
                                                    width: (parent.width - 8) / 3
                                                    height: 11

                                                    Text {
                                                        anchors.centerIn: parent
                                                        text: (root.lowProfile === modelData ? "* " : "") + modelData
                                                        color: theme.accent
                                                        font.family: "FiraCode Nerd Font"
                                                        font.pixelSize: 7
                                                        font.bold: root.lowProfile === modelData
                                                        renderType: Text.NativeRendering
                                                    }

                                                    MouseArea {
                                                        anchors.fill: parent
                                                        onClicked: {
                                                            root.lowProfile = modelData;
                                                            root.saveSettings();
                                                        }
                                                    }

                                                }

                                            }

                                        }

                                    }

                                    // Row 2: Brightness controls (full width distribution via anchors)
                                    Item {
                                        width: parent.width
                                        height: 12
                                        visible: root.lowExpanded

                                        // Screen Brightness (Left half, fully anchored)
                                        Item {
                                            anchors.left: parent.left
                                            anchors.right: parent.horizontalCenter
                                            anchors.rightMargin: 6
                                            height: parent.height

                                            Text {
                                                id: lowScrIcon

                                                anchors.left: parent.left
                                                anchors.verticalCenter: parent.verticalCenter
                                                text: "󰃠 Screen"
                                                color: theme.accent
                                                font.pixelSize: 8
                                            }

                                            Item {
                                                id: lowScrDec

                                                anchors.left: lowScrIcon.right
                                                anchors.leftMargin: 4
                                                anchors.verticalCenter: parent.verticalCenter
                                                width: 12
                                                height: 11

                                                Text {
                                                    anchors.centerIn: parent
                                                    text: "-"
                                                    color: theme.accent
                                                    font.pixelSize: 8
                                                    font.bold: true
                                                    opacity: decLowBr.containsMouse ? 1 : 0.7
                                                }

                                                MouseArea {
                                                    id: decLowBr

                                                    anchors.fill: parent
                                                    hoverEnabled: true
                                                    onClicked: {
                                                        root.lowScreenBrightness = Math.max(10, root.lowScreenBrightness - 5);
                                                        root.saveSettings();
                                                    }
                                                }

                                            }

                                            Item {
                                                id: lowScrInc

                                                anchors.right: parent.right
                                                anchors.verticalCenter: parent.verticalCenter
                                                width: 12
                                                height: 11

                                                Text {
                                                    anchors.centerIn: parent
                                                    text: "+"
                                                    color: theme.accent
                                                    font.pixelSize: 8
                                                    font.bold: true
                                                    opacity: incLowBr.containsMouse ? 1 : 0.7
                                                }

                                                MouseArea {
                                                    id: incLowBr

                                                    anchors.fill: parent
                                                    hoverEnabled: true
                                                    onClicked: {
                                                        root.lowScreenBrightness = Math.min(100, root.lowScreenBrightness + 5);
                                                        root.saveSettings();
                                                    }
                                                }

                                            }

                                            Text {
                                                anchors.left: lowScrDec.right
                                                anchors.right: lowScrInc.left
                                                anchors.verticalCenter: parent.verticalCenter
                                                text: root.lowScreenBrightness + "%"
                                                color: theme.accent
                                                font.pixelSize: 7
                                                horizontalAlignment: Text.AlignHCenter
                                            }

                                        }

                                        // Keyboard (Right half, fully anchored)
                                        Item {
                                            anchors.left: parent.horizontalCenter
                                            anchors.leftMargin: 6
                                            anchors.right: parent.right
                                            height: parent.height

                                            Text {
                                                id: lowKbIcon

                                                anchors.left: parent.left
                                                anchors.verticalCenter: parent.verticalCenter
                                                text: "󰥻 Keyboard"
                                                color: theme.accent
                                                font.pixelSize: 8
                                            }

                                            Item {
                                                id: lowKbDec

                                                anchors.left: lowKbIcon.right
                                                anchors.leftMargin: 4
                                                anchors.verticalCenter: parent.verticalCenter
                                                width: 12
                                                height: 11

                                                Text {
                                                    anchors.centerIn: parent
                                                    text: "-"
                                                    color: theme.accent
                                                    font.pixelSize: 8
                                                    font.bold: true
                                                    opacity: decLowKb.containsMouse ? 1 : 0.7
                                                }

                                                MouseArea {
                                                    id: decLowKb

                                                    anchors.fill: parent
                                                    hoverEnabled: true
                                                    onClicked: {
                                                        root.lowKbdBrightness = Math.max(0, root.lowKbdBrightness - 33);
                                                        root.saveSettings();
                                                    }
                                                }

                                            }

                                            Item {
                                                id: lowKbInc

                                                anchors.right: parent.right
                                                anchors.verticalCenter: parent.verticalCenter
                                                width: 12
                                                height: 11

                                                Text {
                                                    anchors.centerIn: parent
                                                    text: "+"
                                                    color: theme.accent
                                                    font.pixelSize: 8
                                                    font.bold: true
                                                    opacity: incLowKb.containsMouse ? 1 : 0.7
                                                }

                                                MouseArea {
                                                    id: incLowKb

                                                    anchors.fill: parent
                                                    hoverEnabled: true
                                                    onClicked: {
                                                        root.lowKbdBrightness = Math.min(100, root.lowKbdBrightness + 33);
                                                        root.saveSettings();
                                                    }
                                                }

                                            }

                                            Text {
                                                anchors.left: lowKbDec.right
                                                anchors.right: lowKbInc.left
                                                anchors.verticalCenter: parent.verticalCenter
                                                text: root.lowKbdBrightness + "%"
                                                color: theme.accent
                                                font.pixelSize: 7
                                                horizontalAlignment: Text.AlignHCenter
                                            }

                                        }

                                    }

                                }

                            }

                        }

                        // Separator 2
                        Rectangle {
                            id: sep2

                            anchors.top: root.automationEnabled ? adjustersCol.bottom : autoToggleArea.bottom
                            anchors.topMargin: 6
                            anchors.left: parent.left
                            anchors.right: parent.right
                            height: 1
                            color: theme.accent
                            opacity: 0.25
                        }

                        // Section: Power Modes
                        Item {
                            id: modeTitle

                            anchors.top: sep2.bottom
                            anchors.topMargin: 6
                            anchors.left: parent.left
                            anchors.right: parent.right
                            height: 12

                            Text {
                                anchors.left: parent.left
                                anchors.verticalCenter: parent.verticalCenter
                                text: "Power Mode"
                                color: theme.accent
                                font.family: "FiraCode Nerd Font"
                                font.pixelSize: 9
                                font.bold: true
                                renderType: Text.NativeRendering
                            }

                            Text {
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                text: "Override"
                                color: theme.accent
                                font.family: "FiraCode Nerd Font"
                                font.pixelSize: 7
                                font.bold: true
                                opacity: 0.5
                                renderType: Text.NativeRendering
                            }

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
                                    color: root.activeProfile === "Quiet" ? theme.accent : theme.accent
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
                                            quietText.color = theme.accent;
                                            quietText.opacity = 1;
                                        }
                                    }
                                    onExited: {
                                        if (root.activeProfile !== "Quiet") {
                                            quietText.color = theme.accent;
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
                                    color: root.activeProfile === "Balanced" ? theme.accent : theme.accent
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
                                            balancedText.color = theme.accent;
                                            balancedText.opacity = 1;
                                        }
                                    }
                                    onExited: {
                                        if (root.activeProfile !== "Balanced") {
                                            balancedText.color = theme.accent;
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
                                    color: root.activeProfile === "Performance" ? theme.accent : theme.accent
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
                                            perfText.color = theme.accent;
                                            perfText.opacity = 1;
                                        }
                                    }
                                    onExited: {
                                        if (root.activeProfile !== "Performance") {
                                            perfText.color = theme.accent;
                                            perfText.opacity = 0.7;
                                        }
                                    }
                                    onClicked: root.setProfile("Performance")
                                }

                            }

                        }

                        // Separator 3
                        Rectangle {
                            id: sep3

                            anchors.top: modeRow.bottom
                            anchors.topMargin: 6
                            anchors.left: parent.left
                            anchors.right: parent.right
                            height: 1
                            color: theme.accent
                            opacity: 0.25
                        }

                        // Section: Power Options
                        Row {
                            id: powerRow

                            anchors.top: sep3.bottom
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
                                    color: theme.accent
                                    font.family: "FiraCode Nerd Font"
                                    font.pixelSize: 9
                                    renderType: Text.NativeRendering
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    onEntered: {
                                        logoutText.color = theme.accent;
                                    }
                                    onExited: {
                                        logoutText.color = theme.accent;
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
                                    color: theme.accent
                                    font.family: "FiraCode Nerd Font"
                                    font.pixelSize: 9
                                    renderType: Text.NativeRendering
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    onEntered: {
                                        poweroffText.color = theme.accent;
                                    }
                                    onExited: {
                                        poweroffText.color = theme.accent;
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
