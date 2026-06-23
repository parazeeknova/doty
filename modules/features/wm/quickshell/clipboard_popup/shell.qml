import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland

Scope {
    id: root

    property string homeDir: Quickshell.env("HOME")
    // State properties
    property var rawEntries: []
    property var filteredEntries: []
    property string searchQuery: ""
    property int selectedIndex: 0
    property int activeWindow: 0 // 0 = main popup, 1 = external preview popup
    property string currentPreviewText: ""
    // Theme tokens (Gruvbox Material Dark)
    readonly property color colorBgDark: "#e61d2021"
    // Sleek dark background
    readonly property color colorBgCell: theme.bg_dark
    // Item cell bg
    readonly property color colorBgActive: "#504945"
    // Selected cell bg
    readonly property color colorBorder: theme.accent
    // Accent border
    readonly property color colorText: theme.accent
    // Foreground text
    readonly property color colorTextMuted: "#a89984"
    // Muted text
    readonly property color colorHover: "#665c54"
    // Hover cell bg
    readonly property string fontName: "FiraCode Nerd Font"

    signal requestClose

    function refreshClipboard() {
        decodeScript.running = true;
    }

    function getPreviewType(entry) {
        if (!entry)
            return "text";

        if (entry.indexOf("binary data") !== -1)
            return "image";

        return "text";
    }

    function getEntryId(entry) {
        if (!entry)
            return "";

        var parts = entry.split("\t");
        return parts[0];
    }

    function getEntryText(entry) {
        if (!entry)
            return "";

        var parts = entry.split("\t");
        if (parts.length > 1)
            return parts.slice(1).join("\t").trim();

        return entry;
    }

    function hasPreview(entry) {
        if (!entry)
            return false;

        var text = getEntryText(entry);
        var type = getPreviewType(entry);
        if (type === "image")
            return true;

        if (isFile(text))
            return true;

        if (text.length > 80)
            return true;

        return false;
    }

    function isFile(text) {
        if (!text)
            return false;

        var trimmed = text.trim();
        if (trimmed.startsWith("/") || trimmed.startsWith("file://"))
            return true;

        return false;
    }

    function cleanFilePath(text) {
        var trimmed = text.trim();
        if (trimmed.startsWith("file://"))
            return trimmed.substring(7);

        return trimmed;
    }

    function getLineCount(text) {
        if (!text)
            return 0;

        return text.split("\n").length;
    }

    function getWordCount(text) {
        if (!text)
            return 0;

        return text.split(/\s+/).filter(Boolean).length;
    }

    function filterEntries() {
        if (searchQuery.trim() === "") {
            filteredEntries = rawEntries;
        } else {
            var temp = [];
            var query = searchQuery.toLowerCase();
            for (var i = 0; i < rawEntries.length; i++) {
                var txt = getEntryText(rawEntries[i]).toLowerCase();
                if (txt.indexOf(query) !== -1)
                    temp.push(rawEntries[i]);
            }
            filteredEntries = temp;
        }
        selectedIndex = 0;
    }

    function updatePreviewText() {
        decodeTextProc.running = false;
        if (root.filteredEntries && root.filteredEntries.length > root.selectedIndex) {
            var entry = root.filteredEntries[root.selectedIndex];
            var type = root.getPreviewType(entry);
            if (type === "text" && root.hasPreview(entry)) {
                decodeTextProc.entryText = entry;
                decodeTextProc.running = true;
            } else {
                root.currentPreviewText = root.getEntryText(entry);
            }
        } else {
            root.currentPreviewText = "";
        }
    }

    onSelectedIndexChanged: {
        updatePreviewText();
    }
    onFilteredEntriesChanged: {
        updatePreviewText();
    }
    Component.onCompleted: {
        refreshClipboard();
    }

    Theme {
        id: theme
    }

    IpcHandler {
        function close() {
            root.requestClose();
        }

        target: "clipboard_popup"
    }

    // Run the image decoding helper script
    Process {
        id: decodeScript

        command: [root.homeDir + "/.config/quickshell/clipboard_popup/decode_cliphist.sh"]
        running: false
        onExited: {
            // Once decoding is done, query the cliphist list
            cliphistListProc.running = true;
        }
    }

    // Query list of clipboard entries
    Process {
        id: cliphistListProc

        command: ["cliphist", "list"]
        running: false

        stdout: StdioCollector {
            onStreamFinished: {
                var lines = this.text.split("\n");
                var temp = [];
                for (var i = 0; i < lines.length; i++) {
                    var line = lines[i].trim();
                    if (line !== "")
                        temp.push(line);
                }
                root.rawEntries = temp;
                root.filterEntries();
            }
        }
    }

    // Copy selected entry
    Process {
        id: copyProc

        property string entryText: ""

        command: ["sh", "-c", "decoded=$(echo \"$1\" | cliphist decode); echo -n \"$decoded\" | wl-copy && notify-send -t 1000 -h string:x-canonical-private-synchronous:clip-notify -a \"clipboard\" -i \"edit-copy\" \"copied to clipboard\" \"$(echo -n \"$decoded\" | head -c 50)\"", "sh", entryText]
        running: false
        onExited: {
            root.requestClose();
        }
    }

    // Delete selected entry
    Process {
        id: deleteProc

        property string entryText: ""

        command: ["sh", "-c", "echo \"$1\" | cliphist delete", "sh", entryText]
        running: false
        onExited: {
            root.refreshClipboard();
        }
    }

    // Wipe all clipboard entries
    Process {
        id: wipeProc

        command: ["cliphist", "wipe"]
        running: false
        onExited: {
            root.refreshClipboard();
        }
    }

    // Decode text for preview
    Process {
        id: decodeTextProc

        property string entryText: ""

        command: ["sh", "-c", "echo \"$1\" | cliphist decode", "sh", entryText]
        running: false

        stdout: StdioCollector {
            onStreamFinished: {
                root.currentPreviewText = this.text;
            }
        }
    }

    // Render Window on each Screen
    Variants {
        model: Quickshell.screens

        delegate: Component {
            PanelWindow {
                id: win

                required property var modelData
                property bool isClosing: false
                property real animOffsetY: -350
                property real animOpacity: 0
                readonly property bool showPreview: root.filteredEntries && root.filteredEntries.length > root.selectedIndex ? root.hasPreview(root.filteredEntries[root.selectedIndex]) : false

                function closePopup() {
                    if (isClosing)
                        return;

                    isClosing = true;
                    exitAnim.start();
                }

                function handleUp() {
                    if (root.activeWindow === 1) {
                        previewScrollView.ScrollBar.vertical.decrease();
                    } else {
                        if (root.selectedIndex > 0) {
                            root.selectedIndex--;
                            listView.positionViewAtIndex(root.selectedIndex, ListView.Contain);
                        }
                    }
                }

                function handleDown() {
                    if (root.activeWindow === 1) {
                        previewScrollView.ScrollBar.vertical.increase();
                    } else {
                        if (root.selectedIndex < root.filteredEntries.length - 1) {
                            root.selectedIndex++;
                            listView.positionViewAtIndex(root.selectedIndex, ListView.Contain);
                        }
                    }
                }

                function handleEscape() {
                    win.closePopup();
                }

                function handleReturn() {
                    if (root.filteredEntries.length > 0) {
                        copyProc.entryText = root.filteredEntries[root.selectedIndex];
                        copyProc.running = true;
                    }
                }

                function handleTab() {
                    if (root.activeWindow === 0) {
                        if (win.showPreview)
                            root.activeWindow = 1;
                    } else {
                        root.activeWindow = 0;
                    }
                }

                screen: modelData
                WlrLayershell.namespace: "quickshell"
                WlrLayershell.layer: WlrLayer.Overlay
                WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
                exclusionMode: PanelWindow.ExclusionMode.Ignore
                focusable: true
                color: "transparent"
                implicitWidth: showPreview ? 528 : 200
                implicitHeight: 260
                Component.onCompleted: {
                    introAnim.start();
                    searchInput.forceActiveFocus();
                }

                Connections {
                    function onRequestClose() {
                        win.closePopup();
                    }

                    function onActiveWindowChanged() {
                        if (root.activeWindow === 0) {
                            searchInput.forceActiveFocus();
                        } else if (root.activeWindow === 1) {
                            if (win.showPreview)
                                mainContainer.forceActiveFocus();
                            else
                                root.activeWindow = 0;
                        }
                    }

                    target: root
                }

                anchors {
                    top: true
                    left: true
                }

                margins {
                    top: win.animOffsetY
                    left: 32
                }

                // Slide & Fade Animations
                ParallelAnimation {
                    id: introAnim

                    NumberAnimation {
                        target: win
                        property: "animOffsetY"
                        from: -350
                        to: 4
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

                ParallelAnimation {
                    id: exitAnim

                    onStopped: Qt.quit()

                    NumberAnimation {
                        target: win
                        property: "animOffsetY"
                        from: 4
                        to: -350
                        duration: 120
                        easing.type: Easing.OutCubic
                    }

                    NumberAnimation {
                        target: win
                        property: "animOpacity"
                        from: 1
                        to: 0
                        duration: 120
                        easing.type: Easing.OutCubic
                    }
                }

                // Click outside or focus loss to close
                HyprlandFocusGrab {
                    active: !win.isClosing
                    windows: [win]
                    onCleared: {
                        console.log("clipboard_popup: focus grab cleared, closing popup");
                        win.closePopup();
                    }
                    onActiveChanged: {
                        console.log("clipboard_popup: focus grab active status changed to:", active);
                    }
                }

                // Main Container (left card)
                Rectangle {
                    id: mainContainer

                    anchors.left: parent.left
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    width: 200
                    opacity: (root.activeWindow === 0) ? win.animOpacity : win.animOpacity * 0.4
                    color: theme.popupBgColor
                    border.width: 1
                    border.color: theme.accent
                    radius: 0
                    focus: true
                    Keys.onPressed: event => {
                        if (event.key === Qt.Key_Tab) {
                            win.handleTab();
                            event.accepted = true;
                        } else if (event.key === Qt.Key_Up) {
                            win.handleUp();
                            event.accepted = true;
                        } else if (event.key === Qt.Key_Down) {
                            win.handleDown();
                            event.accepted = true;
                        } else if (event.key === Qt.Key_Escape) {
                            win.handleEscape();
                            event.accepted = true;
                        } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                            win.handleReturn();
                            event.accepted = true;
                        }
                    }

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 4
                        spacing: 4

                        // Search Bar (Underline only, matching rofi inputbar)
                        Rectangle {
                            Layout.fillWidth: true
                            height: 16
                            color: "transparent"

                            TextInput {
                                id: searchInput

                                anchors.fill: parent
                                anchors.bottomMargin: 2
                                verticalAlignment: TextInput.AlignVCenter
                                color: theme.accent
                                font.family: root.fontName
                                font.pointSize: 8
                                focus: root.activeWindow === 0
                                Keys.onPressed: event => {
                                    if (event.key === Qt.Key_Tab) {
                                        win.handleTab();
                                        event.accepted = true;
                                    } else if (event.key === Qt.Key_Up) {
                                        win.handleUp();
                                        event.accepted = true;
                                    } else if (event.key === Qt.Key_Down) {
                                        win.handleDown();
                                        event.accepted = true;
                                    } else if (event.key === Qt.Key_Escape) {
                                        win.handleEscape();
                                        event.accepted = true;
                                    } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                                        win.handleReturn();
                                        event.accepted = true;
                                    } else if (event.key === Qt.Key_Delete) {
                                        if (root.filteredEntries.length > 0) {
                                            deleteProc.entryText = root.filteredEntries[root.selectedIndex];
                                            deleteProc.running = true;
                                        }
                                        event.accepted = true;
                                    }
                                }
                                onTextChanged: {
                                    root.searchQuery = text.toLowerCase();
                                    root.filterEntries();
                                }

                                Text {
                                    text: "search..."
                                    color: theme.secondary
                                    font.family: root.fontName
                                    font.pointSize: 8
                                    visible: searchInput.text === ""
                                    anchors.fill: parent
                                    verticalAlignment: Text.AlignVCenter
                                }
                            }

                            // Underline
                            Rectangle {
                                anchors.bottom: parent.bottom
                                width: parent.width
                                height: 1
                                color: (root.activeWindow === 0 && searchInput.activeFocus) ? theme.accent : theme.secondary
                            }
                        }

                        // List view
                        ListView {
                            id: listView

                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            clip: true
                            model: root.filteredEntries
                            spacing: 2

                            delegate: Rectangle {
                                property string previewType: root.getPreviewType(modelData)
                                property string entryId: root.getEntryId(modelData)
                                property string entryText: root.getEntryText(modelData)

                                width: listView.width
                                height: previewType === "image" ? 40 : 16
                                color: (root.selectedIndex === index) ? theme.bg_dark : "transparent"
                                radius: 0

                                MouseArea {
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    onEntered: {
                                        root.selectedIndex = index;
                                    }
                                    onClicked: {
                                        copyProc.entryText = modelData;
                                        copyProc.running = true;
                                    }
                                }

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 4
                                    anchors.rightMargin: 4
                                    spacing: 4

                                    // Preview (Text or Image)
                                    Rectangle {
                                        Layout.fillWidth: true
                                        Layout.fillHeight: true
                                        color: "transparent"

                                        // Image preview
                                        Image {
                                            visible: previewType === "image"
                                            anchors.fill: parent
                                            fillMode: Image.PreserveAspectFit
                                            horizontalAlignment: Image.AlignLeft
                                            source: "file:///tmp/clip_" + entryId + ".png"
                                            cache: false
                                        }

                                        // Text preview (Lowercase matching rofi)
                                        Text {
                                            visible: previewType === "text"
                                            anchors.fill: parent
                                            text: entryText.toLowerCase()
                                            color: (root.selectedIndex === index) ? theme.accent : theme.secondary
                                            font.family: root.fontName
                                            font.pointSize: 8
                                            elide: Text.ElideRight
                                            wrapMode: Text.NoWrap
                                            verticalAlignment: Text.AlignVCenter
                                            renderType: Text.NativeRendering
                                        }
                                    }

                                    // Indicator showing a preview is available
                                    Text {
                                        text: "󰍜"
                                        color: (root.selectedIndex === index) ? theme.accent : theme.secondary
                                        font.family: root.fontName
                                        font.pointSize: 8
                                        visible: root.hasPreview(modelData)
                                        renderType: Text.NativeRendering
                                        Layout.alignment: Qt.AlignVCenter
                                    }
                                }
                            }
                        }

                        // Bottom Row (total items & clear all)
                        RowLayout {
                            Layout.fillWidth: true
                            Layout.bottomMargin: 2
                            Layout.leftMargin: 4
                            Layout.rightMargin: 4

                            Text {
                                text: root.filteredEntries.length + " items"
                                font.family: root.fontName
                                font.pointSize: 8
                                font.italic: true
                                color: theme.secondary
                                renderType: Text.NativeRendering
                            }

                            Item {
                                Layout.fillWidth: true
                            }

                            Text {
                                text: "clear all"
                                font.family: root.fontName
                                font.pointSize: 8
                                color: clearAllMouseArea.containsMouse ? "#fb4934" : theme.secondary
                                renderType: Text.NativeRendering

                                MouseArea {
                                    id: clearAllMouseArea

                                    anchors.fill: parent
                                    hoverEnabled: true
                                    onClicked: {
                                        wipeProc.running = true;
                                    }
                                }
                            }
                        }
                    }

                    Behavior on opacity {
                        NumberAnimation {
                            duration: 100
                        }
                    }
                }

                // Preview Container (right card)
                Rectangle {
                    id: previewContainer

                    anchors.right: parent.right
                    anchors.top: parent.top
                    height: Math.min(260, previewLayout.implicitHeight + 8)
                    width: 320
                    opacity: win.showPreview ? ((root.activeWindow === 1) ? win.animOpacity : win.animOpacity * 0.6) : 0
                    visible: opacity > 0
                    color: theme.popupBgColor
                    border.width: 1
                    border.color: theme.accent
                    radius: 0

                    ColumnLayout {
                        id: previewLayout

                        anchors.fill: parent
                        anchors.margins: 4
                        spacing: 3

                        // Header (Title & Meta)
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 4

                            Text {
                                text: "󰈈 Preview"
                                color: theme.accent
                                font.family: root.fontName
                                font.pointSize: 7.5
                                font.bold: true
                                renderType: Text.NativeRendering
                            }

                            Item {
                                Layout.fillWidth: true
                            }

                            Text {
                                text: {
                                    var entry = root.filteredEntries[root.selectedIndex];
                                    if (!entry)
                                        return "";

                                    var type = root.getPreviewType(entry);
                                    if (type === "image")
                                        return "Image";

                                    var text = root.getEntryText(entry);
                                    if (root.isFile(text))
                                        return "File";

                                    return "Text (" + text.length + " chars)";
                                }
                                color: theme.secondary
                                font.family: root.fontName
                                font.pointSize: 7.5
                                renderType: Text.NativeRendering
                            }
                        }

                        // Content Preview Area
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: {
                                var entry = root.filteredEntries[root.selectedIndex];
                                if (!entry)
                                    return 20;

                                var type = root.getPreviewType(entry);
                                if (type === "image")
                                    return 120;

                                return Math.min(212, Math.max(40, previewText.implicitHeight + 8));
                            }
                            color: theme.bg_dark
                            radius: 0
                            clip: true

                            // 1. Image Preview
                            Image {
                                anchors.fill: parent
                                anchors.margins: 2
                                fillMode: Image.PreserveAspectFit
                                horizontalAlignment: Image.AlignHCenter
                                verticalAlignment: Image.AlignVCenter
                                visible: (root.filteredEntries && root.filteredEntries.length > root.selectedIndex) ? (root.getPreviewType(root.filteredEntries[root.selectedIndex]) === "image") : false
                                source: {
                                    var entry = root.filteredEntries[root.selectedIndex];
                                    if (!entry)
                                        return "";

                                    return "file:///tmp/clip_" + root.getEntryId(entry) + ".png";
                                }
                                cache: false
                            }

                            // 2. Text Preview Scrollable
                            ScrollView {
                                id: previewScrollView

                                anchors.fill: parent
                                anchors.margins: 2
                                clip: true
                                visible: (root.filteredEntries && root.filteredEntries.length > root.selectedIndex) ? (root.getPreviewType(root.filteredEntries[root.selectedIndex]) === "text") : false

                                Text {
                                    id: previewText

                                    width: previewContainer.width - 12
                                    text: root.currentPreviewText
                                    color: theme.fg
                                    font.family: root.fontName
                                    font.pointSize: 7.5
                                    wrapMode: Text.WrapAnywhere
                                    renderType: Text.NativeRendering
                                }
                            }
                        }

                        // Actions / Option Buttons Row
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 8

                            // Info label
                            Text {
                                text: {
                                    var entry = root.filteredEntries[root.selectedIndex];
                                    if (!entry)
                                        return "";

                                    var text = root.getEntryText(entry);
                                    if (root.isFile(text))
                                        return "File path";

                                    var lines = root.getLineCount(text);
                                    var words = root.getWordCount(text);
                                    return lines + " lines, " + words + " words";
                                }
                                color: theme.secondary
                                font.family: root.fontName
                                font.pointSize: 7.5
                                renderType: Text.NativeRendering
                            }

                            Item {
                                Layout.fillWidth: true
                            }

                            // "go to location" for files
                            Text {
                                text: "go to location"
                                font.family: root.fontName
                                font.pointSize: 7.5
                                font.bold: true
                                color: fileLocMouse.containsMouse ? theme.accent : theme.secondary
                                visible: (root.filteredEntries && root.filteredEntries.length > root.selectedIndex) ? root.isFile(root.getEntryText(root.filteredEntries[root.selectedIndex])) : false

                                MouseArea {
                                    id: fileLocMouse

                                    anchors.fill: parent
                                    hoverEnabled: true
                                    onClicked: {
                                        var entry = root.filteredEntries[root.selectedIndex];
                                        if (entry) {
                                            var path = root.cleanFilePath(root.getEntryText(entry));
                                            Quickshell.execDetached(["xdg-open", path]);
                                        }
                                    }
                                }
                            }

                            // "copy" button
                            Text {
                                text: "copy"
                                font.family: root.fontName
                                font.pointSize: 7.5
                                font.bold: true
                                color: copyBtnMouse.containsMouse ? theme.accent : theme.secondary

                                MouseArea {
                                    id: copyBtnMouse

                                    anchors.fill: parent
                                    hoverEnabled: true
                                    onClicked: {
                                        var entry = root.filteredEntries[root.selectedIndex];
                                        if (entry) {
                                            copyProc.entryText = entry;
                                            copyProc.running = true;
                                        }
                                    }
                                }
                            }
                        }
                    }

                    Behavior on opacity {
                        NumberAnimation {
                            duration: 100
                        }
                    }
                }
            }
        }
    }
}
