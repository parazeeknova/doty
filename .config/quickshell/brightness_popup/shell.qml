import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io

Scope {
    id: root

    property string homeDir: Quickshell.env("HOME")
    // Brightness state properties
    property int screenBrightness: 80
    property int kbdBrightness: 100
    property string kbdDevice: ""
    property string sunsetState: "Off"
    property bool caffeineActive: false
    // Temporary targets for dragging/scrolling sliders
    property int pendingScreenVol: -1
    property int pendingKbdVol: -1
    property int pendingSunsetTemp: -1

    signal requestClose()

    function triggerRefresh() {
        delayRefreshTimer.restart();
    }

    Component.onCompleted: {
        checkStatusProc.running = true;
    }

    Theme {
        id: theme
    }

    IpcHandler {
        function close() {
            root.requestClose();
        }

        target: "brightness_popup"
    }

    // Timer to apply brightness/temperature changes at most once every 50ms to prevent bottlenecking
    Timer {
        id: applyTimer

        interval: 50
        repeat: true
        running: true
        onTriggered: {
            if (pendingScreenVol !== -1) {
                Quickshell.execDetached(["brightnessctl", "set", pendingScreenVol + "%"]);
                // Trigger OSD
                Quickshell.execDetached([root.homeDir + "/.config/quickshell/osd/bin/osdctl", "show", "brightness " + pendingScreenVol + "%", "info", "1200"]);
                pendingScreenVol = -1;
            }
            if (pendingKbdVol !== -1) {
                // Keyboard backlight is usually 0-3 on ASUS, let's map percentage to 0..3
                var val = Math.round((pendingKbdVol / 100) * 3);
                if (root.kbdDevice !== "") {
                    Quickshell.execDetached(["brightnessctl", "-d", root.kbdDevice, "set", String(val)]);
                    // Trigger OSD
                    var pct = Math.round((val / 3) * 100);
                    Quickshell.execDetached([root.homeDir + "/.config/quickshell/osd/bin/osdctl", "show", "kbd brightness " + pct + "%", "info", "1200"]);
                }
                pendingKbdVol = -1;
            }
            if (pendingSunsetTemp !== -1) {
                Quickshell.execDetached([root.homeDir + "/.config/rofi/scripts/sunset.sh", String(pendingSunsetTemp)]);
                pendingSunsetTemp = -1;
            }
        }
    }

    // Process to run the Rust helper
    Process {
        id: checkStatusProc

        command: [root.homeDir + "/.config/quickshell/brightness_popup/get_brightness_status"]
        running: false

        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var data = JSON.parse(this.text);
                    root.screenBrightness = data.screen_brightness_pct;
                    root.kbdBrightness = data.kbd_brightness_pct;
                    root.kbdDevice = data.kbd_device || "";
                    root.sunsetState = data.sunset_state;
                    root.caffeineActive = data.caffeine_active;
                } catch (e) {
                    console.log("Failed to parse: " + e);
                }
            }
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
            if (pendingScreenVol === -1 && pendingKbdVol === -1) {
                if (!checkStatusProc.running)
                    checkStatusProc.running = true;

            }
        }
    }

    Timer {
        id: delayRefreshTimer

        interval: 150
        repeat: false
        running: false
        onTriggered: {
            checkStatusProc.running = false;
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

                        // --- SECTION 1: MONITOR BRIGHTNESS ---
                        Column {
                            width: parent.width
                            spacing: 3

                            Item {
                                width: parent.width
                                height: 14

                                Text {
                                    anchors.left: parent.left
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: "󰃠 Brightness: " + root.screenBrightness + "%"
                                    color: theme.c.accent
                                    font.family: "FiraCode Nerd Font"
                                    font.pixelSize: 9
                                    font.bold: true
                                    renderType: Text.NativeRendering
                                }

                            }

                            // Brightness Slider
                            Item {
                                width: parent.width
                                height: 8

                                Row {
                                    id: screenSliderBlocks

                                    property int totalBlocks: 15
                                    property double currentVal: root.screenBrightness / 100

                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    anchors.verticalCenter: parent.verticalCenter
                                    height: 5
                                    spacing: 1

                                    Repeater {
                                        model: screenSliderBlocks.totalBlocks

                                        delegate: Rectangle {
                                            height: parent.height
                                            width: (screenSliderBlocks.width - (screenSliderBlocks.spacing * (screenSliderBlocks.totalBlocks - 1))) / screenSliderBlocks.totalBlocks
                                            color: (index < Math.round(screenSliderBlocks.currentVal * screenSliderBlocks.totalBlocks)) ? theme.c.accent : theme.c.bg_light
                                        }

                                    }

                                }

                                MouseArea {
                                    function updateVol(mouseX) {
                                        var clampedX = Math.max(0, Math.min(mouseX, parent.width));
                                        var pct = Math.round((clampedX / parent.width) * 100);
                                        root.screenBrightness = pct;
                                        root.pendingScreenVol = pct;
                                    }

                                    anchors.fill: parent
                                    preventStealing: true
                                    onWheel: (wheel) => {
                                        var change = wheel.angleDelta.y > 0 ? 5 : -5;
                                        var newVol = Math.max(0, Math.min(root.screenBrightness + change, 100));
                                        root.screenBrightness = newVol;
                                        root.pendingScreenVol = newVol;
                                    }
                                    onPressed: (mouse) => {
                                        updateVol(mouse.x);
                                    }
                                    onPositionChanged: (mouse) => {
                                        updateVol(mouse.x);
                                    }
                                }

                            }

                        }

                        Rectangle {
                            width: parent.width
                            height: 1
                            color: theme.c.accent
                            opacity: 0.15
                        }

                        // --- SECTION 2: KEYBOARD BACKLIGHT ---
                        Column {
                            width: parent.width
                            spacing: 3

                            Item {
                                width: parent.width
                                height: 14

                                Text {
                                    anchors.left: parent.left
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: "󰥻 Keyboard Backlight: " + root.kbdBrightness + "%"
                                    color: theme.c.accent
                                    font.family: "FiraCode Nerd Font"
                                    font.pixelSize: 9
                                    font.bold: true
                                    renderType: Text.NativeRendering
                                }

                            }

                            // Keyboard Slider
                            Item {
                                width: parent.width
                                height: 8

                                Row {
                                    id: kbdSliderBlocks

                                    property int totalBlocks: 15
                                    property double currentVal: root.kbdBrightness / 100

                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    anchors.verticalCenter: parent.verticalCenter
                                    height: 5
                                    spacing: 1

                                    Repeater {
                                        model: kbdSliderBlocks.totalBlocks

                                        delegate: Rectangle {
                                            height: parent.height
                                            width: (kbdSliderBlocks.width - (kbdSliderBlocks.spacing * (kbdSliderBlocks.totalBlocks - 1))) / kbdSliderBlocks.totalBlocks
                                            color: (index < Math.round(kbdSliderBlocks.currentVal * kbdSliderBlocks.totalBlocks)) ? theme.c.accent : theme.c.bg_light
                                        }

                                    }

                                }

                                MouseArea {
                                    function updateVol(mouseX) {
                                        var clampedX = Math.max(0, Math.min(mouseX, parent.width));
                                        var pct = Math.round((clampedX / parent.width) * 100);
                                        // Map to nearest ASUS backlight steps (0%, 33%, 67%, 100%)
                                        if (pct < 16)
                                            pct = 0;
                                        else if (pct < 50)
                                            pct = 33;
                                        else if (pct < 83)
                                            pct = 67;
                                        else
                                            pct = 100;
                                        root.kbdBrightness = pct;
                                        root.pendingKbdVol = pct;
                                    }

                                    anchors.fill: parent
                                    preventStealing: true
                                    onWheel: (wheel) => {
                                        var change = wheel.angleDelta.y > 0 ? 33 : -33;
                                        var newVol = Math.max(0, Math.min(root.kbdBrightness + change, 100));
                                        root.kbdBrightness = newVol;
                                        root.pendingKbdVol = newVol;
                                    }
                                    onPressed: (mouse) => {
                                        updateVol(mouse.x);
                                    }
                                    onPositionChanged: (mouse) => {
                                        updateVol(mouse.x);
                                    }
                                }

                            }

                        }

                        Rectangle {
                            width: parent.width
                            height: 1
                            color: theme.c.accent
                            opacity: 0.15
                        }

                        // --- SECTION 3: NIGHT LIGHT (HYPRSUNSET) ---
                        Column {
                            width: parent.width
                            spacing: 4

                            Text {
                                text: "Night Light (Hyprsunset)"
                                color: theme.c.accent
                                font.family: "FiraCode Nerd Font"
                                font.pixelSize: 9
                                font.bold: true
                                renderType: Text.NativeRendering
                            }

                            Text {
                                text: "Current: " + root.sunsetState
                                color: theme.c.accent
                                opacity: 0.6
                                font.family: "FiraCode Nerd Font"
                                font.pixelSize: 8
                                renderType: Text.NativeRendering
                            }

                            Row {
                                spacing: 8
                                anchors.horizontalCenter: parent.horizontalCenter

                                // Auto Button
                                Rectangle {
                                    width: 106
                                    height: 16
                                    color: (root.sunsetState.toLowerCase() === "auto") ? theme.c.accent : theme.c.bg_light
                                    radius: 0

                                    Text {
                                        anchors.centerIn: parent
                                        text: "Auto"
                                        color: (root.sunsetState.toLowerCase() === "auto") ? theme.c.bg : theme.c.accent
                                        font.family: "FiraCode Nerd Font"
                                        font.pixelSize: 8
                                        font.bold: true
                                        renderType: Text.NativeRendering
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        onClicked: {
                                            root.sunsetState = "Auto";
                                            Quickshell.execDetached([root.homeDir + "/.config/rofi/scripts/sunset.sh", "auto"]);
                                            root.triggerRefresh();
                                        }
                                    }

                                }

                                // Off Button
                                Rectangle {
                                    width: 106
                                    height: 16
                                    color: (root.sunsetState.toLowerCase() === "off") ? theme.c.accent : theme.c.bg_light
                                    radius: 0

                                    Text {
                                        anchors.centerIn: parent
                                        text: "Off"
                                        color: (root.sunsetState.toLowerCase() === "off") ? theme.c.bg : theme.c.accent
                                        font.family: "FiraCode Nerd Font"
                                        font.pixelSize: 8
                                        font.bold: true
                                        renderType: Text.NativeRendering
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        onClicked: {
                                            root.sunsetState = "Off";
                                            Quickshell.execDetached([root.homeDir + "/.config/rofi/scripts/sunset.sh", "off"]);
                                            root.triggerRefresh();
                                        }
                                    }

                                }

                            }

                            // Temperature Slider (visible when not Auto/Off, or drag changes state to a custom temperature)
                            Item {
                                width: parent.width
                                height: 14
                                visible: root.sunsetState.toLowerCase() !== "auto"

                                Text {
                                    anchors.left: parent.left
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: "Temperature: " + (root.sunsetState.toLowerCase() === "off" ? "Identity (No change)" : root.sunsetState + "K")
                                    color: theme.c.accent
                                    font.family: "FiraCode Nerd Font"
                                    font.pixelSize: 8
                                    opacity: 0.8
                                    renderType: Text.NativeRendering
                                }

                            }

                            Item {
                                width: parent.width
                                height: 8
                                visible: root.sunsetState.toLowerCase() !== "auto"

                                Row {
                                    id: tempSliderBlocks

                                    property int totalBlocks: 15
                                    // Map temperature range 1000K (full orange) to 6500K (identity/cool)
                                    // Let's parse current temp: if off, set it to 6500.
                                    property int parsedTemp: {
                                        var t = parseInt(root.sunsetState);
                                        if (isNaN(t))
                                            return 6500;

                                        return t;
                                    }
                                    // Map range 2800K to 6500K.
                                    property double currentVal: (parsedTemp - 2800) / (6500 - 2800)

                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    anchors.verticalCenter: parent.verticalCenter
                                    height: 5
                                    spacing: 1

                                    Repeater {
                                        model: tempSliderBlocks.totalBlocks

                                        delegate: Rectangle {
                                            height: parent.height
                                            width: (tempSliderBlocks.width - (tempSliderBlocks.spacing * (tempSliderBlocks.totalBlocks - 1))) / tempSliderBlocks.totalBlocks
                                            color: (index < Math.round(tempSliderBlocks.currentVal * tempSliderBlocks.totalBlocks)) ? theme.c.accent : theme.c.bg_light
                                        }

                                    }

                                }

                                MouseArea {
                                    function updateTemp(mouseX) {
                                        var clampedX = Math.max(0, Math.min(mouseX, parent.width));
                                        var pct = clampedX / parent.width;
                                        var target = Math.round(2800 + pct * (6500 - 2800));
                                        // Round to nearest 50K
                                        target = Math.round(target / 50) * 50;
                                        target = Math.max(2800, Math.min(target, 6500));
                                        root.sunsetState = String(target);
                                        root.pendingSunsetTemp = target;
                                    }

                                    anchors.fill: parent
                                    preventStealing: true
                                    onWheel: (wheel) => {
                                        var current = tempSliderBlocks.parsedTemp;
                                        var change = wheel.angleDelta.y > 0 ? 250 : -250;
                                        var target = Math.max(2800, Math.min(current + change, 6500));
                                        root.sunsetState = String(target);
                                        root.pendingSunsetTemp = target;
                                    }
                                    onPressed: (mouse) => {
                                        updateTemp(mouse.x);
                                    }
                                    onPositionChanged: (mouse) => {
                                        updateTemp(mouse.x);
                                    }
                                }

                            }

                        }

                        Rectangle {
                            width: parent.width
                            height: 1
                            color: theme.c.accent
                            opacity: 0.15
                        }

                        // --- SECTION 4: TOGGLES (CAFFEINE & SLEEP) ---
                        Row {
                            width: parent.width
                            spacing: 20
                            anchors.horizontalCenter: parent.horizontalCenter

                            // Caffeine Toggle Button
                            Text {
                                id: caffeineToggle

                                text: "Caffeine: " + (root.caffeineActive ? "On" : "Off")
                                color: theme.c.accent
                                font.family: "FiraCode Nerd Font"
                                font.pixelSize: 9
                                font.bold: true
                                renderType: Text.NativeRendering

                                MouseArea {
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    onEntered: caffeineToggle.color = theme.c.accent
                                    onExited: caffeineToggle.color = theme.c.accent
                                    onClicked: {
                                        var nextState = !root.caffeineActive;
                                        root.caffeineActive = nextState;
                                        Quickshell.execDetached([root.homeDir + "/.config/rofi/scripts/caffeine.sh"]);
                                        // Refresh in the background to sync state
                                        root.triggerRefresh();
                                    }
                                }

                            }

                            // Sleep/Inhibit status
                            Text {
                                id: sleepToggle

                                text: "Sleep: " + (root.caffeineActive ? "Off" : "On")
                                color: theme.c.accent
                                font.family: "FiraCode Nerd Font"
                                font.pixelSize: 9
                                font.bold: true
                                opacity: 0.6
                                renderType: Text.NativeRendering
                            }

                        }

                    }

                }

            }

        }

    }

}
