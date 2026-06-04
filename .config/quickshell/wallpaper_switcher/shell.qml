import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland

Scope {
    id: root

    property string homeDir: Quickshell.env("HOME")
    property string animeDir: homeDir + "/Pictures/Anime"
    property var wallpapers: []
    property string activeWallpaper: ""
    property string lastWallpaperPath: ""
    property int selectedIndex: -2
    property bool isReady: false
    property bool lastWallpaperLoaded: false

    signal requestClose()

    function setLastWallpaper(path) {
        root.lastWallpaperLoaded = true;
        root.lastWallpaperPath = path;
        root.selectLastWallpaper();
    }

    function selectLastWallpaper() {
        if (!root.lastWallpaperLoaded || root.wallpapers.length === 0)
            return ;

        var indexToSelect = 0;
        if (root.lastWallpaperPath !== "") {
            for (var i = 0; i < root.wallpapers.length; i++) {
                if (root.wallpapers[i].path === root.lastWallpaperPath) {
                    indexToSelect = i;
                    break;
                }
            }
        }
        root.selectedIndex = indexToSelect;
        root.isReady = true;
    }

    function scanWallpapers() {
        scanProc.running = false;
        scanProc.running = true;
    }

    function applyWallpaper(path) {
        root.activeWallpaper = path;
        applyTimer.restart();
    }

    function confirmWallpaper(path) {
        // Cancel any pending preview awww call so it can't overwrite our confirmed path.
        applyTimer.stop();
        root.activeWallpaper = path;

        // Set the actual wallpaper (awww) AND the color scheme (theme_switcher) atomically.
        // If we only run one, the screen and the colors drift apart — the preview path
        // calls awww on a 260ms debounce, which is skipped when the user confirms fast.
        Quickshell.execDetached(["awww", "img", path]);
        Quickshell.execDetached([root.homeDir + "/doty/scripts/theme_switcher", "wallpaper", path]);
        Quickshell.execDetached(["mkdir", "-p", root.homeDir + "/.cache"]);
        Quickshell.execDetached(["sh", "-c", "printf %s \"$1\" > " + root.homeDir + "/.cache/last_wallpaper", "sh", path]);
        Qt.quit();
    }

    onWallpapersChanged: {
        root.selectLastWallpaper();
    }
    Component.onCompleted: {
        loadLastWallpaperProc.running = true;
        scanWallpapers();
    }


    Theme {
        id: theme
    }

    IpcHandler {
        function close() {
            root.requestClose();
        }

        target: "wallpaper_switcher"
    }

    Process {
        id: loadLastWallpaperProc

        command: ["sh", "-c", "test -r " + root.homeDir + "/.cache/last_wallpaper && cat " + root.homeDir + "/.cache/last_wallpaper || true"]
        running: false

        stdout: StdioCollector {
            onStreamFinished: {
                root.setLastWallpaper(this.text.trim());
            }
        }

    }

    // Scan wallpapers using the rust helper watcher in print mode for maximum speed.
    Process {
        id: scanProc

        command: [root.homeDir + "/.config/quickshell/wallpaper_switcher/wallpaper_thumb_watcher", "--print"]
        running: false

        stdout: StdioCollector {
            onStreamFinished: {
                var lines = this.text.split("\n");
                var list = [];
                for (var i = 0; i < lines.length; i++) {
                    var line = lines[i];
                    if (line.length > 0) {
                        var parts = line.split("\t");
                        if (parts.length >= 2)
                            list.push({
                            "path": parts[0],
                            "thumb": parts[1]
                        });

                    }
                }
                root.wallpapers = list;
            }
        }

    }

    // Debounce wallpaper application so process spawning does not fight scroll animation.
    Timer {
        id: applyTimer

        interval: 260
        repeat: false
        running: false
        onTriggered: {
            if (root.activeWallpaper !== "") {
                Quickshell.execDetached(["awww", "img", root.activeWallpaper]);
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
                property real animLeftMargin: -300
                property real animOpacity: 0
                property bool hasInitialized: false

                function closePopup() {
                    if (isClosing)
                        return ;

                    isClosing = true;
                    exitAnim.start();
                }

                function initializeAndStart() {
                    if (hasInitialized)
                        return ;

                    hasInitialized = true;
                    restoreTimer.start();
                    introAnim.start();
                }

                function restoreSelection() {
                    if (root.selectedIndex < 0 || root.selectedIndex >= root.wallpapers.length)
                        return ;

                    listView.suppressApply = true;
                    listView.currentIndex = root.selectedIndex;
                    listView.positionViewAtIndex(root.selectedIndex, ListView.Center);
                    listView.suppressApply = false;
                    listView.isInitialized = true;
                }

                screen: modelData
                color: "transparent"
                exclusionMode: PanelWindow.ExclusionMode.Ignore
                focusable: true
                WlrLayershell.namespace: "wallpaper_switcher"
                WlrLayershell.layer: WlrLayer.Overlay
                WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
                implicitWidth: 280
                implicitHeight: 650
                Component.onCompleted: {
                    if (root.isReady)
                        win.initializeAndStart();

                }

                Connections {
                    function onRequestClose() {
                        win.closePopup();
                    }

                    function onIsReadyChanged() {
                        if (root.isReady)
                            win.initializeAndStart();

                    }

                    target: root
                }

                Timer {
                    id: restoreTimer

                    interval: 16
                    repeat: false
                    running: false
                    onTriggered: win.restoreSelection()
                }

                anchors {
                    left: true
                    right: true
                    top: true
                    bottom: true
                }

                // Slide-in + fade-in from the left (matching notification popup)
                ParallelAnimation {
                    id: introAnim

                    NumberAnimation {
                        target: win
                        property: "animLeftMargin"
                        from: -300
                        to: 32
                        duration: 140
                        easing.type: Easing.OutCubic
                    }

                    NumberAnimation {
                        target: win
                        property: "animOpacity"
                        from: 0
                        to: 1
                        duration: 140
                        easing.type: Easing.OutCubic
                    }

                }

                // Slide-out + fade-out to the left
                ParallelAnimation {
                    id: exitAnim

                    onStopped: Qt.quit()

                    NumberAnimation {
                        target: win
                        property: "animLeftMargin"
                        from: 32
                        to: -300
                        duration: 110
                        easing.type: Easing.InCubic
                    }

                    NumberAnimation {
                        target: win
                        property: "animOpacity"
                        from: 1
                        to: 0
                        duration: 110
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

                MouseArea {
                    anchors.fill: parent
                    onClicked: win.closePopup()
                }

                Item {
                    width: 280
                    height: 650
                    anchors.verticalCenter: parent.verticalCenter
                    x: win.animLeftMargin
                    opacity: win.animOpacity
                    focus: true
                    Keys.onPressed: (event) => {
                        if (event.key === Qt.Key_Up) {
                            listView.decrementCurrentIndex();
                            event.accepted = true;
                        } else if (event.key === Qt.Key_Down) {
                            listView.incrementCurrentIndex();
                            event.accepted = true;
                        } else if (event.key === Qt.Key_Enter || event.key === Qt.Key_Return) {
                            if (listView.currentIndex >= 0 && listView.currentIndex < root.wallpapers.length) {
                                root.confirmWallpaper(root.wallpapers[listView.currentIndex].path);
                            } else {
                                win.closePopup();
                            }
                            event.accepted = true;
                        } else if (event.key === Qt.Key_Escape) {
                            win.closePopup();
                            event.accepted = true;
                        }
                    }
                    Component.onCompleted: {
                        forceActiveFocus();
                    }

                    Column {
                        id: mainLayout

                        anchors.fill: parent
                        anchors.margins: 4
                        spacing: 0

                        // Vertical curved coverflow stack
                        ListView {
                            id: listView

                            property bool isInitialized: false
                            property bool suppressApply: false

                            width: parent.width
                            height: parent.height - y - 10
                            clip: true
                            model: root.wallpapers
                            focus: false
                            // Keep the active selection centered
                            highlight: null
                            highlightRangeMode: ListView.StrictlyEnforceRange
                            preferredHighlightBegin: height / 2 - 62
                            preferredHighlightEnd: height / 2 + 62
                            highlightMoveDuration: 220
                            highlightMoveVelocity: -1
                            highlightResizeDuration: 220
                            snapMode: ListView.SnapToItem
                            keyNavigationEnabled: false
                            onCurrentIndexChanged: {
                                if (!isInitialized)
                                    return ;

                                if (suppressApply)
                                    return ;

                                if (root.selectedIndex === -2)
                                    return ;

                                if (currentIndex >= 0 && currentIndex < root.wallpapers.length) {
                                    root.selectedIndex = currentIndex;
                                    root.applyWallpaper(root.wallpapers[currentIndex].path);
                                }
                            }

                            header: Item {
                                width: listView.width
                                height: Math.max(0, listView.height / 2 - 40)
                            }

                            footer: Item {
                                width: listView.width
                                height: Math.max(0, listView.height / 2 - 40)
                            }

                            delegate: Item {
                                id: delegateItem

                                property string wallpaperPath: modelData.path
                                property string thumbnailPath: modelData.thumb
                                property real distance: Math.abs(index - listView.currentIndex)
                                // Dynamic scale, opacity, and curved horizontal offset
                                property real targetScale: Math.max(0.65, 1 - distance * 0.15)
                                property real targetOpacity: Math.max(0.15, 1 - distance * 0.35)
                                property real targetXOffset: -(distance * distance * 14)

                                property var colorsList: ["#a9b665", "#7daea3", "#d8a657", "#cc241d", "#1d2021", "#ebdbb2"]

                                FileView {
                                    id: colorReader
                                    path: "file://" + thumbnailPath.replace(/\.jpg$/, ".json")
                                    onLoaded: {
                                        try {
                                            var textVal = colorReader.text().trim();
                                            if (textVal.length === 0) return;
                                            var data = JSON.parse(textVal);
                                            if (data && data.colors) {
                                                var c = data.colors;
                                                delegateItem.colorsList = [
                                                    c.primary ? c.primary.default.color : "#a9b665",
                                                    c.secondary ? c.secondary.default.color : "#7daea3",
                                                    c.tertiary ? c.tertiary.default.color : "#d8a657",
                                                    c.error ? c.error.default.color : "#cc241d",
                                                    c.surface ? c.surface.default.color : "#1d2021",
                                                    c.on_surface ? c.on_surface.default.color : "#ebdbb2"
                                                ];
                                            }
                                        } catch (e) {
                                            // ignore
                                        }
                                    }
                                }

                                width: listView.width
                                height: 136
                                scale: targetScale
                                opacity: targetOpacity
                                x: targetXOffset

                                Rectangle {
                                    id: previewRect
                                    width: 212
                                    height: 124
                                    anchors.left: parent.left
                                    anchors.leftMargin: 12
                                    anchors.verticalCenter: parent.verticalCenter
                                    color: theme.bg
                                    clip: true

                                    // Border overlay for the currently selected/applied wallpaper
                                    Rectangle {
                                        anchors.fill: parent
                                        color: "transparent"
                                        border.width: index === listView.currentIndex ? 3 : 0
                                        border.color: theme.accent
                                        z: 2
                                    }

                                    Image {
                                        id: wallpaperPreview

                                        anchors.fill: parent
                                        source: "file://" + thumbnailPath
                                        fillMode: Image.PreserveAspectCrop
                                        asynchronous: false
                                        cache: true
                                        smooth: true
                                    }

                                    // Wallpaper Name Overlay at the bottom
                                    Rectangle {
                                        width: parent.width
                                        height: 18
                                        anchors.bottom: parent.bottom
                                        color: delegateItem.colorsList[4]
                                        opacity: 0.85

                                        Text {
                                            anchors.centerIn: parent
                                            text: {
                                                var parts = delegateItem.wallpaperPath.split("/");
                                                var filename = parts[parts.length - 1];
                                                return filename.replace(/\.[^/.]+$/, "");
                                            }
                                            color: delegateItem.colorsList[5]
                                            font.family: "FiraCode Nerd Font"
                                            font.pixelSize: 8
                                            elide: Text.ElideRight
                                            width: parent.width - 12
                                            horizontalAlignment: Text.AlignHCenter
                                            renderType: Text.NativeRendering
                                        }

                                    }

                                }

                                Column {
                                    id: colorColumn
                                    anchors.left: previewRect.right
                                    anchors.leftMargin: 8
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: 5

                                    Repeater {
                                        model: delegateItem.colorsList.slice(0, 5)
                                        delegate: Rectangle {
                                            width: 16
                                            height: 16
                                            color: modelData
                                            border.width: 1
                                            border.color: "#30ffffff"
                                        }
                                    }
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        listView.currentIndex = index;
                                    }
                                    onDoubleClicked: {
                                        listView.currentIndex = index;
                                        root.confirmWallpaper(root.wallpapers[index].path);
                                    }
                                }

                                Behavior on scale {
                                    NumberAnimation {
                                        duration: 150
                                        easing.type: Easing.OutCubic
                                    }

                                }

                                Behavior on opacity {
                                    NumberAnimation {
                                        duration: 150
                                        easing.type: Easing.OutCubic
                                    }

                                }

                                Behavior on x {
                                    NumberAnimation {
                                        duration: 150
                                        easing.type: Easing.OutCubic
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
