import QtQuick
import Quickshell
import Quickshell.Io
import "file:///home/parazeeknova/.cache/quickshell" as ThemeCache

QtObject {
    id: theme

    property ThemeCache.Colors c: ThemeCache.Colors {}

    property bool animationsEnabled: false
    Component.onCompleted: {
        animationsEnabled = true;
    }

    property color bg: c.bg
    Behavior on bg {
        enabled: theme.animationsEnabled
        ColorAnimation {
            duration: 350
            easing.type: Easing.InOutQuad
        }
    }
    property color bg_dark: c.bg_dark
    Behavior on bg_dark {
        enabled: theme.animationsEnabled
        ColorAnimation {
            duration: 350
            easing.type: Easing.InOutQuad
        }
    }
    property color bg_light: c.bg_light
    Behavior on bg_light {
        enabled: theme.animationsEnabled
        ColorAnimation {
            duration: 350
            easing.type: Easing.InOutQuad
        }
    }
    property color fg: c.fg
    Behavior on fg {
        enabled: theme.animationsEnabled
        ColorAnimation {
            duration: 350
            easing.type: Easing.InOutQuad
        }
    }
    property color fg_light: c.fg_light
    Behavior on fg_light {
        enabled: theme.animationsEnabled
        ColorAnimation {
            duration: 350
            easing.type: Easing.InOutQuad
        }
    }
    property color accent: c.accent
    Behavior on accent {
        enabled: theme.animationsEnabled
        ColorAnimation {
            duration: 350
            easing.type: Easing.InOutQuad
        }
    }
    property color secondary: c.secondary
    Behavior on secondary {
        enabled: theme.animationsEnabled
        ColorAnimation {
            duration: 350
            easing.type: Easing.InOutQuad
        }
    }
    property color tertiary: c.tertiary
    Behavior on tertiary {
        enabled: theme.animationsEnabled
        ColorAnimation {
            duration: 350
            easing.type: Easing.InOutQuad
        }
    }
    property color error: c.error
    Behavior on error {
        enabled: theme.animationsEnabled
        ColorAnimation {
            duration: 350
            easing.type: Easing.InOutQuad
        }
    }

    property bool glassEnabled: (typeof c.glass !== "undefined") ? c.glass : false
    property color popupBgColor: glassEnabled ? Qt.rgba(bg.r, bg.g, bg.b, 0.5) : bg
    Behavior on popupBgColor {
        enabled: theme.animationsEnabled
        ColorAnimation {
            duration: 350
            easing.type: Easing.InOutQuad
        }
    }

    property color podmanBgColor: glassEnabled ? Qt.rgba(bg.r, bg.g, bg.b, 0.9) : bg
    Behavior on podmanBgColor {
        enabled: theme.animationsEnabled
        ColorAnimation {
            duration: 350
            easing.type: Easing.InOutQuad
        }
    }

    property color trayBgColor: glassEnabled ? Qt.rgba(bg.r, bg.g, bg.b, 0.95) : bg
    Behavior on trayBgColor {
        enabled: theme.animationsEnabled
        ColorAnimation {
            duration: 350
            easing.type: Easing.InOutQuad
        }
    }
    property FileView glassState

    glassState: FileView {
        path: "file:///tmp/quickshell_glass_state"
        watchChanges: true
        blockLoading: true
        preload: true
        onLoaded: {
            var val = glassState.text().trim();
            theme.glassEnabled = (val !== "false");
        }
        onFileChanged: reload()
    }

    // Layout mode (written by the layoutmode Hyprland plugin): popups dock
    // top-right while floating, keep their original edges while tiling.
    // Primary source: QS_LAYOUT_MODE env injected by the keybind launcher —
    // env reads are synchronous, so the value is correct at construction
    // (FileView reads are async and land AFTER windows map; that race made
    // popups flash with the wrong position/animation).
    // The FileView watcher keeps long-lived processes (osd) updated live.
    property bool floatingMode: Quickshell.env("QS_LAYOUT_MODE") === "floating"

    property FileView layoutMode

    layoutMode: FileView {
        path: "file:///home/parazeeknova/.cache/hypr_layout_mode"
        watchChanges: true
        onLoaded: {
            var v = layoutMode.text().trim();
            if (v !== "")
                theme.floatingMode = (v === "floating");
        }
        onFileChanged: reload()
    }

    property FileView colorsWatcher

    colorsWatcher: FileView {
        path: "file:///home/parazeeknova/.cache/quickshell/colors.json"
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
