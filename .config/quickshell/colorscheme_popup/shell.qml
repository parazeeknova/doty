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
    property var wallpapers: []

    signal requestClose()

    Theme {
        id: theme
    }

    IpcHandler {
        function close() {
            root.requestClose();
        }

        target: "colorscheme_popup"
    }

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

    // Process to scan wallpapers horizontally
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
                        if (event.key === Qt.Key_Escape)
                            win.closePopup();

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

                        // --- SECTION 1: CENTERED ACTIVE WALLPAPER WITH OVERLAY ---
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

                            // Bottom overlay displaying name and colors in a single row (gradient bg)
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
                                            var filename = parts[parts.length - 1];
                                            return filename.replace(/\.[^/.]+$/, "");
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

                                    // Color preview squares of current theme colors (increased to 8x8)
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
                                    if (root.currentWallpaperPath !== "")
                                        Quickshell.execDetached([root.homeDir + "/doty/scripts/theme_switcher", "wallpaper", root.currentWallpaperPath]);

                                }
                            }

                        }

                        // --- SECTION 2: HORIZONTAL TIMELINE OF WALLPAPERS ---
                        Column {
                            width: parent.width
                            spacing: 4

                            Text {
                                text: "Wallpapers"
                                color: theme.accent
                                font.family: "FiraCode Nerd Font"
                                font.pixelSize: 8
                                font.bold: true
                                opacity: 0.5
                                renderType: Text.NativeRendering
                            }

                            ListView {
                                id: wallpaperTimeline

                                width: parent.width
                                height: 32
                                orientation: ListView.Horizontal
                                spacing: 6
                                clip: true
                                model: root.wallpapers

                                delegate: Rectangle {
                                    width: 32
                                    height: 32
                                    color: theme.bg_dark
                                    border.width: 1
                                    border.color: (root.currentWallpaperPath === modelData.path) ? theme.accent : theme.bg_light
                                    clip: true

                                    Image {
                                        anchors.fill: parent
                                        source: "file://" + modelData.thumb
                                        fillMode: Image.PreserveAspectCrop
                                        asynchronous: true
                                    }

                                    // Hover apply overlay
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
                                            Quickshell.execDetached([root.homeDir + "/doty/scripts/theme_switcher", "wallpaper", modelData.path]);
                                        }
                                    }

                                }

                            }

                        }

                        // --- SECTION 3: PRESETS (TEXT ONLY WITH COLOR DOTS) ---
                        Column {
                            width: parent.width
                            spacing: 6

                            Text {
                                text: "Presets"
                                color: theme.accent
                                font.family: "FiraCode Nerd Font"
                                font.pixelSize: 8
                                font.bold: true
                                opacity: 0.5
                                renderType: Text.NativeRendering
                            }

                            Column {
                                width: parent.width
                                spacing: 0

                                // Auto (Wallpaper) Preset Row
                                Rectangle {
                                    width: parent.width
                                    height: 14
                                    color: autoMouse.containsMouse ? theme.bg_light : "transparent"

                                    MouseArea {
                                        id: autoMouse

                                        anchors.fill: parent
                                        hoverEnabled: true
                                        onClicked: {
                                            if (root.currentWallpaperPath !== "")
                                                Quickshell.execDetached([root.homeDir + "/doty/scripts/theme_switcher", "wallpaper", root.currentWallpaperPath]);

                                        }
                                    }

                                    Item {
                                        anchors.fill: parent
                                        anchors.leftMargin: 6
                                        anchors.rightMargin: 6

                                        Text {
                                            text: (root.currentThemeMode === "wallpaper") ? "Auto - active" : "Auto"
                                            color: (root.currentThemeMode === "wallpaper") ? theme.accent : theme.fg_light
                                            font.family: "FiraCode Nerd Font"
                                            font.pixelSize: 8
                                            font.bold: (root.currentThemeMode === "wallpaper")
                                            renderType: Text.NativeRendering
                                            anchors.verticalCenter: parent.verticalCenter
                                            anchors.left: parent.left
                                        }

                                        Row {
                                            spacing: 4
                                            anchors.verticalCenter: parent.verticalCenter
                                            anchors.right: parent.right

                                            Repeater {
                                                model: [theme.bg, theme.bg_light, theme.fg, theme.accent, theme.secondary, theme.tertiary]

                                                delegate: Rectangle {
                                                    width: 8
                                                    height: 8
                                                    color: modelData
                                                }

                                            }

                                        }

                                    }

                                }

                                // Everforest Preset Row
                                Rectangle {
                                    width: parent.width
                                    height: 14
                                    color: everforestMouse.containsMouse ? theme.bg_light : "transparent"

                                    MouseArea {
                                        id: everforestMouse

                                        anchors.fill: parent
                                        hoverEnabled: true
                                        onClicked: {
                                            Quickshell.execDetached([root.homeDir + "/doty/scripts/theme_switcher", "preset", "everforest"]);
                                        }
                                    }

                                    Item {
                                        anchors.fill: parent
                                        anchors.leftMargin: 6
                                        anchors.rightMargin: 6

                                        Text {
                                            text: (root.currentThemeMode === "preset" && root.currentThemeValue === "everforest") ? "Everforest - active" : "Everforest"
                                            color: (root.currentThemeMode === "preset" && root.currentThemeValue === "everforest") ? theme.accent : theme.fg_light
                                            font.family: "FiraCode Nerd Font"
                                            font.pixelSize: 8
                                            font.bold: (root.currentThemeMode === "preset" && root.currentThemeValue === "everforest")
                                            renderType: Text.NativeRendering
                                            anchors.verticalCenter: parent.verticalCenter
                                            anchors.left: parent.left
                                        }

                                        Row {
                                            spacing: 4
                                            anchors.verticalCenter: parent.verticalCenter
                                            anchors.right: parent.right

                                            Repeater {
                                                model: ["#2d353b", "#d3c6aa", "#a7c080", "#7fbbb3", "#dbbc7f", "#e67e80"]

                                                delegate: Rectangle {
                                                    width: 8
                                                    height: 8
                                                    color: modelData
                                                }

                                            }

                                        }

                                    }

                                }

                                // Gruvbox Preset Row
                                Rectangle {
                                    width: parent.width
                                    height: 14
                                    color: gruvboxMouse.containsMouse ? theme.bg_light : "transparent"

                                    MouseArea {
                                        id: gruvboxMouse

                                        anchors.fill: parent
                                        hoverEnabled: true
                                        onClicked: {
                                            Quickshell.execDetached([root.homeDir + "/doty/scripts/theme_switcher", "preset", "gruvbox"]);
                                        }
                                    }

                                    Item {
                                        anchors.fill: parent
                                        anchors.leftMargin: 6
                                        anchors.rightMargin: 6

                                        Text {
                                            text: (root.currentThemeMode === "preset" && root.currentThemeValue === "gruvbox") ? "Gruvbox - active" : "Gruvbox"
                                            color: (root.currentThemeMode === "preset" && root.currentThemeValue === "gruvbox") ? theme.accent : theme.fg_light
                                            font.family: "FiraCode Nerd Font"
                                            font.pixelSize: 8
                                            font.bold: (root.currentThemeMode === "preset" && root.currentThemeValue === "gruvbox")
                                            renderType: Text.NativeRendering
                                            anchors.verticalCenter: parent.verticalCenter
                                            anchors.left: parent.left
                                        }

                                        Row {
                                            spacing: 4
                                            anchors.verticalCenter: parent.verticalCenter
                                            anchors.right: parent.right

                                            Repeater {
                                                model: ["#1d2021", "#ebdbb2", "#a9b665", "#7daea3", "#d8a657", "#cc241d"]

                                                delegate: Rectangle {
                                                    width: 8
                                                    height: 8
                                                    color: modelData
                                                }

                                            }

                                        }

                                    }

                                }

                            }

                            // --- SECTION 4: GLASS BLUR SINGLE ROW SQUARE TOGGLE ---
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

                                    // Square switch toggle (square track + square thumb)
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

}
