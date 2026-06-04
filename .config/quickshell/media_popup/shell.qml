import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland

Scope {
    id: root

    property string homeDir: Quickshell.env("HOME")
    property string helperPath: homeDir + "/.config/quickshell/media_popup/get_media_status"
    property bool isRecording: false
    property string screenshotDir: ""
    property string recordingDir: ""
    property var history: []
    property string activeHistoryTab: "ALL"
    property int expandedOcrIndex: -1
    property bool recordAudio: false
    property bool recordMic: false

    // Properties for popup behavior
    signal requestClose()

    function updateStatus() {
        statusProc.running = false;
        statusProc.running = true;
    }

    Component.onCompleted: {
        updateStatus();
    }

    Theme {
        id: theme
    }

    IpcHandler {
        function close() {
            root.requestClose();
        }

        target: "media_popup"
    }

    // Process to run the Rust helper and retrieve JSON status
    Process {
        id: statusProc

        command: [root.helperPath]
        running: false

        stdout: StdioCollector {
            onStreamFinished: {
                var txt = this.text.trim();
                if (txt === "")
                    return ;

                try {
                    var data = JSON.parse(txt);
                    root.isRecording = data.is_recording;
                    root.screenshotDir = data.screenshot_dir;
                    root.recordingDir = data.recording_dir;
                    root.history = data.history || [];
                } catch (e) {
                    console.log("Failed to parse media status JSON: " + e + " | Content: '" + txt + "'");
                }
            }
        }

    }

    // Timer to poll status every 1.5 seconds (mainly for wf-recorder status and path updates)
    Timer {
        id: refreshTimer

        interval: 1500
        repeat: true
        running: true
        triggeredOnStart: true
        onTriggered: {
            updateStatus();
        }
    }

    // Process to browse directories
    Process {
        id: browseScreenshotProc

        command: ["zenity", "--file-selection", "--directory", "--title=Select Screenshot Directory"]
        running: false

        stdout: StdioCollector {
            onStreamFinished: {
                var path = this.text.trim();
                if (path !== "") {
                    Quickshell.execDetached([root.helperPath, "set-screenshot-dir", path]);
                    updateStatus();
                }
            }
        }

    }

    Process {
        id: browseRecordingProc

        command: ["zenity", "--file-selection", "--directory", "--title=Select Recording Directory"]
        running: false

        stdout: StdioCollector {
            onStreamFinished: {
                var path = this.text.trim();
                if (path !== "") {
                    Quickshell.execDetached([root.helperPath, "set-recording-dir", path]);
                    updateStatus();
                }
            }
        }

    }

    Process {
        id: ocrImagePickerProc

        command: ["zenity", "--file-selection", "--file-filter=Images | *.png *.jpg *.jpeg *.webp", "--title=Select Image for OCR"]
        running: false

        stdout: StdioCollector {
            onStreamFinished: {
                var file = this.text.trim();
                if (file !== "")
                    Quickshell.execDetached(["sh", "-c", "TEXT=$(tesseract \"" + file + "\" stdout 2>/dev/null) && if [ ! -z \"$TEXT\" ]; then echo -n \"$TEXT\" | wl-copy && " + root.homeDir + "/.config/quickshell/osd/bin/osdctl show \"Text Extracted\" \"good\" 1200 && \"" + root.helperPath + "\" add ocr \"$TEXT\"; else notify-send -t 1500 -a \"OCR\" \"No text found\"; fi"]);

            }
        }

    }

    Variants {
        model: Quickshell.screens

        delegate: Component {
            PanelWindow {
                id: win

                required property var modelData
                property bool isClosing: false
                property real animOffsetX: -260
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
                // Set layershell requirements matching workspace_popup
                WlrLayershell.namespace: "quickshell"
                WlrLayershell.layer: WlrLayer.Overlay
                WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
                implicitWidth: 240
                implicitHeight: mainLayout.implicitHeight + 12
                Component.onCompleted: introAnim.start()

                Connections {
                    function onRequestClose() {
                        win.closePopup();
                    }

                    target: root
                }

                anchors {
                    top: true
                    left: true
                }

                margins {
                    top: 4
                    left: win.animOffsetX
                }

                // Slide-in + fade-in
                ParallelAnimation {
                    id: introAnim

                    NumberAnimation {
                        target: win
                        property: "animOffsetX"
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
                        property: "animOffsetX"
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

                // Auto-close on click outside
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
                    color: "#f01d2021" // Solid/semi-transparent Gruvbox dark background
                    border.width: 1
                    border.color: theme.accent
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
                        anchors.margins: 8
                        spacing: 6

                        // HEADER
                        Row {
                            width: parent.width

                            Text {
                                text: "Media Actions"
                                color: theme.accent
                                font.family: "FiraCode Nerd Font"
                                font.pixelSize: 9
                                font.bold: true
                            }

                        }

                        // SCREENSHOTS SECTION
                        Column {
                            width: parent.width
                            spacing: 3

                            Text {
                                text: "Screenshots"
                                color: "#a89984"
                                font.family: "FiraCode Nerd Font"
                                font.pixelSize: 8
                                font.bold: true
                            }

                            Row {
                                width: parent.width
                                spacing: 4

                                // Area (Edit)
                                Rectangle {
                                    width: (parent.width - 12) / 4
                                    height: 38
                                    color: theme.bg_light
                                    border.width: 1
                                    border.color: "#504945"

                                    Column {
                                        anchors.centerIn: parent
                                        spacing: 2

                                        Text {
                                            text: "󰆞"
                                            color: theme.accent
                                            font.family: "FiraCode Nerd Font"
                                            font.pixelSize: 12
                                            anchors.horizontalCenter: parent.horizontalCenter
                                        }

                                        Text {
                                            text: "Area (Ed)"
                                            color: theme.accent
                                            font.family: "FiraCode Nerd Font"
                                            font.pixelSize: 7
                                            anchors.horizontalCenter: parent.horizontalCenter
                                        }

                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        onEntered: parent.border.color = theme.accent
                                        onExited: parent.border.color = "#504945"
                                        onClicked: {
                                            win.closePopup();
                                            var slurp = "slurp -b \\#1d2021b0 -c \\#d5c4a1ff -s \\#00000000";
                                            Quickshell.execDetached(["sh", "-c", "mkdir -p \"" + root.screenshotDir + "\" && FILE=\"" + root.screenshotDir + "/Screenshot_$(date '+%Y-%m-%d_%H.%M.%S').png\" && grim -g \"$(" + slurp + ")\" \"$FILE\" && swappy -f \"$FILE\" -o \"$FILE\" && wl-copy < \"$FILE\" && \"" + root.helperPath + "\" add screenshot \"$FILE\""]);
                                        }
                                    }

                                }

                                // Area (Clip)
                                Rectangle {
                                    width: (parent.width - 12) / 4
                                    height: 38
                                    color: theme.bg_light
                                    border.width: 1
                                    border.color: "#504945"

                                    Column {
                                        anchors.centerIn: parent
                                        spacing: 2

                                        Text {
                                            text: "󰹑"
                                            color: theme.accent
                                            font.family: "FiraCode Nerd Font"
                                            font.pixelSize: 12
                                            anchors.horizontalCenter: parent.horizontalCenter
                                        }

                                        Text {
                                            text: "Area (Cl)"
                                            color: theme.accent
                                            font.family: "FiraCode Nerd Font"
                                            font.pixelSize: 7
                                            anchors.horizontalCenter: parent.horizontalCenter
                                        }

                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        onEntered: parent.border.color = theme.accent
                                        onExited: parent.border.color = "#504945"
                                        onClicked: {
                                            win.closePopup();
                                            var slurp = "slurp -b \\#1d2021b0 -c \\#d5c4a1ff -s \\#00000000";
                                            Quickshell.execDetached(["sh", "-c", "grim -g \"$(" + slurp + ")\" - | wl-copy && \"" + root.helperPath + "\" add screenshot \"Clipboard (Area)\""]);
                                        }
                                    }

                                }

                                // Full (Clip)
                                Rectangle {
                                    width: (parent.width - 12) / 4
                                    height: 38
                                    color: theme.bg_light
                                    border.width: 1
                                    border.color: "#504945"

                                    Column {
                                        anchors.centerIn: parent
                                        spacing: 2

                                        Text {
                                            text: "󰉉"
                                            color: theme.accent
                                            font.family: "FiraCode Nerd Font"
                                            font.pixelSize: 12
                                            anchors.horizontalCenter: parent.horizontalCenter
                                        }

                                        Text {
                                            text: "Full (Cl)"
                                            color: theme.accent
                                            font.family: "FiraCode Nerd Font"
                                            font.pixelSize: 7
                                            anchors.horizontalCenter: parent.horizontalCenter
                                        }

                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        onEntered: parent.border.color = theme.accent
                                        onExited: parent.border.color = "#504945"
                                        onClicked: {
                                            win.closePopup();
                                            Quickshell.execDetached(["sh", "-c", "grim -o \"$(hyprctl activeworkspace -j | jq -r '.monitor')\" - | wl-copy && \"" + root.helperPath + "\" add screenshot \"Clipboard (Full)\""]);
                                        }
                                    }

                                }

                                // Full (File)
                                Rectangle {
                                    width: (parent.width - 12) / 4
                                    height: 38
                                    color: theme.bg_light
                                    border.width: 1
                                    border.color: "#504945"

                                    Column {
                                        anchors.centerIn: parent
                                        spacing: 2

                                        Text {
                                            text: "󰄀"
                                            color: theme.accent
                                            font.family: "FiraCode Nerd Font"
                                            font.pixelSize: 12
                                            anchors.horizontalCenter: parent.horizontalCenter
                                        }

                                        Text {
                                            text: "Full (Fi)"
                                            color: theme.accent
                                            font.family: "FiraCode Nerd Font"
                                            font.pixelSize: 7
                                            anchors.horizontalCenter: parent.horizontalCenter
                                        }

                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        onEntered: parent.border.color = theme.accent
                                        onExited: parent.border.color = "#504945"
                                        onClicked: {
                                            win.closePopup();
                                            Quickshell.execDetached(["sh", "-c", "mkdir -p \"" + root.screenshotDir + "\" && FILE=\"" + root.screenshotDir + "/Screenshot_$(date '+%Y-%m-%d_%H.%M.%S').png\" && grim -o \"$(hyprctl activeworkspace -j | jq -r '.monitor')\" \"$FILE\" && wl-copy < \"$FILE\" && \"" + root.helperPath + "\" add screenshot \"$FILE\""]);
                                        }
                                    }

                                }

                            }

                        }

                        // SCREEN RECORDING SECTION
                        Column {
                            width: parent.width
                            spacing: 3

                            Text {
                                text: "Screen Recording"
                                color: "#a89984"
                                font.family: "FiraCode Nerd Font"
                                font.pixelSize: 8
                                font.bold: true
                            }

                            Row {
                                width: parent.width
                                spacing: 4

                                // Screen Record Area / Stop
                                Rectangle {
                                    width: root.isRecording ? parent.width : (parent.width - 4) / 2
                                    height: 18
                                    color: root.isRecording ? "#80cc241d" : theme.bg_light
                                    border.width: 1
                                    border.color: root.isRecording ? theme.error : "#504945"

                                    Text {
                                        anchors.centerIn: parent
                                        text: root.isRecording ? "󰻃 Stop Recording" : "󰑋 Rec Area"
                                        color: theme.accent
                                        font.family: "FiraCode Nerd Font"
                                        font.pixelSize: 8
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        onEntered: {
                                            if (!root.isRecording)
                                                parent.border.color = theme.accent;

                                        }
                                        onExited: {
                                            if (!root.isRecording)
                                                parent.border.color = "#504945";

                                        }
                                        onClicked: {
                                            if (root.isRecording) {
                                                Quickshell.execDetached(["sh", "-c", "pkill -SIGINT wf-recorder && " + root.homeDir + "/.config/quickshell/osd/bin/osdctl show \"Recording Saved\" \"good\" 1200"]);
                                                root.updateStatus();
                                            } else {
                                                win.closePopup();
                                                var audioArgs = "";
                                                if (root.recordAudio && root.recordMic)
                                                    audioArgs = "-a -a";
                                                else if (root.recordAudio || root.recordMic)
                                                    audioArgs = "-a";
                                                Quickshell.execDetached(["sh", "-c", "GEOM=$(slurp) && if [ ! -z \"$GEOM\" ]; then " + root.homeDir + "/.config/quickshell/osd/bin/osdctl show \"Recording Started\" \"bad\" 1200 && mkdir -p \"" + root.recordingDir + "\" && FILE=\"" + root.recordingDir + "/Recording_$(date '+%Y-%m-%d_%H.%M.%S').mp4\" && (wf-recorder " + audioArgs + " -g \"$GEOM\" -f \"$FILE\" ; ffmpeg -y -i \"$FILE\" -ss 00:00:00.500 -vframes 1 \"${FILE%.mp4}.png\" 2>/dev/null ; \"" + root.helperPath + "\" add recording \"$FILE\") ; fi"]);
                                            }
                                        }
                                    }

                                }

                                // Record Full (only visible if not recording)
                                Rectangle {
                                    width: (parent.width - 4) / 2
                                    height: 18
                                    color: theme.bg_light
                                    border.width: 1
                                    border.color: "#504945"
                                    visible: !root.isRecording

                                    Text {
                                        anchors.centerIn: parent
                                        text: "󰕧 Rec Fullscreen"
                                        color: theme.accent
                                        font.family: "FiraCode Nerd Font"
                                        font.pixelSize: 8
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        onEntered: parent.border.color = theme.accent
                                        onExited: parent.border.color = "#504945"
                                        onClicked: {
                                            win.closePopup();
                                            var audioArgs = "";
                                            if (root.recordAudio && root.recordMic)
                                                audioArgs = "-a -a";
                                            else if (root.recordAudio || root.recordMic)
                                                audioArgs = "-a";
                                            Quickshell.execDetached(["sh", "-c", root.homeDir + "/.config/quickshell/osd/bin/osdctl show \"Recording Started\" \"bad\" 1200 && mkdir -p \"" + root.recordingDir + "\" && FILE=\"" + root.recordingDir + "/Recording_$(date '+%Y-%m-%d_%H.%M.%S').mp4\" && (wf-recorder " + audioArgs + " -f \"$FILE\" ; ffmpeg -y -i \"$FILE\" -ss 00:00:00.500 -vframes 1 \"${FILE%.mp4}.png\" 2>/dev/null ; \"" + root.helperPath + "\" add recording \"$FILE\")"]);
                                        }
                                    }

                                }

                            }

                            // Audio & Mic configuration row
                            Row {
                                width: parent.width
                                spacing: 4
                                visible: !root.isRecording

                                Item {
                                    width: (parent.width - 4) / 2
                                    height: 14

                                    Text {
                                        anchors.centerIn: parent
                                        text: "System Audio: " + (root.recordAudio ? "ON" : "OFF")
                                        color: root.recordAudio ? "#fe8019" : "#a89984"
                                        font.family: "FiraCode Nerd Font"
                                        font.pixelSize: 8
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        onClicked: root.recordAudio = !root.recordAudio
                                    }

                                }

                                Item {
                                    width: (parent.width - 4) / 2
                                    height: 14

                                    Text {
                                        anchors.centerIn: parent
                                        text: "Microphone: " + (root.recordMic ? "ON" : "OFF")
                                        color: root.recordMic ? "#fe8019" : "#a89984"
                                        font.family: "FiraCode Nerd Font"
                                        font.pixelSize: 8
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        onClicked: root.recordMic = !root.recordMic
                                    }

                                }

                            }

                        }

                        // OCR TEXT EXTRACTION SECTION
                        Column {
                            width: parent.width
                            spacing: 3

                            Text {
                                text: "OCR Text Extraction"
                                color: "#a89984"
                                font.family: "FiraCode Nerd Font"
                                font.pixelSize: 8
                                font.bold: true
                            }

                            Row {
                                width: parent.width
                                spacing: 4

                                // OCR Area
                                Rectangle {
                                    width: (parent.width - 4) / 2
                                    height: 18
                                    color: theme.bg_light
                                    border.width: 1
                                    border.color: "#504945"

                                    Text {
                                        anchors.centerIn: parent
                                        text: "󰙎 OCR Area"
                                        color: theme.accent
                                        font.family: "FiraCode Nerd Font"
                                        font.pixelSize: 8
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        onEntered: parent.border.color = theme.accent
                                        onExited: parent.border.color = "#504945"
                                        onClicked: {
                                            win.closePopup();
                                            var slurp = "slurp -b \\#1d2021b0 -c \\#d5c4a1ff -s \\#00000000";
                                            Quickshell.execDetached(["sh", "-c", "grim -g \"$(" + slurp + ")\" /tmp/ocr_image.png && TEXT=$(tesseract /tmp/ocr_image.png stdout 2>/dev/null) && rm /tmp/ocr_image.png && if [ ! -z \"$TEXT\" ]; then echo -n \"$TEXT\" | wl-copy && " + root.homeDir + "/.config/quickshell/osd/bin/osdctl show \"Text Extracted\" \"good\" 1200 && \"" + root.helperPath + "\" add ocr \"$TEXT\"; else notify-send -t 1500 -a \"OCR\" \"No text found\"; fi"]);
                                        }
                                    }

                                }

                                // OCR Image File
                                Rectangle {
                                    width: (parent.width - 4) / 2
                                    height: 18
                                    color: theme.bg_light
                                    border.width: 1
                                    border.color: "#504945"

                                    Text {
                                        anchors.centerIn: parent
                                        text: "󰉋 OCR Image File"
                                        color: theme.accent
                                        font.family: "FiraCode Nerd Font"
                                        font.pixelSize: 8
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        onEntered: parent.border.color = theme.accent
                                        onExited: parent.border.color = "#504945"
                                        onClicked: {
                                            ocrImagePickerProc.running = true;
                                        }
                                    }

                                }

                            }

                        }

                        // SETTINGS SECTION
                        Column {
                            width: parent.width
                            spacing: 3

                            Text {
                                text: "Target Directories"
                                color: "#a89984"
                                font.family: "FiraCode Nerd Font"
                                font.pixelSize: 8
                                font.bold: true
                            }

                            // Screenshot location
                            Row {
                                width: parent.width
                                spacing: 4

                                Rectangle {
                                    width: parent.width - 24
                                    height: 18
                                    color: theme.bg_dark
                                    border.width: 1
                                    border.color: theme.bg_light

                                    TextInput {
                                        id: scrInput

                                        anchors.fill: parent
                                        anchors.leftMargin: 4
                                        anchors.rightMargin: 4
                                        verticalAlignment: TextInput.AlignVCenter
                                        text: root.screenshotDir
                                        color: theme.accent
                                        font.family: "FiraCode Nerd Font"
                                        font.pixelSize: 8
                                        selectByMouse: true
                                        onAccepted: {
                                            Quickshell.execDetached([root.helperPath, "set-screenshot-dir", text]);
                                            focus = false;
                                            root.updateStatus();
                                        }
                                    }

                                }

                                // Browse button
                                Rectangle {
                                    width: 20
                                    height: 18
                                    color: theme.bg_light
                                    border.width: 1
                                    border.color: "#504945"

                                    Text {
                                        anchors.centerIn: parent
                                        text: "󰉋"
                                        color: theme.accent
                                        font.family: "FiraCode Nerd Font"
                                        font.pixelSize: 8
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        onClicked: browseScreenshotProc.running = true
                                    }

                                }

                            }

                            // Recording location
                            Row {
                                width: parent.width
                                spacing: 4

                                Rectangle {
                                    width: parent.width - 24
                                    height: 18
                                    color: theme.bg_dark
                                    border.width: 1
                                    border.color: theme.bg_light

                                    TextInput {
                                        id: recInput

                                        anchors.fill: parent
                                        anchors.leftMargin: 4
                                        anchors.rightMargin: 4
                                        verticalAlignment: TextInput.AlignVCenter
                                        text: root.recordingDir
                                        color: theme.accent
                                        font.family: "FiraCode Nerd Font"
                                        font.pixelSize: 8
                                        selectByMouse: true
                                        onAccepted: {
                                            Quickshell.execDetached([root.helperPath, "set-recording-dir", text]);
                                            focus = false;
                                            root.updateStatus();
                                        }
                                    }

                                }

                                // Browse button
                                Rectangle {
                                    width: 20
                                    height: 18
                                    color: theme.bg_light
                                    border.width: 1
                                    border.color: "#504945"

                                    Text {
                                        anchors.centerIn: parent
                                        text: "󰉋"
                                        color: theme.accent
                                        font.family: "FiraCode Nerd Font"
                                        font.pixelSize: 8
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        onClicked: browseRecordingProc.running = true
                                    }

                                }

                            }

                        }

                        // Separator before history
                        Rectangle {
                            width: parent.width
                            height: 1
                            color: theme.accent
                            opacity: 0.15
                        }

                        // HISTORY SECTION
                        Column {
                            width: parent.width
                            spacing: 4

                            Item {
                                width: parent.width
                                height: 12

                                Row {
                                    anchors.left: parent.left
                                    spacing: 8

                                    Text {
                                        text: "Asset history"
                                        color: root.activeHistoryTab === "ALL" ? theme.accent : "#928374"
                                        font.family: "FiraCode Nerd Font"
                                        font.pixelSize: 8
                                        font.bold: root.activeHistoryTab === "ALL"

                                        MouseArea {
                                            anchors.fill: parent
                                            onClicked: root.activeHistoryTab = "ALL"
                                        }

                                    }

                                    Text {
                                        text: "OCR history"
                                        color: root.activeHistoryTab === "OCR" ? theme.accent : "#928374"
                                        font.family: "FiraCode Nerd Font"
                                        font.pixelSize: 8
                                        font.bold: root.activeHistoryTab === "OCR"

                                        MouseArea {
                                            anchors.fill: parent
                                            onClicked: root.activeHistoryTab = "OCR"
                                        }

                                    }

                                }

                                Text {
                                    anchors.right: parent.right
                                    text: "clear"
                                    color: "#928374"
                                    font.family: "FiraCode Nerd Font"
                                    font.pixelSize: 8

                                    MouseArea {
                                        anchors.fill: parent
                                        onClicked: {
                                            Quickshell.execDetached([root.helperPath, "clear-history"]);
                                            root.updateStatus();
                                        }
                                    }

                                }

                            }

                            // General History (ALL) Grid (4 in a row)
                            Grid {
                                width: parent.width
                                columns: 4
                                spacing: 4
                                visible: root.activeHistoryTab === "ALL"

                                Repeater {
                                    model: root.history.filter(function(item) {
                                        return item.type === "screenshot" || item.type === "recording";
                                    }).slice(0, 4)

                                    delegate: Column {
                                        width: (mainLayout.width - 12) / 4
                                        spacing: 2

                                        // Square Box representing the item
                                        Rectangle {
                                            width: parent.width
                                            height: parent.width // Square shape
                                            color: theme.bg_dark
                                            border.width: 1
                                            border.color: theme.bg_light

                                            // Image thumbnail if screenshot or recording is a file
                                            Image {
                                                anchors.fill: parent
                                                source: (modelData.type === "screenshot" && modelData.detail.indexOf("/") === 0) ? "file://" + modelData.detail : ((modelData.type === "recording" && modelData.detail.indexOf("/") === 0) ? "file://" + modelData.detail.replace(".mp4", ".png") : "")
                                                fillMode: Image.PreserveAspectCrop
                                                asynchronous: true
                                                visible: source.toString() !== ""
                                            }

                                            // Icon overlay in center (to identify image, video, OCR)
                                            Text {
                                                anchors.centerIn: parent
                                                text: modelData.type === "screenshot" ? "󰄀" : (modelData.type === "recording" ? "󰑋" : "󰙎")
                                                color: modelData.type === "screenshot" ? "#8ec07c" : (modelData.type === "recording" ? "#fe8019" : "#fb4934")
                                                font.family: "FiraCode Nerd Font"
                                                font.pixelSize: 12
                                            }

                                            MouseArea {
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                onEntered: parent.border.color = theme.accent
                                                onExited: parent.border.color = theme.bg_light
                                                onClicked: {
                                                    if (modelData.type === "ocr") {
                                                        Quickshell.execDetached(["sh", "-c", "echo -n '" + modelData.detail.replace(/'/g, "'\\''") + "' | wl-copy && notify-send -t 1000 -a 'OCR' 'Copied OCR text'"]);
                                                    } else if (modelData.type === "screenshot") {
                                                        if (modelData.detail.indexOf("/") === 0)
                                                            Quickshell.execDetached(["sh", "-c", "wl-copy < '" + modelData.detail + "' && notify-send -t 1000 -a 'Screenshot' 'Copied image'"]);
                                                        else
                                                            Quickshell.execDetached(["sh", "-c", "notify-send -t 1000 -a 'Screenshot' 'Already in clipboard'"]);
                                                    } else if (modelData.type === "recording") {
                                                        Quickshell.execDetached(["mpv", modelData.detail]);
                                                    }
                                                }
                                            }

                                        }

                                        // Truncated name below the box
                                        Text {
                                            width: parent.width
                                            horizontalAlignment: Text.AlignHCenter
                                            text: {
                                                if (modelData.detail.indexOf("/") === 0)
                                                    return modelData.detail.substring(modelData.detail.lastIndexOf('/') + 1);

                                                return modelData.detail;
                                            }
                                            color: theme.accent
                                            font.family: "FiraCode Nerd Font"
                                            font.pixelSize: 7
                                            elide: Text.ElideRight
                                        }

                                    }

                                }

                            }

                            // OCR History Tab
                            Column {
                                width: parent.width
                                spacing: 4
                                visible: root.activeHistoryTab === "OCR"

                                Repeater {
                                    model: root.history.filter(function(item) {
                                        return item.type === "ocr";
                                    })

                                    delegate: Column {
                                        width: parent.width
                                        spacing: 2

                                        // Collapsible Header Row
                                        Rectangle {
                                            width: parent.width
                                            height: 18
                                            color: theme.bg_dark
                                            border.width: 1
                                            border.color: root.expandedOcrIndex === index ? theme.accent : theme.bg_light

                                            Item {
                                                anchors.fill: parent
                                                anchors.margins: 2

                                                Text {
                                                    id: ocrIcon

                                                    text: "󰙎"
                                                    color: "#fb4934"
                                                    font.family: "FiraCode Nerd Font"
                                                    font.pixelSize: 8
                                                    anchors.left: parent.left
                                                    anchors.verticalCenter: parent.verticalCenter
                                                }

                                                Text {
                                                    id: ocrHeaderVal

                                                    anchors.left: ocrIcon.right
                                                    anchors.leftMargin: 4
                                                    anchors.right: ocrArrow.left
                                                    anchors.rightMargin: 4
                                                    text: {
                                                        var clean = modelData.detail.replace(/[\r\n\t]+/g, " ").trim();
                                                        if (clean.length > 25)
                                                            return clean.substring(0, 25) + "...";

                                                        return clean;
                                                    }
                                                    color: theme.accent
                                                    font.family: "FiraCode Nerd Font"
                                                    font.pixelSize: 8
                                                    elide: Text.ElideRight
                                                    anchors.verticalCenter: parent.verticalCenter
                                                }

                                                Text {
                                                    id: ocrArrow

                                                    text: root.expandedOcrIndex === index ? "󰅃" : "󰅀"
                                                    color: "#928374"
                                                    font.family: "FiraCode Nerd Font"
                                                    font.pixelSize: 8
                                                    anchors.right: parent.right
                                                    anchors.verticalCenter: parent.verticalCenter
                                                }

                                            }

                                            MouseArea {
                                                anchors.fill: parent
                                                onClicked: {
                                                    if (root.expandedOcrIndex === index)
                                                        root.expandedOcrIndex = -1;
                                                    else
                                                        root.expandedOcrIndex = index;
                                                }
                                            }

                                        }

                                        // Expanded Text & Copy Row
                                        Rectangle {
                                            width: parent.width
                                            height: expandedLayout.implicitHeight + 10
                                            color: theme.bg
                                            border.width: 1
                                            border.color: theme.bg_light
                                            visible: root.expandedOcrIndex === index

                                            Column {
                                                id: expandedLayout

                                                anchors.top: parent.top
                                                anchors.left: parent.left
                                                anchors.right: parent.right
                                                anchors.margins: 4
                                                spacing: 4

                                                Text {
                                                    anchors.left: parent.left
                                                    anchors.right: parent.right
                                                    text: modelData.detail
                                                    color: theme.accent
                                                    font.family: "FiraCode Nerd Font"
                                                    font.pixelSize: 8
                                                    wrapMode: Text.Wrap
                                                }

                                                // Copy Action Button
                                                Rectangle {
                                                    width: 68
                                                    height: 14
                                                    color: theme.bg_light
                                                    border.width: 1
                                                    border.color: "#504945"
                                                    anchors.right: parent.right

                                                    Text {
                                                        anchors.centerIn: parent
                                                        text: "󰆏 Copy Text"
                                                        color: theme.accent
                                                        font.family: "FiraCode Nerd Font"
                                                        font.pixelSize: 7
                                                    }

                                                    MouseArea {
                                                        anchors.fill: parent
                                                        hoverEnabled: true
                                                        onEntered: parent.border.color = theme.accent
                                                        onExited: parent.border.color = "#504945"
                                                        onClicked: {
                                                            Quickshell.execDetached(["sh", "-c", "echo -n '" + modelData.detail.replace(/'/g, "'\\''") + "' | wl-copy && notify-send -t 1000 -a 'OCR' 'Copied OCR text'"]);
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

        }

    }

}
