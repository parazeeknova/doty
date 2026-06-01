import QtQuick
import Quickshell
import Quickshell.Io

Scope {
    id: root

    readonly property string statePath: Qt.resolvedUrl("./state.json")
    property string message: ""
    property string kind: "info"
    property bool visibleNow: false
    property var media: null
    property string sunsetState: "Off"
    property bool caffeineActive: false
    property int lastKbdBrightness: -1
    property int lastBatteryCapacity: -1
    property bool lowBatteryAlerted: false
    property string lastBatteryStatus: ""
    property string lastPlatformProfile: ""

    function getPercentage(msg) {
        var match = msg.match(/(\d+)%/);
        return match ? parseInt(match[1]) : -1;
    }

    function getPrefix(msg) {
        var match = msg.match(/^(.*?)\s+\d+%/);
        return match ? match[1] : msg;
    }

    function getPercentText(msg) {
        var match = msg.match(/(\d+%)/);
        return match ? match[1] : "";
    }

    function defaultState() {
        return {
            "visible": false,
            "text": "",
            "kind": "info",
            "timeout_ms": 1200
        };
    }

    function readState() {
        try {
            var raw = stateFile.text();
            if (!raw || raw.trim() === "")
                return defaultState();

            var parsed = JSON.parse(raw);
            return {
                "visible": parsed.visible !== false,
                "text": String(parsed.text ?? ""),
                "kind": String(parsed.kind ?? "info"),
                "timeout_ms": parsed.timeout_ms ?? 1200
            };
        } catch (error) {
            return defaultState();
        }
    }

    function refreshState() {
        var state = readState();
        message = state.text;
        kind = state.kind;
        visibleNow = state.visible && state.text.length > 0;
        if (visibleNow) {
            hideTimer.interval = state.timeout_ms || 1200;
            hideTimer.restart();
            if (message.includes("volume")) {
                checkAudioStatusProc.running = false;
                checkAudioStatusProc.running = true;
            } else {
                root.media = null;
            }
        } else {
            hideTimer.stop();
            root.media = null;
        }
    }

    function showOSD(text, kind, timeout_ms) {
        message = text;
        root.kind = kind;
        visibleNow = true;
        hideTimer.interval = timeout_ms || 1200;
        hideTimer.restart();
        if (text.includes("volume")) {
            checkAudioStatusProc.running = false;
            checkAudioStatusProc.running = true;
        } else {
            root.media = null;
        }
    }

    Component.onCompleted: root.refreshState()

    Process {
        id: checkAudioStatusProc

        command: ["/home/parazeeknova/doty/.config/quickshell/volume_popup/get_audio_status"]
        running: false

        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var data = JSON.parse(this.text);
                    root.media = data.media || null;
                } catch (e) {
                    root.media = null;
                }
            }
        }

    }

    FileView {
        id: sunsetStateFile

        path: "file:///home/parazeeknova/.config/hypr/sunset.state"
        watchChanges: true
        onLoaded: {
            var txt = sunsetStateFile.text().trim();
            sunsetState = txt !== "" ? txt : "Off";
        }
        onFileChanged: reload()
    }

    FileView {
        id: caffeineFile

        path: "file:///tmp/caffeine-mode"
        watchChanges: true
        onLoaded: {
            var val = caffeineFile.text().trim();
            caffeineActive = val !== "";
        }
        onFileChanged: reload()
    }

    Timer {
        id: hideTimer

        interval: 1200
        repeat: false
        onTriggered: {
            root.visibleNow = false;
        }
    }

    FileView {
        id: stateFile

        path: root.statePath
        blockLoading: true
        watchChanges: true
        onFileChanged: reload()
        onLoaded: root.refreshState()
    }

    Timer {
        id: kbdPollTimer

        interval: 350
        repeat: true
        running: true
        onTriggered: {
            kbdBacklightFile.reload();
        }
    }

    FileView {
        id: kbdBacklightFile

        path: "file:///sys/class/leds/asus::kbd_backlight/brightness"
        onLoaded: {
            var val = kbdBacklightFile.text().trim();
            var intVal = parseInt(val);
            if (!isNaN(intVal)) {
                if (lastKbdBrightness !== -1 && lastKbdBrightness !== intVal) {
                    var pct = Math.round((intVal / 3) * 100);
                    root.showOSD("kbd brightness " + pct + "%", "info", 1200);
                }
                lastKbdBrightness = intVal;
            }
        }
    }

    // System Monitor Poller (Battery & Power Profiles)
    Timer {
        id: systemMonitorTimer

        interval: 1000
        repeat: true
        running: true
        onTriggered: {
            batteryStatusFile.reload();
            batteryCapacityFile.reload();
            platformProfileFile.reload();
        }
    }

    FileView {
        id: batteryCapacityFile

        path: "file:///sys/class/power_supply/BAT1/capacity"
        onLoaded: {
            var val = parseInt(batteryCapacityFile.text().trim());
            if (!isNaN(val)) {
                // Alert once when crossing down to 30% while discharging
                if (val <= 30 && lastBatteryCapacity > 30 && root.lastBatteryStatus === "Discharging") {
                    root.showOSD("low battery " + val + "%", "bad", 2500);
                    lowBatteryAlerted = true;
                }
                // Also alert at 15% and 5% critical
                if (val <= 15 && lastBatteryCapacity > 15 && root.lastBatteryStatus === "Discharging")
                    root.showOSD("critical battery " + val + "%", "bad", 3000);

                if (val <= 5 && lastBatteryCapacity > 5 && root.lastBatteryStatus === "Discharging")
                    root.showOSD("battery dying " + val + "%", "bad", 4000);

                // Reset alert flag when charging
                if (root.lastBatteryStatus === "Charging")
                    lowBatteryAlerted = false;

                lastBatteryCapacity = val;
            }
        }
    }

    FileView {
        id: batteryStatusFile

        path: "file:///sys/class/power_supply/BAT1/status"
        onLoaded: {
            var val = batteryStatusFile.text().trim();
            if (val !== "") {
                if (lastBatteryStatus !== "" && lastBatteryStatus !== val) {
                    if (val === "Charging")
                        root.showOSD("charging", "good", 1200);
                    else if (val === "Discharging")
                        root.showOSD("battery", "warn", 1200);
                    else if (val === "Full")
                        root.showOSD("battery full", "good", 1500);
                }
                lastBatteryStatus = val;
            }
        }
    }

    FileView {
        id: platformProfileFile

        path: "file:///sys/firmware/acpi/platform_profile"
        onLoaded: {
            var val = platformProfileFile.text().trim();
            if (val !== "") {
                if (lastPlatformProfile !== "" && lastPlatformProfile !== val) {
                    var displayProfile = val.toLowerCase();
                    root.showOSD("profile: " + displayProfile, "good", 1500);
                }
                lastPlatformProfile = val;
            }
        }
    }

    Variants {
        model: Quickshell.screens

        delegate: Component {
            PanelWindow {
                id: win

                required property var modelData
                property bool isShown: root.visibleNow
                property real animTopMargin: -50
                property real animOpacity: 0

                onIsShownChanged: {
                    if (isShown) {
                        exitAnim.stop();
                        introAnim.start();
                    } else {
                        introAnim.stop();
                        exitAnim.start();
                    }
                }
                screen: modelData
                color: "transparent"
                exclusionMode: PanelWindow.ExclusionMode.Ignore
                visible: root.visibleNow || exitAnim.running
                implicitWidth: (root.getPercentage(root.message) !== -1) ? 180 : (fallbackLabel.implicitWidth + 18)
                implicitHeight: mainLayout.implicitHeight + 12
                Component.onCompleted: {
                    if (root.visibleNow) {
                        animTopMargin = 5;
                        animOpacity = 1;
                    }
                }

                anchors {
                    top: true
                    left: true
                }

                margins {
                    top: win.animTopMargin
                    left: 30
                }

                // Slide-in + fade-in
                ParallelAnimation {
                    id: introAnim

                    NumberAnimation {
                        target: win
                        property: "animTopMargin"
                        from: -50
                        to: 5
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

                    NumberAnimation {
                        target: win
                        property: "animTopMargin"
                        from: 5
                        to: -50
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

                Rectangle {
                    anchors.fill: parent
                    opacity: win.animOpacity
                    color: "#801d2021"
                    border.width: 1
                    border.color: root.kind === "good" ? "#a9b665" : root.kind === "bad" ? "#ea6962" : root.kind === "warn" ? "#e78a4e" : "#7c6f64"
                    radius: 0
                    antialiasing: false

                    Column {
                        id: mainLayout

                        anchors.centerIn: parent
                        spacing: 4
                        width: parent.width - 18

                        // Single line layout: prefix <bar> percentage (for volume/brightness)
                        Row {
                            id: osdStatusRow

                            spacing: 6
                            anchors.horizontalCenter: parent.horizontalCenter
                            visible: root.getPercentage(root.message) !== -1 && !root.message.includes("kbd")

                            Text {
                                text: root.getPrefix(root.message)
                                color: "#d4be98"
                                font.family: "FiraCode Nerd Font"
                                font.pixelSize: 9
                                renderType: Text.NativeRendering
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            // Block Slider
                            Row {
                                id: blockSlider

                                property int totalBlocks: 15
                                property double currentVal: root.getPercentage(root.message) / 100

                                spacing: 1
                                height: 4
                                anchors.verticalCenter: parent.verticalCenter

                                Repeater {
                                    model: blockSlider.totalBlocks

                                    delegate: Rectangle {
                                        height: parent.height
                                        width: 5
                                        color: (index < Math.round(blockSlider.currentVal * blockSlider.totalBlocks)) ? "#d5c4a1" : "#3c3836"
                                    }

                                }

                            }

                            Text {
                                text: root.getPercentText(root.message)
                                color: "#d4be98"
                                font.family: "FiraCode Nerd Font"
                                font.pixelSize: 9
                                renderType: Text.NativeRendering
                                anchors.verticalCenter: parent.verticalCenter
                            }

                        }

                        // Two-line layout for keyboard backlight: label on top, bar + pct below
                        Column {
                            id: kbdOsdLayout

                            spacing: 3
                            anchors.horizontalCenter: parent.horizontalCenter
                            visible: root.getPercentage(root.message) !== -1 && root.message.includes("kbd")

                            Text {
                                text: root.getPrefix(root.message)
                                color: "#d4be98"
                                font.family: "FiraCode Nerd Font"
                                font.pixelSize: 9
                                renderType: Text.NativeRendering
                                anchors.horizontalCenter: parent.horizontalCenter
                            }

                            Row {
                                spacing: 6
                                anchors.horizontalCenter: parent.horizontalCenter

                                Row {
                                    id: kbdBlockSlider

                                    property int totalBlocks: 15
                                    property double currentVal: root.getPercentage(root.message) / 100

                                    spacing: 1
                                    height: 4
                                    anchors.verticalCenter: parent.verticalCenter

                                    Repeater {
                                        model: kbdBlockSlider.totalBlocks

                                        delegate: Rectangle {
                                            height: parent.height
                                            width: 5
                                            color: (index < Math.round(kbdBlockSlider.currentVal * kbdBlockSlider.totalBlocks)) ? "#d5c4a1" : "#3c3836"
                                        }

                                    }

                                }

                                Text {
                                    text: root.getPercentText(root.message)
                                    color: "#d4be98"
                                    font.family: "FiraCode Nerd Font"
                                    font.pixelSize: 9
                                    renderType: Text.NativeRendering
                                    anchors.verticalCenter: parent.verticalCenter
                                }

                            }

                        }

                        // Fallback label for text-only messages
                        Text {
                            id: fallbackLabel

                            anchors.horizontalCenter: parent.horizontalCenter
                            text: root.message
                            color: "#d4be98"
                            font.family: "FiraCode Nerd Font"
                            font.pixelSize: 9
                            renderType: Text.NativeRendering
                            visible: root.getPercentage(root.message) === -1
                        }

                        // Separator
                        Rectangle {
                            width: parent.width
                            height: 1
                            color: "#d5c4a1"
                            opacity: 0.15
                            visible: root.media !== null && root.message.includes("volume")
                        }

                        // Media Player Widget inside OSD (below volume slider)
                        Row {
                            width: parent.width
                            spacing: 6
                            visible: root.media !== null && root.message.includes("volume")
                            anchors.horizontalCenter: parent.horizontalCenter

                            // Cover Art (small, to fit two lines height)
                            Rectangle {
                                width: 18
                                height: 18
                                color: "#3c3836"
                                radius: 0
                                border.width: 1
                                border.color: "#d5c4a1"
                                anchors.verticalCenter: parent.verticalCenter

                                Image {
                                    id: artImage

                                    anchors.fill: parent
                                    source: (root.media && root.media.art_url) ? root.media.art_url : ""
                                    fillMode: Image.PreserveAspectCrop
                                    visible: source.toString() !== ""
                                    asynchronous: true
                                }

                                Text {
                                    anchors.centerIn: parent
                                    text: "󰎆"
                                    color: "#d5c4a1"
                                    font.family: "FiraCode Nerd Font"
                                    font.pixelSize: 8
                                    visible: !artImage.visible
                                    renderType: Text.NativeRendering
                                }

                            }

                            // Media Info
                            Column {
                                width: parent.width - 24
                                spacing: 1
                                anchors.verticalCenter: parent.verticalCenter

                                Text {
                                    width: parent.width
                                    text: root.media ? root.media.title : ""
                                    color: "#ebdbb2"
                                    font.family: "FiraCode Nerd Font"
                                    font.pixelSize: 8
                                    font.bold: true
                                    elide: Text.ElideRight
                                    renderType: Text.NativeRendering
                                }

                                Text {
                                    width: parent.width
                                    text: root.media ? (root.media.artist ? root.media.artist + " • " + root.media.player : root.media.player) : ""
                                    color: "#d5c4a1"
                                    opacity: 0.6
                                    font.family: "FiraCode Nerd Font"
                                    font.pixelSize: 7
                                    elide: Text.ElideRight
                                    renderType: Text.NativeRendering
                                }

                            }

                        }

                        // Separator for sunset
                        Rectangle {
                            width: parent.width
                            height: 1
                            color: "#d5c4a1"
                            opacity: 0.15
                            visible: root.message.includes("brightness") && !root.message.includes("kbd")
                        }

                        // Sunset & Caffeine/Sleep status row below brightness slider
                        Item {
                            width: parent.width
                            height: 10
                            visible: root.message.includes("brightness") && !root.message.includes("kbd")

                            Text {
                                anchors.left: parent.left
                                text: "Sunset: " + root.sunsetState
                                color: "#d5c4a1"
                                opacity: 0.6
                                font.family: "FiraCode Nerd Font"
                                font.pixelSize: 8
                                renderType: Text.NativeRendering
                            }

                            Text {
                                anchors.right: parent.right
                                text: root.caffeineActive ? "Caffeine: On" : "Sleep: On"
                                color: "#d5c4a1"
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

    }

}
