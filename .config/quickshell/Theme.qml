import QtQuick
import Quickshell.Io

QtObject {
    id: theme

    property string homeDir: Quickshell.env("HOME")
    property string cacheDir: homeDir + "/.cache/quickshell"

    property QtObject c: QtObject {
        property color bg: "#1d2021"
        property color bg_dark: "#18191a"
        property color bg_light: "#282a2e"
        property color fg: "#ebdbb2"
        property color fg_light: "#fbf1c7"
        property color accent: "#d79921"
        property color secondary: "#b8bb26"
        property color tertiary: "#928374"
        property color error: "#fb4934"
    }

    property color bg: c.bg
    Behavior on bg { ColorAnimation { duration: 350; easing.type: Easing.InOutQuad } }
    property color bg_dark: c.bg_dark
    Behavior on bg_dark { ColorAnimation { duration: 350; easing.type: Easing.InOutQuad } }
    property color bg_light: c.bg_light
    Behavior on bg_light { ColorAnimation { duration: 350; easing.type: Easing.InOutQuad } }
    property color fg: c.fg
    Behavior on fg { ColorAnimation { duration: 350; easing.type: Easing.InOutQuad } }
    property color fg_light: c.fg_light
    Behavior on fg_light { ColorAnimation { duration: 350; easing.type: Easing.InOutQuad } }
    property color accent: c.accent
    Behavior on accent { ColorAnimation { duration: 350; easing.type: Easing.InOutQuad } }
    property color secondary: c.secondary
    Behavior on secondary { ColorAnimation { duration: 350; easing.type: Easing.InOutQuad } }
    property color tertiary: c.tertiary
    Behavior on tertiary { ColorAnimation { duration: 350; easing.type: Easing.InOutQuad } }
    property color error: c.error
    Behavior on error { ColorAnimation { duration: 350; easing.type: Easing.InOutQuad } }

    property bool glassEnabled: true
    property color popupBgColor: glassEnabled ? Qt.rgba(bg.r, bg.g, bg.b, 0.5) : bg
    Behavior on popupBgColor { ColorAnimation { duration: 350; easing.type: Easing.InOutQuad } }

    property color podmanBgColor: glassEnabled ? Qt.rgba(bg.r, bg.g, bg.b, 0.9) : bg
    Behavior on podmanBgColor { ColorAnimation { duration: 350; easing.type: Easing.InOutQuad } }

    property color trayBgColor: glassEnabled ? Qt.rgba(bg.r, bg.g, bg.b, 0.95) : bg
    Behavior on trayBgColor { ColorAnimation { duration: 350; easing.type: Easing.InOutQuad } }

    property FileView glassState
    glassState: FileView {
        path: "file://" + cacheDir + "/glass_state"
        watchChanges: true
        onLoaded: {
            var val = glassState.text().trim();
            theme.glassEnabled = (val !== "false");
        }
        onFileChanged: reload()
    }

    property FileView colorsWatcher
    colorsWatcher: FileView {
        path: "file://" + cacheDir + "/colors.json"
        watchChanges: true
        onLoaded: {
            try {
                var textVal = colorsWatcher.text().trim();
                if (textVal.length === 0) return;
                var data = JSON.parse(textVal);
                if (data.bg) theme.bg = data.bg;
                if (data.bg_dark) theme.bg_dark = data.bg_dark;
                if (data.bg_light) theme.bg_light = data.bg_light;
                if (data.fg) theme.fg = data.fg;
                if (data.fg_light) theme.fg_light = data.fg_light;
                if (data.accent) theme.accent = data.accent;
                if (data.secondary) theme.secondary = data.secondary;
                if (data.tertiary) theme.tertiary = data.tertiary;
                if (data.error) theme.error = data.error;
            } catch (e) {
                // Ignore parse errors on empty or half-written files
            }
        }
        onFileChanged: reload()
    }
}
