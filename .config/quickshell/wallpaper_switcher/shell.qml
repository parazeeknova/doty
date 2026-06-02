import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland

Scope {
    id: root

    property string animeDir: "/home/parazeeknova/Pictures/Anime"
    property var wallpapers: []
    property string activeWallpaper: ""
    property string lastWallpaperPath: ""
    property int selectedIndex: -2
    property bool isReady: false
    property bool lastWallpaperLoaded: false

    onWallpapersChanged: {
        root.selectLastWallpaper();
    }

    function setLastWallpaper(path) {
        root.lastWallpaperLoaded = true;
        root.lastWallpaperPath = path;
        root.selectLastWallpaper();
    }

    function selectLastWallpaper() {
        if (!root.lastWallpaperLoaded || root.wallpapers.length === 0)
            return;

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

    signal requestClose()

    function scanWallpapers() {
        scanProc.running = false;
        scanProc.running = true;
    }

    function applyWallpaper(path) {
        root.activeWallpaper = path;
        applyTimer.restart();
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

        command: ["sh", "-c", "test -r /home/parazeeknova/.cache/last_wallpaper && cat /home/parazeeknova/.cache/last_wallpaper || true"]
        running: false

        stdout: StdioCollector {
            onStreamFinished: {
                root.setLastWallpaper(this.text.trim());
            }
        }
    }

    // Scan wallpapers and build small preview thumbnails so the UI never decodes full wallpapers.
    Process {
        id: scanProc

        command: ["sh", "-c", "thumb_dir=/home/parazeeknova/.cache/quickshell/wallpaper_switcher/thumbs\nmkdir -p \"$thumb_dir\"\nfind -L \"$1\" -maxdepth 1 -type f \\( -iname '*.jpg' -o -iname '*.png' -o -iname '*.jpeg' -o -iname '*.gif' \\) | sort | while IFS= read -r file; do\n  resolved=$(readlink -f \"$file\") || resolved=\"$file\"\n  hash=$(printf %s \"$resolved\" | sha256sum | cut -c 1-16)\n  thumb=\"$thumb_dir/$hash.jpg\"\n  if [ ! -s \"$thumb\" ] || [ \"$resolved\" -nt \"$thumb\" ]; then\n    magick \"$resolved\" -auto-orient -thumbnail '440x248^' -gravity center -extent 440x248 \"$thumb\" >/dev/null 2>&1 || thumb=\"$resolved\"\n  fi\n  printf '%s\\t%s\\n' \"$resolved\" \"$thumb\"\ndone", "sh", root.animeDir]
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
                            list.push({ "path": parts[0], "thumb": parts[1] });
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
                Quickshell.execDetached(["mkdir", "-p", "/home/parazeeknova/.cache"]);
                Quickshell.execDetached(["sh", "-c", "printf %s \"$1\" > /home/parazeeknova/.cache/last_wallpaper", "sh", root.activeWallpaper]);
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
                        return;

                    isClosing = true;
                    exitAnim.start();
                }

                screen: modelData
                color: "transparent"
                exclusionMode: PanelWindow.ExclusionMode.Ignore
                focusable: true
                WlrLayershell.namespace: "wallpaper_switcher"
                WlrLayershell.layer: WlrLayer.Overlay
                WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
                implicitWidth: 280
                implicitHeight: 650

                function initializeAndStart() {
                    if (hasInitialized)
                        return;

                    hasInitialized = true;
                    restoreTimer.start();
                    introAnim.start();
                }

                function restoreSelection() {
                    if (root.selectedIndex < 0 || root.selectedIndex >= root.wallpapers.length)
                        return;

                    listView.suppressApply = true;
                    listView.currentIndex = root.selectedIndex;
                    listView.positionViewAtIndex(root.selectedIndex, ListView.Center);
                    listView.suppressApply = false;
                    listView.isInitialized = true;
                }

                Connections {
                    target: root
                    function onRequestClose() {
                        win.closePopup();
                    }
                    function onIsReadyChanged() {
                        if (root.isReady) {
                            win.initializeAndStart();
                        }
                    }
                }

                Component.onCompleted: {
                    if (root.isReady) {
                        win.initializeAndStart();
                    }
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
                }

                margins {
                    left: win.animLeftMargin
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

                Item {
                    anchors.fill: parent
                    opacity: win.animOpacity
                    focus: true

                    Keys.onPressed: (event) => {
                        if (event.key === Qt.Key_Up) {
                            listView.decrementCurrentIndex();
                            event.accepted = true;
                        } else if (event.key === Qt.Key_Down) {
                            listView.incrementCurrentIndex();
                            event.accepted = true;
                        } else if (event.key === Qt.Key_Escape || event.key === Qt.Key_Enter || event.key === Qt.Key_Return) {
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
                            width: parent.width
                            height: parent.height - y - 10
                            clip: true
                            model: root.wallpapers
                            focus: false

                            property bool isInitialized: false
                            property bool suppressApply: false

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
                            header: Item {
                                width: listView.width
                                height: Math.max(0, listView.height / 2 - 68)
                            }
                            footer: Item {
                                width: listView.width
                                height: Math.max(0, listView.height / 2 - 68)
                            }

                            onCurrentIndexChanged: {
                                if (!isInitialized) return;
                                if (suppressApply) return;
                                if (root.selectedIndex === -2) return;
                                if (currentIndex >= 0 && currentIndex < root.wallpapers.length) {
                                    root.selectedIndex = currentIndex;
                                    root.applyWallpaper(root.wallpapers[currentIndex].path);
                                }
                            }

                            delegate: Item {
                                id: delegateItem
                                width: listView.width
                                height: 136

                                property string wallpaperPath: modelData.path
                                property string thumbnailPath: modelData.thumb
                                property real distance: Math.abs(index - listView.currentIndex)

                                // Dynamic scale, opacity, and curved horizontal offset
                                property real targetScale: Math.max(0.65, 1.0 - distance * 0.15)
                                property real targetOpacity: Math.max(0.15, 1.0 - distance * 0.35)
                                property real targetXOffset: -(distance * distance * 14)

                                scale: targetScale
                                opacity: targetOpacity
                                x: targetXOffset

                                Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
                                Behavior on opacity { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
                                Behavior on x { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }

                                Rectangle {
                                    width: 220
                                    height: 124
                                    anchors.centerIn: parent
                                    color: "#1d2021"
                                    radius: 8
                                    clip: true

                                    Image {
                                        id: wallpaperPreview

                                        anchors.fill: parent
                                        source: "file://" + thumbnailPath
                                        fillMode: Image.PreserveAspectCrop
                                        asynchronous: false
                                        cache: true
                                        smooth: true
                                    }
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        listView.currentIndex = index;
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
