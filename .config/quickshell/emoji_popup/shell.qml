import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland

Scope {
    id: root

    // State properties
    property string searchQuery: ""
    property var emojisDb: []
    property var filteredEmojis: []
    property int selectedIndex: 0
    // Theme tokens (Gruvbox Material Dark)
    readonly property color colorBgDark: "#e61d2021"
    // Sleek dark background
    readonly property color colorBgCell: "#282828"
    // Item cell bg
    readonly property color colorBgActive: "#504945"
    // Selected cell bg
    readonly property color colorBorder: "#d5c4a1"
    // Accent border
    readonly property color colorText: "#d5c4a1"
    // Foreground text
    readonly property color colorTextMuted: "#a89984"
    // Muted text
    readonly property color colorHover: "#665c54"
    // Hover cell bg
    readonly property string fontName: "FiraCode Nerd Font"

    signal requestClose()

    function filterEmojis() {
        var temp = [];
        var query = searchQuery.trim().toLowerCase();
        for (var i = 0; i < emojisDb.length; i++) {
            var item = emojisDb[i];
            if (query === "") {
                temp.push(item);
            } else {
                if (item.name.indexOf(query) !== -1 || item.char.indexOf(query) !== -1)
                    temp.push(item);

            }
        }
        filteredEmojis = temp;
        selectedIndex = 0;
    }

    onSearchQueryChanged: filterEmojis()

    Theme {
        id: theme
    }

    // Process to run the compiled Rust helper to get emojis JSON
    Process {
        id: getEmojisProc

        command: ["/home/parazeeknova/doty/.config/quickshell/emoji_popup/get_emojis"]
        running: true

        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.emojisDb = JSON.parse(this.text);
                    root.filterEmojis();
                } catch (e) {
                    console.log("Failed to parse emojis JSON: " + e);
                }
            }
        }

    }

    IpcHandler {
        function close() {
            root.requestClose();
        }

        target: "emoji_popup"
    }

    // Copy selected emoji process
    Process {
        id: copyProc

        property string emojiChar: ""

        command: ["sh", "-c", "echo -n \"$1\" | wl-copy && notify-send -t 1000 -h string:x-canonical-private-synchronous:emoji-notify -a \"emoji picker\" -i \"edit-copy\" \"copied to clipboard\" \"$1\"", "sh", emojiChar]
        running: false
        onExited: {
            root.requestClose();
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

                HyprlandFocusGrab {
                    active: !win.isClosing
                    windows: [win]
                    onCleared: win.closePopup()
                }

                // Main Container
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
                        } else if (event.key === Qt.Key_Left) {
                            if (root.selectedIndex > 0)
                                root.selectedIndex--;

                            event.accepted = true;
                        } else if (event.key === Qt.Key_Right) {
                            if (root.selectedIndex < root.filteredEmojis.length - 1)
                                root.selectedIndex++;

                            event.accepted = true;
                        } else if (event.key === Qt.Key_Up) {
                            if (root.selectedIndex >= 5)
                                root.selectedIndex -= 5;

                            event.accepted = true;
                        } else if (event.key === Qt.Key_Down) {
                            if (root.selectedIndex + 5 < root.filteredEmojis.length)
                                root.selectedIndex += 5;

                            event.accepted = true;
                        } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                            if (root.filteredEmojis.length > 0) {
                                copyProc.emojiChar = root.filteredEmojis[root.selectedIndex].char;
                                copyProc.running = true;
                            }
                            event.accepted = true;
                        }
                    }

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 4
                        spacing: 4

                        // Search Field (Underline only, matching rofi inputbar)
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

                        // Grid of Emojis
                        GridView {
                            id: gridView

                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            clip: true
                            cellWidth: gridView.width / 5
                            cellHeight: 32
                            model: root.filteredEmojis

                            delegate: Rectangle {
                                width: gridView.cellWidth - 2
                                height: gridView.cellHeight - 2
                                color: (root.selectedIndex === index) ? "#282828" : "transparent"
                                radius: 0

                                Text {
                                    anchors.centerIn: parent
                                    text: modelData.char
                                    font.family: "Noto Color Emoji"
                                    font.pixelSize: 14
                                    horizontalAlignment: Text.AlignHCenter
                                    verticalAlignment: Text.AlignVCenter
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    onEntered: {
                                        root.selectedIndex = index;
                                    }
                                    onClicked: {
                                        copyProc.emojiChar = modelData.char;
                                        copyProc.running = true;
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
