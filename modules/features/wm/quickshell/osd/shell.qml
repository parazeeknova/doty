//@ pragma UseQApplication
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.SystemTray
import Quickshell.Wayland

Scope {
    id: root

    property string homeDir: Quickshell.env("HOME")
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

    function resetPomoShowTimer() {
        root.pomoShowAlways = true;
        pomoShowTimer.restart();
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

    function getIcon(msg) {
        var lower = msg.toLowerCase();
        // Volume
        if (lower.includes("volume")) {
            if (lower.includes("mute"))
                return "󰝟";

            return "󰕾";
        }
        // Mic
        if (lower.includes("mic")) {
            if (lower.includes("mute"))
                return "󰍭";

            return "󰍬";
        }
        // Brightness
        if (lower.includes("kbd brightness") || lower.includes("kbdbrightness"))
            return "󰌶";

        if (lower.includes("brightness"))
            return "󰃠";

        // Profiles / Performance modes
        if (lower.includes("profile:")) {
            if (lower.includes("performance"))
                return "󰓅";

            if (lower.includes("balanced"))
                return "󰾅";

            if (lower.includes("quiet") || lower.includes("power-saver") || lower.includes("power saver"))
                return "󰾆";

            return "󰓅";
        }
        // Battery capacity & alerts
        if (lower.includes("battery")) {
            if (lower.includes("low") || lower.includes("critical") || lower.includes("dying"))
                return "󰂃";

            if (lower.includes("charging"))
                return "󰂄";

            if (lower.includes("full"))
                return "󰁹";

            return "󰁹";
        }
        if (lower.includes("charging"))
            return "󰂄";

        // Caffeine
        if (lower.includes("caffeine")) {
            if (lower.includes("on"))
                return "󰛊";

            return "󰾪";
        }
        // Sunset
        if (lower.includes("sunset")) {
            if (lower.includes("off"))
                return "󰖔";

            return "󰖚";
        }
        // Caps Lock
        if (lower.includes("caps"))
            return "󰪛";

        // Recording & OCR
        if (msg.includes("Recording Started"))
            return "󰑋";

        if (msg.includes("Recording Saved") || msg.includes("Recording Stopped"))
            return "󰻃";

        if (msg.includes("Extracted") || msg.includes("OCR"))
            return "󰙎";

        // Glass
        if (msg.includes("Glass:"))
            return "󰖆";

        // Pomodoro
        if (lower.includes("pomodoro"))
            return "󰔛";

        return "";
    }

    function getIconColor(msg) {
        var lower = msg.toLowerCase();
        if (msg.includes("Recording Started"))
            return theme.error;

        if (msg.includes("Recording Saved") || msg.includes("Recording Stopped"))
            return theme.accent;

        if (msg.includes("Extracted") || msg.includes("OCR"))
            return theme.tertiary;

        if (msg.includes("Glass: On"))
            return theme.accent;

        if (msg.includes("Glass: Off"))
            return theme.error;

        // Caffeine
        if (lower.includes("caffeine on"))
            return theme.accent;

        if (lower.includes("caffeine off"))
            return theme.secondary;

        // Sunset
        if (lower.includes("sunset auto") || lower.includes("sunset off"))
            return theme.secondary;

        if (lower.includes("sunset"))
            return theme.tertiary;

        // Profile
        if (lower.includes("profile:")) {
            if (lower.includes("performance"))
                return theme.error;

            if (lower.includes("balanced"))
                return theme.accent;

            if (lower.includes("quiet") || lower.includes("power-saver") || lower.includes("power saver"))
                return theme.secondary;
        }
        // Caps
        if (lower.includes("caps on"))
            return theme.error;

        if (lower.includes("caps off"))
            return theme.secondary;

        // Mute states
        if (lower.includes("mute"))
            return theme.error;

        // Battery
        if (lower.includes("low battery") || lower.includes("critical battery") || lower.includes("battery dying"))
            return theme.error;

        if (lower.includes("charging") || lower.includes("battery full"))
            return theme.accent;

        if (lower.includes("battery"))
            return theme.tertiary;

        return theme.fg;
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

    Theme {
        id: theme
    }

    Timer {
        id: pomoShowTimer

        interval: 5000
        repeat: false
        onTriggered: {
            root.pomoShowAlways = false;
        }
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
                if (raw === "")
                    return;

                var parsed = JSON.parse(raw);
                root.pomoActive = parsed.active ?? false;
                root.pomoEndTime = parsed.endTime ?? 0;
                root.pomoDuration = parsed.duration ?? 1500;
                root.pomoPaused = parsed.paused ?? false;
                root.pomoPausedTimeLeft = parsed.pausedTimeLeft ?? 0;
                if (root.pomoActive) {
                    if (root.pomoPaused)
                        root.pomoTimeLeft = root.pomoPausedTimeLeft;
                    else
                        root.pomoTimeLeft = Math.max(0, Math.round((root.pomoEndTime - Date.now()) / 1000));
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

    Connections {
        function onRowsInserted() {
            root.updateTrayCount();
        }

        function onRowsRemoved() {
            root.updateTrayCount();
        }

        function onModelReset() {
            root.updateTrayCount();
        }

        target: SystemTray.items
        ignoreUnknownSignals: true
    }

    Process {
        id: checkAudioStatusProc

        command: [root.homeDir + "/.config/quickshell/volume_popup/get_audio_status"]
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

        path: "file://" + root.homeDir + "/.config/hypr/sunset.state"
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
                WlrLayershell.namespace: "osd"
                visible: root.visibleNow || exitAnim.running
                implicitWidth: (root.getPercentage(root.message) !== -1) ? 200 : (fallbackLabel.implicitWidth + (fallbackIcon.visible ? fallbackIcon.implicitWidth + 6 : 0) + 18)
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
                    color: theme.popupBgColor
                    border.width: 1
                    border.color: root.kind === "good" ? theme.accent : root.kind === "bad" ? theme.error : root.kind === "warn" ? theme.tertiary : theme.secondary
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
                                text: root.getIcon(root.message)
                                color: root.getIconColor(root.message)
                                font.family: "FiraCode Nerd Font"
                                font.pixelSize: 10
                                renderType: Text.NativeRendering
                                anchors.verticalCenter: parent.verticalCenter
                                visible: text !== ""
                            }

                            Text {
                                text: root.getPrefix(root.message)
                                color: theme.fg
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
                                        color: (index < Math.round(blockSlider.currentVal * blockSlider.totalBlocks)) ? theme.accent : theme.bg_light
                                    }
                                }
                            }

                            Text {
                                text: root.getPercentText(root.message)
                                color: theme.fg
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

                            Row {
                                spacing: 4
                                anchors.horizontalCenter: parent.horizontalCenter

                                Text {
                                    text: root.getIcon(root.message)
                                    color: root.getIconColor(root.message)
                                    font.family: "FiraCode Nerd Font"
                                    font.pixelSize: 10
                                    renderType: Text.NativeRendering
                                    anchors.verticalCenter: parent.verticalCenter
                                    visible: text !== ""
                                }

                                Text {
                                    text: root.getPrefix(root.message)
                                    color: theme.fg
                                    font.family: "FiraCode Nerd Font"
                                    font.pixelSize: 9
                                    renderType: Text.NativeRendering
                                    anchors.verticalCenter: parent.verticalCenter
                                }
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
                                            color: (index < Math.round(kbdBlockSlider.currentVal * kbdBlockSlider.totalBlocks)) ? theme.accent : theme.bg_light
                                        }
                                    }
                                }

                                Text {
                                    text: root.getPercentText(root.message)
                                    color: theme.fg
                                    font.family: "FiraCode Nerd Font"
                                    font.pixelSize: 9
                                    renderType: Text.NativeRendering
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                            }
                        }

                        Row {
                            spacing: 6
                            anchors.horizontalCenter: parent.horizontalCenter
                            visible: root.getPercentage(root.message) === -1

                            Text {
                                id: fallbackIcon

                                text: root.getIcon(root.message)
                                color: root.getIconColor(root.message)
                                font.family: "FiraCode Nerd Font"
                                font.pixelSize: 10
                                renderType: Text.NativeRendering
                                visible: text !== ""
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            Text {
                                id: fallbackLabel

                                text: root.message
                                color: theme.fg
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
                            color: theme.accent
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
                                color: theme.bg_light
                                radius: 0
                                border.width: 1
                                border.color: theme.accent
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
                                    color: theme.accent
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
                                        color: theme.accent
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
                                                color: index === root.currentMediaSourceIndex() ? theme.accent : theme.bg_light
                                                border.width: 1
                                                border.color: theme.accent
                                                opacity: index === root.currentMediaSourceIndex() ? 1 : 0.55
                                            }
                                        }
                                    }
                                }

                                Text {
                                    width: parent.width
                                    text: root.media ? (root.media.artist ? root.media.artist + " • " + root.media.player : root.media.player) : ""
                                    color: theme.accent
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
                            color: theme.accent
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
                                color: theme.accent
                                opacity: 0.6
                                font.family: "FiraCode Nerd Font"
                                font.pixelSize: 8
                                renderType: Text.NativeRendering
                            }

                            Text {
                                anchors.right: parent.right
                                text: root.caffeineActive ? "Caffeine: On" : "Sleep: On"
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
                width: (root.pomoShowAlways || root.pomoHovered) ? 45 : 8
                height: (root.pomoShowAlways || root.pomoHovered) ? 22 : 8

                anchors {
                    top: true
                    right: true
                }

                margins {
                    top: (root.pomoShowAlways || root.pomoHovered) ? 4 : 0
                    right: (root.pomoShowAlways || root.pomoHovered) ? 4 : 0
                }

                Rectangle {
                    id: pomoContent

                    anchors.fill: parent
                    color: (root.pomoShowAlways || root.pomoHovered) ? "#e61d2021" : "#01000000"
                    border.width: (root.pomoShowAlways || root.pomoHovered) ? 1 : 0
                    border.color: theme.accent
                    radius: 0
                    opacity: (root.pomoShowAlways || root.pomoHovered) ? 1 : 0.01

                    Row {
                        anchors.centerIn: parent
                        visible: (root.pomoShowAlways || root.pomoHovered)

                        Text {
                            text: root.formatPomoTime(root.pomoTimeLeft)
                            color: theme.accent
                            font.family: "FiraCode Nerd Font"
                            font.pixelSize: 8
                            font.bold: true
                            renderType: Text.NativeRendering
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    Behavior on opacity {
                        NumberAnimation {
                            duration: 150
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
