//@ pragma UseQApplication
import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Services.SystemTray

Scope {
    id: root

    Component.onCompleted: {
        SystemTray.isService = false;
    }

    Theme {
        id: theme
    }

    Variants {
        model: Quickshell.screens

        delegate: Component {
            PanelWindow {
                id: win

                required property var modelData
                property bool isClosing: false
                property real animLeftMargin: -260
                property real animOpacity: 0
                property bool isMenuOpen: false
                property var activeMenu: null
                property real menuX: 0

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
                implicitWidth: win.isMenuOpen ? Math.max(180 + 16, mainLayout.implicitWidth + 16) : Math.max(34, mainLayout.implicitWidth + 16)
                implicitHeight: (win.isMenuOpen ? menuContent.implicitHeight + 8 : 0) + Math.max(34, mainLayout.implicitHeight + 16)
                Component.onCompleted: introAnim.start()

                anchors {
                    bottom: true
                    left: true
                }

                margins {
                    bottom: 162 - (win.isMenuOpen ? menuContent.implicitHeight + 8 : 0)
                    left: win.animLeftMargin
                }

                // Slide-in + fade-in
                ParallelAnimation {
                    id: introAnim

                    NumberAnimation {
                        target: win
                        property: "animLeftMargin"
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
                        property: "animLeftMargin"
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

                HyprlandFocusGrab {
                    active: !win.isClosing
                    windows: [win]
                    onCleared: {
                        win.closePopup();
                    }
                }

                // Dismiss menu if user clicks in empty transparent area of window
                MouseArea {
                    anchors.fill: parent
                    visible: win.isMenuOpen
                    onClicked: {
                        win.isMenuOpen = false;
                    }
                }

                // Custom menu QML container
                QsMenuOpener {
                    id: menuOpener

                    menu: win.activeMenu
                }

                Rectangle {
                    id: menuContent

                    visible: win.isMenuOpen
                    width: 180
                    implicitHeight: menuColumn.implicitHeight + 8
                    color: theme.trayBgColor // Semi-transparent Gruvbox dark background
                    border.width: 1
                    border.color: "#d5c4a1" // Gruvbox retro warm text/border color
                    radius: 0
                    opacity: win.animOpacity
                    anchors.top: trayBar.bottom
                    anchors.topMargin: 8
                    x: Math.max(8, Math.min(win.width - width - 8, win.menuX - width / 2 + 9))

                    Column {
                        id: menuColumn

                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.topMargin: 4
                        spacing: 1

                        Repeater {
                            model: menuOpener.children

                            delegate: Rectangle {
                                anchors.left: parent.left
                                anchors.right: parent.right
                                height: modelData.isSeparator ? 5 : 16
                                color: "transparent" // No hover background highlight

                                Row {
                                    visible: !modelData.isSeparator
                                    anchors.fill: parent
                                    anchors.leftMargin: 6
                                    anchors.rightMargin: 6
                                    spacing: 6
                                    anchors.verticalCenter: parent.verticalCenter

                                    Rectangle {
                                        width: 10
                                        height: 10
                                        color: "transparent"
                                        anchors.verticalCenter: parent.verticalCenter

                                        Image {
                                            anchors.fill: parent
                                            source: modelData.icon
                                            visible: modelData.icon !== ""
                                        }

                                        Text {
                                            anchors.centerIn: parent
                                            text: modelData.checkState === Qt.Checked ? "✓" : ""
                                            color: mouseArea.containsMouse ? "#ebdbb2" : "#d4be98"
                                            font.bold: true
                                            font.pixelSize: 8
                                            visible: modelData.buttonType === 1 || modelData.buttonType === 2
                                        }

                                    }

                                    Text {
                                        text: modelData.text.replace(/&/g, "")
                                        color: modelData.enabled ? (mouseArea.containsMouse ? "#ebdbb2" : "#d4be98") : "#7c6f64" // Hover text only color shift
                                        font.family: "FiraCode Nerd Font"
                                        font.pixelSize: 8
                                        renderType: Text.NativeRendering
                                        anchors.verticalCenter: parent.verticalCenter
                                    }

                                }

                                MouseArea {
                                    id: mouseArea

                                    anchors.fill: parent
                                    hoverEnabled: modelData.enabled && !modelData.isSeparator
                                    acceptedButtons: Qt.LeftButton
                                    onClicked: {
                                        if (modelData.enabled && !modelData.isSeparator) {
                                            modelData.triggered();
                                            win.isMenuOpen = false;
                                        }
                                    }
                                }

                            }

                        }

                    }

                }

                // Tray icons bar
                Rectangle {
                    id: trayBar

                    anchors.top: parent.top
                    anchors.left: parent.left
                    width: Math.max(34, mainLayout.implicitWidth + 16)
                    height: Math.max(34, mainLayout.implicitHeight + 16)
                    opacity: win.animOpacity
                    color: win.isMenuOpen ? "transparent" : theme.popupBgColor
                    border.width: win.isMenuOpen ? 0 : 1
                    border.color: "#d5c4a1"
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

                    Row {
                        id: mainLayout

                        anchors.top: parent.top
                        anchors.bottom: parent.bottom
                        anchors.left: parent.left
                        anchors.topMargin: 8
                        anchors.bottomMargin: 8
                        anchors.leftMargin: 8
                        spacing: 8

                        Repeater {
                            model: SystemTray.items

                            delegate: Rectangle {
                                id: trayIconItem

                                width: 18
                                height: 18
                                color: "transparent"
                                radius: 2

                                Image {
                                    anchors.fill: parent
                                    anchors.margins: 2
                                    source: modelData.icon
                                    fillMode: Image.PreserveAspectFit
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                                    hoverEnabled: true
                                    onEntered: parent.color = "#30d5c4a1"
                                    onExited: parent.color = "transparent"
                                    onClicked: (mouse) => {
                                        if (mouse.button === Qt.RightButton) {
                                            if (modelData.hasMenu) {
                                                win.activeMenu = modelData.menu;
                                                win.menuX = trayIconItem.mapToItem(win.contentItem, 0, 0).x;
                                                win.isMenuOpen = true;
                                            }
                                        } else {
                                            if (modelData.hasMenu && modelData.onlyMenu) {
                                                win.activeMenu = modelData.menu;
                                                win.menuX = trayIconItem.mapToItem(win.contentItem, 0, 0).x;
                                                win.isMenuOpen = true;
                                            } else {
                                                modelData.activate();
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
