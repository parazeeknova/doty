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
    property var bindsData: []
    property string searchQuery: ""
    property var flatBinds: []
    property int selectedIndex: 0
    
    readonly property string fontName: "FiraCode Nerd Font"
    
    signal requestClose()

    function updateFlatBinds() {
        var query = searchQuery.trim().toLowerCase();
        var temp = [];
        for (var i = 0; i < bindsData.length; i++) {
            var cat = bindsData[i];
            for (var j = 0; j < cat.binds.length; j++) {
                var bind = cat.binds[j];
                if (query === "" || 
                    bind.keys.toLowerCase().indexOf(query) !== -1 || 
                    bind.description.toLowerCase().indexOf(query) !== -1 ||
                    cat.category.toLowerCase().indexOf(query) !== -1) {
                    
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

    // Process to run the compiled Rust parser to get binds data
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

    // Copy process for clipboard feedback
    Process {
        id: copyProc
        property string copyText: ""
        property string notificationTitle: ""
        command: ["sh", "-c", "echo -n \"$1\" | wl-copy && notify-send -t 1000 -h string:x-canonical-private-synchronous:shortcut-notify -a \"Shortcuts\" -i \"edit-copy\" \"$2\" \"$1\"", "sh", copyText, notificationTitle]
        running: false
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
                implicitWidth: 220
                implicitHeight: 300


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

                HyprlandFocusGrab {
                    active: !win.isClosing
                    windows: [win]
                    onCleared: win.closePopup()
                }

                // Concise Boxy Main Container
                Rectangle {
                    anchors.fill: parent
                    opacity: win.animOpacity
                    color: theme.popupBgColor
                    border.width: 1
                    border.color: theme.accent
                    radius: 0
                    antialiasing: false
                    focus: true
                    
                    Keys.onPressed: (event) => {
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
                        anchors.margins: 4
                        spacing: 4

                        // Search Input
                        Rectangle {
                            Layout.fillWidth: true
                            height: 18
                            color: "transparent"

                            TextInput {
                                id: searchInput
                                renderType: Text.NativeRendering
                                anchors.fill: parent
                                anchors.bottomMargin: 2
                                verticalAlignment: TextInput.AlignVCenter
                                color: theme.fg
                                font.family: root.fontName
                                font.pixelSize: 9
                                focus: true
                                onTextChanged: {
                                    root.searchQuery = text;
                                }

                                Text {
                                    text: "Search binds..."
                                    renderType: Text.NativeRendering
                                    color: theme.secondary
                                    font.family: root.fontName
                                    font.pixelSize: 9
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
                                color: searchInput.activeFocus ? theme.fg : theme.secondary
                            }
                        }

                        // Unified Binds List
                        ListView {
                            id: bindsList
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            model: root.flatBinds
                            clip: true
                            spacing: 0

                            delegate: ColumnLayout {
                                width: bindsList.width
                                spacing: 0

                                // Section Header (Visible dynamically)
                                Rectangle {
                                    id: headerRect
                                    Layout.fillWidth: true
                                    visible: {
                                        if (index === 0) return true;
                                        if (index > 0 && root.flatBinds && index < root.flatBinds.length) {
                                            return root.flatBinds[index].category !== root.flatBinds[index - 1].category;
                                        }
                                        return false;
                                    }
                                    height: visible ? 16 : 0
                                    color: "transparent"

                                    Text {
                                        text: {
                                            var catName = modelData.category.toLowerCase();
                                            var icon = "󰘳";
                                            if (catName.indexOf("application") !== -1) icon = "󰀻";
                                            else if (catName.indexOf("window") !== -1) icon = "󱂬";
                                            else if (catName.indexOf("layout") !== -1) icon = "󰕰";
                                            else if (catName.indexOf("workspace") !== -1) icon = "󰖲";
                                            else if (catName.indexOf("rofi") !== -1 || catName.indexOf("menu") !== -1) icon = "󰍜";
                                            else if (catName.indexOf("pypr") !== -1) icon = "󱗼";
                                            else if (catName.indexOf("screenshot") !== -1) icon = "󰄀";
                                            else if (catName.indexOf("system") !== -1) icon = "󰒓";
                                            return icon + " " + modelData.category.toUpperCase();
                                        }
                                        renderType: Text.NativeRendering
                                        color: theme.accent
                                        font.family: root.fontName
                                        font.pixelSize: 8
                                        font.bold: true
                                        verticalAlignment: Text.AlignVCenter
                                        anchors.fill: parent
                                        anchors.leftMargin: 2
                                    }
                                }

                                // Main Item Row
                                Rectangle {
                                    Layout.fillWidth: true
                                    height: 25
                                    color: (root.selectedIndex === index) ? theme.bg_light : "transparent"
                                    radius: 0
                                    antialiasing: false

                                    ColumnLayout {
                                        anchors.left: parent.left
                                        anchors.right: parent.right
                                        anchors.verticalCenter: parent.verticalCenter
                                        anchors.leftMargin: 4
                                        anchors.rightMargin: 4
                                        spacing: 0

                                        // Keys row
                                        Text {
                                            text: modelData.keys
                                            renderType: Text.NativeRendering
                                            color: (root.selectedIndex === index) ? theme.accent : theme.fg
                                            font.family: root.fontName
                                            font.pixelSize: 9
                                            font.bold: true
                                            Layout.fillWidth: true
                                            elide: Text.ElideRight
                                        }

                                        // Description
                                        Text {
                                            text: modelData.description
                                            renderType: Text.NativeRendering
                                            color: (root.selectedIndex === index) ? theme.fg : theme.secondary
                                            font.family: root.fontName
                                            font.pixelSize: 8
                                            Layout.fillWidth: true
                                            elide: Text.ElideRight
                                        }
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        onEntered: {
                                            root.selectedIndex = index;
                                        }
                                        onClicked: (mouse) => {
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
                    }
                }
            }
        }
    }
}
