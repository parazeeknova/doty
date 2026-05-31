import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io

Scope {
    id: root

    // Audio state properties
    property var defaultSink: null
    property var defaultSource: null
    property var sinks: []
    property var sources: []
    property var apps: []
    property var diagnostics: {
        "pipewire_version": "Running",
        "sample_rate": "48kHz",
        "output_desc": "Default"
    }
    property bool devicesDropdownOpen: false
    property var media: null
    // Pending volume changes for throttling
    property int pendingOutVol: -1
    property int pendingInVol: -1
    property var pendingAppVols: ({
    })

    function formatTime(secs) {
        if (isNaN(secs) || secs < 0)
            return "0:00";

        var m = Math.floor(secs / 60);
        var s = Math.floor(secs % 60);
        return m + ":" + (s < 10 ? "0" : "") + s;
    }

    Component.onCompleted: {
        checkStatusProc.running = true;
    }

    // Timer to apply volume updates at most once every 50ms (prevents process spawning bottleneck)
    Timer {
        id: volumeApplyTimer

        interval: 50
        repeat: true
        running: true
        onTriggered: {
            if (pendingOutVol !== -1 && root.defaultSink) {
                Quickshell.execDetached(["pactl", "set-sink-volume", String(root.defaultSink.index), pendingOutVol + "%"]);
                // Trigger OSD
                Quickshell.execDetached(["/home/parazeeknova/doty/.config/quickshell/osd/bin/osdctl", "show", "volume " + pendingOutVol + "%", "info", "1200"]);
                pendingOutVol = -1;
            }
            if (pendingInVol !== -1 && root.defaultSource) {
                Quickshell.execDetached(["pactl", "set-source-volume", String(root.defaultSource.index), pendingInVol + "%"]);
                // Trigger OSD
                Quickshell.execDetached(["/home/parazeeknova/doty/.config/quickshell/osd/bin/osdctl", "show", "mic " + pendingInVol + "%", "info", "1200"]);
                pendingInVol = -1;
            }
            var appKeys = Object.keys(pendingAppVols);
            if (appKeys.length > 0) {
                for (var i = 0; i < appKeys.length; i++) {
                    var index = appKeys[i];
                    var pct = pendingAppVols[index];
                    Quickshell.execDetached(["pactl", "set-sink-input-volume", String(index), pct + "%"]);
                }
                pendingAppVols = {
                };
            }
        }
    }

    // Process to run the Rust helper
    Process {
        id: checkStatusProc

        command: ["/home/parazeeknova/doty/.config/quickshell/volume_popup/get_audio_status"]
        running: false

        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var data = JSON.parse(this.text);
                    root.defaultSink = data.default_sink;
                    root.defaultSource = data.default_source;
                    root.sinks = data.sinks || [];
                    root.sources = data.sources || [];
                    root.apps = data.apps || [];
                    root.diagnostics = data.diagnostics || {
                    };
                    root.media = data.media || null;
                } catch (e) {
                    console.log("Failed to parse: " + e);
                }
            }
        }

    }

    // Timer to wait for D-Bus status updates after player actions
    Timer {
        id: mediaRefreshTimer

        interval: 250
        repeat: false
        running: false
        onTriggered: {
            checkStatusProc.running = false;
            checkStatusProc.running = true;
        }
    }

    // Timer to smoothly advance media position locally while playing
    Timer {
        id: mediaPositionTimer

        interval: 500
        repeat: true
        running: root.media && root.media.status === "Playing"
        onTriggered: {
            if (root.media) {
                var newPos = root.media.position + 0.5;
                if (root.media.length > 0 && newPos > root.media.length)
                    newPos = root.media.length;

                var m = {
                    "player": root.media.player,
                    "title": root.media.title,
                    "artist": root.media.artist,
                    "art_url": root.media.art_url,
                    "status": root.media.status,
                    "position": newPos,
                    "length": root.media.length
                };
                root.media = m;
            }
        }
    }

    // Process to listen for pactl events and update status in real-time
    Process {
        id: pactlSubscribe

        command: ["pactl", "subscribe"]
        running: true

        stdout: SplitParser {
            onRead: (data) => {
                // Trigger status check on events (sink, source, sink-input changes)
                if (pendingOutVol === -1 && pendingInVol === -1 && Object.keys(pendingAppVols).length === 0) {
                    if (!checkStatusProc.running)
                        checkStatusProc.running = true;

                }
            }
        }

    }

    // Timer to poll audio status every 2 seconds as a fallback
    Timer {
        id: refreshTimer

        interval: 2000
        repeat: true
        running: true
        triggeredOnStart: true
        onTriggered: {
            if (pendingOutVol === -1 && pendingInVol === -1 && Object.keys(pendingAppVols).length === 0) {
                if (!checkStatusProc.running)
                    checkStatusProc.running = true;

            }
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
                // Enable keyboard focus for key events (Esc key)
                focusable: true
                // Adjust dimensions dynamically based on layout contents
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

                // Use HyprlandFocusGrab to automatically close the widget when clicking outside
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
                    // Request keyboard focus and listen for Escape key
                    focus: true
                    Keys.onPressed: (event) => {
                        if (event.key === Qt.Key_Escape)
                            Qt.quit();

                    }
                    Component.onCompleted: {
                        forceActiveFocus();
                    }

                    // Main Column Layout
                    Column {
                        id: mainLayout

                        anchors.top: parent.top
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.margins: 10
                        spacing: 8

                        // --- SECTION 0: MEDIA PLAYER WIDGET ---
                        Column {
                            width: parent.width
                            spacing: 6
                            visible: root.media !== null

                            Row {
                                width: parent.width
                                spacing: 8

                                // Cover Art Image or Fallback Box
                                Rectangle {
                                    width: 48
                                    height: 48
                                    color: "#3c3836"
                                    radius: 0
                                    border.width: 1
                                    border.color: "#d5c4a1"

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
                                        font.pixelSize: 18
                                        visible: !artImage.visible
                                        renderType: Text.NativeRendering
                                    }

                                }

                                // Media Info and Controls
                                Column {
                                    width: parent.width - 56 // 48 width + 8 spacing
                                    spacing: 2
                                    anchors.verticalCenter: parent.verticalCenter

                                    Text {
                                        width: parent.width
                                        text: root.media ? root.media.title : ""
                                        color: "#ebdbb2"
                                        font.family: "FiraCode Nerd Font"
                                        font.pixelSize: 9
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
                                        font.pixelSize: 8
                                        elide: Text.ElideRight
                                        renderType: Text.NativeRendering
                                    }

                                    // Media Controls Row
                                    Row {
                                        spacing: 12
                                        anchors.topMargin: 2

                                        Text {
                                            id: prevBtn

                                            text: "prev"
                                            color: "#d5c4a1"
                                            font.family: "FiraCode Nerd Font"
                                            font.pixelSize: 9
                                            renderType: Text.NativeRendering

                                            MouseArea {
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                onEntered: prevBtn.color = "#ebdbb2"
                                                onExited: prevBtn.color = "#d5c4a1"
                                                onClicked: {
                                                    Quickshell.execDetached(["playerctl", "--player=" + root.media.player, "previous"]);
                                                    mediaRefreshTimer.running = true;
                                                }
                                            }

                                        }

                                        Text {
                                            id: playBtn

                                            text: (root.media && root.media.status === "Playing") ? "pause" : "play"
                                            color: "#d5c4a1"
                                            font.family: "FiraCode Nerd Font"
                                            font.pixelSize: 9
                                            renderType: Text.NativeRendering

                                            MouseArea {
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                onEntered: playBtn.color = "#ebdbb2"
                                                onExited: playBtn.color = "#d5c4a1"
                                                onClicked: {
                                                    // Instant toggle visual feedback by creating a new object reference
                                                    if (root.media) {
                                                        var m = {
                                                            "player": root.media.player,
                                                            "title": root.media.title,
                                                            "artist": root.media.artist,
                                                            "art_url": root.media.art_url,
                                                            "status": (root.media.status === "Playing") ? "Paused" : "Playing",
                                                            "position": root.media.position,
                                                            "length": root.media.length
                                                        };
                                                        root.media = m;
                                                    }
                                                    Quickshell.execDetached(["playerctl", "--player=" + root.media.player, "play-pause"]);
                                                    mediaRefreshTimer.running = true;
                                                }
                                            }

                                        }

                                        Text {
                                            id: nextBtn

                                            text: "next"
                                            color: "#d5c4a1"
                                            font.family: "FiraCode Nerd Font"
                                            font.pixelSize: 9
                                            renderType: Text.NativeRendering

                                            MouseArea {
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                onEntered: nextBtn.color = "#ebdbb2"
                                                onExited: nextBtn.color = "#d5c4a1"
                                                onClicked: {
                                                    Quickshell.execDetached(["playerctl", "--player=" + root.media.player, "next"]);
                                                    mediaRefreshTimer.running = true;
                                                }
                                            }

                                        }

                                    }

                                    // Duration Slider Row
                                    Row {
                                        width: parent.width
                                        spacing: 6
                                        anchors.topMargin: 2
                                        visible: root.media !== null && root.media.length > 0

                                        Text {
                                            id: posText

                                            text: root.formatTime(root.media ? root.media.position : 0)
                                            color: "#d5c4a1"
                                            font.family: "FiraCode Nerd Font"
                                            font.pixelSize: 8
                                            renderType: Text.NativeRendering
                                        }

                                        // Progress bar slider
                                        Rectangle {
                                            id: progressSlider

                                            width: parent.width - posText.implicitWidth - lenText.implicitWidth - 12
                                            height: 4
                                            color: "#3c3836"
                                            anchors.verticalCenter: parent.verticalCenter

                                            Rectangle {
                                                height: parent.height
                                                width: (root.media && root.media.length > 0) ? (parent.width * Math.min(1, root.media.position / root.media.length)) : 0
                                                color: "#d5c4a1"
                                            }

                                            MouseArea {
                                                anchors.fill: parent
                                                enabled: root.media && root.media.length > 0
                                                onClicked: (mouse) => {
                                                    var pct = mouse.x / width;
                                                    var targetSecs = pct * root.media.length;
                                                    // Update local UI immediately
                                                    if (root.media) {
                                                        var m = {
                                                            "player": root.media.player,
                                                            "title": root.media.title,
                                                            "artist": root.media.artist,
                                                            "art_url": root.media.art_url,
                                                            "status": root.media.status,
                                                            "position": targetSecs,
                                                            "length": root.media.length
                                                        };
                                                        root.media = m;
                                                    }
                                                    Quickshell.execDetached(["playerctl", "--player=" + root.media.player, "position", String(Math.round(targetSecs))]);
                                                    mediaRefreshTimer.running = true;
                                                }
                                            }

                                        }

                                        Text {
                                            id: lenText

                                            text: (root.media && root.media.length > 0) ? root.formatTime(root.media.length) : "--:--"
                                            color: "#d5c4a1"
                                            font.family: "FiraCode Nerd Font"
                                            font.pixelSize: 8
                                            renderType: Text.NativeRendering
                                        }

                                    }

                                }

                            }

                            // Separator below media widget
                            Rectangle {
                                width: parent.width
                                height: 1
                                color: "#d5c4a1"
                                opacity: 0.25
                            }

                        }

                        // --- SECTION 1: MASTER OUTPUT ---
                        Column {
                            width: parent.width
                            spacing: 3

                            Item {
                                width: parent.width
                                height: 14

                                Text {
                                    anchors.left: parent.left
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: (root.defaultSink && root.defaultSink.is_bluetooth ? "󰋋" : "󰕾") + " Output: " + (root.defaultSink ? (root.defaultSink.muted ? "Muted" : root.defaultSink.volume + "%") : "0%")
                                    color: "#d5c4a1"
                                    font.family: "FiraCode Nerd Font"
                                    font.pixelSize: 9
                                    font.bold: true
                                    renderType: Text.NativeRendering
                                }

                                Text {
                                    id: muteText

                                    anchors.right: parent.right
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: root.defaultSink && root.defaultSink.muted ? "Unmute" : "Mute"
                                    color: "#d5c4a1"
                                    font.family: "FiraCode Nerd Font"
                                    font.pixelSize: 9
                                    renderType: Text.NativeRendering

                                    MouseArea {
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        onEntered: muteText.color = "#ebdbb2"
                                        onExited: muteText.color = "#d5c4a1"
                                        onClicked: {
                                            if (root.defaultSink) {
                                                Quickshell.execDetached(["pactl", "set-sink-mute", String(root.defaultSink.index), "toggle"]);
                                                var muted = !root.defaultSink.muted;
                                                var text = muted ? "vol muted" : "vol " + root.defaultSink.volume + "%";
                                                var kind = muted ? "warn" : "info";
                                                Quickshell.execDetached(["/home/parazeeknova/doty/.config/quickshell/osd/bin/osdctl", "show", text, kind, "1200"]);
                                                checkStatusProc.running = true;
                                            }
                                        }
                                    }

                                }

                            }

                            // Master Output Horizontal Slider
                            Item {
                                width: parent.width
                                height: 8

                                // Block-style Slider
                                Row {
                                    id: masterSliderBlocks

                                    property int totalBlocks: 15
                                    property double currentVal: root.defaultSink ? root.defaultSink.volume / 100 : 0

                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    anchors.verticalCenter: parent.verticalCenter
                                    height: 5
                                    spacing: 1

                                    Repeater {
                                        model: masterSliderBlocks.totalBlocks

                                        delegate: Rectangle {
                                            height: parent.height
                                            width: (masterSliderBlocks.width - (masterSliderBlocks.spacing * (masterSliderBlocks.totalBlocks - 1))) / masterSliderBlocks.totalBlocks
                                            color: (index < Math.round(masterSliderBlocks.currentVal * masterSliderBlocks.totalBlocks)) ? "#d5c4a1" : "#3c3836"
                                        }

                                    }

                                }

                                MouseArea {
                                    function updateVol(mouseX) {
                                        if (root.defaultSink) {
                                            var clampedX = Math.max(0, Math.min(mouseX, parent.width));
                                            var pct = Math.round((clampedX / parent.width) * 100);
                                            root.defaultSink.volume = pct; // Instant visual feedback
                                            root.pendingOutVol = pct; // Queue command apply
                                        }
                                    }

                                    anchors.fill: parent
                                    preventStealing: true
                                    onWheel: (wheel) => {
                                        if (root.defaultSink) {
                                            var change = wheel.angleDelta.y > 0 ? 2 : -2;
                                            var newVol = Math.max(0, Math.min(root.defaultSink.volume + change, 100));
                                            root.defaultSink.volume = newVol;
                                            root.pendingOutVol = newVol;
                                        }
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

                        // --- SECTION 2: MIC INPUT ---
                        Column {
                            width: parent.width
                            spacing: 3

                            Item {
                                width: parent.width
                                height: 14

                                Text {
                                    anchors.left: parent.left
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: "󰍬 Input: " + (root.defaultSource ? (root.defaultSource.muted ? "Muted" : root.defaultSource.volume + "%") : "0%")
                                    color: "#d5c4a1"
                                    font.family: "FiraCode Nerd Font"
                                    font.pixelSize: 9
                                    font.bold: true
                                    renderType: Text.NativeRendering
                                }

                                Text {
                                    id: micMuteText

                                    anchors.right: parent.right
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: root.defaultSource && root.defaultSource.muted ? "Unmute" : "Mute"
                                    color: "#d5c4a1"
                                    font.family: "FiraCode Nerd Font"
                                    font.pixelSize: 9
                                    renderType: Text.NativeRendering

                                    MouseArea {
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        onEntered: micMuteText.color = "#ebdbb2"
                                        onExited: micMuteText.color = "#d5c4a1"
                                        onClicked: {
                                            if (root.defaultSource) {
                                                Quickshell.execDetached(["pactl", "set-source-mute", String(root.defaultSource.index), "toggle"]);
                                                var muted = !root.defaultSource.muted;
                                                var text = muted ? "mic muted" : "mic " + root.defaultSource.volume + "%";
                                                var kind = muted ? "warn" : "info";
                                                Quickshell.execDetached(["/home/parazeeknova/doty/.config/quickshell/osd/bin/osdctl", "show", text, kind, "1200"]);
                                                checkStatusProc.running = true;
                                            }
                                        }
                                    }

                                }

                            }

                            // Mic Input Horizontal Slider
                            Item {
                                width: parent.width
                                height: 8

                                // Block-style Slider
                                Row {
                                    id: micSliderBlocks

                                    property int totalBlocks: 15
                                    property double currentVal: root.defaultSource ? root.defaultSource.volume / 100 : 0

                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    anchors.verticalCenter: parent.verticalCenter
                                    height: 5
                                    spacing: 1

                                    Repeater {
                                        model: micSliderBlocks.totalBlocks

                                        delegate: Rectangle {
                                            height: parent.height
                                            width: (micSliderBlocks.width - (micSliderBlocks.spacing * (micSliderBlocks.totalBlocks - 1))) / micSliderBlocks.totalBlocks
                                            color: (index < Math.round(micSliderBlocks.currentVal * micSliderBlocks.totalBlocks)) ? "#d5c4a1" : "#3c3836"
                                        }

                                    }

                                }

                                MouseArea {
                                    function updateVol(mouseX) {
                                        if (root.defaultSource) {
                                            var clampedX = Math.max(0, Math.min(mouseX, parent.width));
                                            var pct = Math.round((clampedX / parent.width) * 100);
                                            root.defaultSource.volume = pct; // Instant visual feedback
                                            root.pendingInVol = pct; // Queue command apply
                                        }
                                    }

                                    anchors.fill: parent
                                    preventStealing: true
                                    onWheel: (wheel) => {
                                        if (root.defaultSource) {
                                            var change = wheel.angleDelta.y > 0 ? 2 : -2;
                                            var newVol = Math.max(0, Math.min(root.defaultSource.volume + change, 100));
                                            root.defaultSource.volume = newVol;
                                            root.pendingInVol = newVol;
                                        }
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

                        // --- SECTION 5: APP VOLUMES ---
                        Column {
                            width: parent.width
                            spacing: 6
                            visible: root.apps.length > 0

                            Text {
                                text: "App Volumes"
                                color: "#d5c4a1"
                                font.family: "FiraCode Nerd Font"
                                font.pixelSize: 9
                                font.bold: true
                                renderType: Text.NativeRendering
                            }

                            Column {
                                width: parent.width
                                spacing: 6

                                Repeater {
                                    model: root.apps

                                    delegate: Column {
                                        width: parent.width
                                        spacing: 2

                                        Text {
                                            text: modelData.name.substring(0, 20) + " (" + modelData.volume + "%)"
                                            color: "#d5c4a1"
                                            font.family: "FiraCode Nerd Font"
                                            font.pixelSize: 8
                                            renderType: Text.NativeRendering
                                        }

                                        // App Horizontal Slider
                                        Item {
                                            width: parent.width
                                            height: 8

                                            // Block-style Slider
                                            Row {
                                                id: appSliderBlocks

                                                property int totalBlocks: 15
                                                property double currentVal: modelData.volume / 100

                                                anchors.left: parent.left
                                                anchors.right: parent.right
                                                anchors.verticalCenter: parent.verticalCenter
                                                height: 4
                                                spacing: 1

                                                Repeater {
                                                    model: appSliderBlocks.totalBlocks

                                                    delegate: Rectangle {
                                                        height: parent.height
                                                        width: (appSliderBlocks.width - (appSliderBlocks.spacing * (appSliderBlocks.totalBlocks - 1))) / appSliderBlocks.totalBlocks
                                                        color: (index < Math.round(appSliderBlocks.currentVal * appSliderBlocks.totalBlocks)) ? "#d5c4a1" : "#3c3836"
                                                    }

                                                }

                                            }

                                            MouseArea {
                                                function updateVol(mouseX) {
                                                    var clampedX = Math.max(0, Math.min(mouseX, parent.width));
                                                    var pct = Math.round((clampedX / parent.width) * 100);
                                                    modelData.volume = pct; // Instant feedback
                                                    var temp = root.pendingAppVols;
                                                    temp[modelData.index] = pct;
                                                    root.pendingAppVols = temp;
                                                }

                                                anchors.fill: parent
                                                preventStealing: true
                                                onWheel: (wheel) => {
                                                    var change = wheel.angleDelta.y > 0 ? 2 : -2;
                                                    var newVol = Math.max(0, Math.min(modelData.volume + change, 100));
                                                    modelData.volume = newVol;
                                                    var temp = root.pendingAppVols;
                                                    temp[modelData.index] = newVol;
                                                    root.pendingAppVols = temp;
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

                                }

                            }

                        }

                        // --- SECTION 6: BLUETOOTH MEDIA ---
                        Column {
                            width: parent.width
                            spacing: 6
                            visible: root.defaultSink && root.defaultSink.is_bluetooth

                            Rectangle {
                                width: parent.width
                                height: 1
                                color: "#d5c4a1"
                                opacity: 0.25
                            }

                            Row {
                                anchors.horizontalCenter: parent.horizontalCenter
                                spacing: 20

                                Text {
                                    id: btPrev

                                    text: "󰙣 Prev"
                                    color: "#d5c4a1"
                                    font.family: "FiraCode Nerd Font"
                                    font.pixelSize: 9
                                    renderType: Text.NativeRendering

                                    MouseArea {
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        onEntered: btPrev.color = "#ebdbb2"
                                        onExited: btPrev.color = "#d5c4a1"
                                        onClicked: Quickshell.execDetached(["playerctl", "previous"])
                                    }

                                }

                                Text {
                                    id: btPlay

                                    text: "󰐊 Play"
                                    color: "#d5c4a1"
                                    font.family: "FiraCode Nerd Font"
                                    font.pixelSize: 9
                                    renderType: Text.NativeRendering

                                    MouseArea {
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        onEntered: btPlay.color = "#ebdbb2"
                                        onExited: btPlay.color = "#d5c4a1"
                                        onClicked: Quickshell.execDetached(["playerctl", "play-pause"])
                                    }

                                }

                                Text {
                                    id: btNext

                                    text: "󰙡 Next"
                                    color: "#d5c4a1"
                                    font.family: "FiraCode Nerd Font"
                                    font.pixelSize: 9
                                    renderType: Text.NativeRendering

                                    MouseArea {
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        onEntered: btNext.color = "#ebdbb2"
                                        onExited: btNext.color = "#d5c4a1"
                                        onClicked: Quickshell.execDetached(["playerctl", "next"])
                                    }

                                }

                            }

                        }

                        // Separator 1
                        Rectangle {
                            width: parent.width
                            height: 1
                            color: "#d5c4a1"
                            opacity: 0.25
                        }

                        // --- SECTION 3: DEVICES ---
                        Rectangle {
                            width: parent.width
                            height: 16
                            color: "transparent"

                            Text {
                                id: devicesHeader

                                anchors.left: parent.left
                                anchors.verticalCenter: parent.verticalCenter
                                text: "Devices " + (root.devicesDropdownOpen ? "󰅀" : "󰅂")
                                color: "#d5c4a1"
                                font.family: "FiraCode Nerd Font"
                                font.pixelSize: 9
                                font.bold: true
                                renderType: Text.NativeRendering
                            }

                            MouseArea {
                                anchors.fill: parent
                                onClicked: {
                                    root.devicesDropdownOpen = !root.devicesDropdownOpen;
                                }
                            }

                        }

                        // Dropdown Content
                        Column {
                            width: parent.width
                            spacing: 6
                            visible: root.devicesDropdownOpen

                            // Subheading: Outputs
                            Text {
                                text: "  Outputs"
                                color: "#d5c4a1"
                                opacity: 0.6
                                font.family: "FiraCode Nerd Font"
                                font.pixelSize: 8
                                font.bold: true
                                renderType: Text.NativeRendering
                            }

                            Column {
                                width: parent.width
                                spacing: 3

                                Repeater {
                                    model: root.sinks

                                    delegate: Rectangle {
                                        width: parent.width
                                        height: 16
                                        color: "transparent"

                                        Text {
                                            id: devText

                                            anchors.left: parent.left
                                            anchors.verticalCenter: parent.verticalCenter
                                            text: (root.defaultSink && root.defaultSink.name === modelData.name ? "  * " : "    ") + modelData.description.substring(0, 30)
                                            color: root.defaultSink && root.defaultSink.name === modelData.name ? "#ebdbb2" : "#d5c4a1"
                                            opacity: root.defaultSink && root.defaultSink.name === modelData.name ? 1 : 0.7
                                            font.family: "FiraCode Nerd Font"
                                            font.pixelSize: 9
                                            renderType: Text.NativeRendering
                                        }

                                        MouseArea {
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            onEntered: {
                                                if (root.defaultSink && root.defaultSink.name !== modelData.name) {
                                                    devText.color = "#ebdbb2";
                                                    devText.opacity = 1;
                                                }
                                            }
                                            onExited: {
                                                if (root.defaultSink && root.defaultSink.name !== modelData.name) {
                                                    devText.color = "#d5c4a1";
                                                    devText.opacity = 0.7;
                                                }
                                            }
                                            onClicked: {
                                                Quickshell.execDetached(["pactl", "set-default-sink", modelData.name]);
                                                checkStatusProc.running = true;
                                            }
                                        }

                                    }

                                }

                            }

                            // Subheading: Inputs
                            Text {
                                text: "  Inputs"
                                color: "#d5c4a1"
                                opacity: 0.6
                                font.family: "FiraCode Nerd Font"
                                font.pixelSize: 8
                                font.bold: true
                                renderType: Text.NativeRendering
                            }

                            Column {
                                width: parent.width
                                spacing: 3

                                Repeater {
                                    model: root.sources

                                    delegate: Rectangle {
                                        width: parent.width
                                        height: 16
                                        color: "transparent"

                                        Text {
                                            id: srcText

                                            anchors.left: parent.left
                                            anchors.verticalCenter: parent.verticalCenter
                                            text: (root.defaultSource && root.defaultSource.name === modelData.name ? "  * " : "    ") + modelData.description.substring(0, 30)
                                            color: root.defaultSource && root.defaultSource.name === modelData.name ? "#ebdbb2" : "#d5c4a1"
                                            opacity: root.defaultSource && root.defaultSource.name === modelData.name ? 1 : 0.7
                                            font.family: "FiraCode Nerd Font"
                                            font.pixelSize: 9
                                            renderType: Text.NativeRendering
                                        }

                                        MouseArea {
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            onEntered: {
                                                if (root.defaultSource && root.defaultSource.name !== modelData.name) {
                                                    srcText.color = "#ebdbb2";
                                                    srcText.opacity = 1;
                                                }
                                            }
                                            onExited: {
                                                if (root.defaultSource && root.defaultSource.name !== modelData.name) {
                                                    srcText.color = "#d5c4a1";
                                                    srcText.opacity = 0.7;
                                                }
                                            }
                                            onClicked: {
                                                Quickshell.execDetached(["pactl", "set-default-source", modelData.name]);
                                                checkStatusProc.running = true;
                                            }
                                        }

                                    }

                                }

                            }

                        }

                        // --- SECTION 7: DIAGNOSTICS ---
                        Text {
                            id: diagText

                            width: parent.width
                            text: "PipeWire: " + root.diagnostics.pipewire_version + " | Rate: " + root.diagnostics.sample_rate + "\nOutput: " + root.diagnostics.output_desc
                            color: "#d5c4a1"
                            opacity: 0.5
                            font.family: "FiraCode Nerd Font"
                            font.pixelSize: 7
                            lineHeight: 1.2
                            renderType: Text.NativeRendering
                        }

                    }

                }

            }

        }

    }

}
