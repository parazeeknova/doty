import QtQuick
import Quickshell.Io
import "file:///home/parazeeknova/.cache/quickshell" as ThemeCache

QtObject {
    id: theme

    property ThemeCache.Colors c: ThemeCache.Colors {}

    property bool glassEnabled: true
    property color popupBgColor: glassEnabled ? Qt.rgba(c.bg.r, c.bg.g, c.bg.b, 0.5) : c.bg
    Behavior on popupBgColor { ColorAnimation { duration: 300 } }

    property color podmanBgColor: glassEnabled ? Qt.rgba(c.bg.r, c.bg.g, c.bg.b, 0.9) : c.bg
    Behavior on podmanBgColor { ColorAnimation { duration: 300 } }

    property color trayBgColor: glassEnabled ? Qt.rgba(c.bg.r, c.bg.g, c.bg.b, 0.95) : c.bg
    Behavior on trayBgColor { ColorAnimation { duration: 300 } }
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

}
