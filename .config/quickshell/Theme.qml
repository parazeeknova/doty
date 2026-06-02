import QtQuick
import Quickshell.Io

QtObject {
    id: theme

    property bool glassEnabled: true
    property color popupBgColor: glassEnabled ? "#801d2021" : "#1d2021"
    Behavior on popupBgColor { ColorAnimation { duration: 300 } }

    property color podmanBgColor: glassEnabled ? "#e61d2021" : "#1d2021"
    Behavior on podmanBgColor { ColorAnimation { duration: 300 } }

    property color trayBgColor: glassEnabled ? "#f21d2021" : "#1d2021"
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
