import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io

Scope {
    id: root

    property string homeDir: Quickshell.env("HOME")
    property int selectedIndex: 0
    readonly property var items: [
        {
            "icon": "󰌾",
            "label": "lock",
            "action": "lock"
        },
        {
            "icon": "󰒲",
            "label": "sleep",
            "action": "sleep"
        },
        {
            "icon": "󰑐",
            "label": "reboot",
            "action": "reboot"
        },
        {
            "icon": "󰐥",
            "label": "poweroff",
            "action": "poweroff"
        },
        {
            "icon": "󰈆",
            "label": "logout",
            "action": "logout"
        }
    ]
    readonly property string fontName: "FiraCode Nerd Font"

    signal requestClose

    function executeAction(action) {
        Quickshell.execDetached([root.homeDir + "/.config/waybar/scripts/wabi_power", action]);
        root.requestClose();
    }

    Theme {
        id: theme
    }

    IpcHandler {
        function close() {
            root.requestClose();
        }

        target: "power_popup"
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
                                root.selectedIndex = root.items.length - 1;
                            event.accepted = true;
                        } else if (event.key === Qt.Key_Down) {
                            if (root.selectedIndex < root.items.length - 1)
                                root.selectedIndex++;
                            else
                                root.selectedIndex = 0;
                            event.accepted = true;
                        } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                            root.executeAction(root.items[root.selectedIndex].action);
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

                        Repeater {
                            model: root.items

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
                                        text: modelData.icon
                                        color: (root.selectedIndex === index) ? theme.accent : theme.secondary
                                        font.family: root.fontName
                                        font.pointSize: 8
                                        anchors.verticalCenter: parent.verticalCenter
                                    }

                                    Text {
                                        text: modelData.label
                                        color: (root.selectedIndex === index) ? theme.accent : theme.secondary
                                        font.family: root.fontName
                                        font.pointSize: 8
                                        anchors.verticalCenter: parent.verticalCenter
                                    }
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    onEntered: root.selectedIndex = index
                                    onClicked: root.executeAction(modelData.action)
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
