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
    // Theme tokens (Gruvbox Material Dark)
    readonly property color colorBgDark: "#e61d2021"
    // Sleek dark background
    readonly property color colorBgCell: theme.c.bg_dark
    // Item cell bg
    readonly property color colorBgActive: "#504945"
    // Selected cell bg
    readonly property color colorBorder: theme.c.accent
    // Accent border
    readonly property color colorText: theme.c.accent
    // Foreground text
    readonly property color colorTextMuted: "#a89984"
    // Muted text
    readonly property color colorHover: "#665c54"
    // Hover cell bg
    readonly property string fontName: "FiraCode Nerd Font"

    signal requestClose()

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

    // Render Window on each Screen
    Variants {
        model: Quickshell.screens

        delegate: Component {
            PanelWindow {
                id: win

                required property var modelData
                property bool isClosing: false
                property real animOffsetX: -550
                property real animOpacity: 0

                function closePopup() {
                    if (isClosing)
                        return ;

                    isClosing = true;
                    exitAnim.start();
                }

                screen: modelData
                WlrLayershell.namespace: "quickshell"
                WlrLayershell.layer: WlrLayer.Overlay
                WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
                exclusionMode: PanelWindow.ExclusionMode.Ignore
                focusable: true
                color: "transparent"
                implicitWidth: 200
                implicitHeight: 260
                Component.onCompleted: {
                    introAnim.start();
                    searchInput.forceActiveFocus();
                }

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

                // Slide & Fade Animations
                ParallelAnimation {
                    id: introAnim

                    NumberAnimation {
                        target: win
                        property: "animOffsetX"
                        from: -550
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

                ParallelAnimation {
                    id: exitAnim

                    onStopped: Qt.quit()

                    NumberAnimation {
                        target: win
                        property: "animOffsetX"
                        from: 32
                        to: -550
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

                // Click outside to close
                HyprlandFocusGrab {
                    active: !win.isClosing
                    windows: [win]
                    onCleared: win.closePopup()
                }

                // Container
                Rectangle {
                    anchors.fill: parent
                    opacity: win.animOpacity
                    color: theme.popupBgColor // transparent matching other widgets
                    border.width: 0
                    radius: 0
                    focus: true
                    Keys.onPressed: (event) => {
                        if (event.key === Qt.Key_Escape) {
                            win.closePopup();
                            event.accepted = true;
                        } else if (event.key === Qt.Key_Up) {
                            if (root.selectedIndex > 0) {
                                root.selectedIndex--;
                                listView.positionViewAtIndex(root.selectedIndex, ListView.Contain);
                            }
                            event.accepted = true;
                        } else if (event.key === Qt.Key_Down) {
                            if (root.selectedIndex < root.filteredEntries.length - 1) {
                                root.selectedIndex++;
                                listView.positionViewAtIndex(root.selectedIndex, ListView.Contain);
                            }
                            event.accepted = true;
                        } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                            if (root.filteredEntries.length > 0) {
                                copyProc.entryText = root.filteredEntries[root.selectedIndex];
                                copyProc.running = true;
                            }
                            event.accepted = true;
                        } else if (event.key === Qt.Key_Delete) {
                            if (root.filteredEntries.length > 0) {
                                deleteProc.entryText = root.filteredEntries[root.selectedIndex];
                                deleteProc.running = true;
                            }
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
                                color: "#d4be98"
                                font.family: root.fontName
                                font.pixelSize: 8
                                focus: true
                                onTextChanged: {
                                    root.searchQuery = text.toLowerCase();
                                    root.filterEntries();
                                }

                                Text {
                                    text: "search..."
                                    color: "#7c6f64"
                                    font.family: root.fontName
                                    font.pixelSize: 8
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
                                color: searchInput.activeFocus ? "#d4be98" : "#7c6f64"
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
                                color: (root.selectedIndex === index) ? theme.c.bg_dark : "transparent"
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
                                            color: (root.selectedIndex === index) ? "#ddc7a1" : "#d4be98"
                                            font.family: root.fontName
                                            font.pixelSize: 8
                                            elide: Text.ElideRight
                                            wrapMode: Text.NoWrap
                                            verticalAlignment: Text.AlignVCenter
                                            renderType: Text.NativeRendering
                                        }

                                    }

                                }

                            }

                        }

                        // Clear All button
                        Text {
                            text: "clear all"
                            font.family: root.fontName
                            font.pixelSize: 8
                            color: clearAllMouseArea.containsMouse ? "#fb4934" : "#7c6f64"
                            Layout.alignment: Qt.AlignRight
                            Layout.bottomMargin: 2
                            Layout.rightMargin: 4

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

            }

        }

    }

}
