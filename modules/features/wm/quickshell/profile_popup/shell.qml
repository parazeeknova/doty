import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io

Scope {
    id: root

    property string homeDir: Quickshell.env("HOME")
    property string currentProfile: ""
    property int selectedIndex: 0
    readonly property var profiles: [
        {
            "name": "Quiet",
            "icon": "󰌪"
        },
        {
            "name": "Balanced",
            "icon": "󰾅"
        },
        {
            "name": "Performance",
            "icon": "󰓅"
        }
    ]
    readonly property string fontName: "FiraCode Nerd Font"

    signal requestClose

    function setProfile(profileName) {
        Quickshell.execDetached(["asusctl", "profile", "set", profileName]);
        Quickshell.execDetached([root.homeDir + "/.config/quickshell/osd/bin/osdctl", "show", "profile: " + profileName.toLowerCase(), "good", "1500"]);
        root.requestClose();
    }

    Component.onCompleted: getProfileProc.running = true

    Theme {
        id: theme
    }

    IpcHandler {
        function close() {
            root.requestClose();
        }

        target: "profile_popup"
    }

    Process {
        id: getProfileProc

        command: ["asusctl", "profile", "get"]
        running: false

        stdout: StdioCollector {
            onStreamFinished: {
                var lines = this.text.split("\n");
                for (var i = 0; i < lines.length; i++) {
                    if (lines[i].indexOf("Active profile") !== -1) {
                        var parts = lines[i].trim().split(/\s+/);
                        if (parts.length >= 3) {
                            root.currentProfile = parts[2];
                            for (var j = 0; j < root.profiles.length; j++) {
                                if (root.profiles[j].name === root.currentProfile) {
                                    root.selectedIndex = j;
                                    break;
                                }
                            }
                        }
                        break;
                    }
                }
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
                implicitWidth: 110
                implicitHeight: mainLayout.implicitHeight + 8
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

                Rectangle {
                    anchors.fill: parent
                    opacity: win.animOpacity
                    color: theme.popupBgColor
                    border.width: 1
                    border.color: theme.accent
                    radius: 0
                    focus: true
                    Component.onCompleted: forceActiveFocus()
                    Keys.onPressed: event => {
                        if (event.key === Qt.Key_Escape) {
                            win.closePopup();
                            event.accepted = true;
                        } else if (event.key === Qt.Key_Up) {
                            if (root.selectedIndex > 0)
                                root.selectedIndex--;
                            else
                                root.selectedIndex = root.profiles.length - 1;
                            event.accepted = true;
                        } else if (event.key === Qt.Key_Down) {
                            if (root.selectedIndex < root.profiles.length - 1)
                                root.selectedIndex++;
                            else
                                root.selectedIndex = 0;
                            event.accepted = true;
                        } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                            root.setProfile(root.profiles[root.selectedIndex].name);
                            event.accepted = true;
                        }
                    }

                    Column {
                        id: mainLayout

                        anchors.top: parent.top
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.margins: 4
                        spacing: 2

                        Text {
                            text: "profile"
                            color: theme.accent
                            font.family: root.fontName
                            font.pointSize: 7
                            font.bold: true
                            anchors.left: parent.left
                            anchors.leftMargin: 4
                        }

                        Rectangle {
                            width: parent.width
                            height: 1
                            color: theme.accent
                            opacity: 0.15
                        }

                        Repeater {
                            model: root.profiles

                            delegate: Rectangle {
                                width: mainLayout.width
                                height: 16
                                color: (root.selectedIndex === index) ? theme.bg_dark : "transparent"
                                radius: 0

                                Row {
                                    anchors.left: parent.left
                                    anchors.verticalCenter: parent.verticalCenter
                                    anchors.leftMargin: 4
                                    spacing: 4

                                    Text {
                                        text: (root.currentProfile === modelData.name) ? "*" : modelData.icon
                                        color: (root.selectedIndex === index) ? theme.accent : theme.secondary
                                        font.family: root.fontName
                                        font.pointSize: 7
                                        anchors.verticalCenter: parent.verticalCenter
                                    }

                                    Text {
                                        text: modelData.name.toLowerCase()
                                        color: (root.selectedIndex === index) ? theme.accent : theme.secondary
                                        font.family: root.fontName
                                        font.pointSize: 7
                                        anchors.verticalCenter: parent.verticalCenter
                                    }
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    onEntered: root.selectedIndex = index
                                    onClicked: root.setProfile(modelData.name)
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
