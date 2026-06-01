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
                implicitWidth: Math.max(34, mainLayout.implicitWidth + 16)
                implicitHeight: Math.max(34, mainLayout.implicitHeight + 16)
                Component.onCompleted: introAnim.start()

                anchors {
                    bottom: true
                    left: true
                }

                margins {
                    bottom: 162
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
                    active: !win.isClosing && !win.isMenuOpen
                    windows: [win]
                    onCleared: {
                        win.closePopup();
                    }
                }

                Rectangle {
                    anchors.fill: parent
                    opacity: win.animOpacity
                    color: "#801d2021"
                    border.width: 1
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
                                width: 18
                                height: 18
                                color: "transparent"
                                radius: 2

                                QsMenuAnchor {
                                    id: menuAnchor

                                    menu: modelData.menu
                                    anchor.window: win
                                    anchor.rect: {
                                        var pt = parent.mapToItem(null, 0, 0);
                                        return Qt.rect(pt.x, pt.y, parent.width, parent.height);
                                    }
                                    onVisibleChanged: {
                                        win.isMenuOpen = visible;
                                    }
                                }

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
                                            if (modelData.hasMenu)
                                                menuAnchor.open();

                                        } else {
                                            if (modelData.hasMenu && modelData.onlyMenu)
                                                menuAnchor.open();
                                            else
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
