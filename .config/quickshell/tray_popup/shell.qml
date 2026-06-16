//@ pragma UseQApplication
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Services.SystemTray

Scope {
    id: root

    property var openWindows: []

    Component.onCompleted: {
        SystemTray.isService = false;
    }

    IpcHandler {
        target: "tray_popup"

        function close(): void {
            for (var i = 0; i < root.openWindows.length; i++) {
                root.openWindows[i].closePopup();
            }
        }
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
                property real menuAnimOpacity: 0
                property real menuScale: 1.0
                property bool suppressCloseHandler: false
                property int selectedIconIndex: 0
                property int selectedMenuItemIndex: -1

                function nextMenuItemIndex(current, dir) {
                    var next = current + dir;
                    while (next >= 0 && next < menuOpener.children.values.length) {
                        if (!menuOpener.children.values[next].isSeparator)
                            return next;
                        next += dir;
                    }
                    return current;
                }

                function openMenu(menu, x) {
                    suppressCloseHandler = true;
                    menuCloseAnim.stop();
                    suppressCloseHandler = false;
                    win.activeMenu = menu;
                    win.menuX = x;
                    if (!win.isMenuOpen) {
                        menuAnimOpacity = 0;
                        menuScale = 0.92;
                        win.isMenuOpen = true;
                        win.selectedMenuItemIndex = win.nextMenuItemIndex(-1, 1);
                        menuOpenAnim.start();
                    }
                }

                function closeMenu() {
                    menuOpenAnim.stop();
                    menuCloseAnim.start();
                }

                function closePopup() {
                    if (isClosing)
                        return ;

                    isClosing = true;
                    exitAnim.start();
                }

                screen: modelData
                color: "transparent"
                exclusionMode: PanelWindow.ExclusionMode.Ignore
                WlrLayershell.namespace: "quickshell"
                WlrLayershell.layer: WlrLayer.Overlay
                WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
                focusable: true
                implicitWidth: 300
                implicitHeight: 300
                Component.onCompleted: {
                    introAnim.start();
                    root.openWindows.push(win);
                    keyHandler.forceActiveFocus();
                }

                onVisibleChanged: {
                    if (visible)
                        keyHandler.forceActiveFocus();
                }


                onIsClosingChanged: {
                    if (isClosing) {
                        var idx = root.openWindows.indexOf(win);
                        if (idx !== -1)
                            root.openWindows.splice(idx, 1);
                    }
                }

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

                ParallelAnimation {
                    id: menuOpenAnim

                    NumberAnimation {
                        target: win
                        property: "menuAnimOpacity"
                        to: 1
                        duration: 150
                        easing.type: Easing.OutCubic
                    }

                    NumberAnimation {
                        target: win
                        property: "menuScale"
                        to: 1.0
                        duration: 150
                        easing.type: Easing.OutCubic
                    }

                }

                ParallelAnimation {
                    id: menuCloseAnim

                    onStopped: {
                        if (!win.suppressCloseHandler)
                            win.isMenuOpen = false;
                    }

                    NumberAnimation {
                        target: win
                        property: "menuAnimOpacity"
                        to: 0
                        duration: 100
                        easing.type: Easing.InCubic
                    }

                    NumberAnimation {
                        target: win
                        property: "menuScale"
                        to: 0.92
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



                Item {
                    id: keyHandler

                    anchors.fill: parent
                    focus: true
                    activeFocusOnTab: true

                    Keys.onPressed: (event) => {
                        if (event.key === Qt.Key_Escape) {
                            if (win.isMenuOpen) {
                                win.closeMenu();
                            } else {
                                win.closePopup();
                            }
                            event.accepted = true;
                        } else if (win.isMenuOpen) {
                            if (event.key === Qt.Key_Up) {
                                win.selectedMenuItemIndex = win.nextMenuItemIndex(win.selectedMenuItemIndex, -1);
                                event.accepted = true;
                            } else if (event.key === Qt.Key_Down) {
                                win.selectedMenuItemIndex = win.nextMenuItemIndex(win.selectedMenuItemIndex, 1);
                                event.accepted = true;
                            } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Space) {
                                if (win.selectedMenuItemIndex >= 0 && win.selectedMenuItemIndex < menuOpener.children.values.length) {
                                    var item = menuOpener.children.values[win.selectedMenuItemIndex];
                                    if (item.enabled && !item.isSeparator) {
                                        item.triggered();
                                        win.closePopup();
                                    }
                                }
                                event.accepted = true;
                            } else if (event.key === Qt.Key_Left || event.key === Qt.Key_Right) {
                                win.closeMenu();
                                if (event.key === Qt.Key_Left)
                                    win.selectedIconIndex = Math.max(0, win.selectedIconIndex - 1);
                                else
                                    win.selectedIconIndex = Math.min(SystemTray.items.values.length - 1, win.selectedIconIndex + 1);
                                event.accepted = true;
                            }
                        } else {
                            if (event.key === Qt.Key_Left) {
                                win.selectedIconIndex = Math.max(0, win.selectedIconIndex - 1);
                                event.accepted = true;
                            } else if (event.key === Qt.Key_Right) {
                                win.selectedIconIndex = Math.min(SystemTray.items.values.length - 1, win.selectedIconIndex + 1);
                                event.accepted = true;
                            } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Space) {
                                var trayItem = SystemTray.items.values[win.selectedIconIndex];
                                if (trayItem) {
                                    if (trayItem.hasMenu) {
                                        var iconX = 8 + win.selectedIconIndex * 26;
                                        win.openMenu(trayItem.menu, iconX);
                                    } else {
                                        trayItem.activate();
                                        win.closePopup();
                                    }
                                }
                                event.accepted = true;
                            }
                        }
                    }
                }

                // Dismiss menu if user clicks in empty transparent area of window
                MouseArea {
                    anchors.fill: parent
                    visible: win.isMenuOpen
                    onClicked: {
                        win.closeMenu();
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
                    color: theme.trayBgColor
                    border.width: 1
                    border.color: theme.accent
                    radius: 0
                    opacity: menuAnimOpacity
                    scale: menuScale
                    transformOrigin: Item.Bottom
                    anchors.bottom: trayBar.top
                    anchors.bottomMargin: 8
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
                                color: (!modelData.isSeparator && index === win.selectedMenuItemIndex) ? "#30d5c4a1" : "transparent"

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
                                            color: (mouseArea.containsMouse || index === win.selectedMenuItemIndex) ? theme.accent : theme.fg
                                            font.bold: true
                                            font.pixelSize: 8
                                            visible: modelData.buttonType === 1 || modelData.buttonType === 2
                                        }

                                    }

                                    Text {
                                        text: modelData.text.replace(/&/g, "")
                                        color: modelData.enabled ? ((mouseArea.containsMouse || index === win.selectedMenuItemIndex) ? theme.accent : theme.fg) : theme.secondary
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
                                            win.closePopup();
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

                    anchors.bottom: parent.bottom
                    anchors.left: parent.left
                    width: Math.max(34, mainLayout.implicitWidth + 16)
                    height: Math.max(34, mainLayout.implicitHeight + 16)
                    opacity: win.animOpacity
                    color: theme.popupBgColor
                    border.width: 1
                    border.color: theme.accent
                    radius: 0
                    antialiasing: false

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

                            delegate:                                 Rectangle {
                                id: trayIconItem

                                width: 18
                                height: 18
                                color: (index === win.selectedIconIndex || trayIconMouse.containsMouse) ? "#30d5c4a1" : "transparent"
                                radius: 2

                                Image {
                                    anchors.fill: parent
                                    anchors.margins: 2
                                    source: modelData.icon
                                    fillMode: Image.PreserveAspectFit
                                }

                                MouseArea {
                                    id: trayIconMouse
                                    anchors.fill: parent
                                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                                    hoverEnabled: true
                                    onClicked: (mouse) => {
                                        if (mouse.button === Qt.RightButton) {
                                            if (modelData.hasMenu) {
                                                win.openMenu(modelData.menu, trayIconItem.mapToItem(win.contentItem, 0, 0).x);
                                            }
                                        } else {
                                            if (modelData.hasMenu && modelData.onlyMenu) {
                                                win.openMenu(modelData.menu, trayIconItem.mapToItem(win.contentItem, 0, 0).x);
                                            } else {
                                                modelData.activate();
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
