import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland

Scope {
    // (pickColor logic inlined in MouseArea to avoid scope issues with win id)

    id: root

    property string homeDir: Quickshell.env("HOME")
    property string helperPath: homeDir + "/.config/quickshell/media_popup/get_media_status"
    property bool isRecording: false
    property int monitorFps: 60
    property var colors: []
    property string screenshotDir: ""
    property string recordingDir: ""
    property var history: []
    property var assets: []
    property var allTags: []
    property string activeHistoryTab: "ALL"
    property int expandedOcrIndex: -1
    property string filterText: ""
    property string activeTag: ""
    property int expandedAssetId: -1
    property var previewAsset: null
    property string previewOcrText: ""
    property int currentPage: 0
    property string tagDraft: ""
    property var tagSuggestions: []
    property int searchDebounce: 0
    readonly property var recordCodecs: ["h264", "hevc", "vp9", "av1"]
    readonly property var recordFpsOptions: ["native", 30, 60, 120]
    readonly property var recordQualityOptions: ["low", "med", "high", "lossless"]
    readonly property var recordPresetOptions: ["ultrafast", "superfast", "veryfast", "fast", "medium", "slow"]

    // Properties for popup behavior
    signal requestClose()

    function syncColors() {
        colorModel.clear();
        for (var i = 0; i < root.colors.length; i++) {
            colorModel.append(root.colors[i]);
        }
    }

    function updateStatus() {
        if (statusProc.running)
            return ;

        statusProc.running = true;
    }

    function basename(path) {
        if (!path || path.indexOf("/") !== 0)
            return path || "";

        var idx = path.lastIndexOf("/");
        return idx >= 0 ? path.substring(idx + 1) : path;
    }

    function qualityBitrate() {
        switch (flagsAdapter.recordQuality) {
        case "low":
            return "2M";
        case "med":
            return "8M";
        case "high":
            return "20M";
        case "lossless":
            return "";
        }
        return "8M";
    }

    function effectiveFps() {
        if (flagsAdapter.recordFps === "native")
            return root.monitorFps;

        return flagsAdapter.recordFps;
    }

    function recorderExtraArgs() {
        var parts = [];
        if (flagsAdapter.recordCodec)
            parts.push("-c " + flagsAdapter.recordCodec);

        var fps = effectiveFps();
        if (fps)
            parts.push("-r " + fps);

        var b = qualityBitrate();
        if (b)
            parts.push("-b " + b);

        if (flagsAdapter.recordPreset)
            parts.push("-p " + flagsAdapter.recordPreset);

        return parts.join(" ");
    }

    function filteredAssets() {
        var result = [];
        for (var i = 0; i < root.assets.length; i++) {
            var a = root.assets[i];
            if (root.activeTag !== "" && a.tags.indexOf(root.activeTag) === -1)
                continue;

            if (root.filterText !== "") {
                var needle = root.filterText.toLowerCase();
                var hay = (a.source_path + " " + a.tags.join(" ")).toLowerCase();
                if (hay.indexOf(needle) === -1)
                    continue;

            }
            result.push(a);
        }
        return result;
    }

    function refreshTagSuggestions() {
        var q = root.tagDraft.toLowerCase();
        var currentTags = [];
        if (root.expandedAssetId >= 0) {
            for (var i = 0; i < root.assets.length; i++) {
                if (root.assets[i].id === root.expandedAssetId) {
                    currentTags = root.assets[i].tags;
                    break;
                }
            }
        }
        var out = [];
        for (var j = 0; j < root.allTags.length; j++) {
            var name = root.allTags[j].name;
            if (currentTags.indexOf(name) !== -1)
                continue;

            if (q !== "" && name.toLowerCase().indexOf(q) === -1)
                continue;

            out.push(name);
            if (out.length >= 5)
                break;

        }
        root.tagSuggestions = out;
    }

    function assetById(id) {
        for (var i = 0; i < root.assets.length; i++) {
            if (root.assets[i].id === id)
                return root.assets[i];

        }
        return null;
    }

    function closeEditor() {
        root.expandedAssetId = -1;
        root.tagDraft = "";
        root.tagSuggestions = [];
    }

    function closePreview() {
        root.previewAsset = null;
        root.previewOcrText = "";
    }

    function commitTagDraft(tagName) {
        if (root.expandedAssetId < 0)
            return ;

        var asset = root.assetById(root.expandedAssetId);
        if (!asset)
            return ;

        var name = (tagName || root.tagDraft).trim();
        if (name === "")
            return ;

        var newTags = asset.tags.slice();
        if (newTags.indexOf(name) === -1)
            newTags.push(name);

        Quickshell.execDetached([root.helperPath, "set-tags", asset.id.toString(), newTags.join(",")]);
        root.tagDraft = "";
        root.refreshTagSuggestions();
        root.updateStatus();
    }

    function removeTagFromAsset(asset, tagName) {
        var newTags = [];
        for (var i = 0; i < asset.tags.length; i++) {
            if (asset.tags[i] !== tagName)
                newTags.push(asset.tags[i]);

        }
        Quickshell.execDetached([root.helperPath, "set-tags", asset.id.toString(), newTags.join(",")]);
        root.updateStatus();
    }

    function purgeAsset(asset) {
        Quickshell.execDetached([root.helperPath, "remove-asset", asset.id.toString()]);
        if (root.expandedAssetId === asset.id)
            root.closeEditor();

        root.updateStatus();
    }

    onFilterTextChanged: {
        currentPage = 0;
        closePreview();
    }
    onActiveTagChanged: {
        currentPage = 0;
        closePreview();
    }
    onAssetsChanged: {
        currentPage = 0;
        closePreview();
    }
    Component.onCompleted: {
        updateStatus();
    }

    ListModel {
        id: colorModel
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

    // Persistent toggle flags (auto-saved to flags.json)
    FileView {
        id: flagsFile

        path: root.homeDir + "/.config/quickshell/media_popup/flags.json"
        watchChanges: true
        onFileChanged: reload()
        onAdapterUpdated: writeAdapter()

        JsonAdapter {
            id: flagsAdapter

            property bool recordAudio: false
            property bool recordMic: false
            property string recordCodec: "h264"
            property var recordFps: "native"
            property string recordQuality: "med"
            property string recordPreset: "fast"
        }

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
                    root.assets = data.assets || [];
                    root.allTags = data.tags || [];
                    root.colors = data.colors || [];
                    root.syncColors();
                    if (data.monitor_fps)
                        root.monitorFps = data.monitor_fps;

                } catch (e) {
                    console.log("Failed to parse media status JSON: " + e + " | Content: '" + txt + "'");
                }
            }
        }

    }

    // FileView watches a ping file; any change triggers an instant status refresh
    FileView {
        id: pingFile

        path: root.homeDir + "/.config/quickshell/media_popup/ping.txt"
        watchChanges: true
        onFileChanged: updateStatus()
    }

    // Lightweight recording-status poller (pgrep only, no DB)
    Process {
        id: recordingStatusProc

        command: [root.helperPath, "recording-status"]
        running: false

        stdout: StdioCollector {
            onStreamFinished: {
                var txt = this.text.trim();
                if (txt === "")
                    return ;

                try {
                    var data = JSON.parse(txt);
                    if (data.is_recording !== undefined)
                        root.isRecording = data.is_recording;

                } catch (e) {
                }
            }
        }

    }

    Timer {
        id: refreshTimer

        interval: 1000
        repeat: true
        running: true
        triggeredOnStart: true
        onTriggered: {
            if (!recordingStatusProc.running)
                recordingStatusProc.running = true;

        }
    }

    // Process to browse target directory
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
                // (Auto-close removed: popup stays open until Esc or close button.)

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

                Component.onCompleted: {
                    root.updateStatus();
                    introAnim.start();
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

                Rectangle {
                    anchors.fill: parent
                    opacity: win.animOpacity
                    color: theme.popupBgColor // Matching background color of other popups
                    border.width: 1
                    border.color: (root.previewAsset !== null || root.previewOcrText !== "") ? "#504945" : theme.accent
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

                    MouseArea {
                        anchors.fill: parent
                        propagateComposedEvents: true
                        onPressed: function(mouse) {
                            root.closePreview();
                            mouse.accepted = false;
                        }
                    }

                    HyprlandFocusGrab {
                        active: !win.isClosing
                        windows: (root.previewAsset !== null || root.previewOcrText !== "") && previewLoader.item ? [win, previewLoader.item] : [win]
                        onCleared: win.closePopup()
                    }

                    Column {
                        id: mainLayout

                        opacity: (root.previewAsset !== null || root.previewOcrText !== "") ? 0.65 : 1
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

                            Item {
                                width: parent.width - closeText.width - 4
                                height: 1
                            }

                            Text {
                                id: closeText

                                text: "✕"
                                color: "#a89984"
                                font.family: "FiraCode Nerd Font"
                                font.pixelSize: 10
                            }

                            MouseArea {
                                anchors.fill: closeText
                                anchors.margins: -4
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onEntered: closeText.color = theme.error
                                onExited: closeText.color = "#a89984"
                                onClicked: win.closePopup()
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
                                            Quickshell.execDetached(["sh", "-c", "mkdir -p \"" + root.screenshotDir + "\" && FILE=\"" + root.screenshotDir + "/Screenshot_$(date '+%Y-%m-%d_%H.%M.%S').png\" && grim -g \"$(" + slurp + ")\" \"$FILE\" && swappy -f \"$FILE\" -o \"$FILE\" && wl-copy < \"$FILE\" && \"" + root.helperPath + "\" add-asset screenshot \"$FILE\""]);
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
                                            Quickshell.execDetached(["sh", "-c", "grim -g \"$(" + slurp + ")\" - | wl-copy"]);
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
                                            Quickshell.execDetached(["sh", "-c", "grim -o \"$(hyprctl activeworkspace -j | jq -r '.monitor')\" - | wl-copy"]);
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
                                            Quickshell.execDetached(["sh", "-c", "mkdir -p \"" + root.screenshotDir + "\" && FILE=\"" + root.screenshotDir + "/Screenshot_$(date '+%Y-%m-%d_%H.%M.%S').png\" && grim -o \"$(hyprctl activeworkspace -j | jq -r '.monitor')\" \"$FILE\" && wl-copy < \"$FILE\" && \"" + root.helperPath + "\" add-asset screenshot \"$FILE\""]);
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
                                                if (flagsAdapter.recordAudio && flagsAdapter.recordMic)
                                                    audioArgs = "-a\"$(pactl get-default-sink).monitor\" -a\"$(pactl get-default-source)\"";
                                                else if (flagsAdapter.recordAudio)
                                                    audioArgs = "-a\"$(pactl get-default-sink).monitor\"";
                                                else if (flagsAdapter.recordMic)
                                                    audioArgs = "-a\"$(pactl get-default-source)\"";
                                                Quickshell.execDetached(["sh", "-c", "GEOM=$(slurp) && if [ ! -z \"$GEOM\" ]; then " + root.homeDir + "/.config/quickshell/osd/bin/osdctl show \"Recording Started\" \"bad\" 1200 && mkdir -p \"" + root.recordingDir + "\" && FILE=\"" + root.recordingDir + "/Recording_$(date '+%Y-%m-%d_%H.%M.%S').mp4\" && (wf-recorder " + audioArgs + " " + root.recorderExtraArgs() + " -g \"$GEOM\" -f \"$FILE\" ; \"" + root.helperPath + "\" add-asset recording \"$FILE\") ; fi"]);
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
                                            if (flagsAdapter.recordAudio && flagsAdapter.recordMic)
                                                audioArgs = "-a\"$(pactl get-default-sink).monitor\" -a\"$(pactl get-default-source)\"";
                                            else if (flagsAdapter.recordAudio)
                                                audioArgs = "-a\"$(pactl get-default-sink).monitor\"";
                                            else if (flagsAdapter.recordMic)
                                                audioArgs = "-a\"$(pactl get-default-source)\"";
                                            Quickshell.execDetached(["sh", "-c", root.homeDir + "/.config/quickshell/osd/bin/osdctl show \"Recording Started\" \"bad\" 1200 && mkdir -p \"" + root.recordingDir + "\" && FILE=\"" + root.recordingDir + "/Recording_$(date '+%Y-%m-%d_%H.%M.%S').mp4\" && (wf-recorder " + audioArgs + " " + root.recorderExtraArgs() + " -f \"$FILE\" ; \"" + root.helperPath + "\" add-asset recording \"$FILE\")"]);
                                        }
                                    }

                                }

                            }

                            // Audio & Mic configuration row
                            Row {
                                width: parent.width
                                spacing: 4
                                visible: !root.isRecording

                                Rectangle {
                                    width: (parent.width - 4) / 2
                                    height: 18
                                    color: flagsAdapter.recordAudio ? "#504945" : theme.bg_light
                                    border.width: 1
                                    border.color: flagsAdapter.recordAudio ? "#fe8019" : "#504945"

                                    Text {
                                        anchors.centerIn: parent
                                        text: (flagsAdapter.recordAudio ? "󰕾 " : "󰖁 ") + "System Audio"
                                        color: flagsAdapter.recordAudio ? "#fe8019" : "#a89984"
                                        font.family: "FiraCode Nerd Font"
                                        font.pixelSize: 8
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        onEntered: parent.border.color = flagsAdapter.recordAudio ? "#fe8019" : theme.accent
                                        onExited: parent.border.color = flagsAdapter.recordAudio ? "#fe8019" : "#504945"
                                        onClicked: flagsAdapter.recordAudio = !flagsAdapter.recordAudio
                                    }

                                }

                                Rectangle {
                                    width: (parent.width - 4) / 2
                                    height: 18
                                    color: flagsAdapter.recordMic ? "#504945" : theme.bg_light
                                    border.width: 1
                                    border.color: flagsAdapter.recordMic ? "#fe8019" : "#504945"

                                    Text {
                                        anchors.centerIn: parent
                                        text: (flagsAdapter.recordMic ? "󰍬 " : "󰍭 ") + "Microphone"
                                        color: flagsAdapter.recordMic ? "#fe8019" : "#a89984"
                                        font.family: "FiraCode Nerd Font"
                                        font.pixelSize: 8
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        onEntered: parent.border.color = flagsAdapter.recordMic ? "#fe8019" : theme.accent
                                        onExited: parent.border.color = flagsAdapter.recordMic ? "#fe8019" : "#504945"
                                        onClicked: flagsAdapter.recordMic = !flagsAdapter.recordMic
                                    }

                                }

                            }

                            // Recording options: 2x2 grid
                            GridLayout {
                                width: parent.width
                                columns: 2
                                columnSpacing: 6
                                rowSpacing: 2
                                visible: !root.isRecording

                                Item {
                                    Layout.preferredWidth: fpsText.implicitWidth
                                    Layout.preferredHeight: 14
                                    Layout.alignment: Qt.AlignLeft

                                    Text {
                                        id: fpsText

                                        anchors.centerIn: parent
                                        text: "󰈐 FPS: " + (flagsAdapter.recordFps === "native" ? "native (" + root.monitorFps + ")" : flagsAdapter.recordFps)
                                        color: theme.accent
                                        font.family: "FiraCode Nerd Font"
                                        font.pixelSize: 8
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            var arr = root.recordFpsOptions;
                                            var i = arr.indexOf(flagsAdapter.recordFps);
                                            flagsAdapter.recordFps = arr[(i + 1) % arr.length];
                                        }
                                    }

                                }

                                Item {
                                    Layout.preferredWidth: qualityText.implicitWidth
                                    Layout.preferredHeight: 14
                                    Layout.alignment: Qt.AlignLeft

                                    Text {
                                        id: qualityText

                                        anchors.centerIn: parent
                                        text: "󰊢 Quality: " + flagsAdapter.recordQuality
                                        color: theme.accent
                                        font.family: "FiraCode Nerd Font"
                                        font.pixelSize: 8
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            var arr = root.recordQualityOptions;
                                            var i = arr.indexOf(flagsAdapter.recordQuality);
                                            flagsAdapter.recordQuality = arr[(i + 1) % arr.length];
                                        }
                                    }

                                }

                                Item {
                                    Layout.preferredWidth: codecText.implicitWidth
                                    Layout.preferredHeight: 14
                                    Layout.alignment: Qt.AlignLeft

                                    Text {
                                        id: codecText

                                        anchors.centerIn: parent
                                        text: "󰈙 Codec: " + flagsAdapter.recordCodec
                                        color: theme.accent
                                        font.family: "FiraCode Nerd Font"
                                        font.pixelSize: 8
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            var arr = root.recordCodecs;
                                            var i = arr.indexOf(flagsAdapter.recordCodec);
                                            flagsAdapter.recordCodec = arr[(i + 1) % arr.length];
                                        }
                                    }

                                }

                                Item {
                                    Layout.preferredWidth: presetText.implicitWidth
                                    Layout.preferredHeight: 14
                                    Layout.alignment: Qt.AlignLeft

                                    Text {
                                        id: presetText

                                        anchors.centerIn: parent
                                        text: "󰓣 Preset: " + flagsAdapter.recordPreset
                                        color: theme.accent
                                        font.family: "FiraCode Nerd Font"
                                        font.pixelSize: 8
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            var arr = root.recordPresetOptions;
                                            var i = arr.indexOf(flagsAdapter.recordPreset);
                                            flagsAdapter.recordPreset = arr[(i + 1) % arr.length];
                                        }
                                    }

                                }

                            }

                            // COLOR PICKER + HISTORY
                            Column {
                                width: parent.width
                                spacing: 3
                                visible: !root.isRecording

                                RowLayout {
                                    width: parent.width
                                    spacing: 4

                                    Text {
                                        text: "Color Picker"
                                        color: "#a89984"
                                        font.family: "FiraCode Nerd Font"
                                        font.pixelSize: 8
                                        font.bold: true
                                        Layout.alignment: Qt.AlignVCenter
                                    }

                                    Item {
                                        Layout.fillWidth: true
                                        height: 1
                                    }

                                    Item {
                                        id: refreshBtn

                                        implicitWidth: refreshText.implicitWidth + 6
                                        implicitHeight: refreshText.implicitHeight + 4
                                        Layout.alignment: Qt.AlignVCenter

                                        Text {
                                            id: refreshText

                                            anchors.centerIn: parent
                                            text: "↻"
                                            color: "#928374"
                                            font.family: "FiraCode Nerd Font"
                                            font.pixelSize: 9
                                        }

                                        MouseArea {
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onEntered: refreshText.color = theme.accent
                                            onExited: refreshText.color = "#928374"
                                            onClicked: {
                                                root.updateStatus();
                                            }
                                        }

                                    }

                                    Item {
                                        id: clearBtn

                                        visible: root.colors.length > 0
                                        implicitWidth: clearText.implicitWidth + 6
                                        implicitHeight: clearText.implicitHeight + 4
                                        Layout.alignment: Qt.AlignVCenter

                                        Text {
                                            id: clearText

                                            anchors.centerIn: parent
                                            text: "clear"
                                            color: "#928374"
                                            font.family: "FiraCode Nerd Font"
                                            font.pixelSize: 7
                                        }

                                        MouseArea {
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onEntered: clearText.color = theme.error
                                            onExited: clearText.color = "#928374"
                                            onClicked: {
                                                Quickshell.execDetached([root.helperPath, "clear-colors"]);
                                                root.updateStatus();
                                            }
                                        }

                                    }

                                }

                                Row {
                                    width: parent.width
                                    spacing: 4

                                    // Square Pick Color button
                                    Rectangle {
                                        width: 24
                                        height: 24
                                        color: theme.bg_light
                                        border.width: 1
                                        border.color: "#504945"
                                        radius: 2

                                        Text {
                                            anchors.centerIn: parent
                                            text: "󰏘"
                                            color: theme.accent
                                            font.family: "FiraCode Nerd Font"
                                            font.pixelSize: 12
                                        }

                                        MouseArea {
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onEntered: parent.border.color = theme.accent
                                            onExited: parent.border.color = "#504945"
                                            onClicked: {
                                                root.requestClose();
                                                Quickshell.execDetached([root.helperPath, "pick-color"]);
                                            }
                                        }

                                    }

                                    // Color history swatches
                                    ListView {
                                        width: parent.width - 28
                                        height: 24
                                        orientation: ListView.Horizontal
                                        spacing: 4
                                        clip: true
                                        interactive: false
                                        model: colorModel

                                        delegate: Item {
                                            id: colorDelegate

                                            required property var modelData
                                            property string hex: modelData ? modelData.hex : ""
                                            property int colorId: modelData ? modelData.id : -1

                                            width: 24
                                            height: 24

                                            Rectangle {
                                                id: swatch

                                                anchors.fill: parent
                                                radius: 2
                                                color: colorDelegate.hex
                                                border.width: 1
                                                border.color: "#504945"
                                            }

                                            Rectangle {
                                                id: hoverRing

                                                anchors.fill: swatch
                                                anchors.margins: -2
                                                color: "transparent"
                                                border.width: 1
                                                border.color: "transparent"
                                                radius: 3
                                            }

                                            MouseArea {
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor
                                                onEntered: hoverRing.border.color = theme.accent
                                                onExited: hoverRing.border.color = "transparent"
                                                onClicked: {
                                                    Quickshell.execDetached(["wl-copy", colorDelegate.hex]);
                                                }
                                                onPressAndHold: {
                                                    Quickshell.execDetached([root.helperPath, "remove-color", String(colorDelegate.colorId)]);
                                                    root.updateStatus();
                                                }
                                            }

                                        }

                                    }

                                }

                                Text {
                                    visible: root.colors.length === 0
                                    text: "no colors picked yet"
                                    color: "#928374"
                                    font.family: "FiraCode Nerd Font"
                                    font.pixelSize: 7
                                    font.italic: true
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

                            Item {
                                id: targetDirHeader

                                property bool expanded: false

                                width: parent.width
                                height: 14

                                Text {
                                    anchors.left: parent.left
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: "Target Directory  " + (targetDirHeader.expanded ? "v" : ">")
                                    color: "#a89984"
                                    font.family: "FiraCode Nerd Font"
                                    font.pixelSize: 8
                                    font.bold: true
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: targetDirHeader.expanded = !targetDirHeader.expanded
                                }

                            }

                            Column {
                                width: parent.width
                                spacing: 3
                                clip: true
                                height: targetDirHeader.expanded ? implicitHeight : 0
                                opacity: targetDirHeader.expanded ? 1 : 0

                                // Screenshot location
                                Row {
                                    width: parent.width
                                    spacing: 4

                                    Text {
                                        text: "Screenshot:"
                                        color: "#a89984"
                                        font.family: "FiraCode Nerd Font"
                                        font.pixelSize: 7
                                        anchors.verticalCenter: parent.verticalCenter
                                        width: 50
                                    }

                                    Rectangle {
                                        id: scrBox

                                        property bool editing: false
                                        property alias editText: scrInput.text

                                        width: parent.width - 74
                                        height: 18
                                        color: "transparent"

                                        Text {
                                            anchors.left: parent.left
                                            anchors.right: parent.right
                                            anchors.verticalCenter: parent.verticalCenter
                                            anchors.leftMargin: 2
                                            anchors.rightMargin: 2
                                            visible: !scrBox.editing
                                            text: root.screenshotDir
                                            color: theme.accent
                                            font.family: "FiraCode Nerd Font"
                                            font.pixelSize: 7
                                            elide: Text.ElideRight
                                            verticalAlignment: Text.AlignVCenter
                                        }

                                        TextInput {
                                            id: scrInput

                                            anchors.left: parent.left
                                            anchors.right: parent.right
                                            anchors.top: parent.top
                                            anchors.bottom: parent.bottom
                                            anchors.leftMargin: 2
                                            anchors.rightMargin: 2
                                            visible: scrBox.editing
                                            verticalAlignment: TextInput.AlignVCenter
                                            text: root.screenshotDir
                                            color: theme.accent
                                            font.family: "FiraCode Nerd Font"
                                            font.pixelSize: 7
                                            selectByMouse: true
                                            onAccepted: {
                                                Quickshell.execDetached([root.helperPath, "set-screenshot-dir", text]);
                                                scrBox.editing = false;
                                                root.updateStatus();
                                            }
                                            onActiveFocusChanged: {
                                                if (!activeFocus)
                                                    scrBox.editing = false;

                                            }
                                        }

                                        MouseArea {
                                            anchors.fill: parent
                                            enabled: !scrBox.editing
                                            cursorShape: Qt.IBeamCursor
                                            onClicked: {
                                                scrInput.text = root.screenshotDir;
                                                scrBox.editing = true;
                                                scrInput.forceActiveFocus();
                                                scrInput.selectAll();
                                            }
                                        }

                                        Rectangle {
                                            anchors.left: parent.left
                                            anchors.right: parent.right
                                            anchors.bottom: parent.bottom
                                            height: 1
                                            color: theme.bg_light
                                        }

                                    }

                                    Rectangle {
                                        width: 20
                                        height: 18
                                        color: "transparent"
                                        border.width: 0

                                        Text {
                                            anchors.centerIn: parent
                                            text: "󰉋"
                                            color: theme.accent
                                            font.family: "FiraCode Nerd Font"
                                            font.pixelSize: 8
                                        }

                                        MouseArea {
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: browseScreenshotProc.running = true
                                        }

                                    }

                                }

                                // Recording location
                                Row {
                                    width: parent.width
                                    spacing: 4

                                    Text {
                                        text: "Recording:"
                                        color: "#a89984"
                                        font.family: "FiraCode Nerd Font"
                                        font.pixelSize: 7
                                        anchors.verticalCenter: parent.verticalCenter
                                        width: 50
                                    }

                                    Rectangle {
                                        id: recBox

                                        property bool editing: false
                                        property alias editText: recInput.text

                                        width: parent.width - 74
                                        height: 18
                                        color: "transparent"

                                        Text {
                                            anchors.left: parent.left
                                            anchors.right: parent.right
                                            anchors.verticalCenter: parent.verticalCenter
                                            anchors.leftMargin: 2
                                            anchors.rightMargin: 2
                                            visible: !recBox.editing
                                            text: root.recordingDir
                                            color: theme.accent
                                            font.family: "FiraCode Nerd Font"
                                            font.pixelSize: 7
                                            elide: Text.ElideRight
                                            verticalAlignment: Text.AlignVCenter
                                        }

                                        TextInput {
                                            id: recInput

                                            anchors.left: parent.left
                                            anchors.right: parent.right
                                            anchors.top: parent.top
                                            anchors.bottom: parent.bottom
                                            anchors.leftMargin: 2
                                            anchors.rightMargin: 2
                                            visible: recBox.editing
                                            verticalAlignment: TextInput.AlignVCenter
                                            text: root.recordingDir
                                            color: theme.accent
                                            font.family: "FiraCode Nerd Font"
                                            font.pixelSize: 7
                                            selectByMouse: true
                                            onAccepted: {
                                                Quickshell.execDetached([root.helperPath, "set-recording-dir", text]);
                                                recBox.editing = false;
                                                root.updateStatus();
                                            }
                                            onActiveFocusChanged: {
                                                if (!activeFocus)
                                                    recBox.editing = false;

                                            }
                                        }

                                        MouseArea {
                                            anchors.fill: parent
                                            enabled: !recBox.editing
                                            cursorShape: Qt.IBeamCursor
                                            onClicked: {
                                                recInput.text = root.recordingDir;
                                                recBox.editing = true;
                                                recInput.forceActiveFocus();
                                                recInput.selectAll();
                                            }
                                        }

                                        Rectangle {
                                            anchors.left: parent.left
                                            anchors.right: parent.right
                                            anchors.bottom: parent.bottom
                                            height: 1
                                            color: theme.bg_light
                                        }

                                    }

                                    Rectangle {
                                        width: 20
                                        height: 18
                                        color: "transparent"
                                        border.width: 0

                                        Text {
                                            anchors.centerIn: parent
                                            text: "󰉋"
                                            color: theme.accent
                                            font.family: "FiraCode Nerd Font"
                                            font.pixelSize: 8
                                        }

                                        MouseArea {
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: browseRecordingProc.running = true
                                        }

                                    }

                                }

                                Behavior on height {
                                    NumberAnimation {
                                        duration: 180
                                        easing.type: Easing.InOutQuad
                                    }

                                }

                                Behavior on opacity {
                                    NumberAnimation {
                                        duration: 180
                                        easing.type: Easing.InOutQuad
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
                                            onClicked: {
                                                root.activeHistoryTab = "ALL";
                                                root.closeEditor();
                                            }
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
                                            onClicked: {
                                                root.activeHistoryTab = "OCR";
                                                root.closeEditor();
                                            }
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
                                            Quickshell.execDetached([root.helperPath, "clear-all"]);
                                            root.closeEditor();
                                            root.updateStatus();
                                        }
                                    }

                                }

                            }

                            // ALL tab: filter bar + asset grid
                            Column {
                                width: parent.width
                                spacing: 4
                                visible: root.activeHistoryTab === "ALL"

                                // Filter bar
                                Column {
                                    width: parent.width
                                    spacing: 3

                                    // Search input
                                    Rectangle {
                                        width: parent.width
                                        height: 16
                                        color: "transparent"

                                        TextField {
                                            id: searchField

                                            anchors.left: parent.left
                                            anchors.right: parent.right
                                            anchors.top: parent.top
                                            anchors.bottom: parent.bottom
                                            anchors.leftMargin: 2
                                            anchors.rightMargin: 2
                                            background: null
                                            color: theme.accent
                                            placeholderText: "search filename or tag"
                                            placeholderTextColor: "#928374"
                                            font.family: "FiraCode Nerd Font"
                                            font.pixelSize: 8
                                            verticalAlignment: TextInput.AlignVCenter
                                            text: root.filterText
                                            onTextChanged: root.filterText = text
                                            Keys.onEscapePressed: {
                                                text = "";
                                                root.filterText = "";
                                            }
                                        }

                                        Rectangle {
                                            anchors.left: parent.left
                                            anchors.right: parent.right
                                            anchors.bottom: parent.bottom
                                            height: 1
                                            color: theme.bg_light
                                        }

                                    }

                                    // Tag chip row
                                    Flow {
                                        width: parent.width
                                        spacing: 3

                                        Repeater {
                                            model: root.allTags.slice(0, 8)

                                            delegate: Rectangle {
                                                height: 12
                                                width: chipText.implicitWidth + 10
                                                color: root.activeTag === modelData.name ? theme.accent : theme.bg_light
                                                border.width: 1
                                                border.color: root.activeTag === modelData.name ? theme.accent : "#504945"
                                                radius: 2

                                                Text {
                                                    id: chipText

                                                    anchors.centerIn: parent
                                                    text: modelData.name + " " + modelData.count
                                                    color: root.activeTag === modelData.name ? theme.bg : theme.accent
                                                    font.family: "FiraCode Nerd Font"
                                                    font.pixelSize: 7
                                                }

                                                MouseArea {
                                                    anchors.fill: parent
                                                    onClicked: {
                                                        if (root.activeTag === modelData.name)
                                                            root.activeTag = "";
                                                        else
                                                            root.activeTag = modelData.name;
                                                        root.closeEditor();
                                                    }
                                                }

                                            }

                                        }

                                    }

                                    // Clear filter link
                                    Text {
                                        visible: root.filterText !== "" || root.activeTag !== ""
                                        text: "clear filters"
                                        color: "#928374"
                                        font.family: "FiraCode Nerd Font"
                                        font.pixelSize: 7

                                        MouseArea {
                                            anchors.fill: parent
                                            onClicked: {
                                                root.filterText = "";
                                                root.activeTag = "";
                                                searchField.text = "";
                                            }
                                        }

                                    }

                                }

                                // Asset grid
                                Grid {
                                    width: parent.width
                                    columns: 4
                                    spacing: 4

                                    Repeater {
                                        model: root.filteredAssets().slice(root.currentPage * 20, (root.currentPage + 1) * 20)

                                        delegate: Column {
                                            id: tileCol

                                            property var asset: modelData

                                            width: (mainLayout.width - 12) / 4
                                            spacing: 2

                                            Rectangle {
                                                id: tileBox

                                                width: parent.width
                                                height: parent.width
                                                color: theme.bg_dark
                                                border.width: 1
                                                border.color: tileMouse.containsMouse ? theme.accent : theme.bg_light
                                                opacity: modelData.deleted ? 0.4 : 1

                                                Image {
                                                    id: tileImage

                                                    anchors.fill: parent
                                                    anchors.margins: 1
                                                    source: modelData.deleted ? "" : ("file://" + modelData.thumbnail_path)
                                                    sourceSize.width: 120
                                                    sourceSize.height: 120
                                                    fillMode: Image.PreserveAspectCrop
                                                    asynchronous: true
                                                    cache: true
                                                    visible: status !== Image.Error && !modelData.deleted
                                                }

                                                Text {
                                                    anchors.centerIn: parent
                                                    text: modelData.type === "screenshot" ? "󰄀" : "󰑋"
                                                    color: modelData.type === "screenshot" ? "#8ec07c" : "#fe8019"
                                                    font.family: "FiraCode Nerd Font"
                                                    font.pixelSize: 12
                                                    visible: !tileImage.visible && !modelData.deleted
                                                }

                                                Text {
                                                    anchors.centerIn: parent
                                                    text: "󰀨"
                                                    color: "#fb4934"
                                                    font.family: "FiraCode Nerd Font"
                                                    font.pixelSize: 14
                                                    visible: modelData.deleted
                                                }

                                                Rectangle {
                                                    visible: modelData.deleted
                                                    anchors.top: parent.top
                                                    anchors.right: parent.right
                                                    anchors.margins: 2
                                                    width: 28
                                                    height: 9
                                                    color: "#fb4934"
                                                    radius: 2

                                                    Text {
                                                        anchors.centerIn: parent
                                                        text: "deleted"
                                                        color: "#1d2021"
                                                        font.family: "FiraCode Nerd Font"
                                                        font.pixelSize: 6
                                                        font.bold: true
                                                    }

                                                }

                                                // Tag strip on hover
                                                Rectangle {
                                                    id: tagStrip

                                                    visible: tileMouse.containsMouse && modelData.tags.length > 0
                                                    anchors.left: parent.left
                                                    anchors.right: parent.right
                                                    anchors.bottom: parent.bottom
                                                    height: 12
                                                    color: "#1d2021"
                                                    opacity: 0.85

                                                    Flow {
                                                        anchors.fill: parent
                                                        anchors.margins: 1
                                                        spacing: 1

                                                        Repeater {
                                                            model: modelData.tags.slice(0, 3)

                                                            delegate: Rectangle {
                                                                height: 9
                                                                width: tstripText.implicitWidth + 6
                                                                color: theme.accent
                                                                radius: 1

                                                                Text {
                                                                    id: tstripText

                                                                    anchors.centerIn: parent
                                                                    text: modelData
                                                                    color: theme.bg
                                                                    font.family: "FiraCode Nerd Font"
                                                                    font.pixelSize: 6
                                                                }

                                                            }

                                                        }

                                                        Text {
                                                            visible: modelData.tags.length > 3
                                                            text: "+" + (modelData.tags.length - 3)
                                                            color: theme.accent
                                                            font.family: "FiraCode Nerd Font"
                                                            font.pixelSize: 6
                                                        }

                                                    }

                                                }

                                                MouseArea {
                                                    id: tileMouse

                                                    anchors.fill: parent
                                                    hoverEnabled: true
                                                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                                                    onClicked: function(mouse) {
                                                        if (mouse.button === Qt.RightButton) {
                                                            root.previewAsset = modelData;
                                                            return ;
                                                        }
                                                        if (modelData.deleted)
                                                            return ;

                                                        Quickshell.execDetached(["sh", "-c", "echo -n '" + modelData.source_path + "' | wl-copy && notify-send -t 1000 -a 'Media' 'Copied path to clipboard'"]);
                                                        root.closePreview();
                                                        win.closePopup();
                                                    }
                                                }

                                            }

                                            Text {
                                                width: parent.width
                                                horizontalAlignment: Text.AlignHCenter
                                                text: root.basename(modelData.source_path)
                                                color: theme.accent
                                                font.family: "FiraCode Nerd Font"
                                                font.pixelSize: 7
                                                elide: Text.ElideRight
                                            }

                                        }

                                    }

                                }

                                // Pagination controls
                                Row {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    spacing: 12
                                    visible: root.filteredAssets().length > 20

                                    Text {
                                        text: "◀ Prev"
                                        color: root.currentPage > 0 ? theme.accent : "#504945"
                                        font.family: "FiraCode Nerd Font"
                                        font.pixelSize: 8
                                        font.bold: true

                                        MouseArea {
                                            anchors.fill: parent
                                            enabled: root.currentPage > 0
                                            onClicked: {
                                                root.currentPage--;
                                                root.closePreview();
                                            }
                                        }

                                    }

                                    Text {
                                        text: "Page " + (root.currentPage + 1) + " of " + Math.ceil(root.filteredAssets().length / 20)
                                        color: "#928374"
                                        font.family: "FiraCode Nerd Font"
                                        font.pixelSize: 8
                                    }

                                    Text {
                                        text: "Next ▶"
                                        color: (root.currentPage + 1) * 20 < root.filteredAssets().length ? theme.accent : "#504945"
                                        font.family: "FiraCode Nerd Font"
                                        font.pixelSize: 8
                                        font.bold: true

                                        MouseArea {
                                            anchors.fill: parent
                                            enabled: (root.currentPage + 1) * 20 < root.filteredAssets().length
                                            onClicked: {
                                                root.currentPage++;
                                                root.closePreview();
                                            }
                                        }

                                    }

                                }

                                // "Showing N of M" footer
                                Text {
                                    visible: root.filteredAssets().length > 0
                                    text: "showing " + (root.filteredAssets().length === 0 ? "0" : ((root.currentPage * 20 + 1) + "-" + Math.min((root.currentPage + 1) * 20, root.filteredAssets().length))) + " of " + root.filteredAssets().length
                                    color: "#928374"
                                    font.family: "FiraCode Nerd Font"
                                    font.pixelSize: 7
                                }

                            }

                            // Asset editor popup (right-click on a tile)
                            Popup {
                                id: assetEditor

                                property var editorAsset: root.expandedAssetId >= 0 ? root.assetById(root.expandedAssetId) : null

                                visible: root.expandedAssetId >= 0
                                width: mainLayout.width - 16
                                x: 8
                                y: 0
                                padding: 6
                                modal: true
                                focus: true
                                closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
                                onClosed: root.closeEditor()

                                background: Rectangle {
                                    color: theme.bg
                                    border.width: 1
                                    border.color: theme.accent
                                    radius: 2
                                }

                                contentItem: Column {
                                    width: assetEditor.width
                                    spacing: 4

                                    Text {
                                        width: parent.width
                                        text: assetEditor.editorAsset ? root.basename(assetEditor.editorAsset.source_path) : ""
                                        color: theme.accent
                                        font.family: "FiraCode Nerd Font"
                                        font.pixelSize: 8
                                        font.bold: true
                                        elide: Text.ElideMiddle
                                    }

                                    Text {
                                        visible: assetEditor.editorAsset && assetEditor.editorAsset.deleted
                                        text: "file missing"
                                        color: "#fb4934"
                                        font.family: "FiraCode Nerd Font"
                                        font.pixelSize: 7
                                    }

                                    // Existing tags row
                                    Flow {
                                        width: parent.width
                                        spacing: 3

                                        Repeater {
                                            model: assetEditor.editorAsset ? assetEditor.editorAsset.tags : []

                                            delegate: Rectangle {
                                                height: 12
                                                width: tagInnerText.implicitWidth + 14
                                                color: theme.bg_light
                                                border.width: 1
                                                border.color: theme.accent
                                                radius: 2

                                                Text {
                                                    id: tagInnerText

                                                    anchors.verticalCenter: parent.verticalCenter
                                                    anchors.left: parent.left
                                                    anchors.leftMargin: 4
                                                    text: modelData
                                                    color: theme.accent
                                                    font.family: "FiraCode Nerd Font"
                                                    font.pixelSize: 7
                                                }

                                                Text {
                                                    anchors.verticalCenter: parent.verticalCenter
                                                    anchors.right: parent.right
                                                    anchors.rightMargin: 3
                                                    text: "×"
                                                    color: "#fb4934"
                                                    font.family: "FiraCode Nerd Font"
                                                    font.pixelSize: 9
                                                }

                                                MouseArea {
                                                    anchors.fill: parent
                                                    onClicked: root.removeTagFromAsset(assetEditor.editorAsset, modelData)
                                                }

                                            }

                                        }

                                        // + add button
                                        Rectangle {
                                            visible: !tagInput.visible
                                            height: 12
                                            width: addBtnText.implicitWidth + 10
                                            color: theme.bg_light
                                            border.width: 1
                                            border.color: "#504945"
                                            radius: 2

                                            Text {
                                                id: addBtnText

                                                anchors.centerIn: parent
                                                text: "+ add tag"
                                                color: theme.accent
                                                font.family: "FiraCode Nerd Font"
                                                font.pixelSize: 7
                                            }

                                            MouseArea {
                                                anchors.fill: parent
                                                onClicked: {
                                                    tagInput.visible = true;
                                                    tagInput.forceActiveFocus();
                                                }
                                            }

                                        }

                                    }

                                    // Tag input
                                    Rectangle {
                                        id: tagInputWrap

                                        width: parent.width
                                        height: tagInput.visible ? tagInput.implicitHeight + 4 : 0
                                        visible: tagInput.visible
                                        color: theme.bg_dark
                                        border.width: 1
                                        border.color: theme.accent

                                        TextField {
                                            id: tagInput

                                            anchors.fill: parent
                                            anchors.leftMargin: 3
                                            anchors.rightMargin: 3
                                            background: null
                                            color: theme.accent
                                            placeholderText: "type and press enter"
                                            placeholderTextColor: "#928374"
                                            font.family: "FiraCode Nerd Font"
                                            font.pixelSize: 7
                                            text: root.tagDraft
                                            onTextChanged: {
                                                root.tagDraft = text;
                                                root.refreshTagSuggestions();
                                            }
                                            onAccepted: {
                                                root.commitTagDraft();
                                                visible = false;
                                            }
                                            Keys.onEscapePressed: {
                                                text = "";
                                                root.tagDraft = "";
                                                visible = false;
                                            }
                                        }

                                    }

                                    // Suggestions
                                    Column {
                                        width: parent.width
                                        spacing: 1
                                        visible: tagInput.visible && root.tagSuggestions.length > 0

                                        Repeater {
                                            model: root.tagSuggestions

                                            delegate: Rectangle {
                                                width: parent.width
                                                height: 11
                                                color: theme.bg_light

                                                Text {
                                                    anchors.left: parent.left
                                                    anchors.leftMargin: 4
                                                    anchors.verticalCenter: parent.verticalCenter
                                                    text: modelData
                                                    color: theme.accent
                                                    font.family: "FiraCode Nerd Font"
                                                    font.pixelSize: 7
                                                }

                                                MouseArea {
                                                    anchors.fill: parent
                                                    onClicked: {
                                                        root.commitTagDraft(modelData);
                                                        tagInput.visible = false;
                                                    }
                                                }

                                            }

                                        }

                                    }

                                    // Actions
                                    Row {
                                        spacing: 4
                                        anchors.right: parent.right

                                        Rectangle {
                                            width: 32
                                            height: 14
                                            color: theme.bg_light
                                            border.width: 1
                                            border.color: "#504945"

                                            Text {
                                                anchors.centerIn: parent
                                                text: "Open"
                                                color: theme.accent
                                                font.family: "FiraCode Nerd Font"
                                                font.pixelSize: 7
                                            }

                                            MouseArea {
                                                anchors.fill: parent
                                                onClicked: {
                                                    if (assetEditor.editorAsset) {
                                                        Quickshell.execDetached(["xdg-open", assetEditor.editorAsset.source_path]);
                                                        root.closeEditor();
                                                    }
                                                }
                                            }

                                        }

                                        Rectangle {
                                            width: 38
                                            height: 14
                                            color: theme.bg_light
                                            border.width: 1
                                            border.color: "#504945"

                                            Text {
                                                anchors.centerIn: parent
                                                text: "Reveal"
                                                color: theme.accent
                                                font.family: "FiraCode Nerd Font"
                                                font.pixelSize: 7
                                            }

                                            MouseArea {
                                                anchors.fill: parent
                                                onClicked: {
                                                    if (assetEditor.editorAsset) {
                                                        var dir = assetEditor.editorAsset.source_path.substring(0, assetEditor.editorAsset.source_path.lastIndexOf("/"));
                                                        Quickshell.execDetached(["xdg-open", dir]);
                                                        root.closeEditor();
                                                    }
                                                }
                                            }

                                        }

                                        Rectangle {
                                            width: 38
                                            height: 14
                                            color: assetEditor.editorAsset && assetEditor.editorAsset.deleted ? "#fb4934" : theme.bg_light
                                            border.width: 1
                                            border.color: assetEditor.editorAsset && assetEditor.editorAsset.deleted ? "#fb4934" : "#504945"

                                            Text {
                                                anchors.centerIn: parent
                                                text: "Purge"
                                                color: assetEditor.editorAsset && assetEditor.editorAsset.deleted ? "#1d2021" : theme.accent
                                                font.family: "FiraCode Nerd Font"
                                                font.pixelSize: 7
                                            }

                                            MouseArea {
                                                anchors.fill: parent
                                                onClicked: {
                                                    if (assetEditor.editorAsset)
                                                        root.purgeAsset(assetEditor.editorAsset);

                                                }
                                            }

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
                                        spacing: 0

                                        // Collapsible Header Row
                                        Rectangle {
                                            width: parent.width
                                            height: 18
                                            color: theme.bg_dark

                                            Item {
                                                anchors.fill: parent
                                                anchors.leftMargin: 6
                                                anchors.rightMargin: 6
                                                anchors.topMargin: 2
                                                anchors.bottomMargin: 2

                                                Text {
                                                    id: ocrHeaderVal

                                                    anchors.left: parent.left
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
                                                acceptedButtons: Qt.LeftButton | Qt.RightButton
                                                onClicked: function(mouse) {
                                                    if (mouse.button === Qt.RightButton) {
                                                        root.previewOcrText = modelData.detail;
                                                        return ;
                                                    }
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
                                            height: expandedLayout.childrenRect.height + 10
                                            color: theme.bg_dark
                                            visible: root.expandedOcrIndex === index

                                            Column {
                                                id: expandedLayout

                                                anchors.top: parent.top
                                                anchors.left: parent.left
                                                anchors.right: parent.right
                                                anchors.margins: 4
                                                spacing: 4

                                                // Subtle separator
                                                Rectangle {
                                                    width: parent.width
                                                    height: 1
                                                    color: "#504945"
                                                }

                                                Flickable {
                                                    id: ocrFlick

                                                    anchors.left: parent.left
                                                    anchors.right: parent.right
                                                    height: Math.min(ocrContentText.implicitHeight, 80)
                                                    contentHeight: ocrContentText.implicitHeight
                                                    clip: true
                                                    flickableDirection: Flickable.VerticalFlick
                                                    boundsBehavior: Flickable.StopAtBounds

                                                    Text {
                                                        id: ocrContentText

                                                        width: ocrFlick.width
                                                        text: modelData.detail
                                                        color: theme.accent
                                                        font.family: "FiraCode Nerd Font"
                                                        font.pixelSize: 8
                                                        wrapMode: Text.Wrap
                                                    }

                                                    ScrollBar.vertical: ScrollBar {
                                                        policy: ocrFlick.contentHeight > ocrFlick.height ? ScrollBar.AlwaysOn : ScrollBar.AlwaysOff
                                                        width: 3

                                                        contentItem: Rectangle {
                                                            radius: 2
                                                            color: "#928374"
                                                            opacity: 0.6
                                                        }

                                                    }

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

                Loader {
                    id: previewLoader

                    active: root.previewAsset !== null || root.previewOcrText !== ""
                    source: "PreviewWindow.qml"
                    onLoaded: {
                        item.rootObj = root;
                        item.winObj = win;
                        item.themeObj = theme;
                    }
                }

            }

        }

    }

}
