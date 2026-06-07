import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland

Scope {
    id: root

    property string homeDir: Quickshell.env("HOME")
    property string currentWallpaperPath: ""
    property string currentThemeMode: ""
    property string currentThemeValue: ""
    property bool glassEnabled: true
    property bool customWebThemeEnabled: true
    property var wallpapers: []
    property var presets: []
    property string lastPresetsJson: ""

    // Keyboard navigation state
    property int wallpaperFocusIndex: 0
    property int presetFocusIndex: 0
    property string lastFocus: "preset"

    // Clamp focus indices when the underlying lists change underneath us
    onWallpapersChanged: {
        if (root.wallpaperFocusIndex >= root.wallpapers.length && root.wallpapers.length > 0)
            root.wallpaperFocusIndex = root.wallpapers.length - 1;
    }
    onPresetsChanged: {
        var maxPreset = root.presets.length;
        if (root.presetFocusIndex > maxPreset)
            root.presetFocusIndex = maxPreset;
    }

    signal requestClose()

    // Apply both the actual wallpaper (awww) and the color scheme (theme_switcher).
    // These MUST be in sync — if only one runs, the screen and the colors drift apart.
    function applyWallpaper(path) {
        if (path === "")
            return ;
        root.currentWallpaperPath = path;
        root.currentThemeMode = "wallpaper";
        // awww first (sets the visible wallpaper), then theme_switcher (matugen from the same file).
        Quickshell.execDetached(["awww", "img", path]);
        Quickshell.execDetached([root.homeDir + "/doty/scripts/theme_switcher", "wallpaper", path]);
        Quickshell.execDetached(["sh", "-c", "printf %s \"$1\" > " + root.homeDir + "/.cache/last_wallpaper", "sh", path]);
    }

    Theme {
        id: theme
    }

    IpcHandler {
        function close() {
            root.requestClose();
        }

        target: "colorscheme_popup"
    }

    // File watchers
    FileView {
        id: lastWallpaperWatcher

        path: "file://" + root.homeDir + "/.cache/last_wallpaper"
        watchChanges: true
        onLoaded: {
            root.currentWallpaperPath = lastWallpaperWatcher.text().trim();
        }
        onFileChanged: reload()
    }

    FileView {
        id: lastThemeWatcher

        path: "file://" + root.homeDir + "/.cache/quickshell/last_theme"
        watchChanges: true
        onLoaded: {
            var val = lastThemeWatcher.text().trim();
            var parts = val.split(" ");
            if (parts.length >= 2) {
                root.currentThemeMode = parts[0];
                root.currentThemeValue = parts.slice(1).join(" ");
            }
        }
        onFileChanged: reload()
    }

    FileView {
        id: glassWatcher

        path: "file:///tmp/quickshell_glass_state"
        watchChanges: true
        onLoaded: {
            root.glassEnabled = (glassWatcher.text().trim() !== "false");
        }
        onFileChanged: reload()
    }

    FileView {
        id: webThemeWatcher

        path: "file://" + root.homeDir + "/.cache/quickshell/custom_web_theme_state"
        watchChanges: true
        onLoaded: {
            root.customWebThemeEnabled = (webThemeWatcher.text().trim() !== "false");
        }
        onFileChanged: reload()
    }

    // Watch presets dir for add/remove (directory mtime changes when entries change)
    FileView {
        id: presetsDirWatcher

        path: "file://" + root.homeDir + "/doty/.config/hypr/wabi/presets"
        watchChanges: true
        onFileChanged: presetsLister.running = true
        onLoaded: presetsLister.running = true
    }

    // Run lister immediately when popup finishes loading (no delay on open).
    Component.onCompleted: presetsLister.running = true

    // Wallpaper thumb process (existing)
    Process {
        id: scanProc

        command: [root.homeDir + "/.config/quickshell/wallpaper_switcher/wallpaper_thumb_watcher", "--print"]
        running: true

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

    // Presets list process
    Process {
        id: presetsLister

        command: [root.homeDir + "/doty/scripts/presets_lister"]
        running: false

        stdout: StdioCollector {
            onStreamFinished: {
                // Skip reassignment if the data hasn't changed — avoids Repeater rebuilds.
                if (this.text === root.lastPresetsJson)
                    return ;
                root.lastPresetsJson = this.text;
                try {
                    var parsed = JSON.parse(this.text);
                    if (Array.isArray(parsed)) {
                        root.presets = parsed;
                    }
                } catch (e) {
                    console.warn("presets_lister parse error:", e);
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
                property real animLeftMargin: -260
                property real animOpacity: 0

                function closePopup() {
                    if (isClosing)
                        return ;

                    isClosing = true;
                    exitAnim.start();
                }

                screen: modelData
                color: "transparent"
                Component.onCompleted: {
                    introAnim.start();
                }
                exclusionMode: PanelWindow.ExclusionMode.Ignore
                focusable: true
                implicitWidth: 240
                implicitHeight: mainLayout.implicitHeight + 20

                Connections {
                    function onRequestClose() {
                        win.closePopup();
                    }

                    target: root
                }

                anchors {
                    left: true
                }

                margins {
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
                            return ;
                        }
                        if (event.key === Qt.Key_Right || event.key === Qt.Key_L) {
                            if (root.wallpapers.length > 0) {
                                root.wallpaperFocusIndex = Math.min(root.wallpaperFocusIndex + 1, root.wallpapers.length - 1);
                                root.lastFocus = "wallpaper";
                            }
                            event.accepted = true;
                        } else if (event.key === Qt.Key_Left || event.key === Qt.Key_H) {
                            if (root.wallpapers.length > 0) {
                                root.wallpaperFocusIndex = Math.max(root.wallpaperFocusIndex - 1, 0);
                                root.lastFocus = "wallpaper";
                            }
                            event.accepted = true;
                        } else if (event.key === Qt.Key_Down || event.key === Qt.Key_J) {
                            var maxPreset = root.presets.length;
                            if (maxPreset >= 0) {
                                root.presetFocusIndex = Math.min(root.presetFocusIndex + 1, maxPreset);
                                root.lastFocus = "preset";
                            }
                            event.accepted = true;
                        } else if (event.key === Qt.Key_Up || event.key === Qt.Key_K) {
                            if (root.presets.length >= 0) {
                                root.presetFocusIndex = Math.max(root.presetFocusIndex - 1, 0);
                                root.lastFocus = "preset";
                            }
                            event.accepted = true;
                        } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                            if (root.lastFocus === "wallpaper" && root.wallpapers.length > 0) {
                                var wp = root.wallpapers[root.wallpaperFocusIndex];
                                if (wp) {
                                    root.applyWallpaper(wp.path);
                                    win.closePopup();
                                }
                            } else if (root.lastFocus === "preset") {
                                if (root.presetFocusIndex === 0) {
                                    if (root.currentWallpaperPath !== "") {
                                        root.applyWallpaper(root.currentWallpaperPath);
                                        win.closePopup();
                                    }
                                } else {
                                    var p = root.presets[root.presetFocusIndex - 1];
                                    if (p) {
                                        Quickshell.execDetached([root.homeDir + "/doty/scripts/theme_switcher", "preset", p.name]);
                                        win.closePopup();
                                    }
                                }
                            }
                            event.accepted = true;
                        }
                    }
                    Component.onCompleted: {
                        forceActiveFocus();
                    }

                    Column {
                        id: mainLayout

                        anchors.top: parent.top
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.margins: 10
                        spacing: 12

                        // --- SECTION 1: ACTIVE WALLPAPER + COLOR PREVIEW ---
                        Rectangle {
                            width: parent.width
                            height: 60
                            color: theme.bg_dark
                            border.width: 1
                            border.color: (root.currentThemeMode === "wallpaper") ? theme.accent : theme.bg_light
                            clip: true

                            Image {
                                anchors.fill: parent
                                source: root.currentWallpaperPath !== "" ? ("file://" + root.currentWallpaperPath) : ""
                                fillMode: Image.PreserveAspectCrop
                                asynchronous: true
                            }

                            Rectangle {
                                anchors.bottom: parent.bottom
                                width: parent.width
                                height: 28
                                border.width: 0

                                Row {
                                    anchors.fill: parent
                                    anchors.leftMargin: 6
                                    anchors.rightMargin: 6
                                    spacing: 8

                                    Text {
                                        text: {
                                            if (root.currentWallpaperPath === "")
                                                return "No Wallpaper";

                                            var parts = root.currentWallpaperPath.split("/");
                                            return parts[parts.length - 1].replace(/\.[^/.]+$/, "");
                                        }
                                        color: theme.accent
                                        font.family: "FiraCode Nerd Font"
                                        font.pixelSize: 7
                                        font.bold: true
                                        elide: Text.ElideRight
                                        anchors.verticalCenter: parent.verticalCenter
                                        width: parent.width - 80
                                        renderType: Text.NativeRendering
                                    }

                                    Row {
                                        spacing: 3
                                        anchors.verticalCenter: parent.verticalCenter

                                        Repeater {
                                            model: [theme.bg, theme.bg_light, theme.fg, theme.accent, theme.secondary, theme.tertiary]

                                            delegate: Rectangle {
                                                width: 8
                                                height: 8
                                                color: modelData
                                                border.width: 1
                                                border.color: theme.bg_dark
                                            }

                                        }

                                    }

                                }

                                gradient: Gradient {
                                    GradientStop {
                                        position: 0
                                        color: "transparent"
                                    }

                                    GradientStop {
                                        position: 1
                                        color: Qt.rgba(theme.bg.r, theme.bg.g, theme.bg.b, 0.85)
                                    }

                                }

                            }

                            MouseArea {
                                anchors.fill: parent
                                onClicked: {
                                    if (root.currentWallpaperPath !== "") {
                                        root.applyWallpaper(root.currentWallpaperPath);
                                        win.closePopup();
                                    }
                                }
                            }

                        }

                        // --- SECTION 2: WALLPAPER TIMELINE ---
                        Column {
                            width: parent.width
                            spacing: 4

                            Text {
                                text: "Wallpapers (" + root.wallpapers.length + ")"
                                color: theme.accent
                                font.family: "FiraCode Nerd Font"
                                font.pixelSize: 8
                                font.bold: true
                                opacity: 0.5
                                renderType: Text.NativeRendering
                            }

                            Rectangle {
                                width: parent.width
                                height: 32
                                radius: 4
                                clip: true

                                gradient: Gradient {
                                    orientation: Gradient.Horizontal
                                    GradientStop { position: 0.0; color: Qt.rgba(theme.bg_dark.r, theme.bg_dark.g, theme.bg_dark.b, 0.55) }
                                    GradientStop { position: 0.5; color: Qt.rgba(theme.bg_light.r, theme.bg_light.g, theme.bg_light.b, 0.2) }
                                    GradientStop { position: 1.0; color: Qt.rgba(theme.bg_dark.r, theme.bg_dark.g, theme.bg_dark.b, 0.55) }
                                }

                                Row {
                                    anchors.fill: parent
                                    spacing: 4

                                    Rectangle {
                                        width: 12
                                        height: 32
                                        color: leftBtnMouse.containsMouse ? theme.bg_light : "transparent"
                                        radius: 2
                                        Text {
                                            anchors.centerIn: parent
                                            text: ""
                                            color: leftBtnMouse.containsMouse ? theme.accent : theme.fg_light
                                            font.family: "FiraCode Nerd Font"
                                            font.pixelSize: 10
                                            renderType: Text.NativeRendering
                                        }
                                        MouseArea {
                                            id: leftBtnMouse
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            onClicked: {
                                                wallpaperTimeline.contentX = Math.max(0, wallpaperTimeline.contentX - 100);
                                            }
                                        }
                                    }

                                    ListView {
                                        id: wallpaperTimeline

                                        width: parent.width - 32
                                        height: 32
                                        orientation: ListView.Horizontal
                                        spacing: 6
                                        clip: true
                                        model: root.wallpapers

                                        Behavior on contentX {
                                            NumberAnimation { duration: 180; easing.type: Easing.OutQuad }
                                        }

                                        delegate: Rectangle {
                                            required property int index
                                            required property var modelData
                                            width: 32
                                            height: 32
                                            color: "transparent"
                                            border.width: (root.wallpaperFocusIndex === index) ? 2 : 1
                                            border.color: (root.wallpaperFocusIndex === index || root.currentWallpaperPath === modelData.path) ? theme.accent : theme.bg_light
                                            clip: true
                                            opacity: (root.currentWallpaperPath === modelData.path || hoverMouseArea.containsMouse || root.wallpaperFocusIndex === index) ? 1.0 : 0.7

                                            Behavior on opacity {
                                                NumberAnimation { duration: 150 }
                                            }

                                            Image {
                                                anchors.fill: parent
                                                source: "file://" + modelData.thumb
                                                fillMode: Image.PreserveAspectCrop
                                                asynchronous: true
                                            }

                                            Rectangle {
                                                id: hoverOverlay

                                                anchors.fill: parent
                                                color: Qt.rgba(theme.bg.r, theme.bg.g, theme.bg.b, 0.75)
                                                visible: hoverMouseArea.containsMouse

                                                Text {
                                                    anchors.centerIn: parent
                                                    text: "󰸉"
                                                    color: theme.accent
                                                    font.family: "FiraCode Nerd Font"
                                                    font.pixelSize: 10
                                                    renderType: Text.NativeRendering
                                                }

                                            }

                                            MouseArea {
                                                id: hoverMouseArea

                                                anchors.fill: parent
                                                hoverEnabled: true
                                                onClicked: {
                                                    root.wallpaperFocusIndex = index;
                                                    root.lastFocus = "wallpaper";
                                                    root.applyWallpaper(modelData.path);
                                                    win.closePopup();
                                                }
                                            }

                                        }

                                    }

                                    Rectangle {
                                        width: 12
                                        height: 32
                                        color: rightBtnMouse.containsMouse ? theme.bg_light : "transparent"
                                        radius: 2
                                        Text {
                                            anchors.centerIn: parent
                                            text: ""
                                            color: rightBtnMouse.containsMouse ? theme.accent : theme.fg_light
                                            font.family: "FiraCode Nerd Font"
                                            font.pixelSize: 10
                                            renderType: Text.NativeRendering
                                        }
                                        MouseArea {
                                            id: rightBtnMouse
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            onClicked: {
                                                wallpaperTimeline.contentX = Math.min(wallpaperTimeline.contentWidth - wallpaperTimeline.width, wallpaperTimeline.contentX + 100);
                                            }
                                        }
                                    }
                                }
                            }

                        }

                        // --- SECTION 3: PRESETS ---
                        Column {
                            width: parent.width
                            spacing: 6

                            Text {
                                text: "Presets (" + (root.presets.length + 1) + ")"
                                color: theme.accent
                                font.family: "FiraCode Nerd Font"
                                font.pixelSize: 8
                                font.bold: true
                                opacity: 0.5
                                renderType: Text.NativeRendering
                            }

                            Item {
                                width: parent.width
                                height: Math.min(168, (root.presets.length + 1) * 14)

                                ListView {
                                    id: presetListView
                                    anchors.fill: parent
                                    anchors.rightMargin: scrollbar.visible ? 4 : 0
                                    clip: true
                                    model: root.presets
                                    boundsBehavior: Flickable.StopAtBounds

                                    Connections {
                                        target: root
                                        function onPresetFocusIndexChanged() {
                                            if (root.presetFocusIndex === 0) {
                                                presetListView.positionViewAtIndex(0, ListView.Beginning);
                                            } else {
                                                presetListView.positionViewAtIndex(root.presetFocusIndex - 1, ListView.Contain);
                                            }
                                        }
                                    }

                                    header: PresetRow {
                                        width: presetListView.width
                                        rowName: "Auto"
                                        rowActive: (root.currentThemeMode === "wallpaper")
                                        rowFocused: (root.presetFocusIndex === 0)
                                        dotColors: [theme.bg, theme.bg_light, theme.fg, theme.accent, theme.secondary, theme.tertiary]
                                        onTriggered: {
                                            root.presetFocusIndex = 0;
                                            root.lastFocus = "preset";
                                            root.currentThemeMode = "wallpaper";
                                            if (root.currentWallpaperPath !== "") {
                                                root.applyWallpaper(root.currentWallpaperPath);
                                                win.closePopup();
                                            }
                                        }
                                    }

                                    delegate: PresetRow {
                                        required property var modelData
                                        required property int index
                                        width: presetListView.width
                                        rowName: modelData.name
                                        rowActive: (root.currentThemeMode === "preset" && root.currentThemeValue === modelData.name)
                                        rowFocused: (root.presetFocusIndex === index + 1)
                                        dotColors: [modelData.colors.surface, modelData.colors.surface_variant, modelData.colors.on_surface, modelData.colors.primary, modelData.colors.secondary, modelData.colors.tertiary]
                                        onTriggered: {
                                            root.presetFocusIndex = index + 1;
                                            root.lastFocus = "preset";
                                            root.currentThemeMode = "preset";
                                            root.currentThemeValue = modelData.name;
                                            Quickshell.execDetached([root.homeDir + "/doty/scripts/theme_switcher", "preset", modelData.name]);
                                            win.closePopup();
                                        }
                                    }
                                }

                                Rectangle {
                                    id: scrollbar
                                    anchors.right: parent.right
                                    anchors.top: parent.top
                                    anchors.bottom: parent.bottom
                                    width: 1
                                    color: "transparent"
                                    visible: presetListView.contentHeight > presetListView.height

                                    Rectangle {
                                        width: parent.width
                                        height: Math.max(10, (presetListView.height / presetListView.contentHeight) * presetListView.height)
                                        y: (presetListView.contentY / presetListView.contentHeight) * presetListView.height
                                        color: theme.accent
                                        opacity: 0.6
                                        radius: 0.5
                                    }
                                }

                                // Empty state hint
                                Text {
                                    visible: root.presets.length === 0
                                    text: "(no .toml presets found)"
                                    color: theme.fg_light
                                    opacity: 0.5
                                    font.family: "FiraCode Nerd Font"
                                    font.pixelSize: 7
                                    font.italic: true
                                    renderType: Text.NativeRendering
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    topPadding: 4
                                }
                            }
                        }

                        // --- SECTION 4: GLASS BLUR TOGGLE ---
                        MouseArea {
                            width: parent.width
                            height: 14
                            onClicked: {
                                Quickshell.execDetached([root.homeDir + "/doty/.config/rofi/scripts/toggle_glass"]);
                            }

                            Row {
                                anchors.fill: parent
                                spacing: 8

                                Text {
                                    text: "Glass Blur Mode"
                                    color: theme.accent
                                    font.family: "FiraCode Nerd Font"
                                    font.pixelSize: 8
                                    font.bold: false
                                    renderType: Text.NativeRendering
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: parent.width - 36
                                }

                                Rectangle {
                                    width: 28
                                    height: 12
                                    color: root.glassEnabled ? theme.accent : theme.bg_light
                                    border.color: theme.accent
                                    border.width: 1
                                    anchors.verticalCenter: parent.verticalCenter

                                    Rectangle {
                                        width: 8
                                        height: 8
                                        color: root.glassEnabled ? theme.bg : theme.accent
                                        anchors.verticalCenter: parent.verticalCenter
                                        x: root.glassEnabled ? 18 : 2

                                        Behavior on x {
                                            NumberAnimation {
                                                duration: 150
                                                easing.type: Easing.OutQuad
                                            }

                                        }

                                    }

                                    Behavior on color {
                                        ColorAnimation {
                                            duration: 150
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
