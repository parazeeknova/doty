import QtQuick
import Quickshell.Io

QtObject {
    id: theme

    property color bg: "#1a1a2e"
    property color bg_dark: "#16162a"
    property color bg_light: "#222240"
    property color fg: "#c8c8e0"
    property color fg_light: "#e0e0f0"
    property color accent: "#7aa2f7"
    property color secondary: "#7aa2f7"
    property color tertiary: "#bb9af7"
    property color error: "#f7768e"

    property bool glassEnabled: true
    property color popupBgColor: glassEnabled ? Qt.rgba(0.1, 0.1, 0.18, 0.65) : bg

    property string fontName: "FiraCode Nerd Font"
}
