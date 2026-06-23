import QtQuick
import Quickshell.Io

QtObject {
    id: theme

    property bool animationsEnabled: false
    Component.onCompleted: {
        animationsEnabled = true;
    }

    property color bg: "#19120c"
    Behavior on bg { enabled: theme.animationsEnabled; ColorAnimation { duration: 350; easing.type: Easing.InOutQuad } }
    property color bg_dark: "#261e18"
    Behavior on bg_dark { enabled: theme.animationsEnabled; ColorAnimation { duration: 350; easing.type: Easing.InOutQuad } }
    property color bg_light: "#50453a"
    Behavior on bg_light { enabled: theme.animationsEnabled; ColorAnimation { duration: 350; easing.type: Easing.InOutQuad } }
    property color fg: "#eee0d5"
    Behavior on fg { enabled: theme.animationsEnabled; ColorAnimation { duration: 350; easing.type: Easing.InOutQuad } }
    property color fg_light: "#d5c3b5"
    Behavior on fg_light { enabled: theme.animationsEnabled; ColorAnimation { duration: 350; easing.type: Easing.InOutQuad } }
    property color accent: "#fcb974"
    Behavior on accent { enabled: theme.animationsEnabled; ColorAnimation { duration: 350; easing.type: Easing.InOutQuad } }
    property color secondary: "#e1c1a3"
    Behavior on secondary { enabled: theme.animationsEnabled; ColorAnimation { duration: 350; easing.type: Easing.InOutQuad } }
    property color tertiary: "#bfcc9b"
    Behavior on tertiary { enabled: theme.animationsEnabled; ColorAnimation { duration: 350; easing.type: Easing.InOutQuad } }
    property color error: "#ffb4ab"
    Behavior on error { enabled: theme.animationsEnabled; ColorAnimation { duration: 350; easing.type: Easing.InOutQuad } }

    property bool glassEnabled: true
    property color popupBgColor: glassEnabled ? Qt.rgba(bg.r, bg.g, bg.b, 0.5) : bg
    Behavior on popupBgColor { enabled: theme.animationsEnabled; ColorAnimation { duration: 350; easing.type: Easing.InOutQuad } }

    property color podmanBgColor: glassEnabled ? Qt.rgba(bg.r, bg.g, bg.b, 0.9) : bg
    Behavior on podmanBgColor { enabled: theme.animationsEnabled; ColorAnimation { duration: 350; easing.type: Easing.InOutQuad } }

    property color trayBgColor: glassEnabled ? Qt.rgba(bg.r, bg.g, bg.b, 0.95) : bg
    Behavior on trayBgColor { enabled: theme.animationsEnabled; ColorAnimation { duration: 350; easing.type: Easing.InOutQuad } }
    property FileView glassState

    glassState: FileView {
        path: "file:///tmp/quickshell_glass_state"
        watchChanges: true
        onLoaded: {
            var val = glassState.text().trim();
            theme.glassEnabled = (val !== "false");
        }
        onFileChanged: reload()
    }

    property string cacheDir: Quickshell.env("HOME") + "/.cache/quickshell"
    property FileView colorsWatcher

    colorsWatcher: FileView {
        path: "file://" + theme.cacheDir + "/colors.json"
        watchChanges: true
        onLoaded: {
            try {
                var textVal = colorsWatcher.text().trim();
                if (textVal.length === 0)
                    return;
                var data = JSON.parse(textVal);
                if (data.bg)
                    theme.bg = data.bg;
                if (data.bg_dark)
                    theme.bg_dark = data.bg_dark;
                if (data.bg_light)
                    theme.bg_light = data.bg_light;
                if (data.fg)
                    theme.fg = data.fg;
                if (data.fg_light)
                    theme.fg_light = data.fg_light;
                if (data.accent)
                    theme.accent = data.accent;
                if (data.secondary)
                    theme.secondary = data.secondary;
                if (data.tertiary)
                    theme.tertiary = data.tertiary;
                if (data.error)
                    theme.error = data.error;
            } catch (e) {
                // Ignore parse errors on empty or half-written files
            }
        }
        onFileChanged: reload()
    }
}
