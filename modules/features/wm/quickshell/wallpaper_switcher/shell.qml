import QtMultimedia
import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland

Scope {
    id: root

    property string homeDir: Quickshell.env("HOME")
    property string animeDir: homeDir + "/doty/modules/backgrounds"
    property var wallpapers: []
    property var filteredWallpapers: []
    property var searchIndex: []
    property string searchQuery: ""
    property string activeWallpaper: ""
    property string lastWallpaperPath: ""
    property int selectedIndex: -2
    property bool isReady: false
    property bool lastWallpaperLoaded: false
    property bool allowVideoPreview: false
    property bool isClearingSearch: false
    property int preSearchIndex: 0
    property string preSearchPath: ""

    signal requestClose

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

    function fuzzyScore(query, text) {
        var q = query.toLowerCase();
        var t = text.toLowerCase();
        if (t === q)
            return 1000;
        if (t.indexOf(q) === 0)
            return 800 + Math.max(0, 100 - t.length);
        if (t.indexOf(q) !== -1)
            return 600 + Math.max(0, 100 - t.length);

        var qi = 0;
        var score = 0;
        var lastMatch = -2;
        for (var ti = 0; ti < t.length && qi < q.length; ti++) {
            if (t[ti] === q[qi]) {
                score += 10;
                if (lastMatch === ti - 1)
                    score += 15;
                lastMatch = ti;
                qi++;
            }
        }
        if (qi === q.length) {
            score += 200;
            score += Math.floor((q.length / Math.max(1, t.length)) * 100);
            return score;
        }
        return -1;
    }

    function filterWallpapers() {
        if (searchQuery.trim() === "") {
            filteredWallpapers = wallpapers;
        } else {
            var q = searchQuery.trim().toLowerCase();
            var words = q.split(/\s+/);
            var hasIndex = searchIndex.length > 0;

            var scored = [];
            for (var i = 0; i < wallpapers.length; i++) {
                var wp = wallpapers[i];
                var stem = wp.path.split("/").pop().replace(/\.[^/.]+$/, "").toLowerCase();
                var totalScore = 0;
                var matched = true;

                for (var wi = 0; wi < words.length; wi++) {
                    var w = words[wi];
                    var bestScore = fuzzyScore(w, stem);

                    if (hasIndex && i < searchIndex.length) {
                        var entry = searchIndex[i];
                        for (var j = 0; j < entry.words.length; j++) {
                            var ws = fuzzyScore(w, entry.words[j]);
                            if (ws > bestScore)
                                bestScore = ws;
                        }
                    }

                    if (bestScore < 0) {
                        matched = false;
                        break;
                    }
                    totalScore += bestScore;
                }

                if (matched)
                    scored.push({
                        score: totalScore,
                        wp: wp
                    });
            }

            scored.sort(function (a, b) {
                return b.score - a.score;
            });
            var temp = [];
            for (var k = 0; k < scored.length; k++)
                temp.push(scored[k].wp);
            filteredWallpapers = temp;
        }

        listView.suppressApply = true;
        if (listView.count > 0) {
            listView.currentIndex = 0;
            listView.positionViewAtBeginning();
        }
        suppressResetTimer.restart();
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
        applyTimer.stop();
        root.activeWallpaper = path;
        Quickshell.execDetached([root.homeDir + "/doty/modules/scripts/set_wallpaper", path]);
        Quickshell.execDetached([root.homeDir + "/doty/modules/scripts/theme_switcher", "wallpaper", path]);
        Quickshell.execDetached(["mkdir", "-p", root.homeDir + "/.cache"]);
        Quickshell.execDetached(["sh", "-c", "printf %s \"$1\" > " + root.homeDir + "/.cache/last_wallpaper", "sh", path]);
        Qt.quit();
    }

    onWallpapersChanged: {
        root.selectLastWallpaper();
    }
    Component.onCompleted: {
        scanWallpapers();
    }

    Timer {
        id: videoPreviewDelayTimer

        interval: 200
        repeat: false
        running: true
        onTriggered: {
            root.allowVideoPreview = true;
        }
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

    FileView {
        id: lastWallpaperWatcher

        path: "file://" + root.homeDir + "/.cache/last_wallpaper"
        watchChanges: true
        onLoaded: {
            root.setLastWallpaper(lastWallpaperWatcher.text().trim());
        }
        onFileChanged: reload()
    }

    FileView {
        id: searchIndexWatcher

        path: "file://" + root.homeDir + "/.cache/quickshell/wallpaper_switcher/search_index.json"
        watchChanges: true
        onLoaded: {
            try {
                root.searchIndex = JSON.parse(searchIndexWatcher.text());
            } catch (e) {
                root.searchIndex = [];
            }
        }
        onFileChanged: reload()
    }

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
                root.filterWallpapers();
            }
        }
    }

    Timer {
        id: applyTimer

        interval: 260
        repeat: false
        running: false
        onTriggered: {
            if (root.activeWallpaper !== "")
                Quickshell.execDetached([root.homeDir + "/doty/modules/scripts/set_wallpaper", root.activeWallpaper]);
        }
    }

    Timer {
        id: searchDebounce

        interval: 80
        repeat: false
        onTriggered: root.filterWallpapers()
    }

    Timer {
        id: suppressResetTimer

        interval: 0
        repeat: false
        onTriggered: listView.suppressApply = false
    }

    Timer {
        id: clearResetTimer

        interval: 50
        repeat: false
        onTriggered: root.isClearingSearch = false
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

                    if (root.activeWallpaper !== "") {
                        Quickshell.execDetached([root.homeDir + "/doty/modules/scripts/set_wallpaper", root.activeWallpaper]);
                        Quickshell.execDetached([root.homeDir + "/doty/modules/scripts/theme_switcher", "wallpaper", root.activeWallpaper]);
                        Quickshell.execDetached(["mkdir", "-p", root.homeDir + "/.cache"]);
                        Quickshell.execDetached(["sh", "-c", "printf %s \"$1\" > " + root.homeDir + "/.cache/last_wallpaper", "sh", root.activeWallpaper]);
                    }

                    exitAnim.start();
                }

                function initializeAndStart() {
                    if (hasInitialized)
                        return;

                    hasInitialized = true;
                    restoreTimer.start();
                    introAnim.start();
                }

                function restoreSelection() {
                    if (root.selectedIndex < 0 || root.filteredWallpapers.length === 0)
                        return;

                    var restoredIndex = 0;
                    for (var i = 0; i < root.filteredWallpapers.length; i++) {
                        if (root.filteredWallpapers[i].path === root.wallpapers[root.selectedIndex].path) {
                            restoredIndex = i;
                            break;
                        }
                    }

                    listView.suppressApply = true;
                    listView.currentIndex = restoredIndex;
                    listView.positionViewAtIndex(restoredIndex, ListView.Center);
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

                    TextInput {
                        id: hiddenInput

                        width: 0
                        height: 0
                        opacity: 0
                        visible: false
                        focus: false
                        Keys.onPressed: event => {
                            if (event.key === Qt.Key_Escape) {
                                if (root.searchQuery !== "") {
                                    root.isClearingSearch = true;
                                    root.searchQuery = "";
                                    hiddenInput.text = "";
                                    root.filteredWallpapers = root.wallpapers;
                                    var restoreIdx = 0;
                                    if (root.preSearchPath !== "") {
                                        for (var i = 0; i < root.filteredWallpapers.length; i++) {
                                            if (root.filteredWallpapers[i].path === root.preSearchPath) {
                                                restoreIdx = i;
                                                break;
                                            }
                                        }
                                    } else {
                                        restoreIdx = root.preSearchIndex;
                                    }
                                    listView.currentIndex = restoreIdx;
                                    listView.positionViewAtIndex(restoreIdx, ListView.Center);
                                    clearResetTimer.restart();
                                    event.accepted = true;
                                } else {
                                    win.closePopup();
                                    event.accepted = true;
                                }
                            } else if (event.key === Qt.Key_Up) {
                                listView.decrementCurrentIndex();
                                event.accepted = true;
                            } else if (event.key === Qt.Key_Down) {
                                listView.incrementCurrentIndex();
                                event.accepted = true;
                            } else if (event.key === Qt.Key_Enter || event.key === Qt.Key_Return) {
                                if (listView.currentIndex >= 0 && listView.currentIndex < root.filteredWallpapers.length)
                                    root.confirmWallpaper(root.filteredWallpapers[listView.currentIndex].path);
                                else
                                    win.closePopup();
                                event.accepted = true;
                            } else if (event.key === Qt.Key_Backspace) {
                                var t = hiddenInput.text;
                                if (t.length > 0) {
                                    hiddenInput.text = t.substring(0, t.length - 1);
                                    root.searchQuery = hiddenInput.text;
                                    searchDebounce.restart();
                                }
                                event.accepted = true;
                            } else if (event.text !== "" && event.key !== Qt.Key_Shift && event.key !== Qt.Key_Control && event.key !== Qt.Key_Alt && event.key !== Qt.Key_Meta) {
                                hiddenInput.text += event.text;
                                root.searchQuery = hiddenInput.text;
                                searchDebounce.restart();
                                event.accepted = true;
                            }
                        }

                        onTextChanged: {
                            if (text.length === 1 && root.searchQuery === "") {
                                root.preSearchIndex = listView.currentIndex;
                                root.preSearchPath = (listView.currentIndex >= 0 && listView.currentIndex < root.filteredWallpapers.length) ? root.filteredWallpapers[listView.currentIndex].path : "";
                            }
                            root.searchQuery = text;
                            searchDebounce.restart();
                        }
                    }

                    Component.onCompleted: {
                        hiddenInput.forceActiveFocus();
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
                            model: root.filteredWallpapers
                            focus: false
                            highlight: null
                            highlightRangeMode: ListView.StrictlyEnforceRange
                            preferredHighlightBegin: height / 2 - 62
                            preferredHighlightEnd: height / 2 + 62
                            highlightMoveDuration: 220
                            highlightMoveVelocity: -1
                            highlightResizeDuration: 220
                            snapMode: ListView.SnapToItem
                            keyNavigationEnabled: false

                            add: Transition {
                                ParallelAnimation {
                                    NumberAnimation {
                                        property: "opacity"
                                        from: 0
                                        to: 1
                                        duration: 180
                                        easing.type: Easing.OutCubic
                                    }
                                    NumberAnimation {
                                        property: "scale"
                                        from: 0.7
                                        to: 1
                                        duration: 180
                                        easing.type: Easing.OutCubic
                                    }
                                    NumberAnimation {
                                        property: "x"
                                        from: 30
                                        to: 0
                                        duration: 180
                                        easing.type: Easing.OutCubic
                                    }
                                }
                            }

                            addDisplaced: Transition {
                                ParallelAnimation {
                                    NumberAnimation {
                                        property: "y"
                                        duration: 200
                                        easing.type: Easing.OutCubic
                                    }
                                    NumberAnimation {
                                        property: "scale"
                                        duration: 200
                                        easing.type: Easing.OutCubic
                                    }
                                    NumberAnimation {
                                        property: "opacity"
                                        duration: 200
                                        easing.type: Easing.OutCubic
                                    }
                                }
                            }

                            remove: Transition {
                                ParallelAnimation {
                                    NumberAnimation {
                                        property: "opacity"
                                        from: 1
                                        to: 0
                                        duration: 150
                                        easing.type: Easing.InCubic
                                    }
                                    NumberAnimation {
                                        property: "scale"
                                        from: 1
                                        to: 0.7
                                        duration: 150
                                        easing.type: Easing.InCubic
                                    }
                                }
                            }

                            removeDisplaced: Transition {
                                ParallelAnimation {
                                    NumberAnimation {
                                        property: "y"
                                        duration: 200
                                        easing.type: Easing.OutCubic
                                    }
                                    NumberAnimation {
                                        property: "scale"
                                        duration: 200
                                        easing.type: Easing.OutCubic
                                    }
                                    NumberAnimation {
                                        property: "opacity"
                                        duration: 200
                                        easing.type: Easing.OutCubic
                                    }
                                }
                            }

                            onCurrentIndexChanged: {
                                if (!isInitialized)
                                    return;

                                if (suppressApply || root.isClearingSearch)
                                    return;

                                if (root.selectedIndex === -2)
                                    return;

                                if (currentIndex >= 0 && currentIndex < root.filteredWallpapers.length) {
                                    root.selectedIndex = currentIndex;
                                    root.applyWallpaper(root.filteredWallpapers[currentIndex].path);
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
                                property real targetScale: Math.max(0.65, 1 - distance * 0.15)
                                property real targetOpacity: Math.max(0.15, 1 - distance * 0.35)
                                property real targetXOffset: -(distance * distance * 14)
                                property var colorsList: ["#a9b665", "#7daea3", "#d8a657", "#cc241d", "#1d2021", "#ebdbb2"]

                                width: listView.width
                                height: 136
                                scale: targetScale
                                opacity: targetOpacity
                                x: targetXOffset

                                FileView {
                                    id: colorReader

                                    path: "file://" + thumbnailPath.replace(/\.jpg$/, ".json")
                                    onLoaded: {
                                        try {
                                            var textVal = colorReader.text().trim();
                                            if (textVal.length === 0)
                                                return;

                                            var data = JSON.parse(textVal);
                                            if (data && data.colors) {
                                                var c = data.colors;
                                                delegateItem.colorsList = [c.primary ? c.primary.default.color : "#a9b665", c.secondary ? c.secondary.default.color : "#7daea3", c.tertiary ? c.tertiary.default.color : "#d8a657", c.error ? c.error.default.color : "#cc241d", c.surface ? c.surface.default.color : "#1d2021", c.on_surface ? c.on_surface.default.color : "#ebdbb2"];
                                            }
                                        } catch (e) {}
                                    }
                                }

                                Rectangle {
                                    id: previewRect

                                    width: 212
                                    height: 124
                                    anchors.left: parent.left
                                    anchors.leftMargin: 12
                                    anchors.verticalCenter: parent.verticalCenter
                                    color: theme.bg
                                    clip: true

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
                                        asynchronous: true
                                        cache: true
                                        smooth: true
                                    }

                                    Rectangle {
                                        id: videoIndicator

                                        width: 38
                                        height: 16
                                        radius: 4
                                        color: "#d32f2f"
                                        opacity: 0.9
                                        border.width: 1
                                        border.color: "#30ffffff"
                                        anchors.right: parent.right
                                        anchors.top: parent.top
                                        anchors.margins: 6
                                        z: 3
                                        visible: delegateItem.wallpaperPath.endsWith(".mp4") || delegateItem.wallpaperPath.endsWith(".webm")

                                        Row {
                                            anchors.centerIn: parent
                                            spacing: 3
                                            Text {
                                                text: "●"
                                                color: "#ffffff"
                                                font.pixelSize: 6
                                                anchors.verticalCenter: parent.verticalCenter
                                            }
                                            Text {
                                                text: "LIVE"
                                                color: "#ffffff"
                                                font.family: "FiraCode Nerd Font"
                                                font.pixelSize: 7
                                                font.bold: true
                                                anchors.verticalCenter: parent.verticalCenter
                                            }
                                        }
                                    }

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
                                        root.confirmWallpaper(root.filteredWallpapers[index].path);
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

                        // Search query indicator
                        Rectangle {
                            width: parent.width
                            height: root.searchQuery !== "" ? 24 : 0
                            color: "transparent"
                            clip: true

                            Behavior on height {
                                NumberAnimation {
                                    duration: 150
                                    easing.type: Easing.OutCubic
                                }
                            }

                            Text {
                                anchors.centerIn: parent
                                text: root.searchQuery
                                color: theme.accent
                                font.family: "FiraCode Nerd Font"
                                font.pixelSize: 9
                                opacity: 0.7
                                elide: Text.ElideRight
                                width: parent.width - 16
                                horizontalAlignment: Text.AlignHCenter

                                Behavior on opacity {
                                    NumberAnimation {
                                        duration: 120
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
