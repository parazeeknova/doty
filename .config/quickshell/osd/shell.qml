//@ pragma UseQApplication
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.SystemTray

Scope {
    id: root

    readonly property string statePath: Qt.resolvedUrl("./state.json")
    property string message: ""
    property string kind: "info"
    property bool visibleNow: false
    property var media: null
    property var mediaSources: []
    property string currentMediaSource: ""
    property string sunsetState: "Off"
    property bool caffeineActive: false
    property int lastKbdBrightness: -1
    property int lastBatteryCapacity: -1
    property bool lowBatteryAlerted: false
    property string lastBatteryStatus: ""
    property string lastPlatformProfile: ""
    property int trayItemCount: 0

    // Pomodoro Timer State
    property bool pomoActive: false
    property double pomoEndTime: 0
    property int pomoDuration: 1500
    property bool pomoPaused: false
    property int pomoPausedTimeLeft: 0
    property int pomoTimeLeft: 0
    property bool pomoHovered: false
    property bool pomoShowAlways: false

    function formatPomoTime(secs) {
        var m = Math.floor(secs / 60);
        var s = secs % 60;
        return (m < 10 ? "0" + m : m) + ":" + (s < 10 ? "0" + s : s);
    }

    Timer {
        id: pomoShowTimer
        interval: 5000
        repeat: false
        onTriggered: {
            root.pomoShowAlways = false;
        }
    }

    function resetPomoShowTimer() {
        root.pomoShowAlways = true;
        pomoShowTimer.restart();
    }

    Timer {
        id: pomoCountdownTimer
        interval: 1000
        repeat: true
        running: root.pomoActive && !root.pomoPaused
        onTriggered: {
            var diff = Math.max(0, Math.round((root.pomoEndTime - Date.now()) / 1000));
            root.pomoTimeLeft = diff;
            if (diff <= 0) {
                root.pomoActive = false;
                root.pomoTimeLeft = 0;
                root.savePomoState();
                root.showOSD("Pomodoro Finished!", "good", 5000);
                Quickshell.execDetached(["notify-send", "Pomodoro", "Time's up! Take a break."]);
            }
        }
    }

    FileView {
        id: pomoStateFile

        path: "file:///tmp/quickshell_pomodoro.json"
        watchChanges: true
        onLoaded: {
            try {
                var raw = pomoStateFile.text().trim();
                if (raw === "") return;
                var parsed = JSON.parse(raw);
                root.pomoActive = parsed.active ?? false;
                root.pomoEndTime = parsed.endTime ?? 0;
                root.pomoDuration = parsed.duration ?? 1500;
                root.pomoPaused = parsed.paused ?? false;
                root.pomoPausedTimeLeft = parsed.pausedTimeLeft ?? 0;

                if (root.pomoActive) {
                    if (root.pomoPaused) {
                        root.pomoTimeLeft = root.pomoPausedTimeLeft;
                    } else {
                        root.pomoTimeLeft = Math.max(0, Math.round((root.pomoEndTime - Date.now()) / 1000));
                    }
                    root.resetPomoShowTimer();
                } else {
                    root.pomoTimeLeft = 0;
                }
            } catch (e) {
                console.log("Failed to parse pomodoro state: " + e);
            }
        }
        onFileChanged: reload()
    }

    Process {
        id: savePomoProc
        running: false
    }

    function savePomoState() {
        var state = {
            "active": root.pomoActive,
            "endTime": root.pomoEndTime,
            "duration": root.pomoDuration,
            "paused": root.pomoPaused,
            "pausedTimeLeft": root.pomoPausedTimeLeft
        };
        var stateStr = JSON.stringify(state);
        savePomoProc.command = ["sh", "-c", "echo '" + stateStr + "' > /tmp/quickshell_pomodoro.json"];
        savePomoProc.running = false;
        savePomoProc.running = true;
    }


    function updateTrayCount() {
        if (SystemTray.items !== undefined && SystemTray.items !== null) {
            try {
                trayItemCount = SystemTray.items.rowCount();
            } catch (e) {
                trayItemCount = 0;
            }
        } else {
            trayItemCount = 0;
        }
    }

    Connections {
        target: SystemTray.items
        ignoreUnknownSignals: true
        function onRowsInserted() {
            root.updateTrayCount();
        }
        function onRowsRemoved() {
            root.updateTrayCount();
        }
        function onModelReset() {
            root.updateTrayCount();
        }
    }

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

    function currentMediaSourceIndex() {
        for (var i = 0; i < root.mediaSources.length; i++) {
            if (root.mediaSources[i].name === root.currentMediaSource)
                return i;
        }
        return -1;
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
                root.mediaSources = [];
                root.currentMediaSource = "";
            }
        } else {
            hideTimer.stop();
            root.media = null;
            root.mediaSources = [];
            root.currentMediaSource = "";
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
            root.mediaSources = [];
            root.currentMediaSource = "";
        }
    }

    Component.onCompleted: {
        root.refreshState();
        SystemTray.isService = true;
        root.updateTrayCount();
    }
    onTrayItemCountChanged: {
        waybarSignalProc.running = false;
        waybarSignalProc.running = true;
    }

    Process {
        id: checkAudioStatusProc

        command: ["/home/parazeeknova/doty/.config/quickshell/volume_popup/get_audio_status"]
        running: false

        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var data = JSON.parse(this.text);
                    root.media = data.media || null;
                    root.mediaSources = data.media_sources || [];
                    root.currentMediaSource = data.current_media_source || "";
                } catch (e) {
                    root.media = null;
                    root.mediaSources = [];
                    root.currentMediaSource = "";
                }
            }
        }

    }

    // Watch the current-player file. When the volume popup changes the active
    // media source, the OSD re-fetches the audio status so the displayed
    // track + indicator reflect the new player even if no volume event fires.
    FileView {
        id: currentMediaSourceFile

        path: "file:///tmp/quickshell_current_media_player"
        blockLoading: true
        watchChanges: true
        onFileChanged: {
            if (root.visibleNow && root.message.includes("volume")) {
                checkAudioStatusProc.running = false;
                checkAudioStatusProc.running = true;
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
                        Row {
                            spacing: 6
                            anchors.horizontalCenter: parent.horizontalCenter
                            visible: root.getPercentage(root.message) === -1

                            Text {
                                text: {
                                    if (root.message.includes("Recording Started")) return "󰑋";
                                    if (root.message.includes("Recording Saved") || root.message.includes("Recording Stopped")) return "󰻃";
                                    if (root.message.includes("Extracted") || root.message.includes("OCR")) return "󰙎";
                                    return "";
                                }
                                color: {
                                    if (root.message.includes("Recording Started")) return "#ea6962";
                                    if (root.message.includes("Recording Saved") || root.message.includes("Recording Stopped")) return "#a9b665";
                                    if (root.message.includes("Extracted") || root.message.includes("OCR")) return "#e78a4e";
                                    return "#d4be98";
                                }
                                font.family: "FiraCode Nerd Font"
                                font.pixelSize: 10
                                renderType: Text.NativeRendering
                                visible: text !== ""
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            Text {
                                text: root.message
                                color: "#d4be98"
                                font.family: "FiraCode Nerd Font"
                                font.pixelSize: 9
                                renderType: Text.NativeRendering
                                anchors.verticalCenter: parent.verticalCenter
                            }
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

                                // Title row with source indicator on the right
                                Row {
                                    width: parent.width
                                    spacing: 4

                                    Text {
                                        width: parent.width - osdSourceIndicator.implicitWidth - 4
                                        text: root.media ? root.media.title : ""
                                        color: "#ebdbb2"
                                        font.family: "FiraCode Nerd Font"
                                        font.pixelSize: 8
                                        font.bold: true
                                        elide: Text.ElideRight
                                        renderType: Text.NativeRendering
                                        anchors.verticalCenter: parent.verticalCenter
                                    }

                                    Row {
                                        id: osdSourceIndicator

                                        spacing: 2
                                        anchors.verticalCenter: parent.verticalCenter
                                        visible: root.mediaSources.length > 1

                                        Repeater {
                                            model: root.mediaSources

                                            delegate: Rectangle {
                                                width: 3
                                                height: 3
                                                color: index === root.currentMediaSourceIndex() ? "#d5c4a1" : "#3c3836"
                                                border.width: 1
                                                border.color: "#d5c4a1"
                                                opacity: index === root.currentMediaSourceIndex() ? 1.0 : 0.55
                                            }

                                        }

                                    }

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

    Variants {
        model: Quickshell.screens

        delegate: Component {
            PanelWindow {
                id: pomoWin

                required property var modelData
                screen: modelData
                color: "transparent"
                exclusionMode: PanelWindow.ExclusionMode.Ignore
                visible: root.pomoActive

                anchors {
                    top: true
                    right: true
                }

                width: (root.pomoShowAlways || root.pomoHovered) ? 45 : 8
                height: (root.pomoShowAlways || root.pomoHovered) ? 22 : 8

                margins {
                    top: (root.pomoShowAlways || root.pomoHovered) ? 4 : 0
                    right: (root.pomoShowAlways || root.pomoHovered) ? 4 : 0
                }

                Rectangle {
                    id: pomoContent
                    anchors.fill: parent
                    color: (root.pomoShowAlways || root.pomoHovered) ? "#e61d2021" : "#01000000"
                    border.width: (root.pomoShowAlways || root.pomoHovered) ? 1 : 0
                    border.color: "#d5c4a1"
                    radius: 0

                    opacity: (root.pomoShowAlways || root.pomoHovered) ? 1.0 : 0.01
                    Behavior on opacity {
                        NumberAnimation { duration: 150 }
                    }

                    Row {
                        anchors.centerIn: parent
                        visible: (root.pomoShowAlways || root.pomoHovered)

                        Text {
                            text: root.formatPomoTime(root.pomoTimeLeft)
                            color: "#ebdbb2"
                            font.family: "FiraCode Nerd Font"
                            font.pixelSize: 8
                            font.bold: true
                            renderType: Text.NativeRendering
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    onEntered: {
                        root.pomoHovered = true;
                        root.resetPomoShowTimer();
                    }
                    onExited: {
                        root.pomoHovered = false;
                        root.resetPomoShowTimer();
                    }
                }
            }
        }
    }


    Process {
        id: waybarSignalProc

        command: ["pkill", "-RTMIN+5", "waybar"]
        running: false
    }

}
