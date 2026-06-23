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

    property var bindsData: []
    property string searchQuery: ""
    property var flatBinds: []
    property int selectedIndex: 0

    readonly property string fontName: "FiraCode Nerd Font"

    signal requestClose

    function updateFlatBinds() {
        var query = searchQuery.trim().toLowerCase();
        var temp = [];
        for (var i = 0; i < bindsData.length; i++) {
            var cat = bindsData[i];
            for (var j = 0; j < cat.binds.length; j++) {
                var bind = cat.binds[j];
                if (query === "" || bind.keys.toLowerCase().indexOf(query) !== -1 || bind.description.toLowerCase().indexOf(query) !== -1 || cat.category.toLowerCase().indexOf(query) !== -1) {
                    temp.push({
                        keys: bind.keys,
                        description: bind.description,
                        cmd: bind.cmd,
                        category: cat.category
                    });
                }
            }
        }
        flatBinds = temp;
        selectedIndex = 0;
    }

    onBindsDataChanged: updateFlatBinds()
    onSearchQueryChanged: updateFlatBinds()

    Theme {
        id: theme
    }

    Process {
        id: getBindsProc
        command: [root.homeDir + "/.config/quickshell/shortcut_popup/parse_binds"]
        running: true

        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.bindsData = JSON.parse(this.text);
                } catch (e) {
                    console.log("Failed to parse keybinds JSON: " + e);
                }
            }
        }
    }

    IpcHandler {
        function close() {
            root.requestClose();
        }
        target: "shortcut_popup"
    }

    Process {
        id: copyProc
        property string copyText: ""
        property string notificationTitle: ""
        command: ["sh", "-c", "echo -n \"$1\" | wl-copy && notify-send -t 1000 -h string:x-canonical-private-synchronous:shortcut-notify -a \"Shortcuts\" -i \"edit-copy\" \"$2\" \"$1\"", "sh", copyText, notificationTitle]
        running: false
    }

    Variants {
        model: Quickshell.screens

        delegate: Component {
            PanelWindow {
                id: win

                required property var modelData
                property bool isClosing: false
                property real animOffsetY: -10
                property real animOpacity: 0

                function closePopup() {
                    if (isClosing)
                        return;
                    isClosing = true;
                    exitAnim.start();
                }

                screen: modelData
                exclusionMode: PanelWindow.ExclusionMode.Ignore
                focusable: true
                color: "transparent"
                implicitWidth: 240
                implicitHeight: 320

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
                    top: win.animOffsetY
                    left: 32
                }

                ParallelAnimation {
                    id: introAnim
                    NumberAnimation {
                        target: win
                        property: "animOffsetY"
                        from: -10
                        to: 4
                        duration: 100
                        easing.type: Easing.OutCubic
                    }
                    NumberAnimation {
                        target: win
                        property: "animOpacity"
                        from: 0
                        to: 1
                        duration: 100
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
                        to: -10
                        duration: 80
                        easing.type: Easing.InCubic
                    }
                    NumberAnimation {
                        target: win
                        property: "animOpacity"
                        from: 1
                        to: 0
                        duration: 80
                        easing.type: Easing.InCubic
                    }
                }

                HyprlandFocusGrab {
                    active: !win.isClosing
                    windows: [win]
                    onCleared: win.closePopup()
                }

                Rectangle {
                    anchors.fill: parent
                    opacity: win.animOpacity
                    color: theme.popupBgColor
                    border.width: 1
                    border.color: theme.accent
                    radius: 0
                    focus: true

                    Keys.onPressed: event => {
                        if (event.key === Qt.Key_Escape) {
                            win.closePopup();
                            event.accepted = true;
                        } else if (event.key === Qt.Key_Up) {
                            if (root.selectedIndex > 0) {
                                root.selectedIndex--;
                                bindsList.positionViewAtIndex(root.selectedIndex, ListView.Contain);
                            }
                            event.accepted = true;
                        } else if (event.key === Qt.Key_Down) {
                            if (root.selectedIndex < root.flatBinds.length - 1) {
                                root.selectedIndex++;
                                bindsList.positionViewAtIndex(root.selectedIndex, ListView.Contain);
                            }
                            event.accepted = true;
                        } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                            if (root.flatBinds.length > 0 && root.selectedIndex >= 0 && root.selectedIndex < root.flatBinds.length) {
                                var item = root.flatBinds[root.selectedIndex];
                                if (item.cmd) {
                                    Quickshell.execDetached(["sh", "-c", item.cmd]);
                                }
                                win.closePopup();
                            }
                            event.accepted = true;
                        }
                    }

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 2
                        anchors.leftMargin: 6
                        spacing: 0

                        // Search
                        Rectangle {
                            Layout.fillWidth: true
                            height: 16
                            color: "transparent"

                            TextInput {
                                id: searchInput
                                renderType: Text.NativeRendering
                                anchors.fill: parent
                                anchors.bottomMargin: 1
                                verticalAlignment: TextInput.AlignVCenter
                                color: theme.fg
                                font.family: root.fontName
                                font.pixelSize: 9
                                focus: true
                                clip: true
                                onTextChanged: root.searchQuery = text

                                Text {
                                    text: "search..."
                                    renderType: Text.NativeRendering
                                    color: theme.bg_light
                                    font.family: root.fontName
                                    font.pixelSize: 9
                                    visible: searchInput.text === "" && !searchInput.activeFocus
                                    anchors.fill: parent
                                    verticalAlignment: Text.AlignVCenter
                                }
                            }

                            Rectangle {
                                anchors.bottom: parent.bottom
                                width: parent.width
                                height: 1
                                color: searchInput.activeFocus ? theme.accent : theme.bg_light
                            }
                        }

                        // Binds
                        ListView {
                            id: bindsList
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            Layout.topMargin: 2
                            model: root.flatBinds
                            clip: true
                            spacing: 0

                            delegate: ColumnLayout {
                                width: bindsList.width
                                spacing: 0

                                // Category
                                Rectangle {
                                    Layout.fillWidth: true
                                    visible: {
                                        if (index === 0)
                                            return true;
                                        if (index > 0 && root.flatBinds && index < root.flatBinds.length)
                                            return root.flatBinds[index].category !== root.flatBinds[index - 1].category;
                                        return false;
                                    }
                                    height: visible ? 14 : 0
                                    color: "transparent"

                                    Text {
                                        text: modelData.category.charAt(0).toUpperCase() + modelData.category.slice(1)
                                        renderType: Text.NativeRendering
                                        color: theme.accent
                                        font.family: root.fontName
                                        font.pixelSize: 9
                                        font.bold: true
                                        opacity: 0.7
                                        anchors.verticalCenter: parent.verticalCenter
                                        anchors.left: parent.left
                                    }
                                }

                                // Bind
                                Rectangle {
                                    Layout.fillWidth: true
                                    height: 18
                                    color: (root.selectedIndex === index) ? Qt.rgba(theme.accent.r, theme.accent.g, theme.accent.b, 0.1) : "transparent"

                                    RowLayout {
                                        anchors.fill: parent
                                        anchors.leftMargin: 2
                                        anchors.rightMargin: 2
                                        spacing: 6

                                        Text {
                                            text: modelData.keys
                                            renderType: Text.NativeRendering
                                            color: theme.accent
                                            font.family: root.fontName
                                            font.pixelSize: 9
                                            font.bold: true
                                            Layout.preferredWidth: implicitWidth
                                        }

                                        Text {
                                            text: modelData.description
                                            renderType: Text.NativeRendering
                                            color: (root.selectedIndex === index) ? theme.fg : theme.fg_light
                                            font.family: root.fontName
                                            font.pixelSize: 9
                                            Layout.fillWidth: true
                                            elide: Text.ElideRight
                                        }
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        onEntered: root.selectedIndex = index
                                        onClicked: mouse => {
                                            if (mouse.button === Qt.RightButton) {
                                                if (mouse.modifiers & Qt.ShiftModifier) {
                                                    copyProc.copyText = modelData.keys;
                                                    copyProc.notificationTitle = "Keys Copied";
                                                    copyProc.running = true;
                                                } else if (modelData.cmd) {
                                                    copyProc.copyText = modelData.cmd;
                                                    copyProc.notificationTitle = "Command Copied";
                                                    copyProc.running = true;
                                                }
                                                win.closePopup();
                                            } else {
                                                if (modelData.cmd) {
                                                    Quickshell.execDetached(["sh", "-c", modelData.cmd]);
                                                }
                                                win.closePopup();
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        // Footer
                        Rectangle {
                            Layout.fillWidth: true
                            height: 12
                            color: "transparent"

                            Text {
                                text: root.flatBinds.length + " keybinds"
                                renderType: Text.NativeRendering
                                color: theme.bg_light
                                font.family: root.fontName
                                font.pixelSize: 9
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }
                    }
                }
            }
        }
    }
}
